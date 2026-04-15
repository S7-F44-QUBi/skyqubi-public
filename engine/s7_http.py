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
import os
import httpx

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://127.0.0.1:57081")
BITNET_URL = os.getenv("BITNET_URL", "http://127.0.0.1:57091")
MEMPALACE_URL = os.getenv("MEMPALACE_URL", "http://127.0.0.1:57092")
QDRANT_URL = os.getenv("QDRANT_URL", "http://127.0.0.1:6333")

_client = None

def get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(timeout=60.0)
    return _client

async def close_client():
    global _client
    if _client:
        await _client.aclose()
        _client = None

async def ollama_generate(prompt: str, model: str = "llama3.2:1b",
                          num_predict: int = 256) -> dict:
    client = get_client()
    resp = await client.post(f"{OLLAMA_URL}/api/generate", json={
        "model": model, "prompt": prompt, "stream": False,
        "options": {"num_predict": num_predict},
    })
    resp.raise_for_status()
    return resp.json()

async def bitnet_infer(prompt: str) -> dict:
    client = get_client()
    resp = await client.post(f"{BITNET_URL}/infer", json={"prompt": prompt, "max_tokens": 256})
    resp.raise_for_status()
    return resp.json()

async def mempalace_search(query: str, limit: int = 5) -> list[dict]:
    """Recall relevant memories from S7 MemPalace."""
    client = get_client()
    try:
        resp = await client.post(f"{MEMPALACE_URL}/search", json={"query": query, "limit": limit})
        resp.raise_for_status()
        return resp.json().get("results", [])
    except Exception:
        return []


async def mempalace_add_drawer(wing: str, hall: str, room: str, label: str, content: str) -> dict:
    client = get_client()
    resp = await client.post(f"{MEMPALACE_URL}/add_drawer", json={"wing": wing, "hall": hall, "room": room, "label": label, "content": content})
    resp.raise_for_status()
    return resp.json()
