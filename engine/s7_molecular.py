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
"""
S7 Molecular Bond System
=========================
Unified storage: every piece of data is a bond with a
memory.present.destiny vector across 9 planes (-4 to +4).

Dual backend: PostgreSQL (SAGE) or SQLite (USB/portable).
INSERT-only covenant on all backends.

Patent: TPP99606 — 123Tech / 2XR, LLC
"""

import os
import uuid
import math
import json
import sqlite3
from contextlib import contextmanager
from dataclasses import dataclass, field

PLANE_COUNT = 9
PLANE_MIN   = -4
PLANE_MAX   = 4
CURVE_MIN   = -7
CURVE_MAX   = 7
TERNARY_POS = 0.1
TRUST_THRESHOLD = 7 / 9  # 77.777...%
ANCHORED_MIN_SESSIONS = 7

SQLITE_PATH = os.getenv("S7_MOLECULAR_DB", "/s7/skyqubi/data/molecular.db")

PLANE_NAMES = {
    -4: "Guard",   -3: "Refine",  -2: "Math",
    -1: "Router",   0: "Door",
     1: "Chat",     2: "Code",     3: "Embed",   4: "Vision",
}

VECTOR_NAMES = {
    ( 1,  0,  1): "FERTILE",        (-1,  0,  1): "RESURRECTION",
    ( 0,  0,  1): "PORTAL_OPEN",    ( 1,  1,  1): "ABUNDANT",
    (-1, -1, -1): "STASIS",         (-1,  1, -1): "TOWER",
    (-1,  0, -1): "DANGER",         ( 0,  0,  0): "MAX_UNCERTAINTY",
    ( 1,  0,  0): "MEMORY_ONLY",    ( 0,  0, -1): "PORTAL_CLOSE",
    ( 1,  1,  0): "GROWING",        ( 0,  1,  1): "EMERGING",
    ( 1,  0, -1): "FALLING",        (-1,  1,  0): "RECOVERING",
    ( 0,  1,  0): "PRESENT_ONLY",   ( 1, -1,  1): "TESTED",
    (-1, -1,  1): "REDEEMED",       ( 1,  1, -1): "DECLINING",
    ( 0, -1,  0): "SUFFERING",      ( 1, -1,  0): "CHALLENGED",
    (-1,  1,  1): "TRANSFORMED",    ( 0,  1, -1): "MISLED",
    ( 0, -1,  1): "ENDURING",       (-1, -1,  0): "TRAPPED",
    ( 0, -1, -1): "LOST",           ( 1, -1, -1): "BETRAYED",
    (-1,  0,  0): "WOUNDED",
}

def resolve_vector_name(memory: int, present: int, destiny: int) -> str:
    return VECTOR_NAMES.get((memory, present, destiny), "UNKNOWN")


@dataclass
class Bond:
    bond_type: str
    plane: int
    memory: int
    present: int
    destiny: int
    content: str
    vector_name: str = ""
    embedding: list[float] | None = None
    curve_value: int | None = None
    plane_curves: list[float] | None = None
    plane_ternary: list[int] | None = None
    plan_point: str | None = None
    location_weight: float = 1.0
    plane_affinity: list[int] | None = None
    witness_id: str | None = None
    consensus_id: str | None = None
    trust_score: float | None = None
    trust_tier: str | None = None
    latency_ms: int | None = None
    document_id: str | None = None
    chunk_index: int | None = None
    dataset: str | None = None
    state: str | None = None
    id: str = ""

    def __post_init__(self):
        if not self.id:
            self.id = str(uuid.uuid4())
        if not self.vector_name:
            self.vector_name = resolve_vector_name(self.memory, self.present, self.destiny)


class MolecularBackend:
    def store_bond(self, bond: Bond) -> str:
        raise NotImplementedError
    def query_bonds(self, bond_type: str | None = None, plane: int | None = None,
                    state: str | None = None, limit: int = 100) -> list[dict]:
        raise NotImplementedError
    def get_words(self) -> list[dict]:
        raise NotImplementedError
    def compute_trust(self, witness_id: str) -> dict:
        raise NotImplementedError
    def close(self):
        pass


class PostgresBackend(MolecularBackend):
    def __init__(self, conn):
        self._conn = conn

    def store_bond(self, bond: Bond) -> str:
        with self._conn.cursor() as cur:
            cur.execute("""
                INSERT INTO sky_molecular.bonds
                    (id, bond_type, plane, memory, present, destiny, vector_name,
                     content, embedding, curve_value, plane_curves, plane_ternary,
                     plan_point, location_weight, plane_affinity,
                     witness_id, consensus_id, trust_score, trust_tier, latency_ms,
                     document_id, chunk_index, dataset, state)
                VALUES (%s::uuid, %s, %s, %s, %s, %s, %s,
                        %s, %s, %s, %s, %s,
                        %s, %s, %s,
                        %s, %s, %s, %s, %s,
                        %s::uuid, %s, %s, %s)
            """, (bond.id, bond.bond_type, bond.plane, bond.memory, bond.present,
                  bond.destiny, bond.vector_name,
                  bond.content, bond.embedding, bond.curve_value,
                  bond.plane_curves, bond.plane_ternary,
                  bond.plan_point, bond.location_weight, bond.plane_affinity,
                  bond.witness_id, bond.consensus_id, bond.trust_score,
                  bond.trust_tier, bond.latency_ms,
                  bond.document_id, bond.chunk_index, bond.dataset, bond.state))
        self._conn.commit()
        return bond.id

    def query_bonds(self, bond_type=None, plane=None, state=None, limit=100):
        clauses = ["1=1"]
        params = []
        if bond_type:
            clauses.append("bond_type = %s")
            params.append(bond_type)
        if plane is not None:
            clauses.append("plane = %s")
            params.append(plane)
        if state:
            clauses.append("state = %s")
            params.append(state)
        params.append(limit)
        with self._conn.cursor() as cur:
            cur.execute(f"""
                SELECT id, bond_type, plane, memory, present, destiny,
                       vector_name, content, curve_value, state, created_at
                FROM sky_molecular.bonds
                WHERE {' AND '.join(clauses)}
                ORDER BY created_at DESC LIMIT %s
            """, params)
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def get_words(self):
        with self._conn.cursor() as cur:
            cur.execute("""
                SELECT content, curve_value, plane_affinity, plan_point, location_weight
                FROM sky_molecular.bonds
                WHERE bond_type IN ('word', 'symbol')
                ORDER BY content
            """)
            return [{"word": r[0], "curve": r[1], "planes": r[2],
                     "point": r[3], "weight": r[4]} for r in cur.fetchall()]

    def compute_trust(self, witness_id):
        with self._conn.cursor() as cur:
            cur.execute("""
                SELECT
                    COUNT(*) FILTER (WHERE state = 'FERTILE') AS fertile,
                    COUNT(*) AS total
                FROM sky_molecular.bonds
                WHERE bond_type = 'output' AND witness_id = %s
            """, (witness_id,))
            row = cur.fetchone()
            fertile, total = row[0] or 0, row[1] or 0
            score = fertile / max(total, 1)
            if score >= TRUST_THRESHOLD and total >= ANCHORED_MIN_SESSIONS:
                tier = "ANCHORED"
            elif score >= TRUST_THRESHOLD:
                tier = "TRUSTED"
            elif score >= 0.50:
                tier = "PROBATIONARY"
            else:
                tier = "UNTRUSTED"
            return {"witness_id": witness_id, "fertile": fertile, "total": total,
                    "trust_score": round(score, 6), "tier": tier}


class SqliteBackend(MolecularBackend):
    def __init__(self, db_path: str = SQLITE_PATH):
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        self._conn = sqlite3.connect(db_path)
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._init_tables()

    def _init_tables(self):
        self._conn.executescript("""
            CREATE TABLE IF NOT EXISTS bonds (
                id              TEXT PRIMARY KEY,
                bond_type       TEXT NOT NULL,
                plane           INTEGER NOT NULL,
                memory          INTEGER NOT NULL,
                present         INTEGER NOT NULL,
                destiny         INTEGER NOT NULL,
                vector_name     TEXT NOT NULL,
                content         TEXT NOT NULL,
                embedding       TEXT,
                curve_value     INTEGER,
                plane_curves    TEXT,
                plane_ternary   TEXT,
                plan_point      TEXT,
                location_weight REAL DEFAULT 1.0,
                plane_affinity  TEXT,
                witness_id      TEXT,
                consensus_id    TEXT,
                trust_score     REAL,
                trust_tier      TEXT,
                latency_ms      INTEGER,
                document_id     TEXT,
                chunk_index     INTEGER,
                dataset         TEXT,
                state           TEXT,
                created_at      TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_bonds_type ON bonds (bond_type);
            CREATE INDEX IF NOT EXISTS idx_bonds_plane ON bonds (plane);
            CREATE INDEX IF NOT EXISTS idx_bonds_vector ON bonds (memory, present, destiny);
            CREATE INDEX IF NOT EXISTS idx_bonds_state ON bonds (state);

            CREATE TRIGGER IF NOT EXISTS covenant_no_update
                BEFORE UPDATE ON bonds
                BEGIN SELECT RAISE(ABORT, 'INSERT-only covenant: UPDATE forbidden'); END;

            CREATE TRIGGER IF NOT EXISTS covenant_no_delete
                BEFORE DELETE ON bonds
                BEGIN SELECT RAISE(ABORT, 'INSERT-only covenant: DELETE forbidden'); END;
        """)

    def store_bond(self, bond: Bond) -> str:
        self._conn.execute("""
            INSERT INTO bonds
                (id, bond_type, plane, memory, present, destiny, vector_name,
                 content, embedding, curve_value, plane_curves, plane_ternary,
                 plan_point, location_weight, plane_affinity,
                 witness_id, consensus_id, trust_score, trust_tier, latency_ms,
                 document_id, chunk_index, dataset, state)
            VALUES (?,?,?,?,?,?,?, ?,?,?,?,?, ?,?,?, ?,?,?,?,?, ?,?,?,?)
        """, (bond.id, bond.bond_type, bond.plane, bond.memory, bond.present,
              bond.destiny, bond.vector_name,
              bond.content,
              json.dumps(bond.embedding) if bond.embedding else None,
              bond.curve_value,
              json.dumps(bond.plane_curves) if bond.plane_curves else None,
              json.dumps(bond.plane_ternary) if bond.plane_ternary else None,
              bond.plan_point, bond.location_weight,
              json.dumps(bond.plane_affinity) if bond.plane_affinity else None,
              bond.witness_id, bond.consensus_id, bond.trust_score,
              bond.trust_tier, bond.latency_ms,
              bond.document_id, bond.chunk_index, bond.dataset, bond.state))
        self._conn.commit()
        return bond.id

    def query_bonds(self, bond_type=None, plane=None, state=None, limit=100):
        clauses = ["1=1"]
        params = []
        if bond_type:
            clauses.append("bond_type = ?")
            params.append(bond_type)
        if plane is not None:
            clauses.append("plane = ?")
            params.append(plane)
        if state:
            clauses.append("state = ?")
            params.append(state)
        params.append(limit)
        cur = self._conn.execute(f"""
            SELECT id, bond_type, plane, memory, present, destiny,
                   vector_name, content, curve_value, state, created_at
            FROM bonds
            WHERE {' AND '.join(clauses)}
            ORDER BY created_at DESC LIMIT ?
        """, params)
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]

    def get_words(self):
        cur = self._conn.execute("""
            SELECT content, curve_value, plane_affinity, plan_point, location_weight
            FROM bonds WHERE bond_type IN ('word', 'symbol') ORDER BY content
        """)
        results = []
        for r in cur.fetchall():
            results.append({"word": r[0], "curve": r[1],
                            "planes": json.loads(r[2]) if r[2] else [],
                            "point": r[3], "weight": r[4]})
        return results

    def compute_trust(self, witness_id):
        cur = self._conn.execute("""
            SELECT
                SUM(CASE WHEN state = 'FERTILE' THEN 1 ELSE 0 END),
                COUNT(*)
            FROM bonds
            WHERE bond_type = 'output' AND witness_id = ?
        """, (witness_id,))
        row = cur.fetchone()
        fertile, total = row[0] or 0, row[1] or 0
        score = fertile / max(total, 1)
        if score >= TRUST_THRESHOLD and total >= ANCHORED_MIN_SESSIONS:
            tier = "ANCHORED"
        elif score >= TRUST_THRESHOLD:
            tier = "TRUSTED"
        elif score >= 0.50:
            tier = "PROBATIONARY"
        else:
            tier = "UNTRUSTED"
        return {"witness_id": witness_id, "fertile": fertile, "total": total,
                "trust_score": round(score, 6), "tier": tier}

    def close(self):
        self._conn.close()


def get_backend() -> MolecularBackend:
    """Auto-detect: PostgreSQL if available, else SQLite."""
    try:
        import psycopg2
        conn = psycopg2.connect(
            host=os.getenv("CWS_DB_HOST", "127.0.0.1"),
            port=int(os.getenv("CWS_DB_PORT", "7090")),
            dbname=os.getenv("CWS_DB_NAME", "s7_cws"),
            user=os.getenv("CWS_DB_USER", "s7"),
            password=os.getenv("CWS_DB_PASS", ""),
        )
        return PostgresBackend(conn)
    except Exception:
        return SqliteBackend()


# ── Akashic Seed Words as Bonds ──────────────────────────────────
def seed_bonds(backend: MolecularBackend):
    """Seed the Akashic Language Index words into the bonds table."""
    from s7_akashic import SEED_WORDS
    count = 0
    for entry in SEED_WORDS:
        word = entry["word"].lower().strip()
        curve = entry["curve"]
        mem = 1 if curve > 0 else (-1 if curve < 0 else 0)
        prs = 0  # words stand at the Door
        dst = 1 if curve > 0 else (-1 if curve < 0 else 0)
        bond = Bond(
            bond_type="word",
            plane=0,
            memory=mem, present=prs, destiny=dst,
            content=word,
            curve_value=curve,
            plan_point=entry.get("point", ""),
            location_weight=entry.get("weight", 1.0),
            plane_affinity=entry.get("planes", []),
            state="FERTILE" if curve > 0 else ("BABEL" if curve < 0 else "DOOR"),
        )
        backend.store_bond(bond)
        count += 1
    return count
