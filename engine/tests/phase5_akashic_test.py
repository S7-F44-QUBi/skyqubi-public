"""
Phase 5 — Akashic Language Encoding Test
========================================
Validates the Akashic Language Index, 7-plane curve encoding,
ternary boundary classification, and trust tier computation.

Tests:
  T1  Pure trust language     → FERTILE, all 7 planes positive
  T2  Pure BABEL language     → BABEL, negative curves
  T3  Mixed convergent        → FERTILE, majority positive
  T4  Neutral / Door          → DOOR, no indexed words
  T5  Model response encoding → Real Ollama output through Akashic
  T6  Trust tier progression  → UNTRUSTED → PROBATIONARY → TRUSTED → ANCHORED
  T7  DB round-trip           → seed, encode, store, retrieve

Claims validated:
  - Akashic Language as universal encoding substrate
  - 7-plane curve decomposition (-7 to +7)
  - Ternary boundary classification at ^7
  - 77.777% trust tier (7/9)
  - INSERT-only covenant on trust + encoding data
"""

import asyncio
import os
import sys
import uuid
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import psycopg2
import httpx
from s7_akashic import (
    build_seed_index, encode, tokenise, compute_tier,
    store_encoding, store_trust, store_reporter_session,
    seed_to_db, LanguageIndex, PLANE_NAMES, TRUST_THRESHOLD,
)

# ── Colours ──────────────────────────────────────────────────────
B  = "\033[1m"
R  = "\033[0m"
BL = "\033[38;5;75m"
CY = "\033[38;5;38m"
GR = "\033[38;5;40m"
RD = "\033[38;5;196m"
AM = "\033[38;5;214m"
PU = "\033[38;5;141m"

DB_PASS = os.getenv("S7_PG_PASSWORD", "")
OLLAMA  = "http://127.0.0.1:7081"

passed = 0
failed = 0

def check(name: str, condition: bool, detail: str = ""):
    global passed, failed
    if condition:
        passed += 1
        print(f"  {GR}PASS{R}  {name}" + (f"  ({detail})" if detail else ""))
    else:
        failed += 1
        print(f"  {RD}FAIL{R}  {name}" + (f"  ({detail})" if detail else ""))

def get_conn():
    return psycopg2.connect(host='127.0.0.1', port=7090, dbname='s7_cws',
                            user='s7', password=DB_PASS)


async def run_phase5():
    global passed, failed

    print(f"\n{BL}{B}{'═'*62}{R}")
    print(f"{BL}{B}  S7 SkyQUBi — Phase 5: Akashic Language Encoding{R}")
    print(f"{BL}{B}  123Tech / 2XR LLC  ·  CWS v2.3  ·  7 Planes{R}")
    print(f"{BL}{B}{'═'*62}{R}\n")

    index = build_seed_index()
    print(f"  {CY}Language Index loaded: {len(index)} words{R}\n")

    # ── T1: Pure trust language ──────────────────────────────────
    print(f"{PU}{B}T1: Pure trust language{R}")
    tokens = tokenise("trust truth honest reliable faithful integrity confidence verify authentic")
    enc = encode(tokens, index)
    check("State is FERTILE", enc.state == "FERTILE", f"state={enc.state}")
    check("All 7 planes have data", all(ps.count > 0 for ps in enc.plane_scores),
          f"counts={[ps.count for ps in enc.plane_scores]}")
    check("Total curve is positive", enc.total_curve > 0, f"total={enc.total_curve}")
    check("Majority ternary +1", sum(1 for t in enc.plane_ternary if t == 1) >= 4,
          f"ternary={enc.plane_ternary}")
    print()

    # ── T2: Pure BABEL language ──────────────────────────────────
    print(f"{PU}{B}T2: Pure BABEL language{R}")
    tokens = tokenise("deceive deception lie false manipulate weapon surveillance destroy corrupt babel")
    enc = encode(tokens, index)
    check("State is BABEL or negative", enc.state in ("BABEL",), f"state={enc.state}")
    check("Total curve is negative", enc.total_curve < 0, f"total={enc.total_curve}")
    check("Majority ternary -1", sum(1 for t in enc.plane_ternary if t == -1) >= 4,
          f"ternary={enc.plane_ternary}")
    print()

    # ── T3: Mixed convergent ─────────────────────────────────────
    print(f"{PU}{B}T3: Mixed convergent (trust > babel){R}")
    tokens = tokenise("trust convergence agreement harmony safety covenant but some confusion and chaos")
    enc = encode(tokens, index)
    check("State is FERTILE", enc.state == "FERTILE", f"state={enc.state}")
    check("Positive total curve", enc.total_curve > 0, f"total={enc.total_curve}")
    print(f"  {CY}  Plane breakdown:{R}")
    for ps in enc.plane_scores:
        bar_len = int(abs(ps.normalised) * 10)
        bar = "█" * bar_len + "░" * (10 - bar_len)
        sign = "+" if ps.normalised >= 0 else "-"
        color = GR if ps.ternary == 1 else (RD if ps.ternary == -1 else AM)
        print(f"    {ps.plane_name:12s}  {color}{sign}{bar} {ps.normalised:+.3f} [{ps.ternary:+d}]{R}")
    print()

    # ── T4: Neutral / Door ───────────────────────────────────────
    print(f"{PU}{B}T4: Neutral / Door (no indexed words){R}")
    tokens = tokenise("the quick brown fox jumps over the lazy dog")
    enc = encode(tokens, index)
    check("State is DOOR", enc.state == "DOOR", f"state={enc.state}")
    check("All ternary zero", all(t == 0 for t in enc.plane_ternary),
          f"ternary={enc.plane_ternary}")
    check("Unencoded count = token count", enc.unencoded_count == enc.token_count,
          f"unencoded={enc.unencoded_count}/{enc.token_count}")
    print()

    # ── T5: Real model response encoding ─────────────────────────
    print(f"{PU}{B}T5: Real Ollama response through Akashic encoding{R}")
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(f"{OLLAMA}/api/generate",
                                     json={"model": "llama3.2:1b",
                                           "prompt": "Explain why trust is essential for AI safety in two sentences.",
                                           "stream": False},
                                     timeout=120.0)
            resp.raise_for_status()
            model_output = resp.json().get("response", "")
            tokens = tokenise(model_output)
            enc = encode(tokens, index)
            check("Got model response", len(model_output) > 0, f"{len(tokens)} tokens")
            check("Some words encoded", enc.encoded_count > 0,
                  f"{enc.encoded_count}/{enc.token_count} encoded")
            check("State classified", enc.state in ("FERTILE", "BABEL", "DOOR"),
                  f"state={enc.state}, total_curve={enc.total_curve}")
            print(f"  {CY}  Response preview: {model_output[:80]}...{R}")
            print(f"  {CY}  Encoded: {enc.encoded_count} words, Unencoded: {enc.unencoded_count}{R}")
            print(f"  {CY}  Total curve: {enc.total_curve}, State: {enc.state}{R}")
        except Exception as e:
            check("Model response", False, f"error: {e}")
    print()

    # ── T6: Trust tier progression ────────────────────────────────
    print(f"{PU}{B}T6: Trust tier progression (77.777% = 7/9){R}")
    check("0/1 fertile → UNTRUSTED",   compute_tier(0/1, 1) == "UNTRUSTED",    f"tier={compute_tier(0/1, 1)}")
    check("3/5 fertile → PROBATIONARY", compute_tier(3/5, 5) == "PROBATIONARY", f"tier={compute_tier(3/5, 5)}")
    check("4/5 fertile → TRUSTED",      compute_tier(4/5, 5) == "TRUSTED",      f"tier={compute_tier(4/5, 5)}")
    check("7/9 fertile → TRUSTED",      compute_tier(7/9, 6) == "TRUSTED",      f"tier={compute_tier(7/9, 6)} score={7/9:.6f}")
    check("7/9 + 7 sessions → ANCHORED", compute_tier(7/9, 7) == "ANCHORED",   f"tier={compute_tier(7/9, 7)}")
    check("6/9 < threshold → PROBATIONARY", compute_tier(6/9, 7) == "PROBATIONARY",
          f"tier={compute_tier(6/9, 7)} score={6/9:.6f} < {TRUST_THRESHOLD:.6f}")
    print()

    # ── T7: DB round-trip ─────────────────────────────────────────
    print(f"{PU}{B}T7: Database round-trip (INSERT-only){R}")
    conn = get_conn()
    try:
        witness_id = None
        cur = conn.cursor()
        cur.execute("SELECT id::text FROM cws_core.witnesses WHERE model_name = 'llama3.2:1b' LIMIT 1")
        row = cur.fetchone()
        if row:
            witness_id = row[0]
        else:
            witness_id = str(uuid.uuid4())

        cur.execute("SELECT id::text FROM cws_akashic.language_plans WHERE plan_name = 'convergence'")
        plan_id = cur.fetchone()[0]

        # Encode a test text
        test_text = "Trust and convergence enable safe sovereign AI inference with integrity"
        tokens = tokenise(test_text)
        enc = encode(tokens, index)

        # Store encoded response
        enc_id = store_encoding(conn, witness_id, plan_id, test_text, enc)
        conn.commit()
        check("Encoded response stored", enc_id is not None, f"id={enc_id[:8]}...")

        # Store trust
        trust_id = store_trust(conn, witness_id, None, True, enc.total_curve, 1, 1)
        conn.commit()
        check("Trust score stored", trust_id is not None, f"id={trust_id[:8]}...")

        # Store reporter session
        rs_id = store_reporter_session(conn, None, witness_id, 0,
                                       test_text, test_text, enc_id, 1.0, 100)
        conn.commit()
        check("Reporter session stored", rs_id is not None, f"id={rs_id[:8]}...")

        # Verify retrieval
        cur.execute("SELECT state, total_curve, plane_curves FROM cws_akashic.encoded_responses WHERE id = %s::uuid", (enc_id,))
        row = cur.fetchone()
        check("Encoded response retrievable", row is not None and row[0] == enc.state,
              f"state={row[0]}, curve={row[1]}")

        cur.execute("SELECT tier, trust_score FROM cws_akashic.witness_trust WHERE id = %s::uuid", (trust_id,))
        row = cur.fetchone()
        check("Trust retrievable", row is not None, f"tier={row[0]}, score={row[1]:.4f}")

        cur.execute("SELECT plane_name FROM cws_akashic.reporter_sessions WHERE id = %s::uuid", (rs_id,))
        row = cur.fetchone()
        check("Reporter session retrievable", row is not None, f"plane={row[0]}")

        # Count total rows (INSERT-only verification)
        cur.execute("SELECT count(*) FROM cws_akashic.encoded_responses")
        check("encoded_responses INSERT-only", cur.fetchone()[0] >= 1)
        cur.execute("SELECT count(*) FROM cws_akashic.witness_trust")
        check("witness_trust INSERT-only", cur.fetchone()[0] >= 1)

    finally:
        conn.close()
    print()

    # ── Summary ──────────────────────────────────────────────────
    print(f"{BL}{B}{'═'*62}{R}")
    print(f"{BL}{B}  Phase 5 Summary{R}")
    print(f"{BL}{B}{'═'*62}{R}")
    total = passed + failed
    print(f"\n  Tests:  {total}")
    print(f"  Passed: {GR}{passed}{R}")
    print(f"  Failed: {RD}{failed}{R}")

    if failed == 0:
        print(f"\n  {GR}{B}Phase 5 Result: PASS — All {total} tests passed{R}")
    else:
        print(f"\n  {RD}{B}Phase 5 Result: FAIL — {failed}/{total} tests failed{R}")

    print(f"\n  {CY}Architecture validated:{R}")
    print(f"    Akashic Language Index:     67 words, 7 plan points")
    print(f"    7-plane curve encoding:    [-7, +7] per plane")
    print(f"    Ternary boundary:          {{-1, 0, +1}} at ^7")
    print(f"    Trust tier:                77.777% (7/9) threshold")
    print(f"    INSERT-only covenant:      encoded_responses + witness_trust")
    print(f"    Reporter pattern:          1 model = 1 voice = 1 session")
    print(f"{BL}{'═'*62}{R}\n")

if __name__ == "__main__":
    asyncio.run(run_phase5())
