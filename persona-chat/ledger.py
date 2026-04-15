#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Persona Chat Ledger
#
# Hash-chained, append-only, per-persona-room turn ledger. One file
# per persona per session. Every row is linked to the previous row
# by SHA-256, and the chain can be re-verified at any time via
# verify_chain().
#
# This is the local-filesystem substrate for the MemPalace room
# architecture (see feedback_kv_cache_is_mempalace_room.md). When
# the pod is restored, a migration job replays these files into
# mempalace.drawers with original hashes preserved.
#
# Governing rules:
#   - feedback_three_rules.md   Rule 3: Protect the QUBi → quarantine over delete
#   - feedback_qbit_not_token.md Use QBIT, not token, at the user boundary
#   - INSERT-only covenant       No row is ever updated or deleted
#
# Copyright 2026 Jamie Lee Clayton / 2XR LLC
# CWS-BSL-1.1 · Civilian use only.
# ═══════════════════════════════════════════════════════════════════

from __future__ import annotations

import hashlib
import json
import os
import shutil
import time
import uuid
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional, Iterator

# ── Constants ───────────────────────────────────────────────────────

GENESIS_PREV_HASH = "0" * 64
"""The prev_hash value for the first row of any chain. Canonical zero."""

LEDGER_FILE_MODE = 0o600
"""POSIX mode for every persona ledger file. User-only read/write."""

LEDGER_DIR_MODE = 0o700
"""POSIX mode for every session/user directory."""

LEDGER_ROOT_DEFAULT = "/s7/.s7-chat-sessions"
"""Default root of all session ledger files. Override with S7_LEDGER_ROOT env."""

ALLOWED_PERSONAS = frozenset({"carli", "elias", "samuel"})
"""The closed persona set. Any request for a persona outside this set is 403
at the service layer. A new persona is an explicit code change, not a config."""


# ── Row shape ───────────────────────────────────────────────────────

@dataclass(frozen=True)
class LedgerRow:
    """One turn's append-only record.

    The fields are split into three categories:
      1. Chain fields (turn_id, prev_hash, ts, row_hash) — the hash chain
      2. Content fields (session_id, persona, engine, ...) — the turn data
      3. Deferred fields (plane, location_id, trinity, ...) — populated
         when the pod is restored; today they are null or "unknown".

    `row_hash` is computed as
        sha256( prev_hash || canonical_json(other_fields) )
    where canonical_json is JSON with sorted keys, no whitespace, and UTF-8
    encoding. This matches the audit.verify_chain() pattern used elsewhere
    in the repo.
    """

    # Chain fields
    turn_id: str
    prev_hash: str
    ts: str  # ISO 8601 UTC
    row_hash: str

    # Content fields
    session_id: str
    user_id: str
    persona: str
    engine: str  # "ollama" | "bitnet" | "stubbed"
    model: str
    tier: str  # "L1" | "L2" | "L3"
    user_input: str
    assistant_output: str
    qbit_count: dict  # {"in": int, "out": int, "total": int}
    latency_ms: int
    qps: float  # QBITs per second (Ollama eval_count / eval_duration, converted)
    fallback: Optional[dict] = None  # {"from": "...", "to": "...", "reason": "..."}
    status: str = "ok"  # "ok" | "engine_error" | "write_error" | "tamper"

    # Deferred fields (null until pod is restored and MemPalace is online)
    plane: Optional[str] = None
    location_id: Optional[str] = None
    trinity: Optional[int] = None
    fortoken_used: bool = False
    revtoken_predicted: bool = False
    witness_verdict: Optional[str] = None  # "FERTILE" | "BABEL" | "GRAY" | None

    def canonical_without_hash(self) -> str:
        """Return canonical JSON of all fields except row_hash, for hashing."""
        d = asdict(self)
        d.pop("row_hash")
        return json.dumps(d, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def compute_row_hash(prev_hash: str, payload_json: str) -> str:
    """Compute the SHA-256 of prev_hash concatenated with canonical payload JSON."""
    h = hashlib.sha256()
    h.update(prev_hash.encode("ascii"))
    h.update(payload_json.encode("utf-8"))
    return h.hexdigest()


# ── Path helpers ────────────────────────────────────────────────────

def ledger_root() -> Path:
    """Resolve the ledger root, honoring the S7_LEDGER_ROOT env override."""
    return Path(os.environ.get("S7_LEDGER_ROOT", LEDGER_ROOT_DEFAULT))


def session_dir(user_id: str, session_id: str, root: Optional[Path] = None) -> Path:
    """The directory that holds all persona ledgers for one session."""
    root = root or ledger_root()
    return root / user_id / f"session-{session_id}"


def persona_ledger_path(user_id: str, session_id: str, persona: str, root: Optional[Path] = None) -> Path:
    """The NDJSON file for one persona's room in one session."""
    if persona not in ALLOWED_PERSONAS:
        raise ValueError(f"persona {persona!r} is not in ALLOWED_PERSONAS={ALLOWED_PERSONAS}")
    return session_dir(user_id, session_id, root=root) / f"{persona}.ndjson"


def quarantine_dir(user_id: str, session_id: str, root: Optional[Path] = None) -> Path:
    """The dir that holds corrupted-chain files after F3 quarantine."""
    return session_dir(user_id, session_id, root=root) / "quarantine"


# ── Read / append / verify ──────────────────────────────────────────

def ensure_session_dirs(user_id: str, session_id: str, root: Optional[Path] = None) -> Path:
    """Create the per-user and per-session dirs with the right modes, idempotent."""
    root = root or ledger_root()
    root.mkdir(mode=LEDGER_DIR_MODE, parents=True, exist_ok=True)
    user_dir = root / user_id
    user_dir.mkdir(mode=LEDGER_DIR_MODE, parents=True, exist_ok=True)
    sess = user_dir / f"session-{session_id}"
    sess.mkdir(mode=LEDGER_DIR_MODE, parents=True, exist_ok=True)
    return sess


def read_rows(path: Path) -> list[LedgerRow]:
    """Read every row from a ledger file. Returns [] if the file does not exist."""
    if not path.exists():
        return []
    out: list[LedgerRow] = []
    with path.open("r", encoding="utf-8") as f:
        for line_no, raw in enumerate(f, start=1):
            line = raw.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError as e:
                raise LedgerCorruptError(
                    f"{path}:{line_no}: invalid JSON — {e}"
                ) from e
            try:
                out.append(LedgerRow(**d))
            except TypeError as e:
                raise LedgerCorruptError(
                    f"{path}:{line_no}: row schema mismatch — {e}"
                ) from e
    return out


def last_row_hash(path: Path) -> str:
    """Return the row_hash of the last row in the file, or GENESIS_PREV_HASH if empty."""
    rows = read_rows(path)
    if not rows:
        return GENESIS_PREV_HASH
    return rows[-1].row_hash


def append_row(
    *,
    path: Path,
    session_id: str,
    user_id: str,
    persona: str,
    engine: str,
    model: str,
    tier: str,
    user_input: str,
    assistant_output: str,
    qbit_count: dict,
    latency_ms: int,
    qps: float,
    fallback: Optional[dict] = None,
    status: str = "ok",
    plane: Optional[str] = None,
    location_id: Optional[str] = None,
    trinity: Optional[int] = None,
    fortoken_used: bool = False,
    revtoken_predicted: bool = False,
    witness_verdict: Optional[str] = None,
    now_iso: Optional[str] = None,
) -> LedgerRow:
    """Append a new row to the persona ledger with a fresh hash linked to prev.

    Strict mode (Rule F2): if the file write fails, raises and does NOT return.
    The caller MUST NOT stream a response to the user on append failure. The
    covenant's "every action is recorded" clause is broken otherwise.
    """
    if persona not in ALLOWED_PERSONAS:
        raise ValueError(f"persona {persona!r} not in ALLOWED_PERSONAS={ALLOWED_PERSONAS}")

    prev_hash = last_row_hash(path)
    turn_id = str(uuid.uuid4())
    ts = now_iso or _utc_now_iso()

    proto = LedgerRow(
        turn_id=turn_id,
        prev_hash=prev_hash,
        ts=ts,
        row_hash="",  # filled after compute
        session_id=session_id,
        user_id=user_id,
        persona=persona,
        engine=engine,
        model=model,
        tier=tier,
        user_input=user_input,
        assistant_output=assistant_output,
        qbit_count=qbit_count,
        latency_ms=latency_ms,
        qps=qps,
        fallback=fallback,
        status=status,
        plane=plane,
        location_id=location_id,
        trinity=trinity,
        fortoken_used=fortoken_used,
        revtoken_predicted=revtoken_predicted,
        witness_verdict=witness_verdict,
    )

    payload = proto.canonical_without_hash()
    row_hash = compute_row_hash(prev_hash, payload)

    # frozen dataclass: rebuild with the final hash
    final = LedgerRow(
        turn_id=turn_id,
        prev_hash=prev_hash,
        ts=ts,
        row_hash=row_hash,
        session_id=session_id,
        user_id=user_id,
        persona=persona,
        engine=engine,
        model=model,
        tier=tier,
        user_input=user_input,
        assistant_output=assistant_output,
        qbit_count=qbit_count,
        latency_ms=latency_ms,
        qps=qps,
        fallback=fallback,
        status=status,
        plane=plane,
        location_id=location_id,
        trinity=trinity,
        fortoken_used=fortoken_used,
        revtoken_predicted=revtoken_predicted,
        witness_verdict=witness_verdict,
    )

    # Ensure directories exist before writing (idempotent).
    path.parent.mkdir(mode=LEDGER_DIR_MODE, parents=True, exist_ok=True)

    line = json.dumps(asdict(final), sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n"
    flags = os.O_WRONLY | os.O_CREAT | os.O_APPEND
    fd = os.open(path, flags, LEDGER_FILE_MODE)
    try:
        os.write(fd, line.encode("utf-8"))
        # fsync is required for Rule F2 (strict): the row must be on disk before
        # the response is streamed to the browser.
        os.fsync(fd)
    finally:
        os.close(fd)

    # If the file is brand new we also want the mode to be restored
    # in case umask widened it. os.open honors mode for creation but
    # an existing file's perms are untouched; fix that explicitly.
    try:
        os.chmod(path, LEDGER_FILE_MODE)
    except OSError:
        pass  # best-effort — fs may not support chmod

    return final


def verify_chain(path: Path) -> tuple[bool, Optional[str]]:
    """Walk the chain, return (ok, first_error_message).

    ok=True  → every row's row_hash matches sha256(prev_hash||payload), and
               every row's prev_hash matches the previous row's row_hash.
    ok=False → the first error is returned as a string. The caller SHOULD
               quarantine the file per Rule F3, not attempt to repair it.
    """
    rows = read_rows(path)
    expected_prev = GENESIS_PREV_HASH
    for i, row in enumerate(rows):
        if row.prev_hash != expected_prev:
            return (
                False,
                f"row {i}: prev_hash mismatch (expected {expected_prev}, got {row.prev_hash})",
            )
        payload = row.canonical_without_hash()
        computed = compute_row_hash(row.prev_hash, payload)
        if computed != row.row_hash:
            return (
                False,
                f"row {i}: row_hash mismatch (computed {computed}, stored {row.row_hash})",
            )
        expected_prev = row.row_hash
    return (True, None)


def quarantine(
    user_id: str,
    session_id: str,
    persona: str,
    reason: str,
    root: Optional[Path] = None,
) -> Path:
    """Move a corrupted ledger file to quarantine (Rule F3).

    The file is MOVED, not deleted. The chain is preserved as evidence.
    A fresh ledger file is NOT created here — the caller decides whether
    to start a new chain via append_row() (which will find an empty file).
    The quarantine path is returned for audit.
    """
    src = persona_ledger_path(user_id, session_id, persona, root=root)
    if not src.exists():
        raise FileNotFoundError(f"cannot quarantine nonexistent file: {src}")

    qdir = quarantine_dir(user_id, session_id, root=root)
    qdir.mkdir(mode=LEDGER_DIR_MODE, parents=True, exist_ok=True)

    ts_tag = _utc_now_iso().replace(":", "").replace("-", "").replace(".", "")
    dest = qdir / f"{persona}.{ts_tag}.ndjson"
    shutil.move(str(src), str(dest))

    # Write a sidecar reason file so the operator and Witness Samuel (when back)
    # know why this file was quarantined.
    sidecar = dest.with_suffix(".reason.txt")
    with sidecar.open("w", encoding="utf-8") as f:
        f.write(f"reason: {reason}\n")
        f.write(f"ts: {_utc_now_iso()}\n")
        f.write(f"session_id: {session_id}\n")
        f.write(f"user_id: {user_id}\n")
        f.write(f"persona: {persona}\n")
    try:
        os.chmod(sidecar, LEDGER_FILE_MODE)
    except OSError:
        pass

    return dest


# ── Iteration helpers for memory_tiers.py consumers ─────────────────

def iter_rows_reverse(path: Path) -> Iterator[LedgerRow]:
    """Yield rows newest-first. Used by memory_tiers for L1/L2 walk-back."""
    rows = read_rows(path)
    for r in reversed(rows):
        yield r


def iter_cross_persona_rows_reverse(
    user_id: str,
    session_id: str,
    root: Optional[Path] = None,
) -> Iterator[LedgerRow]:
    """Yield all rows from all personas in a session, merged and sorted by ts
    newest-first.

    This is the cross-persona READ that Samuel uses to see what Carli and
    Elias said in the same session. Write access stays per-persona — this
    function is read-only.
    """
    sess = session_dir(user_id, session_id, root=root)
    if not sess.exists():
        return
    merged: list[LedgerRow] = []
    for persona in sorted(ALLOWED_PERSONAS):
        p = sess / f"{persona}.ndjson"
        if p.exists():
            merged.extend(read_rows(p))
    # Sort newest-first by ts. ISO 8601 lex-sort is chronological.
    merged.sort(key=lambda r: r.ts, reverse=True)
    for r in merged:
        yield r


# ── Errors ──────────────────────────────────────────────────────────

class LedgerCorruptError(Exception):
    """Raised by read_rows when a line is not valid JSON or schema-mismatched.

    The caller should catch this and invoke quarantine() rather than retry.
    """


# ── Time ────────────────────────────────────────────────────────────

def _utc_now_iso() -> str:
    """ISO 8601 UTC with millisecond precision, trailing 'Z'."""
    # time.time_ns → divmod → isoformat via time.strftime avoids importing
    # datetime (which pulls tz machinery on Python 3.14) for this hot path.
    ns = time.time_ns()
    secs = ns // 1_000_000_000
    ms = (ns // 1_000_000) % 1000
    base = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(secs))
    return f"{base}.{ms:03d}Z"
