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
import hashlib
from datetime import datetime, timezone

try:
    from s7_molecular import Bond, get_backend
except ImportError:
    from engine.s7_molecular import Bond, get_backend

PLANE_MAP = {
    "semantic": 0, "chat": 1, "code": 2, "embed": 3,
    "vision": 4, "router": -1, "math": -2, "refine": -3, "guard": -4,
}

def filter_fertile(discernment: list[dict]) -> list[dict]:
    return [d for d in discernment if d["result"] == "FERTILE"]

def build_entry(content: str, plane: str | None, entity_id: str | None) -> dict:
    return {
        "id": str(uuid.uuid4()),
        "entity_id": entity_id,
        "plane": plane or "semantic",
        "content": content,
        "content_hash": hashlib.sha256(content.encode()).hexdigest()[:64],
        "source_system": "cws",
        "v_memory": "0", "v_present": "0", "v_destiny": "0",
        "weight": 0,
    }

async def store_memory(db_conn, session_id: str, content: str, discernment: list[dict],
                       plane: str | None = None, entity_id: str | None = None) -> str | None:
    fertile = filter_fertile(discernment)
    if not fertile:
        return None
    entry = build_entry(content, plane, entity_id)

    # ── Legacy table write (backward compat) ─────────────────────
    with db_conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_memory.entries
                (id, entity_id, plane, content, content_hash, source_system,
                 v_memory, v_present, v_destiny, weight, inserted_at)
            VALUES (%(id)s::uuid, %(entity_id)s::uuid, %(plane)s::cws_core.plane_name,
                    %(content)s, %(content_hash)s, %(source_system)s,
                    %(v_memory)s::cws_core.plane_val, %(v_present)s::cws_core.plane_val,
                    %(v_destiny)s::cws_core.plane_val, %(weight)s, NOW())
        """, entry)
        for d in fertile:
            token_id = str(uuid.uuid4())
            cur.execute("""
                INSERT INTO cws_memory.token_store
                    (id, session_id, token_index, token_value, ternary_weight,
                     confidence, discernment, stored_at)
                VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s, %s::cws_core.discernment, NOW())
            """, (token_id, session_id, d["token_index"], d["token_value"],
                  d["weight"], d["agreement"], d["result"]))
            cur.execute("""
                INSERT INTO cws_memory.fortoken_results
                    (id, token_store_id, forward_score, passed, computed_at)
                VALUES (%s::uuid, %s::uuid, %s, true, NOW())
            """, (str(uuid.uuid4()), token_id, d["forward_value"]))
            cur.execute("""
                INSERT INTO cws_memory.revtoken_audits
                    (id, token_store_id, reverse_score, passed, computed_at)
                VALUES (%s::uuid, %s::uuid, %s, true, NOW())
            """, (str(uuid.uuid4()), token_id, d["reverse_value"]))

    # ── Molecular bond write (primary path) ──────────────────────
    try:
        plane_int = PLANE_MAP.get(plane or "semantic", 0)
        fertile_count = len(fertile)
        total_count = len(discernment)
        trust = fertile_count / max(total_count, 1)

        bond = Bond(
            bond_type="word",
            plane=plane_int,
            memory=1, present=0, destiny=1,
            content=content,
            trust_score=trust,
            state="FERTILE",
            document_id=entry["id"],
        )
        backend = get_backend()
        backend.store_bond(bond)
    except Exception:
        pass  # molecular write failure is non-fatal during transition

    return entry["id"]
