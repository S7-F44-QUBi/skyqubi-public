#!/usr/bin/env python3
"""
S7 SkyQUBi BitNet MCP Wrapper
Exposes bitnet.cpp ternary inference as S7 MCP-compatible HTTP tools.

S7 · UNIFIED LINUX SkyCAIR by S7 · BSL-1.1 · 123Tech / 2XR, LLC

5 S7 tools:
  s7_bitnet_infer     — Run ternary inference
  s7_bitnet_status    — Engine health check
  s7_bitnet_models    — List loaded ternary models
  s7_bitnet_benchmark — Run S7 QUANTi comparison
  s7_bitnet_energy    — Energy consumption report

Runs on :57091 · Love is the architecture.
"""

import json
import logging
import os
import subprocess
import time
from flask import Flask, request, jsonify

app = Flask(__name__)
log = logging.getLogger("bitnet_mcp")

BITNET_MODELS_DIR = os.environ.get("BITNET_MODELS", "/s7/s7-timecapsule-assets/models/bitnet")
DEFAULT_MODEL = "BitNet-b1.58-2B-4T"
DEFAULT_GGUF = f"{BITNET_MODELS_DIR}/{DEFAULT_MODEL}/ggml-model-i2_s.gguf"

# Ollama URL — reads s7-ports.env convention, falls back to canonical 57081.
# Closes airgap gap identified in TOOLS_MANIFEST.yaml v5 ledger.
S7_OLLAMA_URL = os.environ.get("S7_OLLAMA_URL", "http://127.0.0.1:57081")

# Whitelist of model files allowed to be loaded — anything else is rejected.
# Computed at request time so newly added GGUFs are picked up without restart.
def allowed_model_paths() -> set[str]:
    if not os.path.isdir(BITNET_MODELS_DIR):
        return {DEFAULT_GGUF}
    paths = {DEFAULT_GGUF}
    for root, _, files in os.walk(BITNET_MODELS_DIR):
        for f in files:
            if f.endswith(".gguf"):
                paths.add(os.path.realpath(os.path.join(root, f)))
    return paths

# Track energy/performance metrics (INSERT-only in memory, flush to CWS)
inference_log = []


def find_bitnet_binary():
    """Find bitnet inference binary."""
    for name in ["bitnet-cli", "main", "llama-cli"]:
        path = f"/usr/local/bin/{name}"
        if os.path.exists(path):
            return path
    return None


def model_available():
    """Check if default model is downloaded."""
    return os.path.exists(DEFAULT_GGUF)


@app.route("/health")
def health():
    return jsonify({
        "status": "ok",
        "service": "bitnet-mcp",
        "model_available": model_available(),
        "binary": find_bitnet_binary() is not None,
    })


@app.route("/tools")
def tools():
    """List available MCP tools."""
    return jsonify({
        "brand": "S7 SkyCAIR",
        "tools": [
            {"name": "s7_bitnet_infer", "description": "S7 ternary inference on a prompt"},
            {"name": "s7_bitnet_status", "description": "S7 engine health and model status"},
            {"name": "s7_bitnet_models", "description": "S7 available ternary models"},
            {"name": "s7_bitnet_benchmark", "description": "S7 QUANTi comparison"},
            {"name": "s7_bitnet_energy", "description": "S7 energy consumption metrics"},
        ]
    })


@app.route("/api/infer", methods=["POST"])
def infer():
    """Run ternary inference."""
    data = request.get_json() or {}
    prompt = data.get("prompt", "")
    max_tokens = data.get("max_tokens", 128)
    requested_model = data.get("model", DEFAULT_GGUF)

    if not prompt:
        return jsonify({"error": "prompt required"}), 400

    # Resolve and validate the model path against the whitelist of GGUF files
    # actually present under BITNET_MODELS_DIR. Prevents path traversal /
    # arbitrary file read via the user-supplied "model" field.
    try:
        candidate = os.path.realpath(requested_model)
    except (TypeError, ValueError):
        return jsonify({"error": "invalid model path"}), 400
    if candidate not in allowed_model_paths():
        return jsonify({"error": "model not in whitelist"}), 403
    model_path = candidate

    binary = find_bitnet_binary()
    if not binary:
        return jsonify({"error": "bitnet binary not found"}), 500

    if not os.path.exists(model_path):
        return jsonify({"error": "model not found"}), 404

    start_time = time.time()

    try:
        result = subprocess.run(
            [binary, "-m", model_path, "-p", prompt, "-n", str(max_tokens)],
            capture_output=True, text=True, timeout=120
        )
        elapsed_ms = int((time.time() - start_time) * 1000)
        output = result.stdout.strip()

        # Estimate metrics
        token_count = len(output.split())
        tokens_per_sec = token_count / max(elapsed_ms / 1000, 0.001)
        energy_j = 0.028 * token_count  # estimated from BitNet paper

        entry = {
            "prompt": prompt[:100],
            "tokens": token_count,
            "latency_ms": elapsed_ms,
            "tokens_per_sec": round(tokens_per_sec, 1),
            "energy_j": round(energy_j, 4),
            "timestamp": time.time(),
        }
        inference_log.append(entry)

        return jsonify({
            "output": output,
            "model": DEFAULT_MODEL,
            "weight_type": "1.58bit",
            "engine": "bitnet.cpp",
            "tokens": token_count,
            "latency_ms": elapsed_ms,
            "tokens_per_sec": round(tokens_per_sec, 1),
            "energy_j": round(energy_j, 4),
            "memory_mb": 400,
        })

    except subprocess.TimeoutExpired:
        return jsonify({"error": "inference timeout (120s)"}), 504
    except Exception:
        log.exception("bitnet inference failed")
        return jsonify({"error": "inference failed"}), 500


@app.route("/api/status")
def status():
    """Engine status."""
    return jsonify({
        "engine": "bitnet.cpp",
        "port": 57091,
        "binary": find_bitnet_binary(),
        "binary_found": find_bitnet_binary() is not None,
        "model_available": model_available(),
        "model_path": DEFAULT_GGUF,
        "model_name": DEFAULT_MODEL,
        "weight_type": "1.58bit",
        "memory_mb": 400 if model_available() else 0,
        "inference_count": len(inference_log),
    })


@app.route("/api/models")
def models():
    """List available ternary models."""
    found = []
    if os.path.isdir(BITNET_MODELS_DIR):
        for entry in os.listdir(BITNET_MODELS_DIR):
            model_dir = os.path.join(BITNET_MODELS_DIR, entry)
            if os.path.isdir(model_dir):
                gguf_files = [f for f in os.listdir(model_dir) if f.endswith(".gguf")]
                for g in gguf_files:
                    full_path = os.path.join(model_dir, g)
                    size_mb = os.path.getsize(full_path) // (1024 * 1024)
                    found.append({
                        "name": entry,
                        "file": g,
                        "path": full_path,
                        "size_mb": size_mb,
                        "weight_type": "1.58bit",
                    })
    return jsonify({"models": found, "models_dir": BITNET_MODELS_DIR})


@app.route("/api/energy")
def energy():
    """Energy consumption report from inference log."""
    if not inference_log:
        return jsonify({"message": "No inference data yet", "total_inferences": 0})

    total_energy = sum(e["energy_j"] for e in inference_log)
    total_tokens = sum(e["tokens"] for e in inference_log)
    avg_latency = sum(e["latency_ms"] for e in inference_log) / len(inference_log)

    return jsonify({
        "total_inferences": len(inference_log),
        "total_tokens": total_tokens,
        "total_energy_j": round(total_energy, 4),
        "avg_energy_per_token_j": round(total_energy / max(total_tokens, 1), 6),
        "avg_latency_ms": round(avg_latency, 0),
        "comparison": {
            "bitnet_j_per_token": 0.028,
            "standard_j_per_token": 0.156,
            "savings_pct": "82.1%",
        }
    })


@app.route("/api/benchmark", methods=["POST"])
def benchmark():
    """Run QUANTi comparison: same prompt through ternary + Ollama."""
    data = request.get_json() or {}
    prompt = data.get("prompt", "What is the meaning of convergence?")

    results = {"prompt": prompt}

    # Ternary path
    if model_available() and find_bitnet_binary():
        try:
            start = time.time()
            r = subprocess.run(
                [find_bitnet_binary(), "-m", DEFAULT_GGUF, "-p", prompt, "-n", "64"],
                capture_output=True, text=True, timeout=60
            )
            results["ternary"] = {
                "output": r.stdout.strip()[:500],
                "latency_ms": int((time.time() - start) * 1000),
                "engine": "bitnet.cpp",
            }
        except Exception as e:
            results["ternary"] = {"error": str(e)}
    else:
        results["ternary"] = {"error": "model or binary not available"}

    # Standard path (via Ollama)
    try:
        start = time.time()
        r = subprocess.run(
            ["curl", "-sf", "-X", "POST", f"{S7_OLLAMA_URL}/api/generate",
             "-d", json.dumps({"model": "llama3.2:1b", "prompt": prompt, "stream": False})],
            capture_output=True, text=True, timeout=60
        )
        if r.returncode == 0:
            resp = json.loads(r.stdout)
            results["standard"] = {
                "output": resp.get("response", "")[:500],
                "latency_ms": int((time.time() - start) * 1000),
                "engine": "ollama",
            }
        else:
            results["standard"] = {"error": "ollama request failed"}
    except Exception as e:
        results["standard"] = {"error": str(e)}

    return jsonify(results)


if __name__ == "__main__":
    print("S7 SkyQUBi BitNet MCP starting on :57091 · Love is the architecture.")
    app.run(host="127.0.0.1", port=57091, debug=False)
