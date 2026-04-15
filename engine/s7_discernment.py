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

AGREEMENT_THRESHOLD = 0.5
HIGH_CONFIDENCE_THRESHOLD = 0.75

def compute_discernment(tokens: list[str], forward_scores: list[float], reverse_scores: list[float]) -> list[dict]:
    results = []
    for i, token in enumerate(tokens):
        fwd = forward_scores[i]
        rev = reverse_scores[i]
        agreement = 1.0 - abs(fwd - rev)
        is_fertile = agreement >= AGREEMENT_THRESHOLD
        if is_fertile and agreement >= HIGH_CONFIDENCE_THRESHOLD:
            weight = 1
        elif is_fertile:
            weight = 0
        else:
            weight = -1
        results.append({
            "token_index": i, "token_value": token,
            "forward_value": round(fwd, 6), "reverse_value": round(rev, 6),
            "agreement": round(agreement, 4),
            "result": "FERTILE" if is_fertile else "BABEL", "weight": weight,
        })
    return results

async def score_tokens_forward(tokens: list[str]) -> list[float]:
    scores = []
    n = len(tokens)
    for i, token in enumerate(tokens):
        position_weight = 1.0 - (i / max(n, 1)) * 0.2
        token_length_factor = min(len(token) / 10.0, 1.0)
        score = position_weight * (0.5 + token_length_factor * 0.5)
        scores.append(round(score, 6))
    return scores

async def score_tokens_reverse(tokens: list[str]) -> list[float]:
    scores = []
    n = len(tokens)
    for i, token in enumerate(reversed(tokens)):
        position_weight = 1.0 - (i / max(n, 1)) * 0.2
        token_length_factor = min(len(token) / 10.0, 1.0)
        score = position_weight * (0.5 + token_length_factor * 0.5)
        scores.append(round(score, 6))
    scores.reverse()
    return scores

async def run_discernment(db_conn, session_id, tokens: list[str]) -> list[dict]:
    # session_id may arrive as str OR uuid.UUID (after the 2026-04-13
    # DiscernRequest.session_id type change to uuid.UUID). psycopg2's
    # %s::uuid cast accepts both, but we normalize to str for clarity
    # and for the ON CONFLICT check in the sessions INSERT below.
    session_id = str(session_id)

    forward_scores = await score_tokens_forward(tokens)
    reverse_scores = await score_tokens_reverse(tokens)
    results = compute_discernment(tokens, forward_scores, reverse_scores)
    with db_conn.cursor() as cur:
        # 2026-04-13 fix: ensure cws_inference.sessions row exists before
        # inserting into cws_inference.passes. The passes table has a
        # foreign key on session_id; without this preamble, a fresh
        # session_id crashes with ForeignKeyViolation. run_witness() has
        # this same preamble — we're bringing run_discernment into
        # parity.
        # ON CONFLICT (id) DO NOTHING so retries + shared sessions work.
        cur.execute("""
            INSERT INTO cws_inference.sessions
                (id, input_tokens, input_constant, input_location,
                 scale_weight, pulse_step, inference_path, started_at)
            VALUES (%s::uuid, %s, 1.0, 0.0, 1.0, 0,
                    'standard'::cws_routing.inference_path, NOW())
            ON CONFLICT (id) DO NOTHING
        """, (session_id, tokens))

        for r in results:
            pass_id_fwd = str(uuid.uuid4())
            pass_id_rev = str(uuid.uuid4())
            cur.execute("""
                INSERT INTO cws_inference.passes
                    (id, session_id, pass_type, token_index, token_value, curve_value, confidence, computed_at)
                VALUES (%s::uuid, %s::uuid, 'FORWARD', %s, %s, %s, %s, NOW())
            """, (pass_id_fwd, session_id, r["token_index"], r["token_value"], r["forward_value"], r["agreement"]))
            cur.execute("""
                INSERT INTO cws_inference.passes
                    (id, session_id, pass_type, token_index, token_value, curve_value, confidence, computed_at)
                VALUES (%s::uuid, %s::uuid, 'REVERSE', %s, %s, %s, %s, NOW())
            """, (pass_id_rev, session_id, r["token_index"], r["token_value"], r["reverse_value"], r["agreement"]))
            cur.execute("""
                INSERT INTO cws_inference.discernment
                    (id, session_id, token_index, token_value, forward_value, reverse_value,
                     agreement, result, weight, computed_at)
                VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s, %s, %s::cws_core.discernment, %s, NOW())
            """, (str(uuid.uuid4()), session_id, r["token_index"], r["token_value"],
                  r["forward_value"], r["reverse_value"], r["agreement"], r["result"], r["weight"]))
    return results
