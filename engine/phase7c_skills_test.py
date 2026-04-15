"""
Phase 7c — SkyAVi FACTS Skills Test
======================================
Tests: all registered FACTS skills across system, security, technician, stack.
S7 SkyQUB*i* — Protected by SkyAV*i*.
"""

import os
import sys
import tempfile
import asyncio
from pathlib import Path
from unittest.mock import AsyncMock, patch

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


def run_phase7c():
    global passed, failed

    print(f"\n{GD}{B}{'='*62}{R}")
    print(f"{GD}{B}  S7 SkyQUBi — Phase 7c: FACTS Skills{R}")
    print(f"{GD}{B}  123Tech / 2XR LLC  ·  Protected by SkyAVi{R}")
    print(f"{GD}{B}{'='*62}{R}\n")

    from s7_molecular import SqliteBackend
    from s7_skyavi_orchestrator import SkyAVi
    from s7_skyavi import Samuel
    from s7_skyavi_skills import register_facts_skills

    agents_dir = Path(os.path.dirname(os.path.abspath(__file__))) / "agents"

    # ── T1: Skill registration ───────────────────────────────────
    print(f"{PU}{B}T1: FACTS skill registration{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)
        samuel = Samuel(skyavi)
        register_facts_skills(samuel)

        skills = samuel.list_skills()
        categories = set(s["category"] for s in skills)

        check("Skills registered", len(skills) >= 25, f"count={len(skills)}")
        check("Has system category", "system" in categories)
        check("Has security category", "security" in categories)
        check("Has technician category", "technician" in categories)
        check("Has stack category", "stack" in categories)

        # Verify key skills exist
        skill_names = [s["name"] for s in skills]
        check("check_disk exists", "check_disk" in skill_names)
        check("luks_status exists", "luks_status" in skill_names)
        check("cert_expiry exists", "cert_expiry" in skill_names)
        check("restart_service exists", "restart_service" in skill_names)
        check("npm_audit exists", "npm_audit" in skill_names)
        check("full_health exists", "full_health" in skill_names)
        check("password_audit exists", "password_audit" in skill_names)

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T2: System skills execute ────────────────────────────────
    print(f"{PU}{B}T2: System skills execute{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)
        samuel = Samuel(skyavi)
        register_facts_skills(samuel)

        # Direct skill execution (bypass chat discernment for unit testing)
        disk = asyncio.run(samuel.skills[0].fn(samuel, "check disk"))
        check("check_disk runs", "Filesystem" in disk or "/" in disk, f"len={len(disk)}")

        mem = asyncio.run(samuel.skills[1].fn(samuel, "check memory"))
        check("check_memory runs", "Mem" in mem or "total" in mem, f"len={len(mem)}")

        uptime = asyncio.run(samuel.skills[2].fn(samuel, "check uptime"))
        check("check_uptime runs", "load" in uptime or "up" in uptime, f"len={len(uptime)}")

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T3: Security skills execute ──────────────────────────────
    print(f"{PU}{B}T3: Security skills execute{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)
        samuel = Samuel(skyavi)
        register_facts_skills(samuel)

        # Find skills by name
        def find_skill(name):
            return next((s for s in samuel.skills if s.name == name), None)

        ports = asyncio.run(find_skill("audit_ports").fn(samuel, "audit ports"))
        check("audit_ports runs", len(ports) > 0, f"len={len(ports)}")

        luks = asyncio.run(find_skill("luks_status").fn(samuel, "luks status"))
        check("luks_status runs", "LUKS" in luks or "crypt" in luks or "No LUKS" in luks,
              f"output={luks[:50]}")

        ssh = asyncio.run(find_skill("ssh_config").fn(samuel, "ssh config"))
        check("ssh_config runs", len(ssh) > 0, f"len={len(ssh)}")

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T4: Technician skills ────────────────────────────────────
    print(f"{PU}{B}T4: Technician skills{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)
        samuel = Samuel(skyavi)
        register_facts_skills(samuel)

        def find_skill(name):
            return next((s for s in samuel.skills if s.name == name), None)

        # restart_service with no name
        rs = asyncio.run(find_skill("restart_service").fn(samuel, "restart"))
        check("restart_service needs name", "Usage" in rs)

        # restart_service with non-s7 name
        rs2 = asyncio.run(find_skill("restart_service").fn(samuel, "restart service nginx"))
        check("restart_service denies non-s7", "DENIED" in rs2)

        # health check
        health = asyncio.run(find_skill("full_health").fn(samuel, "health check"))
        check("full_health runs", "Memory" in health or "Mem" in health, f"len={len(health)}")

        # container logs with no name
        cl = asyncio.run(find_skill("container_logs").fn(samuel, "container logs"))
        check("container_logs needs name", "Usage" in cl)

        # container logs with non-s7 name
        cl2 = asyncio.run(find_skill("container_logs").fn(samuel, "container logs nginx"))
        check("container_logs denies non-s7", "DENIED" in cl2)

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T5: Stack skills ─────────────────────────────────────────
    print(f"{PU}{B}T5: Stack skills{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)
        samuel = Samuel(skyavi)
        register_facts_skills(samuel)

        def find_skill(name):
            return next((s for s in samuel.skills if s.name == name), None)

        pv = asyncio.run(find_skill("python_version").fn(samuel, "python version"))
        check("python_version runs", "3." in pv, f"output={pv.strip()}")

        pd = asyncio.run(find_skill("podman_version").fn(samuel, "podman version"))
        check("podman_version runs", len(pd) > 0, f"len={len(pd)}")

        gs = asyncio.run(find_skill("git_status").fn(samuel, "git status"))
        check("git_status runs", "SkyAVi" in gs or "feat:" in gs or "main" in gs.lower(),
              f"len={len(gs)}")

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T6: Chat integration with FACTS skills ───────────────────
    print(f"{PU}{B}T6: Chat integration with FACTS skills{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)
        samuel = Samuel(skyavi)
        register_facts_skills(samuel)

        mock_resp = {"response": "safe query", "total_duration": 50_000_000}
        with patch("s7_skyavi_orchestrator.ollama_generate", new_callable=AsyncMock,
                   return_value=mock_resp):
            with patch("s7_skyavi_orchestrator.should_trip", return_value=False):
                with patch("s7_skyavi_orchestrator.mempalace_search", new_callable=AsyncMock,
                           return_value=[]):
                    with patch("s7_skyavi_orchestrator.mempalace_add_drawer", new_callable=AsyncMock,
                               return_value={"ok": True}):
                        reply = asyncio.run(samuel.chat("health check"))

        check("Samuel replies", reply["from"] == "Samuel")
        check("Skill matched", reply["skill"] == "full_health")
        check("Category = technician", reply["category"] == "technician")
        check("Not blocked", not reply["blocked"])
        check("Has real output", "Memory" in reply["response"] or "Mem" in reply["response"],
              f"len={len(reply['response'])}")

        # Verify bond stored
        bonds = sb.query_bonds(bond_type="output")
        check("Skill bonded", any("full_health" in (b.get("content", "") or "") for b in bonds),
              f"count={len(bonds)}")

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── Summary ──────────────────────────────────────────────────
    print(f"{GD}{B}{'='*62}{R}")
    print(f"{GD}{B}  Phase 7c Summary — FACTS Skills{R}")
    print(f"{GD}{B}{'='*62}{R}")
    total = passed + failed
    print(f"\n  Tests:  {total}")
    print(f"  Passed: {GR}{passed}{R}")
    print(f"  Failed: {RD}{failed}{R}")

    if failed == 0:
        print(f"\n  {GR}{B}Phase 7c Result: PASS — All {total} tests passed{R}")
        print(f"\n  {GD}S7 SkyQUBi — Protected by SkyAVi{R}")
    else:
        print(f"\n  {RD}{B}Phase 7c Result: FAIL — {failed}/{total} tests failed{R}")

    print(f"{GD}{'='*62}{R}\n")


if __name__ == "__main__":
    run_phase7c()
