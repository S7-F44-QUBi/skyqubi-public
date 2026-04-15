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
import time
from engine.s7_http import ollama_generate, bitnet_infer
from engine.s7_discernment import score_tokens_forward, score_tokens_reverse, compute_discernment
from engine.s7_breaker import compute_babel_ratio

async def run_quanti(db_conn, session_id, prompt: str) -> dict:
    # session_id may arrive as str OR uuid.UUID (after the 2026-04-13
    # QuantiRequest.session_id type change to uuid.UUID). Normalize to
    # str for consistent SQL parameter passing.
    session_id = str(session_id)

    start_std = time.monotonic()
    std_result = await ollama_generate(prompt)
    std_latency = int((time.monotonic() - start_std) * 1000)
    std_tokens = std_result.get("response", "").split()
    start_tern = time.monotonic()
    try:
        tern_result = await bitnet_infer(prompt)
        tern_latency = int((time.monotonic() - start_tern) * 1000)
        tern_tokens = tern_result.get("output", "").split()
        tern_energy = tern_result.get("energy_j", 0.028 * len(tern_tokens))
    except Exception:
        tern_latency = 0
        tern_tokens = []
        tern_energy = 0.0
    std_fwd = await score_tokens_forward(std_tokens)
    std_rev = await score_tokens_reverse(std_tokens)
    std_discernment = compute_discernment(std_tokens, std_fwd, std_rev)
    std_babel = compute_babel_ratio(std_discernment)
    tern_fwd = await score_tokens_forward(tern_tokens) if tern_tokens else []
    tern_rev = await score_tokens_reverse(tern_tokens) if tern_tokens else []
    tern_discernment = compute_discernment(tern_tokens, tern_fwd, tern_rev) if tern_tokens else []
    tern_babel = compute_babel_ratio(tern_discernment)
    convergence = 1.0 - abs(std_babel - tern_babel) if tern_tokens else 0.0
    std_energy = 0.156 * len(std_tokens)
    unanimous = std_babel < 0.70 and tern_babel < 0.70
    circuit_tripped = std_babel >= 0.70 or tern_babel >= 0.70
    metrics = {
        "convergence": round(convergence, 6), "babel_ratio": round(max(std_babel, tern_babel), 4),
        "confidence": round(1.0 - max(std_babel, tern_babel), 4), "unanimous": unanimous,
        "bandage_count": 0, "circuit_tripped": circuit_tripped,
        "standard_latency_ms": std_latency, "ternary_latency_ms": tern_latency,
        "standard_energy_j": round(std_energy, 6), "ternary_energy_j": round(tern_energy, 6),
    }
    with db_conn.cursor() as cur:
        # 2026-04-13 fix: ensure cws_inference.sessions row exists before
        # inserting into cws_inference.quanti_metrics. quanti_metrics has
        # a foreign key on session_id; without this preamble, a fresh
        # session_id crashes with ForeignKeyViolation. Matches the same
        # fix applied to run_discernment() and the same pattern
        # run_witness() has used from the start.
        # ON CONFLICT (id) DO NOTHING so retries + shared sessions work.
        input_tokens = prompt.split()
        cur.execute("""
            INSERT INTO cws_inference.sessions
                (id, input_tokens, input_constant, input_location,
                 scale_weight, pulse_step, inference_path, started_at)
            VALUES (%s::uuid, %s, 1.0, 0.0, 1.0, 0,
                    'standard'::cws_routing.inference_path, NOW())
            ON CONFLICT (id) DO NOTHING
        """, (session_id, input_tokens))

        cur.execute("""
            INSERT INTO cws_inference.quanti_metrics
                (id, session_id, convergence, babel_ratio, confidence, unanimous,
                 bandage_count, circuit_tripped, standard_latency_ms, ternary_latency_ms,
                 standard_energy_j, ternary_energy_j, reported_at)
            VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
        """, (str(uuid.uuid4()), session_id, metrics["convergence"], metrics["babel_ratio"],
              metrics["confidence"], metrics["unanimous"], metrics["bandage_count"],
              metrics["circuit_tripped"], metrics["standard_latency_ms"], metrics["ternary_latency_ms"],
              metrics["standard_energy_j"], metrics["ternary_energy_j"]))
    return metrics
