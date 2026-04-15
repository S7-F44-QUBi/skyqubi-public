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
import os
import psycopg2
from psycopg2 import pool
from contextlib import contextmanager

_pool = None

def init_pool():
    global _pool
    _pool = psycopg2.pool.ThreadedConnectionPool(
        minconn=2, maxconn=10,
        host=os.getenv("CWS_DB_HOST", "127.0.0.1"),
        port=int(os.getenv("CWS_DB_PORT", "57090")),
        dbname=os.getenv("CWS_DB_NAME", "s7_cws"),
        user=os.getenv("CWS_DB_USER", "s7"),
        password=os.getenv("CWS_DB_PASS", ""),
    )

@contextmanager
def get_conn():
    conn = _pool.getconn()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        _pool.putconn(conn)

def close_pool():
    if _pool:
        _pool.closeall()
