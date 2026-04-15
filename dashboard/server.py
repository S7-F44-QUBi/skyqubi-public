#!/usr/bin/env python3
"""
SkyQUBi Command Center — Minimal Dashboard Server
UNIFIED LINUX SkyCAIR by S7 · BSL-1.1 · 123Tech / 2XR, LLC

No NPM. No Node. Pure Python + Flask.
Serves dashboard on :7080 and health/status API.
"""

import json
import os
import subprocess
import time
from flask import Flask, jsonify, Response

app = Flask(__name__)

SERVICES = {
    "s7-postgres":   {"port": 57090, "check": "pg_isready -h localhost -p 57090 -q"},
    "s7-ollama":     {"port": 57081, "check": "curl -sf http://localhost:57081/api/tags"},
    "s7-bitnet":     {"port": 57091, "check": "curl -sf http://localhost:57091/health"},
    "s7-mempalace":  {"port": 57092, "check": "test -d /s7/s7-timecapsule-assets/mempalace"},
    "s7-qdrant":     {"port": 57086, "check": "curl -sf http://localhost:57086"},
    "s7-dashboard":  {"port": 57080, "check": "true"},
}


def check_service(name, svc):
    try:
        result = subprocess.run(
            svc["check"], shell=True, capture_output=True, timeout=5
        )
        return result.returncode == 0
    except Exception:
        return False


@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "s7-skyqubi-dashboard", "version": "2.3", "brand": "S7 SkyCAIR", "vendor": "2XR LLC"})


@app.route("/api/status")
def status():
    services = {}
    for name, svc in SERVICES.items():
        services[name] = {
            "port": svc["port"],
            "healthy": check_service(name, svc),
        }

    healthy_count = sum(1 for s in services.values() if s["healthy"])

    return jsonify({
        "brand": "S7 SkyCAIR — UNIFIED LINUX SkyCAIR by S7",
        "version": "2.3",
        "covenant": "INSERT-only · ForToken/RevToken · 70% babel",
        "services": services,
        "healthy": healthy_count,
        "total": len(services),
        "mcp_tools": 44,
        "witnesses": 7,
        "schemas": 6,
        "pulse": int(time.time()) % 2,  # 01010
    })


@app.route("/api/engines")
def engines():
    """Which inference engines are available and what models are loaded."""
    engines = {}

    # Ollama
    try:
        result = subprocess.run(
            "curl -sf http://localhost:7081/api/tags",
            shell=True, capture_output=True, timeout=5, text=True
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            engines["ollama"] = {
                "port": 7081,
                "status": "running",
                "path": "standard",
                "models": [m["name"] for m in data.get("models", [])],
            }
        else:
            engines["ollama"] = {"port": 7081, "status": "down", "models": []}
    except Exception:
        engines["ollama"] = {"port": 7081, "status": "error", "models": []}

    # BitNet
    bitnet_model = "/s7/s7-timecapsule-assets/models/bitnet/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf"
    engines["bitnet"] = {
        "port": 7091,
        "status": "ready" if os.path.exists(bitnet_model) else "no_model",
        "path": "ternary",
        "models": ["BitNet-b1.58-2B-4T"] if os.path.exists(bitnet_model) else [],
        "weight_type": "1.58bit",
        "memory_mb": 400 if os.path.exists(bitnet_model) else 0,
    }

    return jsonify(engines)


@app.route("/api/cws")
def cws_status():
    """CWS schema status from PostgreSQL."""
    try:
        result = subprocess.run(
            'psql -h localhost -p 7090 -d postgres -tAc '
            '"SELECT COUNT(*) FROM information_schema.tables '
            "WHERE table_schema LIKE 'cws_%'\"",
            shell=True, capture_output=True, timeout=5, text=True
        )
        table_count = int(result.stdout.strip()) if result.returncode == 0 else 0

        schema_result = subprocess.run(
            'psql -h localhost -p 7090 -d postgres -tAc '
            '"SELECT string_agg(schema_name, \',\') FROM information_schema.schemata '
            "WHERE schema_name LIKE 'cws_%'\"",
            shell=True, capture_output=True, timeout=5, text=True
        )
        schemas = schema_result.stdout.strip().split(",") if schema_result.returncode == 0 else []

        return jsonify({
            "version": "2.3",
            "schemas": schemas,
            "schema_count": len(schemas),
            "table_count": table_count,
            "covenant": "INSERT-only",
            "status": "ready" if table_count > 0 else "empty",
        })
    except Exception as e:
        return jsonify({"status": "error", "detail": str(e)})


@app.route("/api/palace")
def palace_status():
    """MemPalace status."""
    palace_path = "/s7/s7-timecapsule-assets/mempalace/palace"
    exists = os.path.isdir(palace_path)
    return jsonify({
        "status": "ready" if exists else "not_initialized",
        "path": palace_path,
        "mcp_tools": 19,
    })


@app.route("/api/routing")
def routing():
    """Current routing configuration."""
    return jsonify({
        "paths": {
            "standard": {"engine": "ollama", "port": 7081, "weights": "GGUF 4-8 bit"},
            "ternary":  {"engine": "bitnet.cpp", "port": 7091, "weights": "1.58-bit native"},
            "dual":     {"engines": ["ollama", "bitnet.cpp"], "note": "Both paths, CWS compares"},
        },
        "rules": [
            {"name": "consensus_dual", "priority": 5, "route": "dual"},
            {"name": "small_model_ternary", "priority": 10, "route": "ternary", "max_params": "4B"},
            {"name": "code_standard", "priority": 15, "route": "standard", "task": "code"},
            {"name": "qa_ternary", "priority": 15, "route": "ternary", "task": "qa"},
        ],
    })


DASHBOARD_HTML = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>S7 SkyQUBi — Command Center</title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><text y='24' font-size='24'>⬡</text></svg>">
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #060c18; color: #e2e8f0; font-family: 'JetBrains Mono', 'SF Mono', 'Share Tech Mono', monospace; padding: 20px; }
.header { text-align: center; padding: 20px 0; border-bottom: 2px solid #1a2d48; margin-bottom: 20px; }
.brand { font-size: 14px; color: #4A90E2; letter-spacing: 0.2em; }
.title { font-size: 24px; font-weight: 800; }
.title .sky { color: #4A90E2; }
.title .s7 { color: #C48B30; }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 12px; }
.card { background: #0f1a2e; border: 1px solid #1a2d48; border-radius: 8px; padding: 14px; }
.card-title { font-size: 10px; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 0.1em; margin-bottom: 8px; }
.svc { display: flex; justify-content: space-between; align-items: center; padding: 4px 0; border-bottom: 1px solid #1e293b22; }
.dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; margin-right: 6px; }
.dot.on { background: #22c55e; box-shadow: 0 0 6px #22c55e66; }
.dot.off { background: #ef4444; }
.port { font-size: 11px; color: #4A90E2; }
.stat { text-align: center; padding: 8px; background: #1a2236; border-radius: 6px; }
.stat-val { font-size: 22px; font-weight: 700; }
.stat-label { font-size: 9px; color: #64748b; }
.badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: 700; }
.footer { text-align: center; margin-top: 20px; font-size: 9px; color: #475569; }
#status-data { white-space: pre; font-size: 11px; color: #94a3b8; }
</style>
</head>
<body>
<div class="header">
  <div class="brand">S7 · UNIFIED LINUX</div>
  <div class="title"><span class="sky">Sky</span><span style="color:#3AAFBF">CAIR</span> by <span class="s7">S7</span></div>
  <div style="font-size:11px; color:#4A90E2; margin-top:4px;">S7 SkyQUBi Command Center · CWS v2.3 · Pulse: <span id="pulse" style="color:#C48B30">0</span></div>
  <div style="font-size:9px; color:#8B6BAE; margin-top:2px;">-1 ROCK · 0 DOOR · +1 REST</div>
</div>

<div class="grid">
  <div class="card" id="services-card">
    <div class="card-title">Services</div>
    <div id="services">Loading...</div>
  </div>

  <div class="card">
    <div class="card-title">Stack Summary</div>
    <div style="display:grid; grid-template-columns:1fr 1fr 1fr; gap:8px;">
      <div class="stat"><div class="stat-val" style="color:#eab308;" id="schema-count">-</div><div class="stat-label">SCHEMAS</div></div>
      <div class="stat"><div class="stat-val" style="color:#a855f7;" id="mcp-count">-</div><div class="stat-label">MCP TOOLS</div></div>
      <div class="stat"><div class="stat-val" style="color:#22c55e;" id="witness-count">-</div><div class="stat-label">WITNESSES</div></div>
    </div>
  </div>

  <div class="card">
    <div class="card-title">Inference Paths</div>
    <div id="engines">Loading...</div>
  </div>

  <div class="card">
    <div class="card-title">CWS Schema</div>
    <div id="cws-info">Loading...</div>
  </div>
</div>

<div class="footer">
  <span style="color:#4A90E2">S7</span> · <span style="color:#C48B30">BSL-1.1</span> · 123Tech.net · Evolve2Linux.com · SkyNetSSL (Safe Secure Linux) · 2XR, LLC<br>
  <span style="color:#3AAFBF">Love is the architecture.</span> · <span style="color:#8B6BAE">Let the world test and develop.</span> · INSERT-only covenant
</div>

<script>
async function refresh() {
  try {
    const res = await fetch('/api/status');
    const d = await res.json();
    document.getElementById('pulse').textContent = d.pulse;
    document.getElementById('schema-count').textContent = d.schemas;
    document.getElementById('mcp-count').textContent = d.mcp_tools;
    document.getElementById('witness-count').textContent = d.witnesses;

    let html = '';
    for (const [name, svc] of Object.entries(d.services)) {
      html += '<div class="svc">' +
        '<span><span class="dot ' + (svc.healthy ? 'on' : 'off') + '"></span>' + name + '</span>' +
        '<span class="port">:' + svc.port + '</span></div>';
    }
    document.getElementById('services').innerHTML = html;
  } catch(e) { console.error(e); }

  try {
    const res2 = await fetch('/api/engines');
    const eng = await res2.json();
    let html = '';
    for (const [name, e] of Object.entries(eng)) {
      html += '<div class="svc"><span>' + name + ' <span class="badge" style="background:' +
        (e.status === 'running' || e.status === 'ready' ? '#22c55e22;color:#22c55e' : '#ef444422;color:#ef4444') +
        '">' + e.status + '</span></span><span class="port">:' + e.port + '</span></div>';
      if (e.models && e.models.length > 0) {
        html += '<div style="font-size:10px;color:#64748b;padding-left:14px;">' + e.models.join(', ') + '</div>';
      }
    }
    document.getElementById('engines').innerHTML = html;
  } catch(e) {}

  try {
    const res3 = await fetch('/api/cws');
    const cws = await res3.json();
    document.getElementById('cws-info').innerHTML =
      '<div style="font-size:12px;">v' + cws.version + ' · ' + cws.table_count + ' tables</div>' +
      '<div style="font-size:10px;color:#64748b;margin-top:4px;">' + (cws.schemas||[]).join(', ') + '</div>' +
      '<div style="font-size:10px;color:#eab308;margin-top:4px;">Covenant: ' + cws.covenant + '</div>';
  } catch(e) {}
}

refresh();
setInterval(refresh, 5000);
</script>
</body>
</html>"""


@app.route("/")
def index():
    return Response(DASHBOARD_HTML, mimetype="text/html")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=7080, debug=False)
