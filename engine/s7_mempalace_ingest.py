#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — MemPalace → Prism Ingest Bridge
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
# Licensed under CWS-BSL-1.1
# Patent Pending: TPP99606 / CWS-005
# ═══════════════════════════════════════════════════════════════════
"""
Phase 1 of the Nightly S7 Self-Optimization Cycle.

Reads drawer bodies out of MemPalace's chroma store, runs each one
through the Prism ingest pipeline (Phase 5 Akashic encoder +
Universals + Input Guard + Forbidden check + LocationID INSERT),
and reports the delta.

Idempotent by source_text_hash — re-running skips drawers already
in the matrix. Room becomes part of the notes so MemPalace rooms
stay queryable on the Prism side.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from s7_prism_ingest import ingest_text  # handles guard, forbidden, insert

MEMPALACE_CHROMA = os.path.expanduser("~/.mempalace/palace/chroma.sqlite3")


def read_drawers(chroma_path: str) -> list[dict]:
    """
    Pivot the Chroma embedding_metadata table into one dict per
    drawer id with the keys we care about: id, wing, room,
    document, source_file.
    """
    if not os.path.isfile(chroma_path):
        raise FileNotFoundError(f"MemPalace chroma not found: {chroma_path}")

    conn = sqlite3.connect(chroma_path)
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT id, key, string_value
            FROM embedding_metadata
            WHERE string_value IS NOT NULL
            ORDER BY id
            """
        )
        drawers: dict[int, dict] = {}
        for drawer_id, key, value in cur.fetchall():
            entry = drawers.setdefault(drawer_id, {"id": drawer_id})
            if key == "chroma:document":
                entry["document"] = value
            elif key == "wing":
                entry["wing"] = value
            elif key == "room":
                entry["room"] = value
            elif key == "source_file":
                entry["source_file"] = value
        return [d for d in drawers.values() if d.get("document")]
    finally:
        conn.close()


def ingest_mempalace(
    aptitude_delta: int = 2,
    limit: int | None = None,
    witness: str = "S7-REF-0001",
) -> dict:
    """
    Walk MemPalace drawers and ingest each one into the Prism matrix.
    Returns a summary dict with ingested / skipped / refused counts.
    Idempotent by source_text_hash.
    """
    drawers = read_drawers(MEMPALACE_CHROMA)
    total = len(drawers)

    from s7_prism_detect import _pg_connect

    door_id: str | None = None
    conn = _pg_connect()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id::text FROM cws_core.location_id
                WHERE witness = %s AND notes LIKE 'Prism v1.0.1 schema foundation%%'
                ORDER BY created_at ASC LIMIT 1
                """,
                (witness,),
            )
            row = cur.fetchone()
            if row:
                door_id = row[0]
    finally:
        conn.close()

    ingested = 0
    skipped = 0
    refused = 0
    new_cells: set = set()

    conn = _pg_connect()
    try:
        rows = drawers[:limit] if limit else drawers
        for drawer in rows:
            text = drawer.get("document") or ""
            if not text.strip():
                continue

            text_hash = hashlib.sha256(text.encode("utf-8")).hexdigest()

            # Idempotency check
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT 1 FROM cws_core.location_id WHERE source_text_hash = %s LIMIT 1",
                    (text_hash,),
                )
                if cur.fetchone():
                    skipped += 1
                    continue

            room = drawer.get("room", "unknown")
            source = drawer.get("source_file", "unknown")
            notes = f"mempalace: room={room} source={source}"

            result = ingest_text(
                text,
                witness=witness,
                aptitude_delta=aptitude_delta,
                rev_token=door_id,
                notes=notes,
                conn=conn,
                session_id="mempalace-ingest",
            )
            if result.get("status") == "refused":
                refused += 1
            else:
                ingested += 1
                cell = tuple(result.get("cell") or [])
                if cell:
                    new_cells.add(cell)
        conn.commit()
    finally:
        conn.close()

    # Fresh matrix stats
    conn = _pg_connect()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT count(*),
                       count(DISTINCT (sensory_dir,episodic_dir,semantic_dir,associative_dir,
                                       procedural_dir,lexical_dir,relational_dir,executive_dir)),
                       sum(aptitude_delta)
                FROM cws_core.location_id
                """
            )
            total_rows, cells_used, apt_total = cur.fetchone()
    finally:
        conn.close()

    return {
        "source": MEMPALACE_CHROMA,
        "drawers_available": total,
        "drawers_examined": len(rows),
        "ingested": ingested,
        "skipped_already_present": skipped,
        "refused_by_covenant": refused,
        "new_cells": len(new_cells),
        "matrix_rows": total_rows,
        "matrix_cells_used": cells_used,
        "matrix_aptitude_total": apt_total,
    }


def main() -> int:
    parser = argparse.ArgumentParser(prog="s7_mempalace_ingest")
    parser.add_argument("--apt", type=int, default=2, help="aptitude_delta per drawer")
    parser.add_argument("--limit", type=int, default=None, help="max drawers to ingest this run")
    parser.add_argument("--witness", default="S7-REF-0001")
    args = parser.parse_args()

    result = ingest_mempalace(
        aptitude_delta=args.apt,
        limit=args.limit,
        witness=args.witness,
    )
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
