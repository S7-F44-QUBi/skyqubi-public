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
import logging
import os
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Request, Security
from fastapi.responses import JSONResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel

log = logging.getLogger("s7_engine")
from engine.s7_db import init_pool, close_pool, get_conn
from engine.s7_http import close_client
from engine.s7_router import route_query
from engine.s7_discernment import run_discernment
from engine.s7_store import store_memory
from engine.s7_breaker import check_breaker, is_circuit_open, reset_circuit
from engine.s7_bridge import sync_to_palace
from engine.s7_witness import run_witness
from engine.s7_quanti import run_quanti
from engine.s7_skyavi_orchestrator import SkyAVi
from engine.s7_skyavi import Samuel
from engine.s7_skyavi_skills import register_facts_skills

_bearer = HTTPBearer(auto_error=True)
_CWS_TOKEN = os.environ.get("CWS_ENGINE_TOKEN", "")

def _require_token(creds: HTTPAuthorizationCredentials = Security(_bearer)) -> None:
    if not _CWS_TOKEN:
        raise HTTPException(503, "CWS_ENGINE_TOKEN not configured on server")
    if creds.credentials != _CWS_TOKEN:
        raise HTTPException(401, "Invalid CWS engine token")

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_pool()
    yield
    close_pool()
    await close_client()

app = FastAPI(title="S7 CWS Engine", version="2.5", lifespan=lifespan)

# ── Global exception handler ──────────────────────────────────────
# Catches anything an endpoint forgot to wrap. Logs the full traceback
# server-side, returns a generic JSON body to the caller. Prevents any
# stack trace from being exposed in HTTP responses (CodeQL: py/stack-trace-exposure).
@app.exception_handler(Exception)
async def _unhandled_exception_handler(request: Request, exc: Exception):
    log.exception("unhandled exception on %s", request.url.path)
    return JSONResponse(status_code=500, content={"error": "internal server error"})

class RouteRequest(BaseModel):
    query: str
    task_type: str | None = None
    model_hint: str | None = None

# 2026-04-13 fix: session_id uses uuid.UUID instead of str so FastAPI rejects
# non-UUID input with a clean 422 at the validator layer. Previously,
# arbitrary strings reached run_discernment() which passed them to SQL with
# %s::uuid and crashed with psycopg2.errors.InvalidTextRepresentation, showing
# up as a 500 to the caller. The UUID type change produces a structured
# error response on bad input instead of a stack trace.
class DiscernRequest(BaseModel):
    session_id: uuid.UUID
    tokens: list[str]

class StoreRequest(BaseModel):
    session_id: uuid.UUID
    content: str
    discernment: list[dict]
    plane: str | None = None
    entity_id: str | None = None

class BreakerRequest(BaseModel):
    session_id: uuid.UUID

class BridgeRequest(BaseModel):
    entry_id: str

class WitnessRequest(BaseModel):
    session_id: uuid.UUID | None = None
    query: str
    model: str = "llama3.2:1b"

class QuantiRequest(BaseModel):
    prompt: str
    session_id: uuid.UUID | None = None

class SkyAViRunRequest(BaseModel):
    agent: str
    query: str

class SkyAViConsensusRequest(BaseModel):
    query: str
    agents: list[str] | None = None

class SkyAViScheduleRequest(BaseModel):
    name: str
    interval_seconds: int
    callback: str

class SamuelChatRequest(BaseModel):
    message: str
    tier: str | None = None  # FAST, LITE, FULL — auto-classified if omitted

_skyavi_core: SkyAVi | None = None

def get_skyavi_core() -> SkyAVi:
    global _skyavi_core
    if _skyavi_core is None:
        _skyavi_core = SkyAVi()
        _skyavi_core.start_scheduler()
        _skyavi_core.schedule("health", 300, "health_check")
    return _skyavi_core

_samuel: Samuel | None = None

def get_samuel() -> Samuel:
    global _samuel
    if _samuel is None:
        _samuel = Samuel(get_skyavi_core())
        register_facts_skills(_samuel)
    return _samuel

@app.post("/route")
async def route(req: RouteRequest, _: None = Security(_require_token)):
    if is_circuit_open():
        raise HTTPException(503, "Circuit breaker is open — babel threshold exceeded")
    with get_conn() as conn:
        return await route_query(conn, req.query, req.task_type, req.model_hint)

@app.post("/discern")
async def discern(req: DiscernRequest, _: None = Security(_require_token)):
    with get_conn() as conn:
        return await run_discernment(conn, req.session_id, req.tokens)

@app.post("/store")
async def store(req: StoreRequest, _: None = Security(_require_token)):
    with get_conn() as conn:
        entry_id = await store_memory(conn, req.session_id, req.content, req.discernment, req.plane, req.entity_id)
    if entry_id is None:
        return {"stored": False, "reason": "all tokens BABEL"}
    return {"stored": True, "entry_id": entry_id}

@app.post("/breaker")
async def breaker(req: BreakerRequest, _: None = Security(_require_token)):
    with get_conn() as conn:
        return await check_breaker(conn, req.session_id)

@app.post("/bridge")
async def bridge(req: BridgeRequest, _: None = Security(_require_token)):
    with get_conn() as conn:
        return await sync_to_palace(conn, req.entry_id)

@app.post("/witness")
async def witness(req: WitnessRequest, _: None = Security(_require_token)):
    if is_circuit_open():
        raise HTTPException(503, "Circuit breaker is open")
    # req.session_id is now uuid.UUID|None from the Pydantic model. Coerce
    # to str for SQL parameter passing — psycopg2 accepts either but the
    # downstream helpers assume str.
    sid = str(req.session_id) if req.session_id else str(uuid.uuid4())
    with get_conn() as conn:
        return await run_witness(conn, sid, req.query, req.model)

@app.post("/quanti")
async def quanti(req: QuantiRequest, _: None = Security(_require_token)):
    # req.session_id is now uuid.UUID|None from the Pydantic model. Coerce
    # to str for SQL parameter passing — psycopg2 accepts either but the
    # downstream helpers assume str.
    sid = str(req.session_id) if req.session_id else str(uuid.uuid4())
    with get_conn() as conn:
        return await run_quanti(conn, sid, req.prompt)

@app.get("/status")
async def status():
    # Public liveness check — no auth required.
    # Reduced 2026-04-13 to {"status":"ok"} per security review:
    # circuit_open and endpoint enumeration moved to /skyavi/core/status
    # which requires Bearer auth. Defense-in-depth even on loopback.
    return {"status": "ok"}

@app.post("/breaker/reset")
async def breaker_reset(_: None = Security(_require_token)):
    reset_circuit()
    return {"circuit_open": False}

# ── SkyAVi Endpoints ──────────────────────────────────────────

@app.get("/skyavi/core/status")
async def skyavi_core_status(_: None = Security(_require_token)):
    return get_skyavi_core().status()

@app.get("/skyavi/core/agents")
async def skyavi_core_agents(_: None = Security(_require_token)):
    core = get_skyavi_core()
    return {name: {"model": a.model, "plane": a.plane, "role": a.role}
            for name, a in core.agents.items()}

@app.post("/skyavi/core/run")
async def skyavi_core_run(req: SkyAViRunRequest, _: None = Security(_require_token)):
    core = get_skyavi_core()
    agent = core.get_agent(req.agent)
    bond = await core.run_agent(agent, req.query)
    return {"bond_id": bond.id, "state": bond.state, "content": bond.content,
            "vector_name": bond.vector_name, "plane": bond.plane}

@app.post("/skyavi/core/consensus")
async def skyavi_core_consensus(req: SkyAViConsensusRequest, _: None = Security(_require_token)):
    core = get_skyavi_core()
    result = await core.run_consensus(req.query, agent_names=req.agents)
    return {
        "verdict": result["verdict"],
        "score": result["score"],
        "fertile": result["fertile"],
        "total": result["total"],
        "consensus_bond_id": result["consensus"].id,
        "witness_bonds": [{"id": b.id, "state": b.state, "agent": b.witness_id}
                          for b in result["bonds"]],
    }

@app.post("/skyavi/core/schedule")
async def skyavi_core_schedule(req: SkyAViScheduleRequest, _: None = Security(_require_token)):
    core = get_skyavi_core()
    task = core.schedule(req.name, req.interval_seconds, req.callback)
    return {"name": task.name, "interval": task.interval_seconds, "active": task.active}

# ── Samuel Endpoints ───────────────────────────────────────────

@app.post("/skyavi/chat")
async def skyavi_chat(req: SamuelChatRequest, _: None = Security(_require_token)):
    return await get_samuel().chat(req.message, tier=req.tier)

@app.get("/skyavi/status")
async def skyavi_status(_: None = Security(_require_token)):
    return get_samuel().status()

@app.get("/skyavi/skills")
async def skyavi_skills(_: None = Security(_require_token)):
    return get_samuel().list_skills()

@app.get("/skyavi/audit")
async def skyavi_audit(_: None = Security(_require_token)):
    samuel = get_samuel()
    bonds = samuel.backend.query_bonds(bond_type="output", limit=50)
    signals = samuel.backend.query_bonds(bond_type="signal", state="BABEL", limit=50)
    return {"outputs": bonds, "blocked": signals}

@app.get("/skyavi/self-audit")
async def skyavi_self_audit(_: None = Security(_require_token)):
    return await get_samuel().self_audit()

@app.get("/skyavi/notifications")
async def skyavi_notifications(_: None = Security(_require_token)):
    return get_samuel().get_notifications(limit=50)

if __name__ == "__main__":
    import uvicorn
    # Always bind to loopback — CWS Engine is an internal service only
    uvicorn.run(app, host="127.0.0.1", port=7077, log_level="info")
