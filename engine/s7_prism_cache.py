#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — Prism Cache (Phase 2 hot tier)
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
# Licensed under CWS-BSL-1.1
# Patent Pending: TPP99606 / CWS-005
# ═══════════════════════════════════════════════════════════════════
"""
T1 hot cache for the Prism matrix.

Phase 2 of the tiered storage strategy
(docs/internal/research/2026-04-13-tiered-storage-strategy.md).

Two backends, selected by S7_PRISM_CACHE_BACKEND env var or the
`backend=` argument:

  'local'       — process-local LRU (default). Sub-microsecond
                  hits, ephemeral, per-process. Lowest latency,
                  no persistence across process restarts.

  'redis-exec'  — redis-via-`podman exec`. Persistent across Python
                  process restarts, slower than local (~500 µs per
                  op because of podman exec overhead), but survives
                  reboots of the Python layer while the pod stays
                  up. Selected only when S7_PRISM_CACHE_BACKEND=
                  redis-exec is set, because podman exec has a cost
                  the caller should opt into explicitly.

Both backends expose the same interface:
  cache.get(cell_tuple)    → row_id str, or None on miss
  cache.set(cell_tuple, row_id)
  cache.delete(cell_tuple)
  cache.stats()            → dict with hits / misses / size
  cache.warm(conn, limit)  → pull anchored+trusted rows from postgres

Cell keys are the 8-direction tuple joined with '/' and base36-
compressed so they fit in a short string:
  (1, 0, -1, 0, 1, -1, 0, 1) → '+0-0+-0+'
"""
from __future__ import annotations

import os
import subprocess
import sys
from collections import OrderedDict
from typing import Optional

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)


def cell_key(cell: tuple) -> str:
    """Compact string form of an 8-plane ternary cell."""
    if len(cell) != 8:
        raise ValueError(f"cell must have 8 directions, got {len(cell)}")
    return "".join({-1: "-", 0: "0", 1: "+"}[int(d)] for d in cell)


def cell_from_key(key: str) -> tuple:
    """Parse a compact cell key back to a tuple."""
    return tuple({"-": -1, "0": 0, "+": 1}[c] for c in key)


# ── Backend: process-local LRU ─────────────────────────────────────

class LocalLRUCache:
    """In-process LRU, bounded by max_size."""

    def __init__(self, max_size: int = 10_000):
        self.max_size = max_size
        self._data: OrderedDict = OrderedDict()
        self._hits = 0
        self._misses = 0

    def get(self, cell: tuple) -> Optional[str]:
        key = cell_key(cell)
        if key in self._data:
            self._data.move_to_end(key)
            self._hits += 1
            return self._data[key]
        self._misses += 1
        return None

    def set(self, cell: tuple, row_id: str) -> None:
        key = cell_key(cell)
        self._data[key] = row_id
        self._data.move_to_end(key)
        while len(self._data) > self.max_size:
            self._data.popitem(last=False)

    def delete(self, cell: tuple) -> None:
        self._data.pop(cell_key(cell), None)

    def clear(self) -> None:
        self._data.clear()
        self._hits = 0
        self._misses = 0

    def stats(self) -> dict:
        total = self._hits + self._misses
        return {
            "backend": "local",
            "size": len(self._data),
            "max_size": self.max_size,
            "hits": self._hits,
            "misses": self._misses,
            "hit_rate": round(self._hits / total, 4) if total else 0.0,
        }

    def warm(self, conn, limit: int = 5000) -> int:
        """
        Pull anchored + trusted rows from cws_core.location_id and
        populate the cache. Uses the partial index so the query is
        sub-millisecond even on a large matrix.
        """
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id::text,
                       sensory_dir, episodic_dir, semantic_dir, associative_dir,
                       procedural_dir, lexical_dir, relational_dir, executive_dir
                FROM cws_core.location_id
                WHERE cws_tier IN ('anchored', 'trusted')
                ORDER BY (CASE cws_tier WHEN 'anchored' THEN 0 ELSE 1 END),
                         dissolution_count DESC
                LIMIT %s
                """,
                (limit,),
            )
            n = 0
            for row in cur.fetchall():
                row_id = row[0]
                cell = tuple(row[1:9])
                self.set(cell, row_id)
                n += 1
            return n


# ── Backend: redis via podman exec (optional, opt-in) ──────────────

_REDIS_POD = os.environ.get("S7_REDIS_POD", "s7-skyqubi-s7-redis")
_REDIS_NS = "s7:prism:cache"


class RedisExecCache:
    """
    Redis backend via `podman exec`. Slower than LocalLRUCache but
    persistent across the Python process. Use only when
    S7_PRISM_CACHE_BACKEND=redis-exec.
    """

    def __init__(self):
        self._hits = 0
        self._misses = 0

    def _cli(self, *args) -> str:
        result = subprocess.run(
            ["podman", "exec", _REDIS_POD, "redis-cli", *args],
            capture_output=True, text=True, timeout=5,
        )
        return result.stdout.strip()

    def get(self, cell: tuple) -> Optional[str]:
        val = self._cli("HGET", _REDIS_NS, cell_key(cell))
        if val and val != "(nil)":
            self._hits += 1
            return val
        self._misses += 1
        return None

    def set(self, cell: tuple, row_id: str) -> None:
        self._cli("HSET", _REDIS_NS, cell_key(cell), row_id)

    def delete(self, cell: tuple) -> None:
        self._cli("HDEL", _REDIS_NS, cell_key(cell))

    def clear(self) -> None:
        self._cli("DEL", _REDIS_NS)
        self._hits = 0
        self._misses = 0

    def stats(self) -> dict:
        size = int(self._cli("HLEN", _REDIS_NS) or "0")
        total = self._hits + self._misses
        return {
            "backend": "redis-exec",
            "pod": _REDIS_POD,
            "size": size,
            "hits": self._hits,
            "misses": self._misses,
            "hit_rate": round(self._hits / total, 4) if total else 0.0,
        }

    def warm(self, conn, limit: int = 5000) -> int:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id::text,
                       sensory_dir, episodic_dir, semantic_dir, associative_dir,
                       procedural_dir, lexical_dir, relational_dir, executive_dir
                FROM cws_core.location_id
                WHERE cws_tier IN ('anchored', 'trusted')
                ORDER BY (CASE cws_tier WHEN 'anchored' THEN 0 ELSE 1 END),
                         dissolution_count DESC
                LIMIT %s
                """,
                (limit,),
            )
            n = 0
            # One HSET per row; for 5000 rows at ~500 µs each this
            # is ~2.5 seconds. Acceptable for a one-shot warm.
            for row in cur.fetchall():
                self.set(tuple(row[1:9]), row[0])
                n += 1
            return n


# ── Module singleton ───────────────────────────────────────────────

_BACKEND = os.environ.get("S7_PRISM_CACHE_BACKEND", "local")
_cache = RedisExecCache() if _BACKEND == "redis-exec" else LocalLRUCache()


def get_cache():
    return _cache


# ── CLI ──
if __name__ == "__main__":
    import json

    cmd = sys.argv[1] if len(sys.argv) > 1 else "stats"

    if cmd == "stats":
        print(json.dumps(_cache.stats(), indent=2))
        sys.exit(0)

    if cmd == "warm":
        from s7_prism_detect import _pg_connect
        conn = _pg_connect()
        try:
            n = _cache.warm(conn)
        finally:
            conn.close()
        print(json.dumps({
            "warmed": n,
            **_cache.stats(),
        }, indent=2))
        sys.exit(0)

    if cmd == "clear":
        _cache.clear()
        print(json.dumps({"cleared": True, **_cache.stats()}, indent=2))
        sys.exit(0)

    if cmd == "selftest":
        # Minimal round-trip
        c = LocalLRUCache(max_size=4)
        c.set((1, 0, -1, 0, 1, -1, 0, 1), "row-a")
        c.set((0, 0, 0, 0, 0, 0, 0, 0), "row-b")
        hit = c.get((1, 0, -1, 0, 1, -1, 0, 1))
        miss = c.get((1, 1, 1, 1, 1, 1, 1, 1))
        print(json.dumps({
            "hit": hit,
            "miss": miss,
            "stats": c.stats(),
            "key_sample": cell_key((1, 0, -1, 0, 1, -1, 0, 1)),
        }, indent=2))
        sys.exit(0)

    print(f"usage: s7_prism_cache.py [stats|warm|clear|selftest]")
    sys.exit(2)
