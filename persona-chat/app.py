#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Persona Chat (standalone, not-yet-landed)
#
# This is the covenant-honoring persona chat service. It is DIFFERENT
# from public-chat/app.py (the stateless Wix demo) and lives on a
# different port (57089 vs 57088). Both services coexist.
#
# What this IS:
#   - A FastAPI app that serves Carli / Elias / Samuel to identified
#     S7 users through the ledger + memory-tier substrate
#   - A consumer of ledger.py, memory_tiers.py, qbit_count.py,
#     persona_engine_map.yaml
#   - Testable standalone via: python3 app.py
#
# What this is NOT:
#   - Registered with systemd (no .service file written)
#   - Auto-started at boot
#   - Wired into public-chat/app.py in any way
#   - Connected to the pod (MemPalace, CWS engine, SkyAVi orchestrator)
#   - Running Witness Samuel's Bible-Code review (pod-blocked)
#   - Running a 1-bit inference path (BitNet-blocked)
#
# Landing gate: Samuel reviews this file against the Bible Code BEFORE
# any `systemctl --user enable s7-persona-chat.service` step. Per the
# Three Rules (feedback_three_rules.md): design substrate = safe,
# landing = requires Samuel.
#
# Copyright 2026 Jamie Lee Clayton / 2XR LLC · CWS-BSL-1.1
# Civilian use only.
# ═══════════════════════════════════════════════════════════════════

from __future__ import annotations

import asyncio
import os
import sys
import time
from collections import OrderedDict
from contextlib import asynccontextmanager
from dataclasses import asdict
from pathlib import Path
from typing import Optional

# Make the sibling modules importable when running from this directory
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import httpx
import yaml
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, HTMLResponse, PlainTextResponse
from pydantic import BaseModel, Field

from ledger import (
    ALLOWED_PERSONAS,
    LedgerCorruptError,
    append_row,
    ensure_session_dirs,
    persona_ledger_path,
    quarantine,
    verify_chain,
)
from memory_tiers import (
    TIER_BUDGETS,
    TierWalk,
    assemble_prompt,
    walk_tier,
)
from qbit_count import count_qbits, ollama_tokens_to_qbits, qps_from_ollama
from skill_runner import run_skill, SkillResult, match_intent, normalize_confirmation, normalize_negative_confirmation

# ── Config ──────────────────────────────────────────────────────────

HOST = os.environ.get("S7_PERSONA_CHAT_HOST", "127.0.0.1")
PORT = int(os.environ.get("S7_PERSONA_CHAT_PORT", "57089"))
CONFIG_PATH = Path(__file__).parent / "persona_engine_map.yaml"
REQUEST_TIMEOUT_S = 90
MAX_INPUT_LEN = 4000  # characters
L2_CACHE_SIZE = 50   # LRU max entries

# Loaded at startup from persona_engine_map.yaml
PERSONA_MAP: dict = {}
ENGINE_MAP: dict = {}


# ── L2 cache (in-memory LRU) ────────────────────────────────────────

class LRUCache:
    """Tiny LRU. Key: (user_id, session_id, persona, tier). Value: TierWalk.

    Used only for L2 tier. L1 is cheap enough to walk on every turn;
    L3 is semantic search (deferred). L2 sits in the middle where
    caching pays off — Section 3 design call.
    """

    def __init__(self, max_size: int):
        self.max_size = max_size
        self._store: OrderedDict[tuple, TierWalk] = OrderedDict()

    def get(self, key: tuple) -> Optional[TierWalk]:
        if key not in self._store:
            return None
        self._store.move_to_end(key)
        return self._store[key]

    def put(self, key: tuple, walk: TierWalk) -> None:
        if key in self._store:
            self._store.move_to_end(key)
        self._store[key] = walk
        while len(self._store) > self.max_size:
            self._store.popitem(last=False)

    def invalidate_session(self, user_id: str, session_id: str) -> None:
        """Drop every cached walk for a session. Called after append_row
        because the new turn makes the cached walk stale."""
        dead = [k for k in self._store if k[0] == user_id and k[1] == session_id]
        for k in dead:
            del self._store[k]

    def __len__(self) -> int:
        return len(self._store)


l2_cache = LRUCache(max_size=L2_CACHE_SIZE)


# ── Config loader ───────────────────────────────────────────────────

def load_config() -> None:
    """Load persona_engine_map.yaml into module-level maps.

    Strict: if the file is missing or malformed, raise — the service
    MUST NOT start with an unknown persona set. This enforces the
    closed-persona-set invariant from the brainstorm decision.
    """
    global PERSONA_MAP, ENGINE_MAP
    if not CONFIG_PATH.exists():
        raise FileNotFoundError(f"persona_engine_map.yaml not found at {CONFIG_PATH}")
    with CONFIG_PATH.open("r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)
    PERSONA_MAP = cfg.get("personas", {}) or {}
    ENGINE_MAP = cfg.get("engines", {}) or {}
    # Cross-check: every persona in the config must be in ALLOWED_PERSONAS
    for p in PERSONA_MAP:
        if p not in ALLOWED_PERSONAS:
            raise ValueError(
                f"config persona {p!r} not in ALLOWED_PERSONAS={ALLOWED_PERSONAS} — "
                "closed persona set violated"
            )
    # And every ALLOWED persona should have a config entry
    for p in ALLOWED_PERSONAS:
        if p not in PERSONA_MAP:
            raise ValueError(
                f"ALLOWED_PERSONAS contains {p!r} but the config has no entry for it"
            )


# ── Engine client ───────────────────────────────────────────────────

_client: httpx.AsyncClient | None = None


async def call_ollama(
    *,
    engine: dict,
    model: str,
    prompt: str,
    num_predict: int,
    temperature: float,
    think: bool,
) -> dict:
    """Call Ollama /api/generate non-streaming and return the raw JSON.

    Raises on HTTP error, timeout, or connection refused. The caller
    translates these into F1-style ledger entries.
    """
    url = engine["url"].rstrip("/") + engine.get("generate_path", "/api/generate")
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "think": think,
        "options": {
            "num_predict": num_predict,
            "temperature": temperature,
        },
    }
    assert _client is not None
    resp = await _client.post(url, json=payload, timeout=engine.get("timeout_s", REQUEST_TIMEOUT_S))
    resp.raise_for_status()
    return resp.json()


# ── Request / response models ───────────────────────────────────────

class PersonaChatRequest(BaseModel):
    user_id: str = Field(..., min_length=1, max_length=128)
    session_id: str = Field(..., min_length=1, max_length=128)
    persona: str = Field(..., min_length=1)
    message: str = Field(..., min_length=1, max_length=MAX_INPUT_LEN)
    tier: str = Field("L1")
    fortoken: bool = Field(False)
    cross_persona: bool = Field(True)


class PersonaChatResponse(BaseModel):
    persona: str
    engine: str
    model: str
    tier: str
    response: str
    qbit_count: dict
    qps: float
    latency_ms: int
    status: str  # "ok" | "engine_error" | "tamper" | "memory_error"
    fallback: Optional[dict] = None
    badge: str  # user-visible status string
    skill_invoked: Optional[dict] = None  # set when Samuel ran a skill instead of LLM


class PersonaSkillRequest(BaseModel):
    """Direct skill invocation — bypasses the chat model entirely.

    Used by operators who want to run a skill directly without the
    conversation overhead. Also the underlying call that /persona/chat
    uses when Samuel's skill runner matches the message.
    """
    user_id: str = Field(..., min_length=1, max_length=128)
    session_id: str = Field(..., min_length=1, max_length=128)
    persona: str = Field(..., min_length=1)
    message: str = Field(..., min_length=1, max_length=MAX_INPUT_LEN)


class PersonaSkillResponse(BaseModel):
    matched: bool
    skill_id: Optional[str]
    mode: str
    attempted: bool
    exit_code: Optional[int]
    state: Optional[str]
    summary: str
    samuel_reply: str
    elapsed_ms: int
    blocked_reason: Optional[str] = None


# ── Lifespan ────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    global _client
    load_config()
    _client = httpx.AsyncClient(timeout=REQUEST_TIMEOUT_S)
    print(f"[persona-chat] config loaded: {len(PERSONA_MAP)} personas, {len(ENGINE_MAP)} engines")
    print(f"[persona-chat] listening on {HOST}:{PORT}")
    yield
    await _client.aclose()


app = FastAPI(
    title="S7 SkyQUBi — Persona Chat",
    version="0.1-substrate",
    description="Covenant-honoring persona chat (Carli/Elias/Samuel). NOT the public demo.",
    lifespan=lifespan,
)


# ── Endpoints ───────────────────────────────────────────────────────

@app.get("/")
async def root():
    return {
        "service": "S7 SkyQUBi Persona Chat",
        "version": "0.1-substrate",
        "personas": sorted(PERSONA_MAP.keys()),
        "engines": sorted(ENGINE_MAP.keys()),
        "port": PORT,
        "cached_l2_walks": len(l2_cache),
        "note": "Standalone substrate. Samuel approval required before systemd landing.",
    }


@app.get("/healthz")
async def healthz():
    # Minimal liveness probe (K8s-style). Does NOT ping Ollama —
    # that's /status. Renamed from /health in B3 of the 24hr ship
    # plan because the /health route is now the covenant-grade
    # Local Health Report GUI surface. /healthz stays available
    # for systemd watchdog / probe consumers that just need
    # "is the process up".
    return {"status": "ok", "personas_loaded": len(PERSONA_MAP)}


@app.get("/status")
async def status():
    """Ping each engine for reachability. Read-only."""
    out: dict = {"engines": {}}
    assert _client is not None
    for name, cfg in ENGINE_MAP.items():
        if not cfg.get("enabled", True):
            out["engines"][name] = {"enabled": False, "reachable": None}
            continue
        url = cfg["url"].rstrip("/") + cfg.get("health_path", "/api/version")
        try:
            r = await _client.get(url, timeout=3.0)
            out["engines"][name] = {
                "enabled": True,
                "reachable": r.status_code == 200,
                "http_status": r.status_code,
            }
        except Exception as e:
            out["engines"][name] = {
                "enabled": True,
                "reachable": False,
                "error": type(e).__name__,
            }
    return out


# ── /digest — household-facing audit projection ──────────────────
# Reads the newest entry from the Living Audit Document and renders
# it via iac/audit/tonya-digest.sh. Single source of truth: the bash
# script is the canonical projection; this route just makes it
# reachable through the trusted local client (Vivaldi → 127.0.0.1).
#
# Read-only. No state change. Safe to call from any household
# surface that the persona-chat user is allowed to reach.
_DIGEST_SCRIPT = "/s7/skyqubi-private/iac/audit/tonya-digest.sh"


@app.get("/digest", response_class=HTMLResponse)
async def digest_html():
    """Household-facing audit digest, HTML form (canonical Tonya palette)."""
    import subprocess
    if not os.path.isfile(_DIGEST_SCRIPT) or not os.access(_DIGEST_SCRIPT, os.X_OK):
        raise HTTPException(status_code=503, detail="audit digest script not available")
    try:
        out = subprocess.run(
            [_DIGEST_SCRIPT, "--html"],
            capture_output=True, text=True, timeout=10, check=False,
        )
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="audit digest timed out")
    if out.returncode != 0:
        raise HTTPException(status_code=500, detail=f"digest script exit {out.returncode}: {out.stderr[:200]}")
    return HTMLResponse(content=out.stdout, status_code=200)


@app.get("/digest.txt", response_class=PlainTextResponse)
async def digest_text():
    """Household-facing audit digest, plain text form (terminal-friendly)."""
    import subprocess
    if not os.path.isfile(_DIGEST_SCRIPT) or not os.access(_DIGEST_SCRIPT, os.X_OK):
        raise HTTPException(status_code=503, detail="audit digest script not available")
    try:
        out = subprocess.run(
            [_DIGEST_SCRIPT],
            capture_output=True, text=True, timeout=10, check=False,
        )
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="audit digest timed out")
    if out.returncode != 0:
        raise HTTPException(status_code=500, detail=f"digest script exit {out.returncode}: {out.stderr[:200]}")
    return PlainTextResponse(content=out.stdout, status_code=200)


# ── Local Health Report endpoints (B3 of the 24hr ship plan) ───────
#
# The Local Health Report is the covenant-grade "is the appliance
# healthy" witness. One JSON source of truth generated by
# iac/audit/local-health-report.sh, served here in three shapes:
#
#   GET /health          — HTML with Tonya's palette, the primary GUI
#   GET /health?format=json  — raw JSON source of truth
#   GET /health.json     — raw JSON (alternate path form)
#
# The route DOES NOT regenerate the report on request — it reads the
# latest snapshot from docs/internal/reports/local-health-latest.json.
# Regeneration happens on three triggers: manual (bash the generator),
# nightly (systemd timer, deferred), or ceremony-gated (pre-advance
# hook, deferred). Serving a stale snapshot is safer than running a
# 30-second generator on every browser refresh.

_HEALTH_JSON = "/s7/skyqubi-private/docs/internal/reports/local-health-latest.json"
_HEALTH_GEN  = "/s7/skyqubi-private/iac/audit/local-health-report.sh"


def _severity_badge(severity: str) -> str:
    """Tonya-palette HTML badge for a severity level."""
    palette = {
        "green":  ("🟢", "#6a8c3c"),  # sandy sunset green
        "yellow": ("🟡", "#c89b3c"),  # sandy sunset amber
        "red":    ("🔴", "#a84632"),  # sandy sunset rust
    }
    icon, color = palette.get(severity, ("⚪", "#888"))
    return f'<span style="color:{color};font-weight:600">{icon} {severity.upper()}</span>'


def _render_health_html(data: dict) -> str:
    """Render the Local Health Report as HTML in the Tonya palette.

    Stand-alone page — no external CSS, no JS, no fonts loaded over
    the network. Cormorant Garamond italic falls back gracefully if
    the local font is not installed. Inline everything.
    """
    import html
    overall = data.get("overall_status", "unknown")
    gen_at = data.get("generated_at", "")
    core = data.get("core_update", "")
    lc = data.get("lifecycle", {})
    ag = data.get("audit_gate", {})
    pod = data.get("pod", {})
    perf = data.get("performance", {})
    findings = data.get("findings", [])

    # Outer overall status banner
    overall_palette = {
        "green":  ("#e8ddc8", "#4a6b2a", "the appliance is healthy"),
        "yellow": ("#f4e4c1", "#7a5a1f", "the household is watching"),
        "red":    ("#f4d0c4", "#6b2418", "attention needed"),
    }
    bg, fg, msg = overall_palette.get(overall, ("#eee", "#333", "status unknown"))

    rows = []
    for f in findings:
        rows.append(
            f"<tr>"
            f"<td>{_severity_badge(f.get('severity', ''))}</td>"
            f"<td><strong>{html.escape(f.get('title', ''))}</strong></td>"
            f"<td>{html.escape(f.get('root_cause', ''))}</td>"
            f"<td><em>{html.escape(f.get('impact', ''))}</em></td>"
            f"<td>{html.escape(f.get('next_step', ''))}</td>"
            f"</tr>"
        )
    findings_rows = "\n".join(rows) if rows else (
        '<tr><td colspan="5" style="text-align:center;padding:1rem;'
        'font-style:italic;color:#6b5a3a">'
        "no findings — the appliance is clean</td></tr>"
    )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>S7 SkyQUBi — Local Health Report</title>
<style>
  :root {{
    --sand: #f4ecd8;
    --sunset: #c89b3c;
    --rust: #a84632;
    --olive: #6a8c3c;
    --twilight: #4a4566;
    --ink: #2b2418;
    --muted: #8b7a5a;
  }}
  body {{
    font-family: 'Cormorant Garamond', Georgia, 'Times New Roman', serif;
    background: linear-gradient(180deg, #f8f0d8 0%, #e8d9b8 100%);
    color: var(--ink);
    max-width: 980px;
    margin: 2rem auto;
    padding: 0 1.5rem 3rem;
    line-height: 1.5;
  }}
  h1 {{
    font-style: italic;
    font-size: 2.4rem;
    font-weight: 500;
    color: var(--twilight);
    border-bottom: 1px solid var(--sunset);
    padding-bottom: 0.4rem;
    margin-top: 0;
  }}
  h2 {{
    font-style: italic;
    font-weight: 500;
    color: var(--twilight);
    margin-top: 2rem;
  }}
  .banner {{
    background: {bg};
    color: {fg};
    padding: 1.2rem 1.5rem;
    border-radius: 6px;
    margin: 1.5rem 0;
    border-left: 4px solid {fg};
  }}
  .banner .status {{
    font-size: 1.8rem;
    font-weight: 600;
    font-style: italic;
    margin-bottom: 0.3rem;
  }}
  .banner .subtitle {{
    font-size: 1.1rem;
  }}
  .metrics {{
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 1rem;
    margin: 1rem 0;
  }}
  .metric {{
    background: rgba(255,255,255,0.5);
    border-left: 3px solid var(--sunset);
    padding: 0.8rem 1rem;
  }}
  .metric .label {{
    font-size: 0.85rem;
    color: var(--muted);
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }}
  .metric .value {{
    font-size: 1.4rem;
    font-weight: 600;
    color: var(--ink);
    margin-top: 0.2rem;
  }}
  table {{
    width: 100%;
    border-collapse: collapse;
    background: rgba(255,255,255,0.4);
    margin: 0.5rem 0;
  }}
  th {{
    text-align: left;
    padding: 0.6rem 0.8rem;
    border-bottom: 1px solid var(--sunset);
    font-weight: 600;
    color: var(--twilight);
  }}
  td {{
    padding: 0.6rem 0.8rem;
    border-bottom: 1px solid rgba(200, 155, 60, 0.2);
    vertical-align: top;
    font-size: 0.95rem;
  }}
  .footer {{
    margin-top: 3rem;
    padding-top: 1rem;
    border-top: 1px solid var(--sunset);
    font-style: italic;
    color: var(--muted);
    font-size: 0.9rem;
  }}
  code {{
    font-family: 'JetBrains Mono', monospace;
    background: rgba(74, 69, 102, 0.08);
    padding: 0.1rem 0.4rem;
    border-radius: 3px;
    font-size: 0.88rem;
  }}
</style>
</head>
<body>

<h1>S7 SkyQUB<em>i</em> — Local Health Report</h1>

<div class="banner">
  <div class="status">{overall.upper()}</div>
  <div class="subtitle">{msg}</div>
</div>

<h2>At a glance</h2>
<div class="metrics">
  <div class="metric">
    <div class="label">Lifecycle</div>
    <div class="value">{lc.get('pass', '?')}/{lc.get('total', '?')}</div>
  </div>
  <div class="metric">
    <div class="label">Audit gate</div>
    <div class="value">{ag.get('pass', '?')} pass · {ag.get('block', '?')} block</div>
  </div>
  <div class="metric">
    <div class="label">Pod</div>
    <div class="value">{'Running' if pod.get('running') else 'Down'}</div>
  </div>
  <div class="metric">
    <div class="label">CWS latency</div>
    <div class="value">{perf.get('cws_latency', '?')}</div>
  </div>
</div>

<h2>Findings</h2>
<table>
  <thead>
    <tr>
      <th>Severity</th>
      <th>Title</th>
      <th>Root cause</th>
      <th>Impact</th>
      <th>Next step</th>
    </tr>
  </thead>
  <tbody>
{findings_rows}
  </tbody>
</table>

<div class="footer">
  Generated <code>{gen_at}</code> · CORE Update <code>{core}</code><br/>
  Source: <code>docs/internal/reports/local-health-latest.json</code> · rendered by <code>persona-chat /health</code><br/>
  <em>Love is the architecture.</em>
</div>

</body>
</html>
"""


@app.get("/health", response_class=HTMLResponse)
async def health_html(request: Request):
    """Local Health Report — primary household-facing GUI.

    Reads the latest JSON snapshot and renders HTML in the Tonya
    palette. If ?format=json is passed, returns the raw JSON body
    instead (convenience for business reviewers).
    """
    import json
    if not os.path.isfile(_HEALTH_JSON):
        raise HTTPException(
            status_code=503,
            detail=(
                "no Local Health Report yet — run "
                f"{_HEALTH_GEN} to generate one"
            ),
        )
    try:
        with open(_HEALTH_JSON, "r") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        raise HTTPException(status_code=500, detail=f"health report unreadable: {e}")

    fmt = request.query_params.get("format", "html")
    if fmt == "json":
        return JSONResponse(content=data)
    return HTMLResponse(content=_render_health_html(data), status_code=200)


@app.get("/health.json", response_class=JSONResponse)
async def health_json():
    """Raw Local Health Report JSON (alternate path form)."""
    import json
    if not os.path.isfile(_HEALTH_JSON):
        raise HTTPException(status_code=503, detail="no Local Health Report yet")
    try:
        with open(_HEALTH_JSON, "r") as f:
            return JSONResponse(content=json.load(f))
    except (OSError, json.JSONDecodeError) as e:
        raise HTTPException(status_code=500, detail=f"health report unreadable: {e}")


@app.post("/persona/chat", response_model=PersonaChatResponse)
async def persona_chat(req: PersonaChatRequest, request: Request):
    """Serve one chat turn through the ledger + memory-tier path.

    Happy path:
      1. Resolve engine from persona_engine_map.yaml
      2. Ensure session dirs exist
      3. Verify the persona's ledger chain (F3: quarantine on tamper)
      4. Walk the memory tier (L1/L2/L3) for prior context
      5. Assemble the prompt
      6. Call the engine (Ollama today)
      7. Append the new row to the ledger (F2: strict — response only
         emits if the row was fsynced)
      8. Return the assistant output + metrics + status badge

    Failure modes per Section 4 of the spec:
      F1 engine unreachable → status="engine_error", HTTP 503
      F2 ledger write fails → status="memory_error", HTTP 507 (strict)
      F3 chain corrupt     → quarantine + HTTP 409 with banner
    """
    # Persona must be in the closed set
    if req.persona not in PERSONA_MAP:
        raise HTTPException(status_code=403, detail=f"persona {req.persona!r} not in closed set")
    if req.tier not in TIER_BUDGETS:
        raise HTTPException(status_code=400, detail=f"unknown tier {req.tier!r}")

    # ── Samuel skill-runner short-circuit ───────────────────────────
    # If the persona is Samuel AND the user's message matches a skill
    # catalog intent, run the skill instead of generating via LLM.
    # Samuel then 'speaks' the skill result in his own voice via
    # SkillResult.as_samuel_reply(). This is the 'waiter walks to the
    # kitchen' interaction — the operator tooling becomes useful to
    # users indirectly, through Samuel.
    # Carli/Elias soft-redirect: if a non-Samuel persona gets an
    # operator-shaped question, don't hallucinate an answer — point
    # the user to Samuel. No subprocess, no LLM round-trip, no ledger
    # row (this is a routing hint, not an action).
    if req.persona in ("carli", "elias"):
        skill_id_hint, _ = match_intent(req.message)
        if skill_id_hint:
            redirect_text = (
                f"That sounds like a Samuel question — he's the FACTS persona "
                f"and the only one who can run operator skills like '{skill_id_hint}'. "
                f"Switch to Samuel and ask him."
            )
            # Write a ledger row so we can see how often Carli/Elias get
            # operator questions (signals demand for the Samuel surface).
            ensure_session_dirs(req.user_id, req.session_id)
            ledger_path = persona_ledger_path(req.user_id, req.session_id, req.persona)
            try:
                append_row(
                    path=ledger_path,
                    session_id=req.session_id,
                    user_id=req.user_id,
                    persona=req.persona,
                    engine="redirect",
                    model=f"redirect:samuel:{skill_id_hint}",
                    tier=req.tier,
                    user_input=req.message,
                    assistant_output=redirect_text,
                    qbit_count={
                        "in": count_qbits(req.message),
                        "out": count_qbits(redirect_text),
                        "total": count_qbits(req.message) + count_qbits(redirect_text),
                    },
                    latency_ms=0,
                    qps=0.0,
                    fallback=None,
                    status="redirected",
                )
            except OSError:
                pass  # observability is best-effort; never fail a redirect
            return PersonaChatResponse(
                persona=req.persona,
                engine="redirect",
                model="redirect:samuel",
                tier=req.tier,
                response=redirect_text,
                qbit_count={
                    "in": count_qbits(req.message),
                    "out": count_qbits(redirect_text),
                    "total": count_qbits(req.message) + count_qbits(redirect_text),
                },
                qps=0.0,
                latency_ms=0,
                status="ok",
                fallback=None,
                badge=f"{req.persona.title()} — redirected to Samuel",
                skill_invoked={
                    "skill_id": skill_id_hint,
                    "mode": "redirect",
                    "exit_code": None,
                    "state": "redirected",
                    "blocked_reason": f"persona {req.persona} is not Samuel",
                },
            )

    if req.persona == "samuel":
        # match_intent is pure — it doesn't know about confirmation
        # phrases ('yes'/'no'). Those are handled inside run_skill via
        # the session ledger lookup. So we trigger the skill-runner
        # branch when EITHER (a) match_intent finds a skill, OR (b)
        # the message is a bare confirmation that might bind to a
        # pending suggestion. Without (b), 'yes' falls through to the
        # LLM and looks like a fresh chat turn.
        skill_id_hint, _mode_hint = match_intent(req.message)
        is_confirmation = normalize_confirmation(req.message) is not None
        is_negative = normalize_negative_confirmation(req.message) is not None
        if skill_id_hint or is_confirmation or is_negative:
            skill_result = run_skill(
                user_message=req.message,
                persona=req.persona,
                user_id=req.user_id,
                session_id=req.session_id,
            )
            if skill_result.matched:
                # Short-circuit: return the skill result as Samuel's reply.
                # Still writes a ledger row so the chat has an audit trail
                # of what Samuel did on the user's behalf.
                ensure_session_dirs(req.user_id, req.session_id)
                ledger_path = persona_ledger_path(req.user_id, req.session_id, req.persona)
                reply_text = skill_result.as_samuel_reply()
                try:
                    append_row(
                        path=ledger_path,
                        session_id=req.session_id,
                        user_id=req.user_id,
                        persona=req.persona,
                        engine="skill-runner",
                        model=f"skill:{skill_result.skill_id}",
                        tier=req.tier,
                        user_input=req.message,
                        assistant_output=reply_text,
                        qbit_count={
                            "in": count_qbits(req.message),
                            "out": count_qbits(reply_text),
                            "total": count_qbits(req.message) + count_qbits(reply_text),
                        },
                        latency_ms=skill_result.elapsed_ms,
                        qps=0.0,
                        fallback=None,
                        status="ok",
                    )
                except OSError as e:
                    raise HTTPException(
                        status_code=507,
                        detail={
                            "error": "memory_error",
                            "detail": type(e).__name__,
                            "badge": f"{req.persona.title()} — memory error, turn not completed",
                        },
                    )
                l2_cache.invalidate_session(req.user_id, req.session_id)
                return PersonaChatResponse(
                    persona=req.persona,
                    engine="skill-runner",
                    model=f"skill:{skill_result.skill_id}",
                    tier=req.tier,
                    response=reply_text,
                    qbit_count={
                        "in": count_qbits(req.message),
                        "out": count_qbits(reply_text),
                        "total": count_qbits(req.message) + count_qbits(reply_text),
                    },
                    qps=0.0,
                    latency_ms=skill_result.elapsed_ms,
                    status="ok",
                    fallback=None,
                    badge=f"{req.persona.title()} — skill ran ({skill_result.skill_id})",
                    skill_invoked={
                        "skill_id": skill_result.skill_id,
                        "mode": skill_result.mode,
                        "exit_code": skill_result.exit_code,
                        "state": skill_result.state,
                        "blocked_reason": skill_result.blocked_reason,
                    },
                )
        # If no skill matched, fall through to normal LLM chat below.

    persona_cfg = PERSONA_MAP[req.persona]
    primary = persona_cfg.get("primary", {})
    engine_name = primary.get("engine", "ollama")
    model = primary.get("model", "s7-carli:0.6b")
    num_predict = persona_cfg.get("num_predict", 512)
    temperature = persona_cfg.get("temperature", 0.7)
    think = persona_cfg.get("think", False)

    engine_cfg = ENGINE_MAP.get(engine_name)
    if not engine_cfg:
        raise HTTPException(status_code=500, detail=f"engine {engine_name!r} not configured")

    ensure_session_dirs(req.user_id, req.session_id)
    ledger_path = persona_ledger_path(req.user_id, req.session_id, req.persona)

    # F3 — verify chain integrity before touching it
    if ledger_path.exists():
        try:
            ok, err = verify_chain(ledger_path)
        except LedgerCorruptError as e:
            ok, err = False, str(e)
        if not ok:
            q_path = quarantine(req.user_id, req.session_id, req.persona, f"verify_chain: {err}")
            raise HTTPException(
                status_code=409,
                detail={
                    "error": "memory_integrity_issue",
                    "reason": err,
                    "quarantined_to": str(q_path),
                    "banner": f"{req.persona.title()} — memory integrity issue, covenant review required",
                },
            )

    # Walk the memory tier. L2 uses cache; L1 does not.
    cache_key = (req.user_id, req.session_id, req.persona, req.tier)
    walk: Optional[TierWalk] = None
    if req.tier == "L2":
        walk = l2_cache.get(cache_key)
    if walk is None:
        walk = walk_tier(
            user_id=req.user_id,
            session_id=req.session_id,
            persona=req.persona,
            tier=req.tier,
            fortoken=req.fortoken,
            cross_persona=req.cross_persona,
        )
        if req.tier == "L2":
            l2_cache.put(cache_key, walk)

    # Assemble prompt. System prompt from persona config, or a default.
    system_prompt = persona_cfg.get("system_prompt", f"You are {persona_cfg.get('display_name', req.persona)}.")
    assembled = assemble_prompt(
        system_prompt=system_prompt,
        walk=walk,
        new_user_input=req.message,
    )

    # Call Ollama
    t0 = time.monotonic()
    try:
        raw = await call_ollama(
            engine=engine_cfg,
            model=model,
            prompt=assembled,
            num_predict=num_predict,
            temperature=temperature,
            think=think,
        )
    except httpx.TimeoutException:
        # F1 — engine unreachable, write failure row, return 503
        _append_error_row(req, "engine_timeout", engine_name, model)
        raise HTTPException(
            status_code=503,
            detail={"error": "engine_timeout", "badge": f"{req.persona.title()} — offline, retrying"},
        )
    except httpx.HTTPError as e:
        _append_error_row(req, f"engine_http_{type(e).__name__}", engine_name, model)
        raise HTTPException(
            status_code=503,
            detail={"error": "engine_error", "detail": type(e).__name__, "badge": f"{req.persona.title()} — unavailable"},
        )

    latency_ms = int((time.monotonic() - t0) * 1000)
    assistant_output = raw.get("response", "").strip()

    # Ollama's own eval metrics → QBIT vocab at the boundary
    eval_count = int(raw.get("eval_count", 0))
    eval_duration_ns = int(raw.get("eval_duration", 0))
    prompt_eval_count = int(raw.get("prompt_eval_count", 0))

    in_qbits = ollama_tokens_to_qbits(prompt_eval_count)
    out_qbits = ollama_tokens_to_qbits(eval_count)
    qps = qps_from_ollama(eval_count, eval_duration_ns)
    qbit_count = {"in": in_qbits, "out": out_qbits, "total": in_qbits + out_qbits}

    # F2 — strict append. If this raises, the response does NOT reach
    # the caller: we return 507 instead.
    try:
        append_row(
            path=ledger_path,
            session_id=req.session_id,
            user_id=req.user_id,
            persona=req.persona,
            engine=engine_name,
            model=model,
            tier=req.tier,
            user_input=req.message,
            assistant_output=assistant_output,
            qbit_count=qbit_count,
            latency_ms=latency_ms,
            qps=qps,
            fortoken_used=req.fortoken,
        )
    except OSError as e:
        raise HTTPException(
            status_code=507,  # Insufficient Storage
            detail={
                "error": "memory_error",
                "detail": type(e).__name__,
                "badge": f"{req.persona.title()} — memory error, turn not completed",
            },
        )

    # New row invalidates the L2 cache for this session
    l2_cache.invalidate_session(req.user_id, req.session_id)

    return PersonaChatResponse(
        persona=req.persona,
        engine=engine_name,
        model=model,
        tier=req.tier,
        response=assistant_output,
        qbit_count=qbit_count,
        qps=round(qps, 2),
        latency_ms=latency_ms,
        status="ok",
        fallback=None,
        badge=_status_badge(req.persona, engine_name, req.tier, ok=True),
    )


def _append_error_row(req: PersonaChatRequest, error_kind: str, engine_name: str, model: str) -> None:
    """Write a failure row to the ledger so the turn is still recorded.

    F1 says engine failures are recorded events, not gaps. This MUST
    succeed even if the primary operation failed. If it can't, we
    swallow the OSError here because the surrounding HTTPException is
    already about engine failure — we don't want to double-raise.
    """
    try:
        append_row(
            path=persona_ledger_path(req.user_id, req.session_id, req.persona),
            session_id=req.session_id,
            user_id=req.user_id,
            persona=req.persona,
            engine=engine_name,
            model=model,
            tier=req.tier,
            user_input=req.message,
            assistant_output="",
            qbit_count={"in": count_qbits(req.message), "out": 0, "total": count_qbits(req.message)},
            latency_ms=0,
            qps=0.0,
            status=error_kind,
        )
    except OSError:
        pass  # last-resort — surface the engine error, accept ledger loss for this error row only


def _status_badge(persona: str, engine: str, tier: str, *, ok: bool) -> str:
    """Produce the user-visible badge string. Follows Section 4 of the spec."""
    name = persona.title()
    if not ok:
        return f"{name} — degraded"
    if engine == "bitnet":
        return f"{name} — fast (1-bit, {tier})"
    return f"{name} — standard ({tier})"


@app.post("/persona/skill", response_model=PersonaSkillResponse)
async def persona_skill(req: PersonaSkillRequest, request: Request):
    """Direct skill invocation — bypasses LLM chat entirely.

    Use this when you explicitly want to run an operator skill on
    the user's behalf without the context-assembly + LLM-generation
    overhead. Samuel's voice still wraps the result (via
    SkillResult.as_samuel_reply()).

    Only persona='samuel' is allowed to invoke skills. Other personas
    get a 403 with an explanation.
    """
    if req.persona not in PERSONA_MAP:
        raise HTTPException(status_code=403, detail=f"persona {req.persona!r} not in closed set")
    if req.persona != "samuel":
        raise HTTPException(
            status_code=403,
            detail=f"Only Samuel may invoke skills. {req.persona.title()} can't run operator commands.",
        )

    result = run_skill(
        user_message=req.message,
        persona=req.persona,
        user_id=req.user_id,
        session_id=req.session_id,
    )

    return PersonaSkillResponse(
        matched=result.matched,
        skill_id=result.skill_id,
        mode=result.mode,
        attempted=result.attempted,
        exit_code=result.exit_code,
        state=result.state,
        summary=result.summary,
        samuel_reply=result.as_samuel_reply(),
        elapsed_ms=result.elapsed_ms,
        blocked_reason=result.blocked_reason,
    )


# ── Main ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    print(f"S7 SkyQUBi Persona Chat v0.1-substrate")
    print(f"  Host:     {HOST}")
    print(f"  Port:     {PORT}")
    print(f"  Config:   {CONFIG_PATH}")
    print(f"  Ledger:   {os.environ.get('S7_LEDGER_ROOT', '/s7/.s7-chat-sessions')}")
    print("Standalone service. NOT wired to systemd. Samuel approval required before landing.")
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")
