"""
Phase 7e — SkyAVi Communications Intelligence Test
=====================================================
Tests: space weather, propagation, mesh status, comms report, monitor.
S7 SkyQUB*i* — Protected by SkyAV*i*.
"""

import os
import sys
import json
import tempfile
import time
from pathlib import Path
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

B  = "\033[1m"
R  = "\033[0m"
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


def run_phase7e():
    global passed, failed

    print(f"\n{GD}{B}{'='*62}{R}")
    print(f"{GD}{B}  S7 SkyQUBi — Phase 7e: Communications Intelligence{R}")
    print(f"{GD}{B}  123Tech / 2XR LLC  ·  Protected by SkyAVi{R}")
    print(f"{GD}{B}{'='*62}{R}\n")

    from s7_molecular import SqliteBackend
    from s7_skyavi_orchestrator import SkyAVi
    from s7_skyavi import Samuel
    from s7_skyavi_comms import (
        get_space_weather, get_mesh_status, get_gps_satellites,
        SpaceWeather, MeshNode,
        register_comms_skills, register_comms_monitor,
    )

    agents_dir = Path(os.path.dirname(os.path.abspath(__file__))) / "agents"

    # ── T1: SpaceWeather dataclass ───────────────────────────────
    print(f"{PU}{B}T1: SpaceWeather dataclass{R}")

    sw = SpaceWeather(kp_index=5.0, kp_category="ACTIVE", rf_impact="MODERATE")
    check("Kp index set", sw.kp_index == 5.0)
    check("Category set", sw.kp_category == "ACTIVE")
    check("RF impact set", sw.rf_impact == "MODERATE")
    check("Alerts default empty", sw.alerts == [])

    print()

    # ── T2: Space weather fetch (live or mock) ───────────────────
    print(f"{PU}{B}T2: Space weather fetch{R}")

    sw = get_space_weather()
    check("Has timestamp", len(sw.timestamp) > 0)
    check("Kp is number", isinstance(sw.kp_index, (int, float)))
    check("Category is valid", sw.kp_category in
          ["QUIET", "UNSETTLED", "ACTIVE", "STORM", "SEVERE"])
    check("RF impact is valid", sw.rf_impact in
          ["NONE", "MINOR", "MODERATE", "SEVERE"])

    print()

    # ── T3: Mesh status (no device = graceful) ───────────────────
    print(f"{PU}{B}T3: Mesh status (graceful without device){R}")

    mesh = get_mesh_status()
    check("Returns dict", isinstance(mesh, dict))
    check("Has connected field", "connected" in mesh)
    # No device expected in test — should degrade gracefully
    if not mesh["connected"]:
        check("Graceful error", "error" in mesh, f"error={mesh.get('error', '')[:50]}")
    else:
        check("Has nodes", "nodes" in mesh)

    print()

    # ── T4: GPS status (graceful without gpsd) ───────────────────
    print(f"{PU}{B}T4: GPS status (graceful without gpsd){R}")

    gps = get_gps_satellites()
    check("Returns dict", isinstance(gps, dict))
    check("Has source", "source" in gps)
    check("Has data", "data" in gps)

    print()

    # ── T5: Comms skills registration ────────────────────────────
    print(f"{PU}{B}T5: Comms skills registration{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_comms_skills(samuel)

        skills = samuel.list_skills()
        names = [s["name"] for s in skills]

        check("Skills registered", len(skills) >= 6, f"count={len(skills)}")
        check("space_weather exists", "space_weather" in names)
        check("mesh_status exists", "mesh_status" in names)
        check("propagation exists", "propagation" in names)
        check("comms_report exists", "comms_report" in names)
        check("mesh_send exists", "mesh_send" in names)
        check("gps_status exists", "gps_status" in names)

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T6: Propagation skill output ─────────────────────────────
    print(f"{PU}{B}T6: Propagation assessment{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_comms_skills(samuel)

        import asyncio
        prop_skill = next(s for s in samuel.skills if s.name == "propagation")
        output = asyncio.run(prop_skill.fn(samuel, "propagation"))

        check("Has LoRa assessment", "LoRa" in output)
        check("Has HF assessment", "HF" in output)
        check("Has GPS assessment", "GPS" in output)
        check("Has recommendation", "RECOMMENDATION" in output)

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T7: Comms report skill ───────────────────────────────────
    print(f"{PU}{B}T7: Full comms report{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_comms_skills(samuel)

        import asyncio
        report_skill = next(s for s in samuel.skills if s.name == "comms_report")
        output = asyncio.run(report_skill.fn(samuel, "comms report"))

        check("Has header", "Communications Report" in output)
        check("Has space weather", "Space Weather" in output)
        check("Has Meshtastic", "Meshtastic" in output)
        check("Has GPS", "GPS" in output)

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T8: Comms monitor registration + execution ───────────────
    print(f"{PU}{B}T8: Comms monitor{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)
        samuel = Samuel(skyavi)
        register_comms_monitor(samuel)

        check("Comms monitor scheduled", "skyavi_comms" in skyavi._tasks)
        check("Interval = 900s", skyavi._tasks["skyavi_comms"].interval_seconds == 900)
        check("monitor_comms callable", hasattr(skyavi, "monitor_comms"))

        # Run manually
        skyavi.monitor_comms()

        bonds = sb.query_bonds(bond_type="signal")
        check("Comms bond stored", len(bonds) >= 1, f"count={len(bonds)}")
        has_comms = any("Space weather" in (b.get("content", "") or "")
                        or "comms" in (b.get("content", "") or "").lower()
                        for b in bonds)
        check("Comms content present", has_comms)

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── Summary ──────────────────────────────────────────────────
    print(f"{GD}{B}{'='*62}{R}")
    print(f"{GD}{B}  Phase 7e Summary — Communications Intelligence{R}")
    print(f"{GD}{B}{'='*62}{R}")
    total = passed + failed
    print(f"\n  Tests:  {total}")
    print(f"  Passed: {GR}{passed}{R}")
    print(f"  Failed: {RD}{failed}{R}")

    if failed == 0:
        print(f"\n  {GR}{B}Phase 7e Result: PASS — All {total} tests passed{R}")
        print(f"\n  {GD}S7 SkyQUBi — Protected by SkyAVi{R}")
    else:
        print(f"\n  {RD}{B}Phase 7e Result: FAIL — {failed}/{total} tests failed{R}")

    print(f"{GD}{'='*62}{R}\n")


if __name__ == "__main__":
    run_phase7e()
