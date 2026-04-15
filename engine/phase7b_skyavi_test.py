"""
Phase 7b — SkyAVi Core Test
==============================
Tests: skill registry, shell executor, chat with discernment gate.
S7 SkyQUBi — Protected by SkyAVi. The 1st QUBi.
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
CY = "\033[38;5;38m"
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


def run_phase7b():
    global passed, failed

    print(f"\n{GD}{B}{'='*62}{R}")
    print(f"{GD}{B}  S7 SkyQUBi — Phase 7b: SkyAVi Core (Samuel){R}")
    print(f"{GD}{B}  123Tech / 2XR LLC  ·  FACTS  ·  Protected by SkyAVi{R}")
    print(f"{GD}{B}{'='*62}{R}\n")

    from s7_molecular import SqliteBackend
    from s7_skyavi_orchestrator import SkyAVi
    from s7_skyavi import Samuel, SHELL_ALLOWLIST, SHELL_DENYLIST

    agents_dir = Path(os.path.dirname(os.path.abspath(__file__))) / "agents"

    # ── T1: Skill registry ───────────────────────────────────────
    print(f"{PU}{B}T1: Skill registry{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)
        samuel = Samuel(skyavi)

        check("Persona = Samuel", samuel.persona == "Samuel")
        check("No skills initially", len(samuel.skills) == 0)

        @samuel.skill("check disk", category="system", description="Check disk usage")
        async def check_disk(self, message):
            return "disk ok"

        @samuel.skill("audit ports", category="security", description="List open ports")
        async def audit_ports(self, message):
            return "ports ok"

        check("2 skills registered", len(samuel.skills) == 2)
        check("Skill list correct", samuel.list_skills()[0]["name"] == "check_disk")

        match = samuel.match_skill("please check disk usage")
        check("Skill matched", match is not None and match.name == "check_disk")

        match2 = samuel.match_skill("audit ports now")
        check("Second skill matched", match2 is not None and match2.name == "audit_ports")

        no_match = samuel.match_skill("what is the weather")
        check("No match returns None", no_match is None)

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T2: Shell executor ───────────────────────────────────────
    print(f"{PU}{B}T2: Shell executor (sandboxed){R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)
        samuel = Samuel(skyavi)

        result = asyncio.run(samuel.shell("hostname"))
        check("hostname allowed", "DENIED" not in result, f"output={result[:40]}")

        result2 = asyncio.run(samuel.shell("uptime"))
        check("uptime allowed", "DENIED" not in result2, f"output={result2[:40]}")

        result3 = asyncio.run(samuel.shell("rm -rf /"))
        check("rm denied", "DENIED" in result3, f"output={result3[:60]}")

        result4 = asyncio.run(samuel.shell("reboot"))
        check("reboot denied", "DENIED" in result4, f"output={result4[:60]}")

        result5 = asyncio.run(samuel.shell("hackertool --pwn"))
        check("Unknown cmd denied", "DENIED" in result5, f"output={result5[:60]}")

        result6 = asyncio.run(samuel.shell("firewall-cmd --panic-on"))
        check("panic-on denied", "DENIED" in result6, f"output={result6[:60]}")

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T3: Chat with discernment gate ───────────────────────────
    print(f"{PU}{B}T3: Chat with discernment gate{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)
        samuel = Samuel(skyavi)

        @samuel.skill("check disk", category="system")
        async def check_disk_chat(self, message):
            return await self.shell("df -h")

        mock_response = {
            "response": "This query is safe to process",
            "total_duration": 100_000_000,
        }
        with patch("s7_skyavi_orchestrator.ollama_generate", new_callable=AsyncMock,
                   return_value=mock_response):
            with patch("s7_skyavi_orchestrator.should_trip", return_value=False):
                with patch("s7_skyavi_orchestrator.mempalace_search", new_callable=AsyncMock,
                           return_value=[]):
                    with patch("s7_skyavi_orchestrator.mempalace_add_drawer", new_callable=AsyncMock,
                               return_value={"ok": True}):
                        reply = asyncio.run(samuel.chat("check disk please"))

        check("Reply from Samuel", reply["from"] == "Samuel")
        check("Not blocked", not reply["blocked"])
        check("Skill matched", reply["skill"] == "check_disk_chat")
        check("Has response", len(reply["response"]) > 0, f"len={len(reply['response'])}")
        check("Verdict FERTILE", reply["verdict"] == "FERTILE")

        bonds = sb.query_bonds(bond_type="output")
        check("Skill output bonded", len(bonds) >= 1, f"count={len(bonds)}")

        # BABEL path — blocked
        with patch("s7_skyavi_orchestrator.ollama_generate", new_callable=AsyncMock,
                   return_value=mock_response):
            with patch("s7_skyavi_orchestrator.should_trip", return_value=True):
                with patch("s7_skyavi_orchestrator.mempalace_search", new_callable=AsyncMock,
                           return_value=[]):
                    blocked = asyncio.run(samuel.chat("do something dangerous"))

        check("Blocked reply", blocked["blocked"])
        check("Block response", "can't" in blocked["response"].lower())

        signals = sb.query_bonds(bond_type="signal", state="BABEL")
        check("BABEL bond stored", len(signals) >= 1, f"count={len(signals)}")

        # No skill match — conversational
        with patch("s7_skyavi_orchestrator.ollama_generate", new_callable=AsyncMock,
                   return_value=mock_response):
            with patch("s7_skyavi_orchestrator.should_trip", return_value=False):
                with patch("s7_skyavi_orchestrator.mempalace_search", new_callable=AsyncMock,
                           return_value=[]):
                    with patch("s7_skyavi_orchestrator.mempalace_add_drawer", new_callable=AsyncMock,
                               return_value={"ok": True}):
                        convo = asyncio.run(samuel.chat("hello Samuel"))

        check("No skill = conversation", convo["skill"] is None)
        check("Still FERTILE", convo["verdict"] == "FERTILE")

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T4: Status ───────────────────────────────────────────────
    print(f"{PU}{B}T4: SkyAVi status{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)
        samuel = Samuel(skyavi)

        @samuel.skill("test", category="test")
        async def test_skill(self, msg):
            return "ok"

        status = samuel.status()
        check("Status has persona", status["persona"] == "Samuel")
        check("Status has skills", status["skills"] == 1)
        check("Status has categories", "test" in status["categories"])
        check("Status has skyavi", "agents" in status["skyavi"])

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── Summary ──────────────────────────────────────────────────
    print(f"{GD}{B}{'='*62}{R}")
    print(f"{GD}{B}  Phase 7b Summary — SkyAVi Core{R}")
    print(f"{GD}{B}{'='*62}{R}")
    total = passed + failed
    print(f"\n  Tests:  {total}")
    print(f"  Passed: {GR}{passed}{R}")
    print(f"  Failed: {RD}{failed}{R}")

    if failed == 0:
        print(f"\n  {GR}{B}Phase 7b Result: PASS — All {total} tests passed{R}")
        print(f"\n  {GD}S7 SkyQUBi — Protected by SkyAVi{R}")
    else:
        print(f"\n  {RD}{B}Phase 7b Result: FAIL — {failed}/{total} tests failed{R}")

    print(f"{GD}{'='*62}{R}\n")


if __name__ == "__main__":
    run_phase7b()
