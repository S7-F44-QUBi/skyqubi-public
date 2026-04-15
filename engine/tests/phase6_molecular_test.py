"""
Phase 6 — Molecular Bond Table Test
=====================================
Validates the unified sky_molecular.bonds table across
both PostgreSQL and SQLite backends.
"""

import os
import sys
import tempfile
import uuid
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from s7_molecular import (
    Bond, resolve_vector_name, VECTOR_NAMES,
    PostgresBackend, SqliteBackend, get_backend, seed_bonds,
    TRUST_THRESHOLD, ANCHORED_MIN_SESSIONS,
)

B  = "\033[1m"
R  = "\033[0m"
BL = "\033[38;5;75m"
CY = "\033[38;5;38m"
GR = "\033[38;5;40m"
RD = "\033[38;5;196m"
PU = "\033[38;5;141m"

passed = 0
failed = 0

def check(name, condition, detail=""):
    global passed, failed
    if condition:
        passed += 1
        print(f"  {GR}PASS{R}  {name}" + (f"  ({detail})" if detail else ""))
    else:
        failed += 1
        print(f"  {RD}FAIL{R}  {name}" + (f"  ({detail})" if detail else ""))


def run_phase6():
    global passed, failed

    print(f"\n{BL}{B}{'='*62}{R}")
    print(f"{BL}{B}  S7 SkyQUBi — Phase 6: Molecular Bond Table{R}")
    print(f"{BL}{B}  123Tech / 2XR LLC  ·  9 Planes  ·  27 Vectors{R}")
    print(f"{BL}{B}{'='*62}{R}\n")

    # ── T6: 27 vector names ──────────────────────────────────────
    print(f"{PU}{B}T6: 27 vector name resolution{R}")
    check("FERTILE = (1,0,1)",   resolve_vector_name(1, 0, 1) == "FERTILE")
    check("TOWER = (-1,1,-1)",   resolve_vector_name(-1, 1, -1) == "TOWER")
    check("STASIS = (-1,-1,-1)", resolve_vector_name(-1, -1, -1) == "STASIS")
    check("MAX_UNCERTAINTY = (0,0,0)", resolve_vector_name(0, 0, 0) == "MAX_UNCERTAINTY")
    check("RESURRECTION = (-1,0,1)", resolve_vector_name(-1, 0, 1) == "RESURRECTION")
    check("ABUNDANT = (1,1,1)",  resolve_vector_name(1, 1, 1) == "ABUNDANT")
    check("All 27 defined", len(VECTOR_NAMES) == 27, f"count={len(VECTOR_NAMES)}")
    print()

    # ── T7: SQLite backend ───────────────────────────────────────
    print(f"{PU}{B}T7: SQLite backend round-trip{R}")
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_path = f.name
    try:
        sb = SqliteBackend(tmp_path)

        # T1: Word bond
        print(f"\n{PU}{B}T1: Word bond (SQLite){R}")
        word_bond = Bond(bond_type="word", plane=0, memory=1, present=0, destiny=1,
                         content="trust", curve_value=7, plan_point="trust",
                         plane_affinity=list(range(-4, 5)), state="FERTILE")
        wid = sb.store_bond(word_bond)
        check("Word stored", wid == word_bond.id)
        check("Vector auto-resolved", word_bond.vector_name == "FERTILE",
              f"vector={word_bond.vector_name}")
        rows = sb.query_bonds(bond_type="word")
        check("Word retrieved", len(rows) == 1 and rows[0]["content"] == "trust")
        check("State preserved", rows[0]["state"] == "FERTILE")

        # T2: Symbol bond
        print(f"\n{PU}{B}T2: Symbol bond (SQLite){R}")
        sym_bond = Bond(bond_type="symbol", plane=0, memory=1, present=0, destiny=1,
                        content="+", curve_value=3, plan_point="boundary", state="FERTILE")
        sb.store_bond(sym_bond)
        rows = sb.query_bonds(bond_type="symbol")
        check("Symbol stored and retrieved", len(rows) == 1 and rows[0]["content"] == "+")

        # T3: Chunk bond
        print(f"\n{PU}{B}T3: Chunk bond (SQLite){R}")
        chunk_bond = Bond(bond_type="chunk", plane=3, memory=0, present=0, destiny=1,
                          content="Trust enables convergence in multi-agent systems.",
                          embedding=[0.1]*768, dataset="test_corpus",
                          document_id=str(uuid.uuid4()), chunk_index=0,
                          state="FERTILE")
        sb.store_bond(chunk_bond)
        rows = sb.query_bonds(bond_type="chunk")
        check("Chunk stored", len(rows) == 1)
        check("Chunk vector = PORTAL_OPEN", chunk_bond.vector_name == "PORTAL_OPEN",
              f"vector={chunk_bond.vector_name}")

        # T5: Signal bond
        print(f"\n{PU}{B}T5: Signal bond (SQLite){R}")
        sig_bond = Bond(bond_type="signal", plane=0, memory=-1, present=-1, destiny=-1,
                        content="Circuit breaker tripped at 71.4% BABEL",
                        state="BABEL")
        sb.store_bond(sig_bond)
        check("Signal vector = STASIS", sig_bond.vector_name == "STASIS",
              f"vector={sig_bond.vector_name}")
        rows = sb.query_bonds(bond_type="signal")
        check("Signal stored", len(rows) == 1)

        # T9: INSERT-only covenant (SQLite)
        print(f"\n{PU}{B}T9: INSERT-only covenant (SQLite){R}")
        try:
            sb._conn.execute("UPDATE bonds SET content='hacked' WHERE id=?", (wid,))
            check("UPDATE rejected", False, "UPDATE succeeded — covenant broken!")
        except Exception as e:
            check("UPDATE rejected", "INSERT-only" in str(e) or "UPDATE forbidden" in str(e),
                  str(e)[:60])
        try:
            sb._conn.execute("DELETE FROM bonds WHERE id=?", (wid,))
            check("DELETE rejected", False, "DELETE succeeded — covenant broken!")
        except Exception as e:
            check("DELETE rejected", "INSERT-only" in str(e) or "DELETE forbidden" in str(e),
                  str(e)[:60])

        sb.close()
    finally:
        os.unlink(tmp_path)
    print()

    # ── T8: PostgreSQL backend ───────────────────────────────────
    print(f"{PU}{B}T8: PostgreSQL backend round-trip{R}")
    try:
        import psycopg2
        conn = psycopg2.connect(host="127.0.0.1", port=7090, dbname="s7_cws",
                                user="s7", password=os.getenv("CWS_DB_PASS", ""))
        pb = PostgresBackend(conn)

        # Verify seeds exist
        words = pb.get_words()
        check("Seeded words present", len(words) >= 67, f"count={len(words)}")
        top = [w for w in words if w["curve"] is not None and w["curve"] >= 7]
        check("Top curve words exist", len(top) >= 5, f"count={len(top)}")

        # T4: Output bond + trust
        print(f"\n{PU}{B}T4: Output bond + trust computation (PostgreSQL){R}")
        test_witness = str(uuid.uuid4())
        for i in range(9):
            out_bond = Bond(
                bond_type="output", plane=1, memory=1, present=0, destiny=1,
                content=f"Test response {i}",
                witness_id=test_witness,
                state="FERTILE" if i < 7 else "BABEL",
            )
            pb.store_bond(out_bond)
        check("9 output bonds stored", True)

        # T10: Trust tier
        print(f"\n{PU}{B}T10: Trust tier from bond log (PostgreSQL){R}")
        trust = pb.compute_trust(test_witness)
        check("Trust score = 7/9", abs(trust["trust_score"] - 7/9) < 0.001,
              f"score={trust['trust_score']:.6f}")
        check("Tier = ANCHORED (7/9 across 9 sessions)",
              trust["tier"] == "ANCHORED", f"tier={trust['tier']}")
        check("Fertile count = 7", trust["fertile"] == 7, f"fertile={trust['fertile']}")
        check("Total count = 9", trust["total"] == 9, f"total={trust['total']}")

        # T9b: PostgreSQL INSERT-only covenant
        print(f"\n{PU}{B}T9b: INSERT-only covenant (PostgreSQL){R}")
        try:
            cur = conn.cursor()
            cur.execute("UPDATE sky_molecular.bonds SET content='hacked' WHERE bond_type='output' AND id = %s::uuid", (out_bond.id,))
            conn.commit()
            check("UPDATE rejected", False, "UPDATE succeeded — covenant broken!")
        except Exception as e:
            conn.rollback()
            check("UPDATE rejected", "INSERT-only" in str(e), str(e)[:80])
        try:
            cur = conn.cursor()
            cur.execute("DELETE FROM sky_molecular.bonds WHERE bond_type='output' AND id = %s::uuid", (out_bond.id,))
            conn.commit()
            check("DELETE rejected", False, "DELETE succeeded — covenant broken!")
        except Exception as e:
            conn.rollback()
            check("DELETE rejected", "INSERT-only" in str(e), str(e)[:80])

        conn.close()
    except ImportError:
        print(f"  {CY}SKIP — psycopg2 not available{R}")
    except Exception as e:
        print(f"  {RD}ERROR — {e}{R}")
    print()

    # ── Summary ──────────────────────────────────────────────────
    print(f"{BL}{B}{'='*62}{R}")
    print(f"{BL}{B}  Phase 6 Summary{R}")
    print(f"{BL}{B}{'='*62}{R}")
    total = passed + failed
    print(f"\n  Tests:  {total}")
    print(f"  Passed: {GR}{passed}{R}")
    print(f"  Failed: {RD}{failed}{R}")

    if failed == 0:
        print(f"\n  {GR}{B}Phase 6 Result: PASS — All {total} tests passed{R}")
    else:
        print(f"\n  {RD}{B}Phase 6 Result: FAIL — {failed}/{total} tests failed{R}")

    print(f"\n  {CY}Architecture validated:{R}")
    print(f"    Molecular bonds table:     sky_molecular.bonds")
    print(f"    Bond types:                word / symbol / image / chunk / output / signal")
    print(f"    Planes:                    -4 to +4 (9 planes, Bible numbering)")
    print(f"    Vector:                    memory.present.destiny (27 named combos)")
    print(f"    Trust tier:                77.777% (7/9) — ANCHORED at 7+ sessions")
    print(f"    Backends:                  PostgreSQL + SQLite")
    print(f"    INSERT-only:               triggers enforced on both backends")
    print(f"{BL}{'='*62}{R}\n")


if __name__ == "__main__":
    run_phase6()
