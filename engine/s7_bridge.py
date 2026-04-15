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
from engine.s7_http import mempalace_add_drawer

async def sync_to_palace(db_conn, entry_id: str) -> dict:
    with db_conn.cursor() as cur:
        cur.execute("""
            SELECT e.plane::text, e.content, e.source_system,
                   COALESCE(c.entity_type, 'memory') as entity_type
            FROM cws_memory.entries e
            LEFT JOIN cws_core.entities c ON e.entity_id = c.id
            WHERE e.id = %s::uuid
        """, (entry_id,))
        row = cur.fetchone()
        if not row:
            return {"synced": False, "error": "entry not found"}
        plane, content, source_system, entity_type = row
        cur.execute("""
            SELECT wing_name, hall_name, room_name
            FROM cws_bridge.palace_mapping
            WHERE cws_plane::text = %s AND cws_entity_type = %s AND sync_enabled = true
            LIMIT 1
        """, (plane, entity_type))
        mapping = cur.fetchone()
    if not mapping:
        wing, hall, room = "private-ai", "facts", plane
    else:
        wing, hall, room = mapping
    try:
        result = await mempalace_add_drawer(wing=wing, hall=hall, room=room, label=f"cws:{entry_id[:8]}", content=content)
        synced = True
        error = None
    except Exception as e:
        result = {}
        synced = False
        error = str(e)
    with db_conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_bridge.sync_log
                (id, source_system, target_system, direction, source_id,
                 source_content, discernment, synced_at)
            VALUES (%s::uuid, 'cws', 'mempalace', 'cws_to_palace'::cws_bridge.sync_direction,
                    %s, %s, 'FERTILE'::cws_core.discernment, NOW())
        """, (str(uuid.uuid4()), entry_id, content[:500]))
    return {"synced": synced, "wing": wing, "hall": hall, "room": room, "error": error}
