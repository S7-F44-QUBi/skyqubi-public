#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — Witness Convergence (7 → 1 vs 7 → 0)
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
# Licensed under CWS-BSL-1.1
# Patent Pending: TPP99606 / CWS-005
# ═══════════════════════════════════════════════════════════════════
"""
7-to-1 witness convergence for Prism LocationIDs.

Jamie: 'So like 7 models converge for 1 token vs 7 tokens = 0 …
        the 1 token is embedded with all evaluation and against
        foundation reducing token and expense of processing same
        data, that is now RAG worthy embedded.'

Rule:
  For each of the 8 OCTi planes, count how many witnesses assigned
  each ternary direction {-1, 0, +1}. If the plurality direction
  is held by at least TRUST_THRESHOLD * N witnesses, that plane
  converges. If EVERY plane converges, the witnesses agreed and a
  single token is emitted. If ANY plane fails to converge, the
  whole witness set produces NULL — '7 tokens = 0.'

  TRUST_THRESHOLD = 7/9 = 0.77777... (Phase 5 covenant constant,
  already in s7_akashic.TRUST_THRESHOLD).

Output when convergence succeeds:
  {
    'converged': True,
    'cell': (d1, d2, ..., d8),
    'witnesses': N,
    'threshold': 0.7777...,
    'per_plane_agreement': {plane: {dir: count}},
    'dissent': [indexes of witnesses who disagreed on at least one
                plane — recorded but not excluded],
  }

Output when convergence fails (7 tokens = 0):
  {
    'converged': False,
    'cell': None,
    'witnesses': N,
    'threshold': 0.7777...,
    'failed_planes': [list of planes that did not cross threshold],
    'per_plane_agreement': {plane: {dir: count}},
  }

The converged case returns a single prism-shaped dict so
build_location_id can consume it directly.
"""
from __future__ import annotations

import json
import os
import sys
from typing import List, Optional

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import s7_prism
import s7_akashic

TRUST_THRESHOLD = s7_akashic.TRUST_THRESHOLD  # 7/9 = 0.77777...


def converge(witness_prisms: List[dict]) -> dict:
    """
    Merge N witness prism dicts into a single consensus result.

    Each witness_prisms[i] must be a dict keyed by plane name with
    {'direction': -1|0|+1, 'magnitude': float}.

    Returns a consensus dict with 'converged' flag, consensus cell
    (or None), per-plane agreement counts, and dissent metadata.
    """
    n = len(witness_prisms)
    if n == 0:
        return {
            "converged": False,
            "cell": None,
            "witnesses": 0,
            "threshold": TRUST_THRESHOLD,
            "failed_planes": list(s7_prism.OCTI_PLANES),
            "per_plane_agreement": {},
            "dissent": [],
        }

    # Count directions per plane
    per_plane: dict = {p: {-1: 0, 0: 0, 1: 0} for p in s7_prism.OCTI_PLANES}
    for wp in witness_prisms:
        for plane in s7_prism.OCTI_PLANES:
            d = int(wp.get(plane, {}).get("direction", 0))
            per_plane[plane][d] = per_plane[plane].get(d, 0) + 1

    # Check each plane against the threshold
    min_needed = int((TRUST_THRESHOLD * n) + 0.9999)   # ceil without importing math
    if TRUST_THRESHOLD * n == int(TRUST_THRESHOLD * n):
        min_needed = int(TRUST_THRESHOLD * n)

    converged_cell = []
    failed_planes = []
    for plane in s7_prism.OCTI_PLANES:
        counts = per_plane[plane]
        top_dir, top_count = max(counts.items(), key=lambda kv: kv[1])
        if top_count >= min_needed:
            converged_cell.append(top_dir)
        else:
            converged_cell.append(None)
            failed_planes.append(plane)

    converged = len(failed_planes) == 0

    # Record which witnesses dissented (had at least one plane not
    # matching the plurality); useful for the Reporter's audit
    dissent = []
    if converged:
        for i, wp in enumerate(witness_prisms):
            for j, plane in enumerate(s7_prism.OCTI_PLANES):
                w_dir = int(wp.get(plane, {}).get("direction", 0))
                if w_dir != converged_cell[j]:
                    dissent.append({"witness_index": i, "plane": plane,
                                    "witness_dir": w_dir,
                                    "consensus_dir": converged_cell[j]})
                    break

    return {
        "converged": converged,
        "cell": tuple(converged_cell) if converged else None,
        "witnesses": n,
        "threshold": TRUST_THRESHOLD,
        "min_witnesses_needed_per_plane": min_needed,
        "per_plane_agreement": {
            p: {str(k): v for k, v in per_plane[p].items()}
            for p in s7_prism.OCTI_PLANES
        },
        "failed_planes": failed_planes,
        "dissent": dissent,
    }


def consensus_to_prism(consensus: dict) -> Optional[dict]:
    """
    Convert a converged consensus dict back into a prism-shaped dict
    that s7_prism.cell_tuple / build_location_id can consume.
    Returns None if the consensus did not converge.
    """
    if not consensus.get("converged"):
        return None
    cell = consensus["cell"]
    return {
        plane: {"direction": cell[i], "magnitude": 0.0}
        for i, plane in enumerate(s7_prism.OCTI_PLANES)
    }


# ── embed_or_dissolve — Jamie's mirror principle in code ─────────

def embed_or_dissolve(
    consensus: dict,
    *,
    witness: str = "S7-REF-0001",
    aptitude_delta: int = 1,
    notes: Optional[str] = None,
) -> dict:
    """
    Take a converged consensus and either:
      (a) emerge a new token in cws_core.location_id with the
          witness_consensus payload embedded, or
      (b) dissolve into an existing converged row at the same cell
          by incrementing its dissolution_count.

    Returns a status dict naming what happened.

    If the consensus did not converge (7→0), returns status='null'
    and no DB write occurs.
    """
    import json as _json
    from s7_prism_detect import _pg_connect  # lazy import, needs psycopg2

    if not consensus.get("converged"):
        return {
            "status": "null",
            "reason": "7→0 — witnesses did not converge past 7/9 threshold",
            "failed_planes": consensus.get("failed_planes", []),
            "witnesses": consensus.get("witnesses", 0),
        }

    cell = consensus["cell"]
    conn = _pg_connect()
    try:
        cur = conn.cursor()
        # Look for an existing converged row at this exact cell
        cur.execute(
            """
            SELECT id::text, dissolution_count
            FROM cws_core.location_id
            WHERE sensory_dir     = %s
              AND episodic_dir    = %s
              AND semantic_dir    = %s
              AND associative_dir = %s
              AND procedural_dir  = %s
              AND lexical_dir     = %s
              AND relational_dir  = %s
              AND executive_dir   = %s
              AND witness_consensus IS NOT NULL
            ORDER BY dissolution_count DESC, created_at ASC
            LIMIT 1
            """,
            cell,
        )
        row = cur.fetchone()

        if row:
            # Mirror moment — increment the dissolution counter
            existing_id, existing_count = row
            cur.execute(
                """
                UPDATE cws_core.location_id
                SET dissolution_count = dissolution_count + 1
                WHERE id = %s::uuid
                RETURNING dissolution_count
                """,
                (existing_id,),
            )
            (new_count,) = cur.fetchone()
            conn.commit()
            return {
                "status": "dissolved",
                "reason": "token met itself in the mirror — existing converged row at this cell",
                "cell": list(cell),
                "existing_id": existing_id,
                "dissolution_count": new_count,
            }

        # Emerge — new converged token enters the matrix
        payload = _json.dumps({
            "witnesses": consensus["witnesses"],
            "threshold": consensus["threshold"],
            "min_witnesses_needed_per_plane": consensus.get("min_witnesses_needed_per_plane"),
            "per_plane_agreement": consensus["per_plane_agreement"],
            "dissent": consensus.get("dissent", []),
            "source": "s7_witness_converge.embed_or_dissolve",
        })
        cur.execute(
            """
            INSERT INTO cws_core.location_id (
                sensory_dir, episodic_dir, semantic_dir, associative_dir,
                procedural_dir, lexical_dir, relational_dir, executive_dir,
                aptitude_delta, witness, notes, witness_consensus
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s::jsonb
            )
            RETURNING id::text
            """,
            (
                cell[0], cell[1], cell[2], cell[3],
                cell[4], cell[5], cell[6], cell[7],
                aptitude_delta, witness, notes or "witness convergence — emerged",
                payload,
            ),
        )
        (new_id,) = cur.fetchone()
        conn.commit()
        return {
            "status": "emerged",
            "reason": "new converged token — first time this cell has been witnessed",
            "cell": list(cell),
            "id": new_id,
            "witnesses": consensus["witnesses"],
            "dissent_count": len(consensus.get("dissent", [])),
        }
    finally:
        conn.close()


# ── Self-test: 7→1 and 7→0 side by side ──────────────────────────

def _mock_prism(directions: list) -> dict:
    return {
        plane: {"direction": int(d), "magnitude": 0.5}
        for plane, d in zip(s7_prism.OCTI_PLANES, directions)
    }


def _selftest() -> dict:
    """
    Demonstrate the two cases:
      case 1 (7 → 1): 9 witnesses, 8 or 9 agree on every plane
      case 2 (7 → 0): 9 witnesses, split decisions, no plane meets threshold
    """
    plane_target = [1, 0, -1, 0, 1, -1, 0, 1]
    unanimous = [_mock_prism(plane_target) for _ in range(9)]
    # One dissenter still allowed — 8/9 > 7/9 threshold
    mostly = list(unanimous)
    mostly[0] = _mock_prism([-1, 0, -1, 0, 1, -1, 0, 1])  # flips plane 0
    # Split case: half vote +1, half vote -1 on almost every plane
    split = []
    for i in range(9):
        split.append(_mock_prism([
            1 if i < 5 else -1,   # 5 vs 4 on plane 0 — too close
            -1 if i < 4 else 1,   # 4 vs 5 on plane 1 — too close
            0, 0, 0, 0, 0, 0,
        ]))

    case_unanimous = converge(unanimous)
    case_mostly    = converge(mostly)
    case_split     = converge(split)

    return {
        "unanimous_9_of_9": {
            "converged": case_unanimous["converged"],
            "cell": list(case_unanimous["cell"]) if case_unanimous["cell"] else None,
            "dissent_count": len(case_unanimous["dissent"]),
        },
        "mostly_8_of_9": {
            "converged": case_mostly["converged"],
            "cell": list(case_mostly["cell"]) if case_mostly["cell"] else None,
            "dissent_count": len(case_mostly["dissent"]),
        },
        "split_5_4": {
            "converged": case_split["converged"],
            "failed_planes": case_split["failed_planes"],
        },
        "threshold": TRUST_THRESHOLD,
        "min_needed_for_9_witnesses": case_unanimous["min_witnesses_needed_per_plane"],
    }


if __name__ == "__main__":
    print(json.dumps(_selftest(), indent=2))
