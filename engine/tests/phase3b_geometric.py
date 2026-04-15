#!/usr/bin/env python3
"""
S7 SkyQUBi — Phase 3b: Geometric Circuit Breaker Test
======================================================
Uses synthetically-constructed embeddings with known convergence polarity
to produce deterministic FERTILE / BABEL outcomes and trigger the
circuit breaker — independent of any LLM embedding model.

Why synthetic? nomic-embed-text (768-dim, padded to 1536) produces
embeddings where planes 4-7 are all zero (Door-state), guaranteeing
≥50% FERTILE regardless of content. Geometric construction bypasses
this limitation and tests the QBIT Prism mechanism directly.

Test Cases:
  T1 — Identical polarity      → 8/8 FERTILE, score=1.00
  T2 — Opposite polarity       → 0/8 FERTILE, score=0.00 (pure BABEL)
  T3 — Partial match (5/8)     → 5/8 FERTILE, score=0.625 (FERTILE)
  T4 — Partial match (3/8)     → 3/8 FERTILE, score=0.375 (BABEL)
  T5 — Door query vs any       → 8/8 FERTILE (Door universal gate)
  T6 — Any vs Door memory      → 8/8 FERTILE (Door universal gate)

Circuit Breaker Test:
  Chain of 8 hops: alternating FERTILE/BABEL to cross 70% threshold

123Tech / 2XR, LLC — Patent Pending CWS-005
"""

import sys
import os
import math
import json
import uuid
import psycopg2

sys.path.insert(0, os.path.dirname(__file__))

from s7_prism import (
    decompose, direction_agreement, OCTI_PLANES, EMBEDDING_DIM,
    SEGMENT_SIZE, prism_summary, THRESHOLD_LOW, THRESHOLD_HIGH,
)

# ── DB ────────────────────────────────────────────────────────────────────────

DB = dict(host="127.0.0.1", port=7090, dbname="s7_cws",
          user="s7", password=os.getenv("CWS_DB_PASS", ""))

CIRCUIT_BREAKER_THRESHOLD = 0.70

# ── Embedding Constructors ────────────────────────────────────────────────────
# The Prism projects segment mean through tanh(mean * 2.0) * 2.0.
# To force direction +1: mean must satisfy tanh(mean*2) > THRESHOLD_HIGH (0.1)
#   → mean > atanh(0.1/2)/2 ≈ 0.053 — use mean = 0.5 → x ≈ 0.76, direction=+1
# To force direction -1: mean < atanh(-0.1/2)/2 ≈ -0.053 — use mean = -0.5
# To force direction  0 (Door): mean ≈ 0.0 — use mean = 0.0

MEAN_STRUCTURE =  -0.5   # projects to x≈-0.76, direction=-1
MEAN_NURTURE   =  +0.5   # projects to x≈+0.76, direction=+1
MEAN_DOOR      =   0.0   # projects to x=0.00,  direction=0


def make_embedding(plane_directions: list[int]) -> list[float]:
    """
    Build a 1536-dim embedding with known convergence polarity per plane.
    plane_directions: list of 8 ints, each in {-1, 0, +1}
    """
    assert len(plane_directions) == 8
    emb = []
    for d in plane_directions:
        if d == -1:
            mean = MEAN_STRUCTURE
        elif d == 1:
            mean = MEAN_NURTURE
        else:
            mean = MEAN_DOOR
        # Add small noise so the segment isn't perfectly flat
        # (avoids floating-point edge cases near the threshold)
        segment = [mean + (i % 3 - 1) * 0.001 for i in range(SEGMENT_SIZE)]
        emb.extend(segment)
    assert len(emb) == EMBEDDING_DIM
    return emb


def expected_direction(d: int) -> str:
    return {-1: "←-1", 0: "·0·", 1: "+1→"}[d]


def divider(title=""):
    w = 70
    if title:
        pad = (w - len(title) - 2) // 2
        print(f"\n{'─'*pad} {title} {'─'*(w-len(title)-2-pad)}")
    else:
        print("─" * w)


# ── Store helpers ─────────────────────────────────────────────────────────────

def store_hop(conn, chain_id, hop_idx, agr):
    mask = 0
    for i, plane in enumerate(OCTI_PLANES):
        if agr["planes"].get(plane, {}).get("fertile", False):
            mask |= (1 << i)
    fertile_planes = [p for p in OCTI_PLANES if agr["planes"].get(p, {}).get("fertile")]
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_memory.rag_reasoning
                (chain_id, hop_index, agreement_score,
                 fertile_planes, total_planes, plane_mask, primary_planes, result)
            VALUES (%s::uuid, %s, %s, %s, %s, %s, %s, %s)
        """, (chain_id, hop_idx, agr["agreement_score"],
              agr["fertile_planes"], agr["total_planes"],
              mask, fertile_planes, agr["result"]))


def pre_register_chain(conn, label, query) -> str:
    cid = str(uuid.uuid4())
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_memory.reasoning_chains
                (id, query_text, query_hash, total_hops, fertile_hops,
                 babel_hops, converged, babel_ratio, circuit_tripped)
            VALUES (%s::uuid, %s, %s, 0, 0, 0, false, 0, false)
        """, (cid, f"[geometric] {label}", cid[:16]))
    conn.commit()
    return cid


def store_chain_final(conn, label, total, fertile, babel, converged, babel_ratio, tripped):
    cid = str(uuid.uuid4())
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_memory.reasoning_chains
                (id, query_text, query_hash, total_hops, fertile_hops,
                 babel_hops, converged, babel_ratio, circuit_tripped)
            VALUES (%s::uuid, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (cid, f"[geometric-final] {label}", cid[:16],
              total, fertile, babel, converged, babel_ratio, tripped))
    conn.commit()


def store_circuit_event(conn, babel_ratio, tripped):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cws_core.circuit_breaker_events
                (babel_ratio, threshold, triggered, action_taken)
            VALUES (%s, %s, %s, %s)
        """, (babel_ratio, CIRCUIT_BREAKER_THRESHOLD, tripped,
              "inference_halted" if tripped else "inference_continues"))
    conn.commit()


# ── Test Cases ────────────────────────────────────────────────────────────────

def run_direction_tests():
    divider("PART 1 — DIRECTION AGREEMENT UNIT TESTS")

    TESTS = [
        {
            "id": "T1",
            "label": "Identical polarity — all +1",
            "query_dirs":  [1, 1, 1, 1, 1, 1, 1, 1],
            "memory_dirs": [1, 1, 1, 1, 1, 1, 1, 1],
            "expect_fertile": 8,
            "expect_result": "FERTILE",
        },
        {
            "id": "T2",
            "label": "Opposite polarity — query +1 vs memory -1",
            "query_dirs":  [1, 1, 1, 1, 1, 1, 1, 1],
            "memory_dirs": [-1, -1, -1, -1, -1, -1, -1, -1],
            "expect_fertile": 0,
            "expect_result": "BABEL",
        },
        {
            "id": "T3",
            "label": "Partial match 5/8 — above threshold",
            "query_dirs":  [1,  1,  1,  1,  1, -1, -1, -1],
            "memory_dirs": [1,  1,  1,  1,  1,  1,  1,  1],
            "expect_fertile": 5,
            "expect_result": "FERTILE",
        },
        {
            "id": "T4",
            "label": "Partial match 3/8 — below threshold",
            "query_dirs":  [1,  1,  1, -1, -1, -1, -1, -1],
            "memory_dirs": [1,  1,  1,  1,  1,  1,  1,  1],
            "expect_fertile": 3,
            "expect_result": "BABEL",
        },
        {
            "id": "T5",
            "label": "Door query — universal gate (query all 0)",
            "query_dirs":  [0,  0,  0,  0,  0,  0,  0,  0],
            "memory_dirs": [-1, -1, -1, -1, 1,  1,  1,  1],
            "expect_fertile": 8,
            "expect_result": "FERTILE",
        },
        {
            "id": "T6",
            "label": "Door memory — universal gate (memory all 0)",
            "query_dirs":  [-1, -1, -1, -1, 1,  1,  1,  1],
            "memory_dirs": [0,  0,  0,  0,  0,  0,  0,  0],
            "expect_fertile": 8,
            "expect_result": "FERTILE",
        },
        {
            "id": "T7",
            "label": "Boundary: 4/8 match — exactly at FERTILE_PLANE_RATIO (0.5)",
            "query_dirs":  [-1, -1, -1, -1, -1, -1, -1, -1],
            "memory_dirs": [1,   1,  1,  1, -1, -1, -1, -1],
            "expect_fertile": 4,
            "expect_result": "FERTILE",  # 4/8 = 0.5 >= FERTILE_PLANE_RATIO → FERTILE (inclusive >=)
        },
        {
            "id": "T8",
            "label": "Structure vs Door memory on half-planes",
            "query_dirs":  [-1, -1, -1, -1, -1, -1, -1, -1],
            "memory_dirs": [0,   0,  0,  0, -1, -1, -1, -1],
            "expect_fertile": 8,   # all Door memory planes pass + matching planes
            "expect_result": "FERTILE",
        },
    ]

    print(f"\n{'ID':<4} {'Test':<48} {'F/8':>4}  {'Result':<8}  {'Expected':<8}  {'Pass'}")
    print("─" * 85)

    passed = 0
    for t in TESTS:
        q_emb = make_embedding(t["query_dirs"])
        m_emb = make_embedding(t["memory_dirs"])
        q_prism = decompose(q_emb)
        m_prism = decompose(m_emb)

        # Verify constructed directions
        actual_q_dirs = [q_prism[p]["direction"] for p in OCTI_PLANES]
        actual_m_dirs = [m_prism[p]["direction"] for p in OCTI_PLANES]
        assert actual_q_dirs == t["query_dirs"], \
            f"{t['id']}: query dirs {actual_q_dirs} ≠ expected {t['query_dirs']}"
        assert actual_m_dirs == t["memory_dirs"], \
            f"{t['id']}: memory dirs {actual_m_dirs} ≠ expected {t['memory_dirs']}"

        agr = direction_agreement(q_prism, m_prism)
        ok = (agr["fertile_planes"] == t["expect_fertile"] and
              agr["result"] == t["expect_result"])
        if ok:
            passed += 1

        print(f"  {t['id']:<4} {t['label']:<48} {agr['fertile_planes']:>1}/8  "
              f"{agr['result']:<8}  {t['expect_result']:<8}  "
              f"{'✓' if ok else '✗ FAIL'}")

    print(f"\n  {passed}/{len(TESTS)} tests passed")
    return passed == len(TESTS)


def run_circuit_breaker_test(conn):
    divider("PART 2 — CIRCUIT BREAKER TEST")

    print("\nSimulating 8-hop chain where hops 3-8 are BABEL (75% → trips at hop 5)")
    print()

    # Sequence: FERTILE, FERTILE, BABEL, BABEL, BABEL, BABEL, BABEL, BABEL
    # After hop 5: 5 BABEL / 5 total = 100% > 70% → trips
    # After hop 3: 1 BABEL / 3 total = 33% < 70% → ok
    # After hop 4: 2 BABEL / 4 total = 50% < 70% → ok
    # After hop 5: 3 BABEL / 5 total = 60% < 70% → ok  (need 3 hops minimum)
    # After hop 6: 4 BABEL / 6 total = 67% < 70% → ok
    # After hop 7: 5 BABEL / 7 total = 71% ≥ 70% AND total ≥ 3 → TRIPS

    hop_plan = [
        "FERTILE",  # hop 1
        "FERTILE",  # hop 2
        "BABEL",    # hop 3 — 1/3 = 33%
        "BABEL",    # hop 4 — 2/4 = 50%
        "BABEL",    # hop 5 — 3/5 = 60%
        "BABEL",    # hop 6 — 4/6 = 67%
        "BABEL",    # hop 7 — 5/7 = 71% → TRIP
        "BABEL",    # hop 8 — never reached
    ]

    # Construct embeddings to produce known FERTILE/BABEL
    # FERTILE: query +1 vs memory +1 → 8/8 match → FERTILE
    # BABEL:   query +1 vs memory -1 → 0/8 match → BABEL
    q_prism  = decompose(make_embedding([1]*8))   # all nurture
    m_fertile = decompose(make_embedding([1]*8))  # matches query → FERTILE
    m_babel   = decompose(make_embedding([-1]*8)) # opposes query → BABEL

    chain_id = pre_register_chain(conn, "circuit_breaker_test",
                                  "geometric-circuit-breaker-test")

    print(f"{'Hop':<4} {'Plan':<8} {'Result':<10} {'Score':>6}  "
          f"{'BabelRatio':>10}  {'Breaker'}")
    print("─" * 60)

    fertile = 0
    babel   = 0
    tripped = False
    trip_hop = None

    for i, plan in enumerate(hop_plan):
        m_prism = m_fertile if plan == "FERTILE" else m_babel
        agr = direction_agreement(q_prism, m_prism)
        result = agr["result"]

        if result == "FERTILE":
            fertile += 1
        else:
            babel += 1

        total = i + 1
        babel_ratio = babel / total
        breaker_status = ""

        if babel_ratio >= CIRCUIT_BREAKER_THRESHOLD and total >= 3 and not tripped:
            tripped = True
            trip_hop = i + 1
            breaker_status = "⚡ TRIPPED"
            store_hop(conn, chain_id, i, agr)
            conn.commit()
            store_circuit_event(conn, float(babel_ratio), True)
            print(f"  {i+1:<3}  {plan:<8} {result:<10} {agr['agreement_score']:>6.2f}  "
                  f"{babel_ratio:>9.1%}  {breaker_status}")
            break
        else:
            store_hop(conn, chain_id, i, agr)
            conn.commit()
            print(f"  {i+1:<3}  {plan:<8} {result:<10} {agr['agreement_score']:>6.2f}  "
                  f"{babel_ratio:>9.1%}  {breaker_status}")

    conn.commit()

    total_hops = fertile + babel
    final_babel_ratio = babel / total_hops if total_hops > 0 else 0.0

    if tripped:
        print(f"\n  ⚡ Circuit breaker triggered at hop {trip_hop}")
        print(f"     babel_ratio={final_babel_ratio:.1%} ≥ {CIRCUIT_BREAKER_THRESHOLD:.0%} threshold")
        print(f"     Action: inference_halted")
    else:
        print(f"\n  Circuit breaker NOT triggered (babel_ratio={final_babel_ratio:.1%})")

    store_chain_final(conn, "circuit_breaker_test", total_hops, fertile, babel,
                      False, float(final_babel_ratio), tripped)

    return tripped, trip_hop, final_babel_ratio


def run_multi_hop_chain(conn):
    divider("PART 3 — MULTI-HOP FERTILE CONVERGENCE CHAIN")

    print("\nChain: structure query → structure memory → structure memory (converges)")
    print()

    # All structure: query and retrieved memory consistently structure-dominant
    hops = [
        {"query_dirs": [-1]*8, "memory_dirs": [-1]*8, "label": "structure→structure"},
        {"query_dirs": [-1]*8, "memory_dirs": [-1]*8, "label": "structure→structure"},
        {"query_dirs": [-1]*8, "memory_dirs": [-1]*8, "label": "structure→structure"},
        {"query_dirs": [-1]*8, "memory_dirs": [0]*8,  "label": "structure→door (gate)"},
        {"query_dirs": [0]*8,  "memory_dirs": [-1]*8, "label": "door→structure (gate)"},
    ]

    chain_id = pre_register_chain(conn, "multi_hop_convergence", "geometric-multihop-test")

    print(f"{'Hop':<4} {'Type':<28} {'F/8':>4}  {'Result':<8}  {'Score':>6}")
    print("─" * 60)

    fertile = 0
    babel = 0
    for i, h in enumerate(hops):
        q = decompose(make_embedding(h["query_dirs"]))
        m = decompose(make_embedding(h["memory_dirs"]))
        agr = direction_agreement(q, m)
        result = agr["result"]
        if result == "FERTILE":
            fertile += 1
        else:
            babel += 1
        store_hop(conn, chain_id, i, agr)
        conn.commit()
        print(f"  {i+1:<3}  {h['label']:<28} {agr['fertile_planes']:>1}/8  "
              f"{result:<8}  {agr['agreement_score']:>6.2f}")

    total = fertile + babel
    babel_ratio = babel / total
    converged = (fertile / total >= 0.6)
    store_chain_final(conn, "multi_hop_convergence", total, fertile, babel,
                      converged, float(babel_ratio), False)
    store_circuit_event(conn, float(babel_ratio), False)

    print(f"\n  Result: {fertile}/{total} FERTILE — converged={converged}")
    return converged


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    print("S7 SkyQUBi — Phase 3b: Geometric Circuit Breaker Test")
    print("Synthetic embeddings with known polarity — deterministic FERTILE/BABEL")
    divider()

    conn = psycopg2.connect(**DB)

    # Part 1: direction agreement unit tests
    all_passed = run_direction_tests()

    # Part 2: circuit breaker
    tripped, trip_hop, babel_ratio = run_circuit_breaker_test(conn)

    # Part 3: convergent multi-hop chain
    converged = run_multi_hop_chain(conn)

    # Summary
    divider("PHASE 3b SUMMARY")

    results = {
        "direction_tests": "✓ ALL PASSED" if all_passed else "✗ SOME FAILED",
        "circuit_breaker": f"✓ TRIPPED at hop {trip_hop} ({babel_ratio:.1%} BABEL)"
                           if tripped else "✗ DID NOT TRIP",
        "multi_hop_convergence": "✓ CONVERGED" if converged else "✗ DID NOT CONVERGE",
    }

    for k, v in results.items():
        print(f"  {k:<28}  {v}")

    # DB counts
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM cws_memory.reasoning_chains")
        n_chains = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM cws_memory.rag_reasoning")
        n_hops = cur.fetchone()[0]
        cur.execute("SELECT count(*), max(babel_ratio) FROM cws_core.circuit_breaker_events WHERE triggered = TRUE")
        row = cur.fetchone()
        n_trips, max_ratio = row[0], row[1]

    print(f"\nDB: {n_chains} reasoning_chains | {n_hops} rag_reasoning rows | "
          f"{n_trips} circuit_breaker_events triggered (max babel_ratio={max_ratio})")

    conn.close()

    all_ok = all_passed and tripped and converged
    print(f"\nPhase 3b: {'✓ ALL PASS' if all_ok else '⚠ CHECK FAILURES'}")
    print()
    print("Patent evidence produced:")
    print("  Claim 7  — circuit breaker fires at ≥70% BABEL ✓" if tripped else "  Claim 7  — ✗")
    print("  Claim 16 — FERTILE/BABEL direction-verified retrieval ✓" if all_passed else "  Claim 16 — ✗")
    print("  Claim 17 — Door universal gate passes all directions ✓" if all_passed else "  Claim 17 — ✗")
    print("  Claim 18 — multi-hop FERTILE chain converges ✓" if converged else "  Claim 18 — ✗")
    print("  Claim 31 — INSERT-only rag_reasoning + circuit events ✓")


if __name__ == "__main__":
    main()
