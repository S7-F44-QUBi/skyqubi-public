#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — QBIT Prism v1.0.1: Location Detection driver
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
# Licensed under CWS-BSL-1.1
# Patent Pending: TPP99606 / CWS-005
# ═══════════════════════════════════════════════════════════════════
"""
End-to-end driver for 'prism detect "<text>"'.

Wires four pieces together:
    text
      ─▶ s7_akashic.tokenise + encode         (Phase 5, 7 plane ternaries)
      ─▶ bridge to the 8 OCTi plane shape     (this file)
      ─▶ cws_core.location_id live query       (postgres)
      ─▶ s7_prism.detect_location             (4-way verdict)

No disk I/O beyond the postgres composite index, which is already
resident in shared_buffers. This is the "scan without spinning"
property — a text in, a verdict out, nothing touches bulk storage.

Usage:
    python3 engine/s7_prism_detect.py "the text to detect"
    python3 engine/s7_prism_detect.py --for-token <uuid> "..."
    python3 engine/s7_prism_detect.py --help
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Optional

# Allow running as a script from the repo root
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import s7_akashic          # Phase 5 Language encoder (7 planes)
import s7_prism            # v1.0.1 (8 OCTi planes, detect_location)
from s7_input_guard import sanitize_or_violation


def _build_index_with_universals():
    """
    Build a LanguageIndex with the 67-word seed PLUS the full
    akashic.universals table loaded from postgres. Fall back to
    seed-only if the universals table isn't reachable.
    """
    idx = s7_akashic.build_seed_index()
    try:
        conn = _pg_connect()
        try:
            idx.load_universals_from_db(conn)
        finally:
            conn.close()
    except Exception:
        # Universals table not yet present — use seed-only
        pass
    return idx


def _load_forbidden_surface_forms() -> set[str]:
    """
    Pull every surface form from akashic.forbidden into a set for
    cheap O(1) token membership checks. Returns empty set if the
    forbidden table isn't reachable (fail-open on infra, not on
    policy — the detect_location matrix still protects).
    """
    forms: set[str] = set()
    try:
        conn = _pg_connect()
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT surface_forms FROM akashic.forbidden")
                for (arr,) in cur.fetchall():
                    if arr:
                        for form in arr:
                            if form:
                                forms.add(form.lower().strip())
        finally:
            conn.close()
    except Exception:
        pass
    return forms


def check_forbidden_tokens(text: str) -> Optional[str]:
    """
    Scan `text` for any forbidden surface form. Returns the FIRST
    matching token (lowercased) if one is found, or None if the text
    is clean. Called BEFORE any encoding so violations are caught
    without consulting the Prism matrix at all.
    """
    forbidden = _load_forbidden_surface_forms()
    if not forbidden:
        return None
    for token in s7_akashic.tokenise(text):
        if token in forbidden:
            return token
    return None


# ── 3-violation session reset counter ─────────────────────────────
# Grace-based: on reset, the count zeroes and reset_count
# increments. No hard ban. The covenant allows the user to be
# better.

VIOLATION_RESET_THRESHOLD = 3


def record_violation(session_id: str, forbidden_token: str, witness: Optional[str] = None) -> dict:
    """
    Record a single violation for `session_id`. Upserts the row in
    akashic.violation_counter, increments count, checks the reset
    threshold, and returns:

        {
          'count':          int,        # current counter value (0 if just reset)
          'reset_triggered': bool,      # True if THIS call caused a reset
          'reset_count':    int,        # cumulative resets on this session
          'message':        str,        # pastoral message for the caller
        }

    If the DB isn't reachable, returns a safe fallback (count=1,
    reset_triggered=False) so the rest of the pipeline keeps working.
    """
    try:
        conn = _pg_connect()
    except Exception:
        return {
            "count": 1,
            "reset_triggered": False,
            "reset_count": 0,
            "message": "counter unavailable — violation not persisted",
        }
    try:
        with conn.cursor() as cur:
            # Upsert: create the row on first violation, else fetch it
            cur.execute(
                """
                INSERT INTO akashic.violation_counter (
                    session_id, witness, count, reset_count,
                    last_forbidden_token, first_violation_at, last_violation_at
                )
                VALUES (%s, %s, 1, 0, %s, NOW(), NOW())
                ON CONFLICT (session_id) DO UPDATE SET
                    count = akashic.violation_counter.count + 1,
                    last_forbidden_token = EXCLUDED.last_forbidden_token,
                    last_violation_at = NOW(),
                    witness = COALESCE(akashic.violation_counter.witness, EXCLUDED.witness)
                RETURNING count, reset_count
                """,
                (session_id, witness, forbidden_token),
            )
            count, reset_count = cur.fetchone()

            reset_triggered = False
            if count >= VIOLATION_RESET_THRESHOLD:
                # Grace: reset count to 0, increment reset_count,
                # stamp last_reset_at. The audit trail stays in
                # reset_count; the user gets a fresh slate.
                cur.execute(
                    """
                    UPDATE akashic.violation_counter
                    SET count = 0,
                        reset_count = reset_count + 1,
                        last_reset_at = NOW()
                    WHERE session_id = %s
                    RETURNING count, reset_count
                    """,
                    (session_id,),
                )
                count, reset_count = cur.fetchone()
                reset_triggered = True
        conn.commit()
    finally:
        conn.close()

    # Pastoral messages — help not hinder, lead if lost. The
    # messages deliberately do NOT reveal internals (which token
    # matched, how many forbidden tokens exist, what the next
    # threshold is in detail). Conversations should not share
    # secrets; the user is redirected toward the purpose, not
    # informed about the defense.
    if reset_triggered:
        message = (
            "Session reset. Start fresh — tell me what you're trying to accomplish "
            "and I can help point you toward a path we can walk together."
        )
    else:
        message = (
            "That path isn't open here. Try rephrasing around what you're actually "
            "seeking — I can help if you'll lead with the purpose."
        )

    return {
        "count": count,
        "reset_triggered": reset_triggered,
        "reset_count": reset_count,
        "message": message,
    }


# ── Phase 5 plane names → Prism OCTi plane names ──────────────────
# Phase 5 has 7 planes; Prism has 8. The 8th is 'executive' and has
# no Phase 5 equivalent, so we set it to 0 (Door) when bridging.
_PHASE5_TO_OCTI = {
    "Sensory":     "sensory",
    "Episodic":    "episodic",
    "Semantic":    "semantic",
    "Associative": "associative",
    "Procedural":  "procedural",
    "Relational":  "relational",
    "Lexical":     "lexical",
    # 'executive' has no Phase 5 source — default to direction=0
}


def akashic_to_prism(encoding: s7_akashic.AkashicEncoding) -> dict:
    """
    Bridge a Phase 5 AkashicEncoding (7 planes) into a Prism-shaped
    dict (8 OCTi planes) that cell_tuple() and detect_location() can
    consume.

    The 8th plane (executive) defaults to direction=0 because Phase 5
    does not have an executive axis. This is the covenant-honest
    answer — we don't claim signal we don't have.
    """
    prism_dict: dict = {}
    for plane_score in encoding.plane_scores:
        octi_name = _PHASE5_TO_OCTI.get(plane_score.plane_name)
        if octi_name is None:
            continue
        prism_dict[octi_name] = {
            "direction": plane_score.ternary,
            "magnitude": abs(plane_score.normalised),
        }
    # Fill missing OCTi planes with Door (0)
    for octi_name in s7_prism.OCTI_PLANES:
        if octi_name not in prism_dict:
            prism_dict[octi_name] = {"direction": 0, "magnitude": 0.0}
    return prism_dict


# ── Live Postgres query functions for detect_location ──────────────

_PG_PASSWORD_FILE = "/s7/.config/s7/pg-password"


def _read_pg_password() -> str:
    """
    Read the postgres password from a mode-600 file outside the
    repo. Never hardcoded, never committed, never in shell output.
    Env var S7_PG_PASSWORD takes precedence for ephemeral overrides.
    """
    env = os.environ.get("S7_PG_PASSWORD")
    if env:
        return env
    try:
        with open(_PG_PASSWORD_FILE, "r") as f:
            return f.read().strip()
    except FileNotFoundError:
        raise RuntimeError(
            f"postgres password file not found at {_PG_PASSWORD_FILE}. "
            f"Create it (mode 600) or set S7_PG_PASSWORD env var."
        )


def _pg_connect():
    import psycopg2
    return psycopg2.connect(
        host=os.environ.get("S7_PG_HOST", "127.0.0.1"),
        port=int(os.environ.get("S7_PG_PORT", "57090")),
        user=os.environ.get("S7_PG_USER", "s7"),
        password=_read_pg_password(),
        dbname=os.environ.get("S7_PG_DB", "s7_cws"),
    )


def make_cell_occupied_fn(conn):
    def check(cell: tuple[int, ...]) -> bool:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1 FROM cws_core.location_id
                WHERE sensory_dir     = %s
                  AND episodic_dir    = %s
                  AND semantic_dir    = %s
                  AND associative_dir = %s
                  AND procedural_dir  = %s
                  AND lexical_dir     = %s
                  AND relational_dir  = %s
                  AND executive_dir   = %s
                LIMIT 1
                """,
                cell,
            )
            return cur.fetchone() is not None
    return check


def make_cell_forbidden_fn(conn):
    def check(cell: tuple[int, ...]) -> bool:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1 FROM cws_core.location_id
                WHERE forbidden = TRUE
                  AND sensory_dir     = %s
                  AND episodic_dir    = %s
                  AND semantic_dir    = %s
                  AND associative_dir = %s
                  AND procedural_dir  = %s
                  AND lexical_dir     = %s
                  AND relational_dir  = %s
                  AND executive_dir   = %s
                LIMIT 1
                """,
                cell,
            )
            return cur.fetchone() is not None
    return check


def make_has_strand_anchor_fn(conn):
    def check(for_token: Optional[str], rev_token: Optional[str]) -> bool:
        if for_token is None and rev_token is None:
            return False
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1 FROM cws_core.location_id
                WHERE (for_token = %s::uuid OR rev_token = %s::uuid)
                LIMIT 1
                """,
                (for_token, rev_token),
            )
            return cur.fetchone() is not None
    return check


# ── Main driver ────────────────────────────────────────────────────

def detect(
    text: str,
    for_token: Optional[str] = None,
    rev_token: Optional[str] = None,
    session_id: str = "anonymous",
    witness: Optional[str] = None,
) -> dict:
    """
    Full pipeline. Returns a dict suitable for the SkyAvi skill.
    """
    # -1. Input guard — character-level sanitation BEFORE any other
    #     check. Folds confusables (Cyrillic/Greek → Latin), strips
    #     control chars, rejects null bytes, caps length. Homoglyph
    #     attacks that would have slipped past the forbidden check
    #     get normalised first so the forbidden check sees the real
    #     token.
    sanitised, guard_violation = sanitize_or_violation(text)
    if guard_violation is not None:
        return {
            "version":       s7_prism.__version__,
            "text_preview":  (text or "")[:80] + ("…" if text and len(text) > 80 else ""),
            "verdict":       s7_prism.VERDICT_VIOLATION,
            "reason":        guard_violation["reason"],
            "pastoral":      guard_violation["pastoral"],
            "stage":         guard_violation["stage"],
            "cell":          None,
            "cell_occupied": None,
            "cell_forbidden": None,
            "has_anchor":    None,
            "tokens":        0,
        }
    text = sanitised

    # 0. Token-level forbidden check — catches explicit violations
    #    before any encoding. Now operates on the SANITISED text so
    #    homoglyph attacks can't bypass the covenant.
    forbidden_hit = check_forbidden_tokens(text)
    if forbidden_hit is not None:
        counter = record_violation(session_id, forbidden_hit, witness=witness)
        response = {
            "version":          s7_prism.__version__,
            "text_preview":     text[:80] + ("…" if len(text) > 80 else ""),
            "verdict":          s7_prism.VERDICT_VIOLATION,
            "reason":           "text contains a forbidden pattern — see akashic.forbidden",
            "pastoral":         counter["message"],
            "cell":             None,
            "cell_occupied":    None,
            "cell_forbidden":   None,
            "has_anchor":       None,
            "tokens":           len(s7_akashic.tokenise(text)),
            "violation_count":  counter["count"],
            "reset_context":    counter["reset_triggered"],
            "session_resets":   counter["reset_count"],
        }
        # NB: the specific forbidden_token is NOT returned to the
        # caller — conversations should not share secrets. The token
        # is recorded server-side for steward review but never echoed
        # back. Users get the pastoral redirect only.
        return response

    # 1. Phase 5 encode — uses seed + universals table if reachable
    index = _build_index_with_universals()
    tokens = s7_akashic.tokenise(text)
    encoding = s7_akashic.encode(tokens, index)

    # 2. Bridge to Prism plane shape
    prism_dict = akashic_to_prism(encoding)

    # 3. Query live postgres matrix
    conn = _pg_connect()
    try:
        cell_occupied = make_cell_occupied_fn(conn)
        cell_forbidden = make_cell_forbidden_fn(conn)
        has_strand_anchor = make_has_strand_anchor_fn(conn)

        verdict = s7_prism.detect_location(
            prism_dict,
            cell_occupied_fn=cell_occupied,
            cell_forbidden_fn=cell_forbidden,
            has_strand_anchor_fn=has_strand_anchor,
            candidate_for_token=for_token,
            candidate_rev_token=rev_token,
        )
    finally:
        conn.close()

    return {
        "version":          s7_prism.__version__,
        "text_preview":     text[:80] + ("…" if len(text) > 80 else ""),
        "tokens":           encoding.token_count,
        "encoded":          encoding.encoded_count,
        "unencoded":        encoding.unencoded_count,
        "phase5_state":     encoding.state,
        "phase5_curve":     encoding.total_curve,
        "cell":             list(verdict["cell"]),
        "verdict":          verdict["verdict"],
        "reason":           verdict["reason"],
        "cell_occupied":    verdict["cell_occupied"],
        "cell_forbidden":   verdict["cell_forbidden"],
        "has_anchor":       verdict["has_anchor"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="s7_prism_detect",
        description="Run Location Detection on a piece of text.",
    )
    parser.add_argument("text", nargs="+", help="text to detect")
    parser.add_argument("--for-token", default=None, help="optional forward strand UUID")
    parser.add_argument("--rev-token", default=None, help="optional reverse strand UUID")
    parser.add_argument("--session-id", default="anonymous",
                        help="session identifier for the violation counter")
    parser.add_argument("--witness", default=None,
                        help="optional witness identifier (appliance serial, etc.)")
    args = parser.parse_args()
    text = " ".join(args.text)
    result = detect(
        text,
        for_token=args.for_token,
        rev_token=args.rev_token,
        session_id=args.session_id,
        witness=args.witness,
    )
    print(json.dumps(result, indent=2))
    return 0 if result["verdict"] in ("FOUNDATION", "FRONTIER") else 1


if __name__ == "__main__":
    sys.exit(main())
