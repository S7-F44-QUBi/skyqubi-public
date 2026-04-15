# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — Covenant Witness System Engine
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
#
# Licensed under CWS-BSL-1.1 (see CWS-LICENSE at repo root)
# Patent Pending: TPP99606 — Jamie Lee Clayton / 123Tech / 2XR, LLC
#
# S7™, SkyQUBi™, SkyCAIR™, CWS™, ForToken™, RevToken™, ZeroClaw™,
# SkyAVi™, MemPalace™, and "Love is the architecture"™ are
# trademarks of 123Tech / 2XR, LLC.
#
# CIVILIAN USE ONLY — See CWS-LICENSE Civilian-Only Covenant.
# ═══════════════════════════════════════════════════════════════════
"""
S7 SkyAVi — Agent Orchestration
===================================
Manages witness model invocation, pipeline chaining,
multi-witness consensus, and scheduled tasks.

All data flows through sky_molecular.bonds.

Patent: TPP99606 — 123Tech / 2XR, LLC
"""

import os
import yaml
import uuid
import asyncio
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path

AGENTS_DIR = Path(os.getenv("S7_AGENTS_DIR",
    os.path.join(os.path.dirname(__file__), "agents")))


@dataclass
class ScheduledTask:
    name: str
    interval_seconds: int
    callback: str
    args: dict = field(default_factory=dict)
    last_run: float = 0.0
    run_count: int = 0
    active: bool = True


@dataclass
class AgentConfig:
    name: str
    model: str
    plane: int
    role: str
    tools: list[str] = field(default_factory=list)
    prompt: str = ""

    @classmethod
    def from_yaml(cls, path: Path) -> "AgentConfig":
        with open(path) as f:
            data = yaml.safe_load(f)
        return cls(
            name=data["name"],
            model=data["model"],
            plane=data["plane"],
            role=data["role"],
            tools=data.get("tools", []),
            prompt=data.get("prompt", ""),
        )


def load_agents(agents_dir: Path = AGENTS_DIR) -> dict[str, AgentConfig]:
    """Load all agent configs from YAML files in agents_dir."""
    agents = {}
    if not agents_dir.exists():
        return agents
    for yaml_file in sorted(agents_dir.glob("*.yaml")):
        agent = AgentConfig.from_yaml(yaml_file)
        agents[agent.name] = agent
    return agents


from s7_molecular import Bond, MolecularBackend, SqliteBackend, get_backend, TRUST_THRESHOLD, SQLITE_PATH
from s7_http import ollama_generate, mempalace_search, mempalace_add_drawer
from s7_discernment import compute_discernment, score_tokens_forward, score_tokens_reverse
from s7_breaker import compute_babel_ratio, should_trip


class SkyAVi:
    def __init__(self, backend: MolecularBackend | None = None,
                 agents_dir: Path = AGENTS_DIR,
                 db_path: str | None = None):
        self.backend = backend or get_backend()
        self.agents = load_agents(agents_dir)
        self._db_path = db_path  # stored for thread-safe SQLite cloning
        self._tasks: dict[str, ScheduledTask] = {}
        self._scheduler_thread: threading.Thread | None = None
        self._scheduler_stop = threading.Event()

    def get_agent(self, name: str) -> AgentConfig:
        if name not in self.agents:
            raise KeyError(f"Agent '{name}' not found. Available: {list(self.agents.keys())}")
        return self.agents[name]

    async def run_agent(self, agent: AgentConfig, query: str) -> Bond:
        """Run a single agent: infer -> discern -> breaker check -> store bond."""
        # 1. Call model via Ollama
        full_prompt = f"{agent.prompt}\n\nQuery: {query}" if agent.prompt else query
        result = await ollama_generate(full_prompt, model=agent.model)
        response_text = result.get("response", "")

        # 2. Tokenize and discern
        tokens = response_text.split()
        if not tokens:
            tokens = ["<empty>"]
        fwd = await score_tokens_forward(tokens)
        rev = await score_tokens_reverse(tokens)
        scored = compute_discernment(tokens, fwd, rev)

        # 3. Check circuit breaker
        ratio = compute_babel_ratio(scored)
        if should_trip(ratio):
            babel_bond = Bond(
                bond_type="signal", plane=agent.plane,
                memory=-1, present=-1, destiny=-1,
                content=f"BABEL threshold exceeded ({ratio:.2%}) for agent {agent.name}",
                witness_id=agent.name,
                state="BABEL",
            )
            self.backend.store_bond(babel_bond)
            return babel_bond

        # 4. Store FERTILE output bond
        fertile_count = sum(1 for s in scored if s["result"] == "FERTILE")
        total_tokens = len(scored)

        bond = Bond(
            bond_type="output", plane=agent.plane,
            memory=1, present=0, destiny=1,
            content=response_text,
            witness_id=agent.name,
            trust_score=fertile_count / max(total_tokens, 1),
            latency_ms=int(result.get("total_duration", 0) / 1_000_000),
            state="FERTILE",
        )
        self.backend.store_bond(bond)
        return bond

    async def run_consensus(self, query: str,
                            agent_names: list[str] | None = None) -> dict:
        """Run multi-witness consensus: MemPalace recall -> guardian gate ->
        all witnesses simultaneously -> consensus -> MemPalace store."""

        # 1. S7 MemPalace recall (+1 REST) — long-term memory
        memories = await mempalace_search(query, limit=5)
        memory_context = ""
        if memories:
            memory_context = "\n".join(
                m.get("content", "")[:200] for m in memories[:3])

        # 2. Guardian gate (-4 Guard)
        if "guardian" in self.agents:
            guardian = self.get_agent("guardian")
            gate = await self.run_agent(guardian, query)
            if gate.state == "BABEL":
                return {"verdict": "BLOCKED", "score": 0.0,
                        "fertile": 0, "total": 0,
                        "bonds": [gate], "consensus": gate,
                        "memories": len(memories)}

        # 3. Select witness agents (exclude guardian)
        if agent_names:
            witnesses = [self.get_agent(n) for n in agent_names]
        else:
            witnesses = [a for a in self.agents.values() if a.plane > 0]

        if not witnesses:
            raise ValueError("No witness agents available")

        # 4. Enrich query with MemPalace context
        enriched_query = query
        if memory_context:
            enriched_query = f"Context from memory:\n{memory_context}\n\nQuery: {query}"

        # 5. ALL witnesses see it simultaneously (parallel)
        bonds = await asyncio.gather(
            *[self.run_agent(agent, enriched_query) for agent in witnesses])
        bonds = list(bonds)

        # 6. S7 CWS consensus (0 DOOR) — compute verdict
        fertile = sum(1 for b in bonds if b.state == "FERTILE")
        total = len(bonds)
        score = fertile / max(total, 1)
        verdict = "FERTILE" if score >= TRUST_THRESHOLD else "BABEL"

        # 7. Store consensus bond at Door (plane 0)
        consensus_bond = Bond(
            bond_type="signal", plane=0,
            memory=1 if verdict == "FERTILE" else -1,
            present=0,
            destiny=1 if verdict == "FERTILE" else -1,
            content=f"Consensus: {fertile}/{total} witnesses FERTILE ({score:.2%})",
            trust_score=score,
            trust_tier="TRUSTED" if verdict == "FERTILE" else "UNTRUSTED",
            state=verdict,
        )
        self.backend.store_bond(consensus_bond)

        # 8. S7 MemPalace store (+1 REST) — FERTILE results become memory
        if verdict == "FERTILE":
            fertile_content = " | ".join(
                b.content[:200] for b in bonds if b.state == "FERTILE")
            try:
                await mempalace_add_drawer(
                    wing="private-ai", hall="consensus",
                    room="skyavi",
                    label=f"consensus:{consensus_bond.id[:8]}",
                    content=fertile_content[:1000])
            except Exception:
                pass  # MemPalace offline is non-fatal

        return {"verdict": verdict, "score": round(score, 6),
                "fertile": fertile, "total": total,
                "bonds": bonds, "consensus": consensus_bond,
                "memories": len(memories)}

    def schedule(self, name: str, interval_seconds: int,
                 callback: str, **kwargs) -> ScheduledTask:
        """Schedule a recurring task."""
        task = ScheduledTask(
            name=name,
            interval_seconds=interval_seconds,
            callback=callback,
            args=kwargs,
        )
        self._tasks[name] = task
        return task

    def cancel(self, name: str) -> bool:
        """Cancel a scheduled task."""
        if name in self._tasks:
            self._tasks[name].active = False
            del self._tasks[name]
            return True
        return False

    def _run_scheduler(self):
        """Background scheduler loop — creates own SQLite connection for thread safety."""
        sched_backend = self._make_thread_backend()

        while not self._scheduler_stop.is_set():
            now = time.time()
            for task in list(self._tasks.values()):
                if not task.active:
                    continue
                if now - task.last_run >= task.interval_seconds:
                    task.last_run = now
                    task.run_count += 1
                    method_name = task.callback
                    # Look up callable: built-in methods or dynamically registered
                    if method_name == "health_check":
                        method = lambda **kw: self._health_check_on(sched_backend)
                    else:
                        method = getattr(self, method_name, None)
                    if method:
                        try:
                            method(**task.args)
                        except Exception as e:
                            try:
                                sched_backend.store_bond(Bond(
                                    bond_type="signal", plane=0,
                                    memory=-1, present=-1, destiny=-1,
                                    content=f"Scheduler error in {task.name}: {e}",
                                    state="BABEL",
                                ))
                            except Exception:
                                pass
            self._scheduler_stop.wait(1.0)

        if isinstance(sched_backend, SqliteBackend):
            sched_backend.close()

    def _make_thread_backend(self) -> MolecularBackend:
        """Create a new backend for use in a different thread."""
        if isinstance(self.backend, SqliteBackend) and self._db_path:
            return SqliteBackend(self._db_path)
        return self.backend

    def _health_check_on(self, backend: MolecularBackend) -> Bond:
        """Health check using a specific backend (thread-safe)."""
        bond = Bond(
            bond_type="signal", plane=0,
            memory=1, present=1, destiny=1,
            content=f"Health check: {len(self.agents)} agents loaded, "
                    f"{len(self._tasks)} tasks scheduled",
            state="FERTILE",
        )
        backend.store_bond(bond)
        return bond

    def start_scheduler(self):
        """Start the background scheduler thread."""
        if self._scheduler_thread and self._scheduler_thread.is_alive():
            return
        self._scheduler_stop.clear()
        self._scheduler_thread = threading.Thread(
            target=self._run_scheduler, daemon=True, name="skyavi-scheduler")
        self._scheduler_thread.start()

    def stop_scheduler(self):
        """Stop the background scheduler thread."""
        self._scheduler_stop.set()
        if self._scheduler_thread:
            self._scheduler_thread.join(timeout=3.0)
            self._scheduler_thread = None

    def health_check(self) -> Bond:
        """Built-in health check task — stores a signal bond."""
        return self._health_check_on(self.backend)

    def status(self) -> dict:
        """Return SkyAVi status."""
        return {
            "agents": len(self.agents),
            "agent_names": list(self.agents.keys()),
            "tasks": {name: {"interval": t.interval_seconds,
                             "run_count": t.run_count, "active": t.active}
                      for name, t in self._tasks.items()},
            "scheduler_running": (self._scheduler_thread is not None
                                  and self._scheduler_thread.is_alive()),
        }
