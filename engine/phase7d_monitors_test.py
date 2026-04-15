"""
Phase 7d — SkyAVi Monitors + Compliance Test
===============================================
Tests: service health, port baseline, outbound scan, disk, CIS, FIPS.
S7 SkyQUB*i* — Protected by SkyAV*i*.
"""

import os
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

B  = "\033[1m"
R  = "\033[0m"
BL = "\033[38;5;75m"
GR = "\033[38;5;40m"
RD = "\033[38;5;196m"
PU = "\033[38;5;141m"
GD = "\033[38;5;220m"

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


def run_phase7d():
    global passed, failed

    print(f"\n{GD}{B}{'='*62}{R}")
    print(f"{GD}{B}  S7 SkyQUBi — Phase 7d: Monitors + Compliance{R}")
    print(f"{GD}{B}  123Tech / 2XR LLC  ·  FACTS  ·  Protected by SkyAVi{R}")
    print(f"{GD}{B}{'='*62}{R}\n")

    from s7_molecular import SqliteBackend
    from s7_skyavi_orchestrator import SkyAVi
    from s7_skyavi import Samuel
    from s7_skyavi_monitors import register_monitors

    agents_dir = Path(os.path.dirname(os.path.abspath(__file__))) / "agents"

    # ── T1: Monitor registration ─────────────────────────────────
    print(f"{PU}{B}T1: Monitor registration{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_monitors(samuel)

        check("skyavi_monitors scheduled", "skyavi_monitors" in skyavi._tasks)
        check("skyavi_compliance scheduled", "skyavi_compliance" in skyavi._tasks)
        check("Monitor interval = 300s", skyavi._tasks["skyavi_monitors"].interval_seconds == 300)
        check("Compliance interval = 86400s", skyavi._tasks["skyavi_compliance"].interval_seconds == 86400)
        check("run_all_monitors callable", hasattr(skyavi, "run_all_monitors"))
        check("run_compliance callable", hasattr(skyavi, "run_compliance"))

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T2: Service health monitor ───────────────────────────────
    print(f"{PU}{B}T2: Service health monitor{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_monitors(samuel)

        skyavi._monitor_service_health()

        bonds = sb.query_bonds(bond_type="signal")
        check("Health bond stored", len(bonds) >= 1, f"count={len(bonds)}")
        check("Health has witness_id", bonds[0].get("content", "").startswith("Service health")
              or "SERVICE" in bonds[0].get("content", ""))

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T3: Port baseline monitor ────────────────────────────────
    print(f"{PU}{B}T3: Port baseline monitor{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_monitors(samuel)

        skyavi._monitor_ports()

        bonds = sb.query_bonds(bond_type="signal")
        check("Port bond stored", len(bonds) >= 1, f"count={len(bonds)}")
        has_port_content = any("Port" in (b.get("content", "") or "")
                              or "port" in (b.get("content", "") or "").lower()
                              for b in bonds)
        check("Port check content", has_port_content)

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T4: Outbound connection monitor ──────────────────────────
    print(f"{PU}{B}T4: Outbound connection monitor{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_monitors(samuel)

        skyavi._monitor_outbound()

        bonds = sb.query_bonds(bond_type="signal")
        check("Outbound bond stored", len(bonds) >= 1, f"count={len(bonds)}")
        has_outbound = any("utbound" in (b.get("content", "") or "") for b in bonds)
        check("Outbound check content", has_outbound)

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T5: Disk usage monitor ───────────────────────────────────
    print(f"{PU}{B}T5: Disk usage monitor{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_monitors(samuel)

        skyavi._monitor_disk()

        bonds = sb.query_bonds(bond_type="signal")
        check("Disk bond stored", len(bonds) >= 1, f"count={len(bonds)}")
        has_disk = any("isk" in (b.get("content", "") or "") for b in bonds)
        check("Disk check content", has_disk)

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T6: CIS baseline check ──────────────────────────────────
    print(f"{PU}{B}T6: CIS baseline compliance{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_monitors(samuel)

        skyavi._monitor_cis()

        bonds = sb.query_bonds(bond_type="output")
        check("CIS bond stored", len(bonds) >= 1, f"count={len(bonds)}")
        cis_bond = bonds[0]
        check("CIS has score", "CIS Baseline:" in (cis_bond.get("content", "") or ""),
              f"content={cis_bond.get('content', '')[:60]}")
        check("CIS has PASS/FAIL lines",
              "PASS:" in (cis_bond.get("content", "") or "") or
              "FAIL:" in (cis_bond.get("content", "") or ""))

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T7: FIPS check ───────────────────────────────────────────
    print(f"{PU}{B}T7: FIPS crypto check{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_monitors(samuel)

        skyavi._monitor_fips()

        bonds = sb.query_bonds(bond_type="output")
        check("FIPS bond stored", len(bonds) >= 1, f"count={len(bonds)}")
        fips_bond = bonds[0]
        check("FIPS has content", "FIPS" in (fips_bond.get("content", "") or ""))

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T8: Master monitor runs all ──────────────────────────────
    print(f"{PU}{B}T8: Master monitor runs all checks{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_monitors(samuel)

        skyavi.run_all_monitors()

        bonds = sb.query_bonds(bond_type="signal")
        check("Multiple monitor bonds", len(bonds) >= 4, f"count={len(bonds)}")

        skyavi.run_compliance()

        all_bonds = sb.query_bonds()
        check("Compliance bonds added", len(all_bonds) >= 6, f"count={len(all_bonds)}")

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T9: Scheduler fires monitors ─────────────────────────────
    print(f"{PU}{B}T9: Scheduler fires monitors{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_monitors(samuel)

        # Override interval to 2s for testing
        skyavi._tasks["skyavi_monitors"].interval_seconds = 2

        skyavi.start_scheduler()
        time.sleep(3)

        check("Monitor task ran", skyavi._tasks["skyavi_monitors"].run_count >= 1,
              f"runs={skyavi._tasks['skyavi_monitors'].run_count}")

        skyavi.stop_scheduler()
        check("Scheduler stopped", not skyavi.status()["scheduler_running"])

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── Summary ──────────────────────────────────────────────────
    print(f"{GD}{B}{'='*62}{R}")
    print(f"{GD}{B}  Phase 7d Summary — Monitors + Compliance{R}")
    print(f"{GD}{B}{'='*62}{R}")
    total = passed + failed
    print(f"\n  Tests:  {total}")
    print(f"  Passed: {GR}{passed}{R}")
    print(f"  Failed: {RD}{failed}{R}")

    if failed == 0:
        print(f"\n  {GR}{B}Phase 7d Result: PASS — All {total} tests passed{R}")
        print(f"\n  {GD}S7 SkyQUBi — Protected by SkyAVi{R}")
    else:
        print(f"\n  {RD}{B}Phase 7d Result: FAIL — {failed}/{total} tests failed{R}")

    print(f"{GD}{'='*62}{R}\n")


if __name__ == "__main__":
    run_phase7d()
