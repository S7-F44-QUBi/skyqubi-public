"""
Phase 7 — SkyAVi Agent Orchestration Test
=============================================
Incremental tests: config loader, single-agent, consensus, scheduler.
"""

import os
import sys
import tempfile
import asyncio
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

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


def run_phase7():
    global passed, failed

    print(f"\n{BL}{B}{'='*62}{R}")
    print(f"{BL}{B}  S7 SkyQUBi — Phase 7: SkyAVi Agent Orchestration{R}")
    print(f"{BL}{B}  123Tech / 2XR LLC  ·  Agent Config  ·  Consensus{R}")
    print(f"{BL}{B}{'='*62}{R}\n")

    from s7_skyavi_orchestrator import AgentConfig, load_agents, SkyAVi
    from s7_molecular import Bond, SqliteBackend

    # ── T1: Agent config loading ─────────────────────────────────
    print(f"{PU}{B}T1: Agent config loading{R}")

    agents_dir = Path(os.path.dirname(os.path.abspath(__file__))) / "agents"
    agents = load_agents(agents_dir)

    check("Agents loaded", len(agents) >= 3, f"count={len(agents)}")
    check("Guardian exists", "guardian" in agents)
    check("Guardian plane = -4", agents["guardian"].plane == -4)
    check("Guardian model set", agents["guardian"].model == "s7-qwen3:0.6b")
    check("Carli exists", "carli" in agents)
    check("Carli plane = 1", agents["carli"].plane == 1)
    check("Elias exists", "elias" in agents)
    check("Elias plane = 2", agents["elias"].plane == 2)

    # Verify from_yaml with temp file
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as f:
        f.write("name: test-agent\nmodel: smollm2:135m\nplane: 0\nrole: test\n")
        tmp = f.name
    try:
        agent = AgentConfig.from_yaml(Path(tmp))
        check("from_yaml works", agent.name == "test-agent" and agent.plane == 0)
    finally:
        os.unlink(tmp)

    print()

    # ── T2: Single-agent runner (SQLite, mocked Ollama) ──────────
    print(f"{PU}{B}T2: Single-agent runner{R}")

    from unittest.mock import AsyncMock, patch

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)

        mock_response = {
            "response": "Trust is the foundation of sovereign computing",
            "total_duration": 150_000_000,
        }
        with patch("s7_skyavi_orchestrator.ollama_generate", new_callable=AsyncMock,
                   return_value=mock_response):
            agent = skyavi.get_agent("carli")
            bond = asyncio.run(skyavi.run_agent(agent, "What is trust?"))

        check("Bond returned", bond is not None)
        check("Bond type = output", bond.bond_type == "output")
        check("Bond plane = 1", bond.plane == 1, f"plane={bond.plane}")
        check("Bond state = FERTILE", bond.state == "FERTILE", f"state={bond.state}")
        check("Bond has content", len(bond.content) > 0, f"len={len(bond.content)}")
        check("Bond witness_id set", bond.witness_id == "carli")
        check("Bond latency_ms set", bond.latency_ms == 150, f"ms={bond.latency_ms}")

        # Verify bond written to SQLite
        rows = sb.query_bonds(bond_type="output")
        check("Bond in SQLite", len(rows) == 1, f"count={len(rows)}")

        # Test BABEL scenario
        mock_babel = {
            "response": "x y z a b c d e f g h i j k l m n o p q",
            "total_duration": 50_000_000,
        }
        with patch("s7_skyavi_orchestrator.ollama_generate", new_callable=AsyncMock,
                   return_value=mock_babel):
            with patch("s7_skyavi_orchestrator.should_trip", return_value=True):
                babel_bond = asyncio.run(skyavi.run_agent(agent, "trigger babel"))

        check("BABEL bond type = signal", babel_bond.bond_type == "signal")
        check("BABEL bond state", babel_bond.state == "BABEL")
        check("BABEL bond vector = STASIS", babel_bond.vector_name == "STASIS",
              f"vector={babel_bond.vector_name}")

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T3: Multi-witness consensus ──────────────────────────────
    print(f"{PU}{B}T3: Multi-witness consensus{R}")

    from s7_molecular import TRUST_THRESHOLD

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)

        mock_fertile = {
            "response": "Trust enables convergence in multi-agent sovereign systems",
            "total_duration": 200_000_000,
        }
        with patch("s7_skyavi_orchestrator.ollama_generate", new_callable=AsyncMock,
                   return_value=mock_fertile):
            with patch("s7_skyavi_orchestrator.should_trip", return_value=False):
                with patch("s7_skyavi_orchestrator.mempalace_search", new_callable=AsyncMock,
                           return_value=[{"content": "prior memory about trust"}]):
                    with patch("s7_skyavi_orchestrator.mempalace_add_drawer", new_callable=AsyncMock,
                               return_value={"ok": True}):
                        result = asyncio.run(skyavi.run_consensus(
                            "What is trust?",
                            agent_names=["carli", "elias"]))

        check("Verdict = FERTILE", result["verdict"] == "FERTILE",
              f"verdict={result['verdict']}")
        check("Score = 2/2", result["score"] == 1.0, f"score={result['score']}")
        check("2 witness bonds", len(result["bonds"]) == 2,
              f"count={len(result['bonds'])}")
        check("Consensus bond exists", result["consensus"] is not None)
        check("Consensus plane = 0", result["consensus"].plane == 0)
        check("Consensus state = FERTILE", result["consensus"].state == "FERTILE")
        check("MemPalace memories recalled", result["memories"] >= 1,
              f"memories={result['memories']}")

        all_bonds = sb.query_bonds()
        check("All bonds stored", len(all_bonds) >= 3,
              f"count={len(all_bonds)}")

        sb.close()
    finally:
        os.unlink(tmp_db)

    print(f"\n{PU}{B}T3b: BABEL consensus (majority fails){R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)

        call_count = 0
        async def mock_generate_mixed(prompt, model=""):
            nonlocal call_count
            call_count += 1
            return {
                "response": "some response text here for testing",
                "total_duration": 100_000_000,
            }

        trip_count = 0
        def mock_trip_majority(ratio, threshold=0.70):
            nonlocal trip_count
            trip_count += 1
            # Guardian passes (call 1), first witness passes (call 2),
            # rest trip (calls 3+)
            return trip_count >= 3

        with patch("s7_skyavi_orchestrator.ollama_generate", new_callable=AsyncMock,
                   side_effect=mock_generate_mixed):
            with patch("s7_skyavi_orchestrator.should_trip", side_effect=mock_trip_majority):
                with patch("s7_skyavi_orchestrator.mempalace_search", new_callable=AsyncMock,
                           return_value=[]):
                    result = asyncio.run(skyavi.run_consensus(
                        "risky query",
                        agent_names=["carli", "elias"]))

        check("BABEL verdict when majority fails",
              result["verdict"] == "BABEL", f"verdict={result['verdict']}")
        check("Score < threshold", result["score"] < TRUST_THRESHOLD,
              f"score={result['score']}")

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T4: Scheduler ────────────────────────────────────────────
    print(f"{PU}{B}T4: Scheduler{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir, db_path=tmp_db)

        task = skyavi.schedule("health", 2, "health_check")
        check("Task scheduled", "health" in skyavi._tasks)
        check("Task interval = 2", task.interval_seconds == 2)

        skyavi.start_scheduler()
        status = skyavi.status()
        check("Scheduler running", status["scheduler_running"])

        import time
        time.sleep(3)

        check("Health check ran", skyavi._tasks["health"].run_count >= 1,
              f"runs={skyavi._tasks['health'].run_count}")

        signals = sb.query_bonds(bond_type="signal")
        check("Health signal bond stored", len(signals) >= 1,
              f"count={len(signals)}")
        check("Health bond state = FERTILE", signals[0]["state"] == "FERTILE")

        cancelled = skyavi.cancel("health")
        check("Task cancelled", cancelled)
        check("Task removed", "health" not in skyavi._tasks)

        skyavi.stop_scheduler()
        status = skyavi.status()
        check("Scheduler stopped", not status["scheduler_running"])

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── T5: Status + agent listing ───────────────────────────────
    print(f"{PU}{B}T5: SkyAVi status API{R}")

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        sb = SqliteBackend(tmp_db)
        skyavi = SkyAVi(backend=sb, agents_dir=agents_dir)

        status = skyavi.status()
        check("Status has agents", status["agents"] >= 3, f"count={status['agents']}")
        check("Status has agent_names", "guardian" in status["agent_names"])
        check("Status has tasks", "tasks" in status)
        check("Scheduler not running initially", not status["scheduler_running"])

        sb.close()
    finally:
        os.unlink(tmp_db)

    print()

    # ── Summary ──────────────────────────────────────────────────
    print(f"{BL}{B}{'='*62}{R}")
    print(f"{BL}{B}  Phase 7 Summary{R}")
    print(f"{BL}{B}{'='*62}{R}")
    total = passed + failed
    print(f"\n  Tests:  {total}")
    print(f"  Passed: {GR}{passed}{R}")
    print(f"  Failed: {RD}{failed}{R}")

    if failed == 0:
        print(f"\n  {GR}{B}Phase 7 Result: PASS — All {total} tests passed{R}")
    else:
        print(f"\n  {RD}{B}Phase 7 Result: FAIL — {failed}/{total} tests failed{R}")

    print(f"{BL}{'='*62}{R}\n")


if __name__ == "__main__":
    run_phase7()
