#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — QBIT Prism v1.0.1: Ingest driver
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
# Licensed under CWS-BSL-1.1
# Patent Pending: TPP99606 / CWS-005
# ═══════════════════════════════════════════════════════════════════
"""
Ingest text into the Prism LocationID matrix.

Same pipeline as s7_prism_detect but instead of a lookup it ends in
an INSERT. Uses the Phase 5 Akashic encoder to get ternary plane
directions, bridges Phase 5 (7 planes) to Prism OCTi (8 planes),
builds a full LocationID record, writes it into cws_core.location_id.

Usage:
    ingest_text(text, witness='S7-REF-0001', aptitude_delta=3,
                rev_token=<door-row-id>, notes='...')

    python3 engine/s7_prism_ingest.py text "the text to ingest" \\
        [--witness S7-REF-0001] [--apt 3] [--rev-token UUID]

    python3 engine/s7_prism_ingest.py corpus akashic
        → ingests every row from akashic.ancient_text by summary,
          anchoring each one back to the Door seed row

    python3 engine/s7_prism_ingest.py --help
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from typing import Optional

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import s7_akashic
import s7_prism
from s7_prism_detect import (
    akashic_to_prism,
    _pg_connect,
    _build_index_with_universals,
    check_forbidden_tokens,
    record_violation,
)
from s7_input_guard import sanitize_or_violation


def _sha256_hex(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def _encode_text_to_prism(text: str) -> dict:
    """Phase 5 encode → bridge to Prism OCTi plane shape. Uses seed + universals."""
    index = _build_index_with_universals()
    tokens = s7_akashic.tokenise(text)
    encoding = s7_akashic.encode(tokens, index)
    return akashic_to_prism(encoding)


def ingest_text(
    text: str,
    *,
    witness: str = "S7-REF-0001",
    aptitude_delta: int = 0,
    for_token: Optional[str] = None,
    rev_token: Optional[str] = None,
    long_deg: Optional[float] = None,
    lat_deg: Optional[float] = None,
    sub_num: int = 1,
    sub_den: int = 1,
    forbidden: bool = False,
    notes: Optional[str] = None,
    conn=None,
    session_id: str = "ingest-cli",
) -> dict:
    """
    Encode `text`, build a LocationID record, INSERT into
    cws_core.location_id, return a summary dict with the new row's
    id and cell.

    Refuses at the token level if the text contains any surface
    form from akashic.forbidden. Refused texts are NEVER written
    to the matrix. Refusals also increment the per-session
    violation counter — 3 violations → reset_context grace.

    If `conn` is supplied, use it (caller manages commit/close).
    Otherwise open and close a connection for this single insert.
    """
    # Input guard — sanitise BEFORE any other check so homoglyphs,
    # null bytes, and oversize payloads never touch the matrix.
    sanitised, guard_violation = sanitize_or_violation(text)
    if guard_violation is not None:
        return {
            **guard_violation,
            "forbidden_token": None,  # not a forbidden hit, a guard hit
        }
    text = sanitised

    # Covenant refusal check — before any encoding, before any write
    hit = check_forbidden_tokens(text)
    if hit is not None:
        counter = record_violation(session_id, hit, witness=witness)
        return {
            "status": "refused",
            "reason": "text contains a forbidden pattern — see akashic.forbidden",
            "pastoral": counter["message"],
            "violation_count": counter["count"],
            "reset_context": counter["reset_triggered"],
            "session_resets": counter["reset_count"],
            # forbidden_token intentionally not echoed — no shared secrets
        }

    prism = _encode_text_to_prism(text)
    cell = s7_prism.cell_tuple(prism)

    manage_conn = conn is None
    if manage_conn:
        conn = _pg_connect()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO cws_core.location_id (
                    sensory_dir, episodic_dir, semantic_dir, associative_dir,
                    procedural_dir, lexical_dir, relational_dir, executive_dir,
                    sub_num, sub_den,
                    long_deg, lat_deg,
                    aptitude_delta,
                    for_token, rev_token,
                    forbidden,
                    witness, source_text_hash, notes
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s,
                    %s, %s,
                    %s,
                    %s::uuid, %s::uuid,
                    %s,
                    %s, %s, %s
                )
                RETURNING id::text
                """,
                (
                    cell[0], cell[1], cell[2], cell[3],
                    cell[4], cell[5], cell[6], cell[7],
                    sub_num, sub_den,
                    long_deg, lat_deg,
                    aptitude_delta,
                    for_token, rev_token,
                    forbidden,
                    witness, _sha256_hex(text), notes,
                ),
            )
            new_id = cur.fetchone()[0]
        if manage_conn:
            conn.commit()
    finally:
        if manage_conn:
            conn.close()

    return {
        "id": new_id,
        "cell": list(cell),
        "witness": witness,
        "aptitude_delta": aptitude_delta,
        "rev_token": rev_token,
        "text_hash": _sha256_hex(text),
    }


def _get_door_seed_id(conn) -> Optional[str]:
    """Find the Door-cell reference row seeded by the schema migration."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id::text FROM cws_core.location_id
            WHERE witness = 'S7-REF-0001'
              AND sensory_dir = 0 AND episodic_dir = 0
              AND semantic_dir = 0 AND associative_dir = 0
              AND procedural_dir = 0 AND lexical_dir = 0
              AND relational_dir = 0 AND executive_dir = 0
              AND notes LIKE 'Prism v1.0.1 schema foundation%'
            ORDER BY created_at ASC
            LIMIT 1
            """
        )
        row = cur.fetchone()
        return row[0] if row else None


def ingest_akashic_corpus(aptitude_delta: int = 3) -> dict:
    """
    Walk every row in akashic.ancient_text and ingest each one's
    summary into the Prism matrix, with rev_token pointing at the
    Door seed row so each ingested entry has a legitimate strand
    anchor.

    Returns a summary: rows_ingested, cells_used, unique_cells.
    Idempotent by text_hash — reruns skip rows we've already ingested.
    """
    conn = _pg_connect()
    try:
        door_id = _get_door_seed_id(conn)
        if not door_id:
            return {"status": "error", "reason": "Door seed row not found — run the schema migration first"}

        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT slug, title, origin_region, origin_language, approximate_age, summary
                FROM akashic.ancient_text
                WHERE summary IS NOT NULL AND summary <> ''
                ORDER BY priority, slug
                """
            )
            rows = cur.fetchall()

        ingested = 0
        skipped = 0
        new_cells: set = set()

        for slug, title, region, language, age, summary in rows:
            # Idempotency: if we've already ingested this exact text, skip
            text_hash = _sha256_hex(summary)
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT 1 FROM cws_core.location_id WHERE source_text_hash = %s LIMIT 1",
                    (text_hash,),
                )
                if cur.fetchone():
                    skipped += 1
                    continue

            result = ingest_text(
                summary,
                witness="S7-REF-0001",
                aptitude_delta=aptitude_delta,
                rev_token=door_id,
                notes=f"akashic corpus: {slug} — {title}",
                conn=conn,
            )
            ingested += 1
            new_cells.add(tuple(result["cell"]))

        conn.commit()

        # Fresh stats
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    count(*) AS rows,
                    count(DISTINCT (sensory_dir,episodic_dir,semantic_dir,associative_dir,
                                    procedural_dir,lexical_dir,relational_dir,executive_dir)) AS cells_used,
                    sum(aptitude_delta) AS aptitude_total
                FROM cws_core.location_id
                """
            )
            total_rows, cells_used, aptitude_total = cur.fetchone()

        return {
            "status": "ok",
            "rows_examined":   len(rows),
            "rows_ingested":   ingested,
            "rows_skipped":    skipped,
            "new_cells":       len(new_cells),
            "matrix_rows":     total_rows,
            "matrix_cells":    cells_used,
            "aptitude_total":  aptitude_total,
        }
    finally:
        conn.close()


def main() -> int:
    parser = argparse.ArgumentParser(prog="s7_prism_ingest")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_text = sub.add_parser("text", help="Ingest one text string")
    p_text.add_argument("text", nargs="+")
    p_text.add_argument("--witness", default="S7-REF-0001")
    p_text.add_argument("--apt", type=int, default=0)
    p_text.add_argument("--for-token", default=None)
    p_text.add_argument("--rev-token", default=None)
    p_text.add_argument("--notes", default=None)
    p_text.add_argument("--session-id", default="ingest-cli",
                        help="session identifier for the violation counter")

    p_corp = sub.add_parser("corpus", help="Ingest a named corpus")
    p_corp.add_argument("name", choices=["akashic"])
    p_corp.add_argument("--apt", type=int, default=3)

    args = parser.parse_args()

    if args.cmd == "text":
        text = " ".join(args.text)
        result = ingest_text(
            text,
            witness=args.witness,
            aptitude_delta=args.apt,
            for_token=args.for_token,
            rev_token=args.rev_token,
            notes=args.notes,
            session_id=args.session_id,
        )
        print(json.dumps(result, indent=2))
        return 0
    elif args.cmd == "corpus" and args.name == "akashic":
        result = ingest_akashic_corpus(aptitude_delta=args.apt)
        print(json.dumps(result, indent=2))
        return 0 if result.get("status") == "ok" else 1
    return 2


if __name__ == "__main__":
    sys.exit(main())
