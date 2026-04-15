# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — Covenant Witness System Engine
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
#
# Licensed under CWS-BSL-1.1 (see CWS-LICENSE at repo root)
# Patent Pending: TPP99606 — Jamie Lee Clayton / 123Tech / 2XR, LLC
#
# S7™, SkyQUBi™, SkyCAIR™, CWS™, ForToken™, RevToken™, ZeroClaw™,
# SkyAVi™, MemPalace™, and "Love is the architecture"™ are
# trademarks of 123Tech / 2XR, LLC.
#
# CIVILIAN USE ONLY — See CWS-LICENSE Civilian-Only Covenant.
# ═══════════════════════════════════════════════════════════════════
import uuid
from datetime import datetime, timezone

BABEL_THRESHOLD = 0.70
_circuit_open = False

def compute_babel_ratio(discernment: list[dict]) -> float:
    if not discernment:
        return 0.0
    babel_count = sum(1 for d in discernment if d["result"] == "BABEL")
    return round(babel_count / len(discernment), 4)

def should_trip(ratio: float, threshold: float = BABEL_THRESHOLD) -> bool:
    return ratio >= threshold

def is_circuit_open() -> bool:
    return _circuit_open

def reset_circuit():
    global _circuit_open
    _circuit_open = False

async def check_breaker(db_conn, session_id) -> dict:
    global _circuit_open
    # session_id may arrive as str OR uuid.UUID (after the 2026-04-13
    # BreakerRequest.session_id type change to uuid.UUID). Normalize.
    session_id = str(session_id)

    with db_conn.cursor() as cur:
        cur.execute("""
            SELECT result::text FROM cws_inference.discernment WHERE session_id = %s::uuid
        """, (session_id,))
        discernment = [{"result": row[0]} for row in cur.fetchall()]
    ratio = compute_babel_ratio(discernment)
    triggered = should_trip(ratio)
    if triggered:
        _circuit_open = True
    babel_count = sum(1 for d in discernment if d["result"] == "BABEL")
    total = len(discernment)
    with db_conn.cursor() as cur:
        # 2026-04-13 fix: ensure cws_core.consensus_sessions row exists
        # before inserting into cws_core.babel_ratios or
        # cws_core.circuit_breaker_events. Both tables have FKs to
        # cws_core.consensus_sessions; without this preamble, a fresh
        # session_id that has never been through /witness crashes with
        # ForeignKeyViolation. Matches the fix pattern in run_witness()
        # which also INSERTs to consensus_sessions with ON CONFLICT.
        #
        # Uses a tiny placeholder input_text because check_breaker
        # doesn't receive the original query text — it's called
        # reactively on existing discernment data.
        import hashlib
        input_hash = hashlib.sha256(session_id.encode()).hexdigest()[:64]
        cur.execute("""
            INSERT INTO cws_core.consensus_sessions
                (id, input_hash, input_text, witness_count, started_at)
            VALUES (%s::uuid, %s, %s, 0, NOW())
            ON CONFLICT (id) DO NOTHING
        """, (session_id, input_hash, f"(breaker check for session {session_id})"))

        cur.execute("""
            INSERT INTO cws_core.babel_ratios
                (id, session_id, babel_count, total_tokens, ratio, computed_at)
            VALUES (%s::uuid, %s::uuid, %s, %s, %s, NOW())
        """, (str(uuid.uuid4()), session_id, babel_count, total, ratio))
        if triggered:
            cur.execute("""
                INSERT INTO cws_core.circuit_breaker_events
                    (id, session_id, babel_ratio, threshold, triggered, action_taken, triggered_at)
                VALUES (%s::uuid, %s::uuid, %s, %s, true, 'reject_inference', NOW())
            """, (str(uuid.uuid4()), session_id, ratio, BABEL_THRESHOLD))
    return {"babel_ratio": ratio, "threshold": BABEL_THRESHOLD, "triggered": triggered, "circuit_open": _circuit_open}
