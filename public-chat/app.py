#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Public Chat Service
#
# A standalone, minimal chat microservice for the public website.
# Supports multiple independent backends: each stands alone, each can
# fail independently, they work together when all are up.
#
# What this IS:
#   - A thin HTTP proxy in front of one or more local Ollama backends
#   - Rate-limited, CORS-protected, no persistence
#   - Completely separate from the S7 pod / CWS Engine stack
#   - Distributed-ready: supports multiple hosts via S7_BACKENDS
#
# What this is NOT:
#   - It does NOT use the CWS Engine
#   - It does NOT access MemPalace or molecular bonds
#   - It does NOT log or store conversations
#   - It does NOT train on visitor data
#   - It is NOT "Carli" in the covenant sense — it is a public demo
#
# Port: 57088 (bound to 127.0.0.1 — tunnel for internet exposure)
#
# Configuration:
#   S7_BACKENDS       comma-separated list of backend URLs
#                     default: http://127.0.0.1:57081
#                     example: http://127.0.0.1:57081,http://10.0.0.2:57081
#   S7_PUBLIC_MODEL   model name to use
#                     default: qwen2.5:3b
#   S7_ROUTING        routing strategy: round_robin | random | first_alive
#                     default: round_robin
#
# Copyright 2026 Jamie Lee Clayton / 2XR LLC
# Civilian use only. No logging of visitor conversations.
# ═══════════════════════════════════════════════════════════════════

import os
import time
import random
import asyncio
import itertools
from collections import defaultdict, deque
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse
from pydantic import BaseModel, Field

# Consensus module — real multi-model witness (not persona wrappers)
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from consensus import run_consensus, WITNESS_MODELS, ConsensusResult

# ── Config ──────────────────────────────────────────────────────
HOST = "127.0.0.1"
PORT = 57088
MODEL = os.getenv("S7_PUBLIC_MODEL", "qwen2.5:3b")
ROUTING = os.getenv("S7_ROUTING", "round_robin")
HEALTH_CHECK_INTERVAL = 30.0
REQUEST_TIMEOUT = 60.0
HEALTH_TIMEOUT = 3.0
MAX_MESSAGE_LENGTH = 500
MAX_RESPONSE_TOKENS = 300
RATE_LIMIT_PER_MINUTE = 10
RATE_LIMIT_PER_HOUR = 60

# Backend URLs — parsed from env
_raw_backends = os.getenv("S7_BACKENDS", "http://127.0.0.1:57081")
BACKEND_URLS = [b.strip().rstrip("/") for b in _raw_backends.split(",") if b.strip()]

ALLOWED_ORIGINS = [
    "https://skyqubi.com",
    "https://www.skyqubi.com",
    "https://skyqubi.ai",
    "https://www.skyqubi.ai",
    "https://123tech.skyqubi.ai",
    "https://123tech.skyqubi.com",
    "https://editor.wix.com",
]
# Allow any wix.com or wixsite.com subdomain
ALLOWED_ORIGIN_REGEX = r"https://.*\.(wix\.com|wixsite\.com|skyqubi\.(com|ai))"

SYSTEM_PROMPT = """You are a public demo assistant for S7 SkyQUBi, a sovereign offline AI platform.
You run on Jamie Lee Clayton's personal hardware, not a cloud server.
Be warm, honest, and brief. You are a demonstration, not the full platform.
If asked about S7 SkyQUBi, tell visitors they can download it at github.com/skycair-code/SkyQUBi-public.
Love is the architecture."""

# ── Backend pool ────────────────────────────────────────────────
@dataclass
class Backend:
    url: str
    alive: bool = True
    last_check: float = 0.0
    last_error: Optional[str] = None
    request_count: int = 0
    failure_count: int = 0

backends: list[Backend] = [Backend(url=u) for u in BACKEND_URLS]
_round_robin = itertools.cycle(range(len(backends))) if backends else None
_lock = asyncio.Lock()

async def health_check_one(client: httpx.AsyncClient, b: Backend) -> None:
    try:
        r = await client.get(f"{b.url}/api/version", timeout=HEALTH_TIMEOUT)
        if r.status_code == 200:
            if not b.alive:
                print(f"[health] backend RECOVERED: {b.url}")
            b.alive = True
            b.last_error = None
        else:
            b.alive = False
            b.last_error = f"HTTP {r.status_code}"
    except Exception as e:
        if b.alive:
            print(f"[health] backend FAILED: {b.url} — {type(e).__name__}")
        b.alive = False
        b.last_error = type(e).__name__
    finally:
        b.last_check = time.time()

async def health_loop(client: httpx.AsyncClient):
    """Background task: check all backends every HEALTH_CHECK_INTERVAL seconds."""
    while True:
        await asyncio.gather(
            *[health_check_one(client, b) for b in backends],
            return_exceptions=True,
        )
        await asyncio.sleep(HEALTH_CHECK_INTERVAL)

async def pick_backend() -> Optional[Backend]:
    """Pick a healthy backend according to the routing strategy."""
    alive = [b for b in backends if b.alive]
    if not alive:
        return None
    if ROUTING == "random":
        return random.choice(alive)
    if ROUTING == "first_alive":
        return alive[0]
    # round_robin (default)
    async with _lock:
        # Rotate through all backends (including dead ones) but skip dead
        for _ in range(len(backends)):
            idx = next(_round_robin)
            if backends[idx].alive:
                return backends[idx]
        return alive[0]  # fallback

# ── Rate limiting (per IP, in-memory, no persistence) ─────────
rate_buckets_minute: dict[str, deque] = defaultdict(lambda: deque(maxlen=RATE_LIMIT_PER_MINUTE))
rate_buckets_hour: dict[str, deque] = defaultdict(lambda: deque(maxlen=RATE_LIMIT_PER_HOUR))

def check_rate_limit(ip: str) -> tuple[bool, str]:
    now = time.time()
    while rate_buckets_minute[ip] and rate_buckets_minute[ip][0] < now - 60:
        rate_buckets_minute[ip].popleft()
    while rate_buckets_hour[ip] and rate_buckets_hour[ip][0] < now - 3600:
        rate_buckets_hour[ip].popleft()
    if len(rate_buckets_minute[ip]) >= RATE_LIMIT_PER_MINUTE:
        return False, "Too many requests this minute. Please slow down."
    if len(rate_buckets_hour[ip]) >= RATE_LIMIT_PER_HOUR:
        return False, "Hourly limit reached. Try again later, or download SkyQUBi to run your own."
    rate_buckets_minute[ip].append(now)
    rate_buckets_hour[ip].append(now)
    return True, ""

# ── HTTP client + lifecycle ────────────────────────────────────
_client: httpx.AsyncClient | None = None
_health_task: asyncio.Task | None = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global _client, _health_task
    _client = httpx.AsyncClient(timeout=REQUEST_TIMEOUT)
    # Initial health check before serving
    await asyncio.gather(*[health_check_one(_client, b) for b in backends])
    _health_task = asyncio.create_task(health_loop(_client))
    print(f"[startup] {sum(1 for b in backends if b.alive)}/{len(backends)} backends alive")
    yield
    if _health_task:
        _health_task.cancel()
    await _client.aclose()

app = FastAPI(
    title="S7 SkyQUBi — Public Chat",
    version="1.1",
    description="Minimal public chat proxy with multi-backend support. Not the full CWS Engine.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=ALLOWED_ORIGIN_REGEX,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)

# ── Models ──────────────────────────────────────────────────────
class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=MAX_MESSAGE_LENGTH)

class ChatResponse(BaseModel):
    response: str
    model: str
    backend: str

class WitnessRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=MAX_MESSAGE_LENGTH)

class WitnessResponse(BaseModel):
    query: str
    agreement_score: float
    classification: str  # FERTILE | AMBIGUOUS | BABEL
    circuit_breaker_tripped: bool
    consensus_answer: Optional[str] = None
    witnesses: list[dict]
    total_latency_ms: int

# ── Endpoints ───────────────────────────────────────────────────
@app.get("/")
async def root():
    alive_count = sum(1 for b in backends if b.alive)
    return {
        "service": "S7 SkyQUBi Public Chat",
        "version": "1.1",
        "model": MODEL,
        "routing": ROUTING,
        "backends_total": len(backends),
        "backends_alive": alive_count,
        "status": "alive" if alive_count > 0 else "all_backends_down",
        "note": "Public demo. Full platform: github.com/skycair-code/SkyQUBi-public",
    }

@app.get("/status")
async def status():
    """Detailed backend status for monitoring."""
    return {
        "model": MODEL,
        "routing": ROUTING,
        "backends": [
            {
                "url": b.url,
                "alive": b.alive,
                "last_check_age": round(time.time() - b.last_check, 1) if b.last_check else None,
                "last_error": b.last_error,
                "requests": b.request_count,
                "failures": b.failure_count,
            }
            for b in backends
        ],
    }

@app.get("/health")
async def health():
    alive = sum(1 for b in backends if b.alive)
    if alive == 0:
        return JSONResponse(
            status_code=503,
            content={"status": "all_down", "alive": 0, "total": len(backends)},
        )
    return {"status": "ok", "alive": alive, "total": len(backends)}

@app.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest, request: Request):
    ip = request.client.host if request.client else "unknown"

    ok, msg = check_rate_limit(ip)
    if not ok:
        raise HTTPException(status_code=429, detail=msg)

    # Try up to N backends in order (failover)
    tried: list[str] = []
    last_error = "no backends configured"

    for attempt in range(len(backends)):
        backend = await pick_backend()
        if not backend:
            break
        if backend.url in tried:
            continue
        tried.append(backend.url)

        backend.request_count += 1
        try:
            resp = await _client.post(
                f"{backend.url}/api/chat",
                json={
                    "model": MODEL,
                    "stream": False,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": req.message},
                    ],
                    "options": {"num_predict": MAX_RESPONSE_TOKENS},
                },
            )
            resp.raise_for_status()
            data = resp.json()
            content = data.get("message", {}).get("content", "")
            if not content:
                last_error = "empty response"
                backend.failure_count += 1
                continue
            return ChatResponse(
                response=content.strip(),
                model=MODEL,
                backend=backend.url.replace("http://", "").replace("https://", ""),
            )
        except httpx.TimeoutException:
            last_error = "timeout"
            backend.failure_count += 1
            backend.alive = False  # mark for re-check
        except httpx.HTTPError as e:
            last_error = type(e).__name__
            backend.failure_count += 1
            backend.alive = False

    raise HTTPException(
        status_code=503,
        detail=f"All backends failed. Last error: {last_error}",
    )

@app.post("/witness", response_model=WitnessResponse)
async def witness(req: WitnessRequest, request: Request):
    """
    Real multi-model consensus endpoint.

    Queries 3 architecturally-diverse models in parallel (different families,
    different training data, different tokenizers), compares their answers,
    and returns a FERTILE/AMBIGUOUS/BABEL classification based on token overlap.

    This is the actual witness system in miniature — not persona wrappers.
    Circuit breaker trips if agreement is below BABEL_THRESHOLD (no consensus).
    """
    ip = request.client.host if request.client else "unknown"

    ok, msg = check_rate_limit(ip)
    if not ok:
        raise HTTPException(status_code=429, detail=msg)

    # Use the first alive backend (consensus queries all models on same backend)
    backend = await pick_backend()
    if not backend:
        raise HTTPException(status_code=503, detail="No backends available")

    result = await run_consensus(
        client=_client,
        backend_url=backend.url,
        query=req.query,
        system_prompt=SYSTEM_PROMPT,
        max_tokens=MAX_RESPONSE_TOKENS,
    )

    backend.request_count += 1

    return WitnessResponse(
        query=result.query,
        agreement_score=result.agreement_score,
        classification=result.classification,
        circuit_breaker_tripped=result.circuit_breaker_tripped,
        consensus_answer=result.consensus_answer,
        witnesses=[
            {
                "model": w.model,
                "family": w.family,
                "role": w.role,
                "response": w.response if not w.error else None,
                "latency_ms": w.latency_ms,
                "error": w.error,
            }
            for w in result.witnesses
        ],
        total_latency_ms=result.total_latency_ms,
    )

@app.get("/witnesses")
async def list_witnesses():
    """List the witness models used for consensus."""
    return {
        "models": [
            {"name": n, "family": f, "role": r, "size_gb": s}
            for n, f, r, s in WITNESS_MODELS
        ],
        "note": "These are architecturally distinct base models, not persona wrappers. Consensus across these is meaningful.",
    }

@app.get("/widget", response_class=HTMLResponse)
async def widget():
    """Embeddable chat widget HTML for Wix HTML embed blocks."""
    return """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>S7 SkyQUBi Chat</title>
<style>
  *,*::before,*::after{margin:0;padding:0;box-sizing:border-box}
  body{font-family:system-ui,-apple-system,sans-serif;background:#0a0e1a;color:#c8d0e0;height:100vh;display:flex;flex-direction:column}
  .header{padding:.75rem 1rem;border-bottom:1px solid #1e2a4a;background:#0f1628;display:flex;justify-content:space-between;align-items:center}
  .header strong{color:#4a9eff}
  .header .status{font-size:.7rem;color:#4a5578}
  .header .status.alive::before{content:"● ";color:#48d89b}
  .header .status.down::before{content:"● ";color:#e85d75}
  .messages{flex:1;overflow-y:auto;padding:1rem;display:flex;flex-direction:column;gap:.75rem}
  .msg{max-width:85%;padding:.65rem .9rem;border-radius:10px;line-height:1.4;font-size:.9rem}
  .msg.user{align-self:flex-end;background:#2a6ecc;color:#fff}
  .msg.bot{align-self:flex-start;background:#151d33;border:1px solid #1e2a4a}
  .msg.err{align-self:center;background:#e85d75;color:#fff;font-size:.8rem;max-width:90%;text-align:center}
  .input-row{padding:.75rem;background:#0f1628;border-top:1px solid #1e2a4a;display:flex;gap:.5rem}
  input{flex:1;padding:.65rem .9rem;background:#151d33;border:1px solid #1e2a4a;border-radius:8px;color:#e8ecf4;font-size:.9rem}
  input:focus{outline:none;border-color:#4a9eff}
  button{padding:.65rem 1.2rem;background:linear-gradient(135deg,#4a9eff,#2a6ecc);color:#fff;border:none;border-radius:8px;font-weight:500;cursor:pointer}
  button:disabled{opacity:.5;cursor:not-allowed}
  .typing{color:#4a5578;font-style:italic;font-size:.85rem}
  .footer{padding:.4rem 1rem;background:#0f1628;text-align:center;font-size:.7rem;color:#4a5578}
  .footer a{color:#4a9eff;text-decoration:none}
</style>
</head>
<body>
  <div class="header">
    <strong>S7 SkyQUB<em style="font-style:italic;color:#d4a843">i</em></strong>
    <span class="status" id="status">checking...</span>
  </div>
  <div class="messages" id="messages">
    <div class="msg bot" style="max-width:95%;background:linear-gradient(135deg,#151d33,#0f1628);border:1px solid #d4a843;">
      <strong style="color:#d4a843;font-size:.95rem;">AI + Humanity is coming.</strong><br><br>
      Something different is being built here. Not another chatbot. Not another cloud AI. Not another subscription.<br><br>
      Core Release locks <strong>July 4, 2026</strong>. Public launch <strong>July 7 &middot; 7:00 AM CT</strong>.<br><br>
      Come back then. Or chat now if you just want a taste.
    </div>
  </div>
  <div class="input-row">
    <input id="input" placeholder="Type a message..." maxlength="500" autocomplete="off">
    <button id="send">Send</button>
  </div>
  <div class="footer">
    Love is the architecture. <a href="https://github.com/skycair-code/SkyQUBi-public" target="_blank">Run your own →</a>
  </div>
<script>
const API = window.location.origin;
const msgs = document.getElementById('messages');
const input = document.getElementById('input');
const sendBtn = document.getElementById('send');
const statusEl = document.getElementById('status');

async function updateStatus() {
  try {
    const r = await fetch(API + '/health');
    const d = await r.json();
    if (d.status === 'ok') {
      statusEl.className = 'status alive';
      statusEl.textContent = d.alive + '/' + d.total + ' backends';
    } else {
      statusEl.className = 'status down';
      statusEl.textContent = 'offline';
    }
  } catch {
    statusEl.className = 'status down';
    statusEl.textContent = 'offline';
  }
}

function add(cls, text) {
  const d = document.createElement('div');
  d.className = 'msg ' + cls;
  d.textContent = text;
  msgs.appendChild(d);
  msgs.scrollTop = msgs.scrollHeight;
  return d;
}

async function send() {
  const msg = input.value.trim();
  if (!msg) return;
  input.value = '';
  sendBtn.disabled = true;
  add('user', msg);
  const typing = add('bot', '…');
  typing.classList.add('typing');
  try {
    const r = await fetch(API + '/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({message: msg}),
    });
    typing.remove();
    if (!r.ok) {
      const err = await r.json().catch(() => ({detail: 'Error'}));
      add('err', err.detail || 'Something went wrong');
    } else {
      const d = await r.json();
      add('bot', d.response);
    }
  } catch (e) {
    typing.remove();
    add('err', 'Connection error. The laptop may be offline.');
  } finally {
    sendBtn.disabled = false;
    input.focus();
    updateStatus();
  }
}

sendBtn.addEventListener('click', send);
input.addEventListener('keydown', (e) => { if (e.key === 'Enter') send(); });
input.focus();
updateStatus();
setInterval(updateStatus, 30000);
</script>
</body>
</html>"""

if __name__ == "__main__":
    import uvicorn
    print(f"S7 SkyQUBi Public Chat v1.1")
    print(f"  Model:    {MODEL}")
    print(f"  Routing:  {ROUTING}")
    print(f"  Backends: {len(backends)}")
    for b in backends:
        print(f"    - {b.url}")
    print(f"  Port:     {PORT}")
    print("This is a standalone service. It does NOT use the CWS Engine.")
    print("Love is the architecture.")
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")
