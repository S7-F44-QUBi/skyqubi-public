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

def match_route(rules: list[dict], task_type: str | None, model_params: int | None) -> dict:
    sorted_rules = sorted([r for r in rules if r["enabled"]], key=lambda r: r["priority"])
    for rule in sorted_rules:
        if rule["match_task_type"] and rule["match_task_type"] != task_type:
            continue
        if rule["match_param_max"] and model_params is not None:
            if model_params >= rule["match_param_max"]:
                continue
        return {
            "id": str(uuid.uuid4()), "rule_id": rule["id"], "rule_name": rule["rule_name"],
            "path_chosen": rule["route_to"], "reason": rule["reason"],
            "decided_at": datetime.now(timezone.utc).isoformat(),
        }
    return {
        "id": str(uuid.uuid4()), "rule_id": None, "rule_name": None,
        "path_chosen": "standard", "reason": "default",
        "decided_at": datetime.now(timezone.utc).isoformat(),
    }

async def route_query(db_conn, query: str, task_type: str | None = None, model_hint: str | None = None) -> dict:
    with db_conn.cursor() as cur:
        cur.execute("""
            SELECT id::text, rule_name, priority, match_model_family, match_task_type,
                   match_param_max, route_to::text, reason::text, enabled
            FROM cws_routing.rules WHERE enabled = true ORDER BY priority
        """)
        cols = [d[0] for d in cur.description]
        rules = [dict(zip(cols, row)) for row in cur.fetchall()]
    decision = match_route(rules, task_type, model_params=None)
    decision["input_hash"] = __import__("hashlib").sha256(query.encode()).hexdigest()[:64]
    decision["detected_task"] = task_type
    with db_conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_routing.decisions
                (id, input_hash, detected_task, rule_matched, path_chosen, reason, decided_at)
            VALUES (%(id)s::uuid, %(input_hash)s, %(detected_task)s,
                    %(rule_id)s::uuid, %(path_chosen)s::cws_routing.inference_path,
                    %(reason)s::cws_routing.route_reason, NOW())
        """, decision)
    return decision
