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
from engine.s7_http import ollama_generate
try:
    from s7_molecular import Bond, get_backend
except ImportError:
    from engine.s7_molecular import Bond, get_backend

async def run_witness(db_conn, session_id: str, query: str, model: str = "llama3.2:1b") -> dict:
    start = time.monotonic()
    result = await ollama_generate(query, model=model)
    latency_ms = int((time.monotonic() - start) * 1000)
    output_text = result.get("response", "")
    output_tokens = output_text.split()
    with db_conn.cursor() as cur:
        # Ensure session exists
        input_tokens = query.split()
        cur.execute("""
            INSERT INTO cws_inference.sessions
                (id, input_tokens, input_constant, input_location, scale_weight, pulse_step, inference_path, started_at)
            VALUES (%s::uuid, %s, 1.0, 0.0, 1.0, 0, 'standard'::cws_routing.inference_path, NOW())
            ON CONFLICT (id) DO NOTHING
        """, (session_id, input_tokens))
        cur.execute("""
            SELECT id::text FROM cws_core.witnesses
            WHERE model_name = %s AND is_active = true LIMIT 1
        """, (model,))
        row = cur.fetchone()
        witness_id = row[0] if row else str(uuid.uuid4())
        cur.execute("""
            INSERT INTO cws_inference.witness_outputs
                (id, session_id, witness_id, engine, output_text, output_tokens, latency_ms, computed_at)
            VALUES (%s::uuid, %s::uuid, %s::uuid, 'ollama', %s, %s, %s, NOW())
        """, (str(uuid.uuid4()), session_id, witness_id, output_text, output_tokens, latency_ms))
        convergence = 1.0
        consensus_id = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO cws_core.consensus_sessions
                (id, input_hash, input_text, witness_count, started_at)
            VALUES (%s::uuid, %s, %s, 1, NOW())
        """, (consensus_id, __import__("hashlib").sha256(query.encode()).hexdigest()[:64], query[:500]))
        cur.execute("""
            INSERT INTO cws_core.convergence_scores
                (id, session_id, witness_id, score, computed_at)
            VALUES (%s::uuid, %s::uuid, %s::uuid, %s, NOW())
        """, (str(uuid.uuid4()), consensus_id, witness_id, convergence))
    # ── Molecular bond write (primary path) ──────────────────────
    try:
        bond = Bond(
            bond_type="output",
            plane=1,  # Chat plane
            memory=1, present=0, destiny=1,
            content=output_text,
            witness_id=witness_id,
            consensus_id=consensus_id,
            latency_ms=latency_ms,
            trust_score=convergence,
            state="FERTILE",
        )
        backend = get_backend()
        backend.store_bond(bond)
    except Exception:
        pass  # molecular write failure is non-fatal during transition

    return {"witness_id": witness_id, "model": model, "output_text": output_text,
            "output_tokens": output_tokens, "latency_ms": latency_ms, "convergence": convergence}
