#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Persona Chat Memory Tiers
#
# L1 / L2 / L3 QBIT-budget context walk from the session ledger.
#
#   L1 Quick Remediation — 333 QBITs      (fast chat turns)
#   L2 Intermediate       — 777 QBITs      (mid-weight, cached)
#   L3 Long-term          — unbounded       (semantic search, deferred)
#
# ForToken = forward-direction expansive search. Gets 3x the tier budget
# so it looks ahead of what the base model sees. Implemented here as a
# second walk with the expanded budget.
#
# RevToken = reverse-direction prediction from interaction plane +
# LocationID + Trinity -1/0/+1. Stubbed today (returns None) because it
# depends on cws_core.location_id which lives in the pod.
#
# Cross-persona READ: within a session, any persona can read every other
# persona's room. Write stays per-persona. The cross-persona walk merges
# all three persona ledgers sorted by timestamp newest-first.
#
# Copyright 2026 Jamie Lee Clayton / 2XR LLC
# CWS-BSL-1.1 · Civilian use only.
# ═══════════════════════════════════════════════════════════════════

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from ledger import (
    LedgerRow,
    persona_ledger_path,
    iter_rows_reverse,
    iter_cross_persona_rows_reverse,
)
from qbit_count import count_qbits, fits_in_budget


# ── Tier budgets ────────────────────────────────────────────────────

TIER_BUDGETS = {
    "L1": 333,
    "L2": 777,
    "L3": None,  # unbounded; L3 lookup uses semantic search, not walk-back
}
"""Canonical QBIT budgets for each context tier, per the 2026-04-13
chat-speed-architecture brainstorm decision."""

FORTOKEN_MULTIPLIER = 3
"""ForToken expansive search gets 3x the tier budget. Design decision
from the same brainstorm. RevToken is a separate mechanism and is not
a multiplier."""

DEFAULT_TIER = "L1"


# ── Walk result ─────────────────────────────────────────────────────

@dataclass
class TierWalk:
    """The context assembly result for one turn.

    `base_drawers` are the drawers that fit within the tier's budget.
    `fortoken_drawers` are the additional drawers that fit within 3x the
    tier's budget (used only when `fortoken_used=True` was requested for
    this turn).

    `base_drawers` is a subset prefix of `fortoken_drawers` — they are
    the same walk, different budgets.

    `tier` and `used_qbits` are for the ledger row and the status badge.
    """
    tier: str
    base_drawers: list[LedgerRow]
    fortoken_drawers: list[LedgerRow]
    used_qbits: int
    fortoken_used_qbits: int
    cross_persona: bool
    revtoken_hint: Optional[str] = None  # Always None until pod is back


# ── L1 / L2 walk ────────────────────────────────────────────────────

def walk_tier(
    *,
    user_id: str,
    session_id: str,
    persona: str,
    tier: str = DEFAULT_TIER,
    fortoken: bool = False,
    cross_persona: bool = True,
    root: Optional[Path] = None,
) -> TierWalk:
    """Walk the ledger newest-first and return the drawers that fit in the
    tier's QBIT budget.

    When `cross_persona=True` (default for Samuel's witness role and for
    Carli/Elias follow-ups in the same session), the walk merges every
    persona's ledger in the session, sorted by timestamp. Each drawer is
    still persona-tagged.

    When `cross_persona=False`, the walk stays within the specified
    persona's room. Useful when the caller explicitly wants the persona's
    own voice only (e.g., reconstructing a persona's solo history for
    debugging).

    ForToken multiplier (3x) applies when `fortoken=True`. The returned
    `fortoken_drawers` list is a superset of `base_drawers` — it contains
    all the base drawers PLUS the additional ones that fit in the 3x budget.

    Raises ValueError if `tier` is unknown or `persona` is not allowed.
    """
    if tier not in TIER_BUDGETS:
        raise ValueError(f"unknown tier {tier!r}; must be one of {list(TIER_BUDGETS)}")

    base_budget = TIER_BUDGETS[tier]
    if base_budget is None:
        # L3: no walk-back; semantic search is used instead (deferred).
        return TierWalk(
            tier=tier,
            base_drawers=[],
            fortoken_drawers=[],
            used_qbits=0,
            fortoken_used_qbits=0,
            cross_persona=cross_persona,
            revtoken_hint=None,
        )

    expanded_budget = base_budget * FORTOKEN_MULTIPLIER if fortoken else base_budget

    # Collect the newest-first walk. Cross-persona or solo-persona.
    if cross_persona:
        walk = list(iter_cross_persona_rows_reverse(user_id, session_id, root=root))
    else:
        p = persona_ledger_path(user_id, session_id, persona, root=root)
        walk = list(iter_rows_reverse(p))

    if not walk:
        return TierWalk(
            tier=tier,
            base_drawers=[],
            fortoken_drawers=[],
            used_qbits=0,
            fortoken_used_qbits=0,
            cross_persona=cross_persona,
            revtoken_hint=None,
        )

    # Each drawer's QBIT cost for context-assembly purposes is the SUM of
    # (user_input + assistant_output) QBITs. The prompt is reconstructed
    # from both sides of the turn when assembling context for the next
    # inference call.
    per_row_qbits = [_row_qbits(r) for r in walk]

    base_fit = fits_in_budget(per_row_qbits, base_budget)
    base_drawers = walk[:base_fit]
    used = sum(per_row_qbits[:base_fit])

    if fortoken:
        fortoken_fit = fits_in_budget(per_row_qbits, expanded_budget)
        fortoken_drawers = walk[:fortoken_fit]
        fortoken_used = sum(per_row_qbits[:fortoken_fit])
    else:
        fortoken_drawers = list(base_drawers)
        fortoken_used = used

    return TierWalk(
        tier=tier,
        base_drawers=base_drawers,
        fortoken_drawers=fortoken_drawers,
        used_qbits=used,
        fortoken_used_qbits=fortoken_used,
        cross_persona=cross_persona,
        revtoken_hint=None,  # STUBBED until pod is back
    )


def _row_qbits(row: LedgerRow) -> int:
    """Sum the input + output QBIT cost of a ledger row.

    Uses the ledger's stored qbit_count.total if present; falls back to
    recomputing from the text if the field is missing or malformed (which
    can happen if a future schema adds fields before this code sees them).
    """
    qc = row.qbit_count
    if isinstance(qc, dict) and isinstance(qc.get("total"), int) and qc["total"] >= 0:
        return qc["total"]
    # Fallback — recompute from the text so the walk is still correct.
    return count_qbits(row.user_input) + count_qbits(row.assistant_output)


# ── Prompt assembly ─────────────────────────────────────────────────

def assemble_prompt(
    *,
    system_prompt: str,
    walk: TierWalk,
    new_user_input: str,
) -> str:
    """Take a tier walk result + new user input and return the full prompt
    string that gets sent to Ollama or bitnet-mcp.

    Format:

        <system_prompt>

        --- prior turns (persona-tagged, chronological order) ---
        [carli] user: ...
        [carli] assistant: ...
        [samuel] user: ...
        [samuel] assistant: ...
        --- end prior turns ---

        user: <new_user_input>

    The prior turns are chronological (oldest first) in the assembled
    prompt because that's what LLMs expect. The walk produced them
    newest-first to enforce budget; we reverse here for ordering.

    When `fortoken_drawers` exceeds `base_drawers`, only the BASE drawers
    are included in the assembled prompt. The ForToken expanded set is
    used for a separate pass (expansive search in the ForToken encoder)
    and not shipped to the base model. This keeps the base model's
    context window within the L1/L2 budget as designed.
    """
    parts = [system_prompt.rstrip(), ""]
    if walk.base_drawers:
        parts.append("--- prior turns ---")
        for row in reversed(walk.base_drawers):
            parts.append(f"[{row.persona}] user: {row.user_input}")
            parts.append(f"[{row.persona}] assistant: {row.assistant_output}")
        parts.append("--- end prior turns ---")
        parts.append("")
    parts.append(f"user: {new_user_input}")
    return "\n".join(parts)
