#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Consensus Module
#
# Real multi-model consensus, not persona wrappers.
#
# This module queries multiple architecturally-diverse models
# (different families, not just different system prompts) and
# computes a genuine agreement score across their responses.
#
# Used by app.py for the /witness and /consensus endpoints.
#
# What this IS:
#   - Real queries to 3+ different base models in parallel
#   - Token-level overlap scoring (Jaccard similarity)
#   - FERTILE / AMBIGUOUS / BABEL classification
#   - Honest reporting of per-model answers
#
# What this is NOT:
#   - The full CWS Engine consensus (that uses molecular bonds + prism)
#   - Sentience detection (there is none; these are language models)
#   - Truth detection (only agreement detection)
# ═══════════════════════════════════════════════════════════════════

import asyncio
import math
import re
import time
from dataclasses import dataclass, field
from typing import Optional

import httpx

# Embedding model for semantic similarity (not token overlap).
# Real CWS uses embeddings because "Hello!" and "Hi there" are semantically
# identical but share zero tokens.
EMBEDDING_MODEL = "all-minilm:latest"
USE_EMBEDDINGS = True  # set False to fall back to Jaccard token overlap

# ── The witness set: architecturally diverse base models ──────
# These are chosen because they come from DIFFERENT model families,
# trained on DIFFERENT data, with DIFFERENT tokenizers. Agreement
# across these is meaningful. Agreement between two wrappers of the
# same weights is not.
WITNESS_MODELS = [
    # (model_name, family, role_hint, approx_size_gb)
    ("qwen2.5:3b", "qwen2", "generalist", 1.9),
    ("deepseek-coder:1.3b", "llama", "technical", 0.7),
    ("qwen3:0.6b", "qwen3", "fast", 0.5),
]

# Consensus thresholds (tunable)
FERTILE_THRESHOLD = 0.50   # >50% token overlap = agreement
BABEL_THRESHOLD = 0.20     # <20% token overlap = no consensus
# Between 0.20 and 0.50 = AMBIGUOUS

# Token filtering for comparison (strip common words that would
# inflate agreement on nothing)
STOPWORDS = set("""
a an the and or but if when where is are was were be been being have has had
do does did will would could should may might can this that these those it
its it's i you he she we they them us him her my your his our their to of
from in on at by for with about into through during before after above
below up down out off over under again further then once here there why
how all any both each few more most other some such no nor not only own
same so than too very just as because while also only than though although
yes okay ok well now even still much many get got
""".split())

def tokenize(text: str) -> set[str]:
    """Convert text to a set of normalized tokens for overlap comparison."""
    text = text.lower()
    # Strip punctuation, split on whitespace
    words = re.findall(r"[a-z0-9]+", text)
    return {w for w in words if len(w) >= 3 and w not in STOPWORDS}

def jaccard(a: set, b: set) -> float:
    """Jaccard similarity: intersection / union."""
    if not a and not b:
        return 1.0
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)

def cosine(a: list[float], b: list[float]) -> float:
    """Cosine similarity between two embedding vectors."""
    if len(a) != len(b) or not a:
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(x * x for x in b))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)

async def get_embedding(client: httpx.AsyncClient, backend_url: str, text: str) -> Optional[list[float]]:
    """Fetch the embedding vector for a text from the embedding model."""
    try:
        resp = await client.post(
            f"{backend_url}/api/embeddings",
            json={"model": EMBEDDING_MODEL, "prompt": text},
            timeout=10.0,
        )
        resp.raise_for_status()
        return resp.json().get("embedding")
    except Exception:
        return None

async def semantic_agreement(client: httpx.AsyncClient, backend_url: str, responses: list[str]) -> float:
    """Average pairwise cosine similarity via embeddings."""
    if len(responses) < 2:
        return 1.0 if responses else 0.0
    # Fetch all embeddings in parallel
    embeddings = await asyncio.gather(
        *[get_embedding(client, backend_url, r) for r in responses]
    )
    valid = [e for e in embeddings if e]
    if len(valid) < 2:
        return 0.0
    scores = []
    for i in range(len(valid)):
        for j in range(i + 1, len(valid)):
            scores.append(cosine(valid[i], valid[j]))
    return sum(scores) / len(scores) if scores else 0.0

def pairwise_agreement(responses: list[str]) -> float:
    """Compute average pairwise Jaccard similarity across responses (token-based fallback)."""
    if len(responses) < 2:
        return 1.0 if responses else 0.0
    token_sets = [tokenize(r) for r in responses]
    scores = []
    for i in range(len(token_sets)):
        for j in range(i + 1, len(token_sets)):
            scores.append(jaccard(token_sets[i], token_sets[j]))
    return sum(scores) / len(scores) if scores else 0.0

def classify(agreement: float, num_valid: int, num_total: int) -> str:
    """
    Classify consensus level. This is the circuit breaker signal.

    - UNVERIFIED: Not enough witnesses responded (need 2+ for real consensus)
    - BABEL: Witnesses disagree strongly — refuse to answer
    - AMBIGUOUS: Partial agreement — return with low confidence
    - FERTILE: Witnesses agree — confident answer
    """
    if num_valid < 2:
        return "UNVERIFIED"  # Cannot form consensus with fewer than 2 witnesses
    if agreement >= FERTILE_THRESHOLD:
        return "FERTILE"
    if agreement <= BABEL_THRESHOLD:
        return "BABEL"
    return "AMBIGUOUS"

@dataclass
class WitnessResult:
    model: str
    family: str
    role: str
    response: str
    latency_ms: int
    error: Optional[str] = None

@dataclass
class ConsensusResult:
    query: str
    witnesses: list[WitnessResult]
    agreement_score: float
    classification: str
    consensus_answer: Optional[str]  # The most agreed-upon response
    circuit_breaker_tripped: bool
    total_latency_ms: int
    scoring_method: str = "semantic"  # 'semantic' or 'jaccard'

async def query_witness(
    client: httpx.AsyncClient,
    backend_url: str,
    model_name: str,
    family: str,
    role: str,
    query: str,
    system_prompt: str,
    max_tokens: int = 200,
    timeout: float = 90.0,
) -> WitnessResult:
    """Query a single witness model. Independent of the others."""
    start = time.time()
    try:
        resp = await client.post(
            f"{backend_url}/api/chat",
            json={
                "model": model_name,
                "stream": False,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": query},
                ],
                "options": {"num_predict": max_tokens},
            },
            timeout=timeout,
        )
        resp.raise_for_status()
        data = resp.json()
        content = data.get("message", {}).get("content", "").strip()
        latency = int((time.time() - start) * 1000)
        return WitnessResult(
            model=model_name,
            family=family,
            role=role,
            response=content,
            latency_ms=latency,
        )
    except Exception as e:
        latency = int((time.time() - start) * 1000)
        return WitnessResult(
            model=model_name,
            family=family,
            role=role,
            response="",
            latency_ms=latency,
            error=f"{type(e).__name__}: {str(e)[:100]}",
        )

async def run_consensus(
    client: httpx.AsyncClient,
    backend_url: str,
    query: str,
    system_prompt: str,
    max_tokens: int = 200,
) -> ConsensusResult:
    """Run the query through all witness models in parallel and classify."""
    start = time.time()

    tasks = [
        query_witness(
            client, backend_url, name, family, role,
            query, system_prompt, max_tokens,
        )
        for name, family, role, _ in WITNESS_MODELS
    ]
    witnesses = await asyncio.gather(*tasks)

    # Only use successful responses for consensus scoring
    valid_responses = [w.response for w in witnesses if w.response and not w.error]

    # Prefer semantic (embedding-based) agreement; fall back to token overlap
    if USE_EMBEDDINGS and valid_responses:
        try:
            agreement = await semantic_agreement(client, backend_url, valid_responses)
            scoring_method = "semantic"
        except Exception:
            agreement = pairwise_agreement(valid_responses)
            scoring_method = "jaccard"
    else:
        agreement = pairwise_agreement(valid_responses) if valid_responses else 0.0
        scoring_method = "jaccard"

    # Semantic similarity runs on a higher scale than Jaccard —
    # adjust thresholds for embedding-based scoring
    if scoring_method == "semantic":
        # Embedding cosine for unrelated text is often ~0.3, related ~0.5, matching ~0.7+
        fertile_threshold = 0.70
        babel_threshold = 0.40
    else:
        fertile_threshold = FERTILE_THRESHOLD
        babel_threshold = BABEL_THRESHOLD

    num_valid = len(valid_responses)
    num_total = len(witnesses)
    if num_valid < 2:
        classification = "UNVERIFIED"
    elif agreement >= fertile_threshold:
        classification = "FERTILE"
    elif agreement <= babel_threshold:
        classification = "BABEL"
    else:
        classification = "AMBIGUOUS"

    # Consensus answer: pick the response that agrees most with the OTHERS
    # (not with the combined token pool — that biases toward the longest).
    # The right answer is the one in the majority cluster.
    consensus_answer = None
    if valid_responses:
        valid_witnesses = [w for w in witnesses if w.response and not w.error]
        if len(valid_witnesses) == 1:
            consensus_answer = valid_witnesses[0].response
        else:
            # Score each witness by its average similarity to the OTHERS
            best_score = -1.0
            for i, w_i in enumerate(valid_witnesses):
                tokens_i = tokenize(w_i.response)
                if scoring_method == "semantic":
                    # Use embedding cosine against other responses
                    emb_i = await get_embedding(client, backend_url, w_i.response)
                    if emb_i is None:
                        continue
                    sims = []
                    for j, w_j in enumerate(valid_witnesses):
                        if i == j:
                            continue
                        emb_j = await get_embedding(client, backend_url, w_j.response)
                        if emb_j is not None:
                            sims.append(cosine(emb_i, emb_j))
                    score = sum(sims) / len(sims) if sims else 0.0
                else:
                    sims = [
                        jaccard(tokens_i, tokenize(w_j.response))
                        for j, w_j in enumerate(valid_witnesses)
                        if i != j
                    ]
                    score = sum(sims) / len(sims) if sims else 0.0
                if score > best_score:
                    best_score = score
                    consensus_answer = w_i.response

    total_latency = int((time.time() - start) * 1000)
    # Circuit breaker trips on BABEL (witnesses disagree) or UNVERIFIED (not enough witnesses)
    circuit_breaker_tripped = classification in ("BABEL", "UNVERIFIED")

    return ConsensusResult(
        query=query,
        witnesses=witnesses,
        agreement_score=round(agreement, 3),
        classification=classification,
        consensus_answer=consensus_answer if not circuit_breaker_tripped else None,
        circuit_breaker_tripped=circuit_breaker_tripped,
        total_latency_ms=total_latency,
        scoring_method=scoring_method,
    )
