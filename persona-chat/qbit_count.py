#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — QBIT Counting
#
# S7 measures context, memory, and inference in QBITs, not tokens.
# See feedback_qbit_not_token.md for the governing rule.
#
# This module is the boundary between Ollama's token vocabulary
# (what its API returns) and S7's QBIT vocabulary (what ledgers,
# status badges, and user-facing text use).
#
# Copyright 2026 Jamie Lee Clayton / 2XR LLC
# CWS-BSL-1.1 · Civilian use only.
# ═══════════════════════════════════════════════════════════════════

from __future__ import annotations

# ── Constants ───────────────────────────────────────────────────────

QBIT_CHARS_PER_UNIT = 4
"""English approximation: ~4 chars per QBIT. Used until the real ForToken
encoder is wired in. Matches the common transformer-token rule-of-thumb,
which is close enough for context-budget decisions (L1=333 QBIT, L2=777
QBIT). A future commit will replace this with engine/s7_akashic.py's
ForToken.encode_count() for per-model accuracy."""


# ── Counting ────────────────────────────────────────────────────────

def count_qbits(text: str) -> int:
    """Return an approximate QBIT count for a string.

    This is a stub that approximates using char/4. The real QBIT count for
    an S7 turn comes from the ForToken encoder in engine/s7_akashic.py once
    that is wired in. The approximation is intentionally conservative —
    it will slightly overestimate the QBIT budget, which means L1 retrieval
    pulls slightly fewer drawers than optimal (safer than overflowing the
    model's context window).

    Empty input returns 0. The function is pure, idempotent, no IO.
    """
    if not text:
        return 0
    # Round up so we never underestimate.
    return (len(text) + QBIT_CHARS_PER_UNIT - 1) // QBIT_CHARS_PER_UNIT


def ollama_tokens_to_qbits(ollama_token_count: int) -> int:
    """Convert an Ollama API token count to QBITs at the user boundary.

    Per feedback_qbit_not_token.md: Ollama's eval_count / prompt_eval_count
    fields are Ollama's internal vocabulary. When we READ them and DISPLAY
    them (in ledger rows, status badges, admin screens), we call them QBITs.

    Today this is a 1:1 passthrough — we treat one Ollama token as one
    QBIT. When the ForToken encoder lands, this function may apply a
    per-model correction factor (e.g., qwen3 tokenizer produces ~1.1 QBITs
    per S7-canonical QBIT because of its BPE merges).

    Today's behavior is deliberate: 1:1 preserves the magnitudes you see
    in Ollama logs, so debugging is not confusing during the stub period.
    """
    return max(0, int(ollama_token_count))


def qps_from_ollama(eval_count: int, eval_duration_ns: int) -> float:
    """Compute QBITs-per-second from Ollama's eval fields.

    Ollama's /api/generate returns:
      eval_count:       int — number of output tokens
      eval_duration:    int — nanoseconds spent generating
    This converts to S7's QBIT/s at the user boundary.

    Returns 0.0 if eval_duration is 0 (no output yet or instantaneous,
    which shouldn't happen but we don't crash).
    """
    if eval_duration_ns <= 0:
        return 0.0
    seconds = eval_duration_ns / 1_000_000_000.0
    return ollama_tokens_to_qbits(eval_count) / seconds


# ── Budget math ─────────────────────────────────────────────────────

def fits_in_budget(rows_qbits: list[int], budget: int) -> int:
    """Walk a list of per-row QBIT counts and return how many rows fit in
    the given budget, starting from the FIRST row.

    Used by memory_tiers.py to pick the newest K drawers whose sum fits
    under L1=333 or L2=777 QBITs.

    Example:
        fits_in_budget([100, 100, 100, 100], 333) → 3
        fits_in_budget([500], 333) → 0
        fits_in_budget([], 333) → 0
    """
    if budget <= 0:
        return 0
    running = 0
    fit = 0
    for q in rows_qbits:
        if running + q > budget:
            return fit
        running += q
        fit += 1
    return fit
