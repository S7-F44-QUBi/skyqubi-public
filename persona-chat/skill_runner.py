#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════
# persona-chat/skill_runner.py
#
# The bridge between a chat turn and Samuel's operator scripts.
#
# When a user sends a message to Samuel like 'check if the pod is
# healthy' or 'run preflight', the skill runner recognizes the intent,
# matches it to an entry in engine/agents/samuel_runnable_scripts.yaml,
# runs the script with --samuel JSON mode, parses the output, and
# returns a structured result the chat handler can fold back into
# Samuel's reply.
#
# This is the 'waiter reading the recipe' piece Jamie flagged in the
# 2026-04-13 'chef recipe wrong interactive toolset' conversation.
# Samuel's scripts are the kitchen. This module is Samuel's arm
# reaching into the kitchen on a user's behalf.
#
# Design principles:
#   1. ONLY 'samuel' persona may invoke skills. carli/elias get
#      rejected with an explicit 'not your role' message. The closed
#      persona set matches the ledger and app.py.
#   2. Intent matching is PHRASE-based, not LLM-based. Keeps the
#      matcher testable and deterministic. A future v2 can add an
#      LLM-routing layer on top, but the base must be explicit.
#   3. Every invocation writes an ops-ledger row matching the
#      fix-pod.sh --samuel mode's hash-chain pattern.
#   4. Emergency-stop file + rate limit enforcement BEFORE any
#      subprocess fires.
#   5. All scripts run with --samuel --json for machine-parseable
#      output. The natural-language summary is generated from the
#      parsed JSON in this module, not by the scripts themselves.
#
# Governing rules:
#   feedback_three_rules.md      Rule 2: Samuel approves landings
#   engine/agents/samuel_runnable_scripts.yaml  The closed skill catalog
#   persona-chat/ledger.py       Per-turn ledger the chat uses
#
# Copyright 2026 Jamie Lee Clayton / 2XR LLC · CWS-BSL-1.1
# ═══════════════════════════════════════════════════════════════════

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import time
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None  # gracefully degrade in environments that lack pyyaml

# ── Config ──────────────────────────────────────────────────────────

CATALOG_PATH = Path("/s7/skyqubi-private/engine/agents/samuel_runnable_scripts.yaml")
OPS_LEDGER_DIR = Path("/s7/.s7-ops-ledger")
OPS_LEDGER_FILE = OPS_LEDGER_DIR / "skill_runner.ndjson"
EMERGENCY_STOP_FILE = Path("/s7/.s7-samuel-emergency-stop")

# Skill invocation is locked to Samuel. Other personas don't have the
# authority. If someone needs to change this, they add an entry to the
# catalog explicitly (and Samuel reviews it against the Bible Code,
# eventually).
ALLOWED_SKILL_CALLER = "samuel"

# Default timeouts — can be overridden per-skill in the catalog
DEFAULT_TIMEOUT_S = 300   # 5 minutes for apply-mode runs
DRY_RUN_TIMEOUT_S = 180   # 3 minutes for diagnose mode. Bumped from 60s
                          # on 2026-04-14 because the 'diag' composite
                          # skill runs preflight + fix-pod-dry-run +
                          # lifecycle-test back to back and the
                          # lifecycle suite alone takes 30-60s on a
                          # healthy box. 180s gives diag headroom
                          # without affecting the fast diagnose paths
                          # (preflight, pod-stats) which still finish
                          # in under 5s.

# Rate-limit ceiling for introspection meta-skills (list-skills,
# explain-skill, recent-activity). They don't fire subprocesses, but
# unbounded calls would still flood the ops ledger and let a
# misbehaving client mine the catalog. 60/hour is generous for any
# legitimate human-paced session.
INTROSPECTION_RATE_LIMIT_PER_HOUR = 60


# ── Result shape ────────────────────────────────────────────────────

@dataclass
class SkillResult:
    """What comes back when Samuel runs a skill on the user's behalf."""

    matched: bool                   # True if skill_runner produced a meaningful reply (catalog skill matched OR confirmation route matched)
    skill_id: Optional[str]         # 'fix-pod' / 'preflight' / 'lifecycle-test' / None
    persona: str                    # who asked (must be 'samuel' for invocation to succeed)
    mode: str                       # 'diagnose' (dry-run) or 'apply'
    attempted: bool                 # True if the subprocess fired
    exit_code: Optional[int]        # the script's exit code (None if not run)
    state: Optional[str]            # parsed 'state' field from script JSON
    parsed: Optional[dict]          # full parsed JSON from stdout
    stderr_tail: str                # last ~500 chars of stderr (for debugging)
    summary: str                    # natural-language one-line summary for Samuel's reply
    elapsed_ms: int                 # wall-clock time spent running
    blocked_reason: Optional[str] = None  # if blocked, why (emergency_stop / rate_limit / persona)

    def as_samuel_reply(self) -> str:
        """Build the sentence Samuel would say back to the user.

        Order of precedence:
          1. If we have a meaningful summary, use it (covers all the
             cases where skill_runner produced a real reply: catalog
             skill ran, introspection meta-skill ran, confirmation
             route handled it).
          2. If blocked, surface the block reason.
          3. If nothing matched at all, the default fall-through.
        """
        if self.summary and self.summary.strip():
            return self.summary
        if self.blocked_reason:
            return f"I can't run that right now: {self.blocked_reason}."
        if not self.matched:
            return "I don't have a skill that matches that request."
        return f"I found the skill '{self.skill_id}' but didn't run it."


# ── Intent matcher ──────────────────────────────────────────────────
#
# Phrase-based matching. Each skill has a list of trigger phrases.
# A user message is lowercased, and if ANY phrase is a substring match,
# the skill matches. Explicit, deterministic, testable.
#
# The matcher returns a tuple (skill_id, mode) where mode is
# 'diagnose' by default (safer — dry-run first), OR 'apply' if the
# user message has an explicit "actually do it" / "apply" / "fix it"
# hint. This two-layer safety means a user saying "check the pod"
# gets a diagnose, and "fix the pod" gets the apply.

DIAGNOSE_HINTS = frozenset({
    "check", "check if", "is the", "are the", "is pod", "status of",
    "look at", "diagnose", "review", "inspect", "verify", "is",
    "preflight", "pre-flight", "pre flight", "pre-check", "dry run",
    "dry-run", "dryrun", "what state", "how is", "how's",
})

APPLY_HINTS = frozenset({
    "fix", "repair", "apply", "run it", "actually", "do it",
    "go ahead", "heal", "recover", "restart", "reset", "resolve",
    "now", "execute", "make it so",
})

# Bare confirmation phrases. When the WHOLE user message is one of
# these (after stripping punctuation), and the session has a recent
# pending suggestion, the confirmation routes the next turn to that
# suggestion's skill in apply mode. Without a pending suggestion,
# 'yes' falls through to normal LLM chat.
CONFIRMATION_PHRASES = frozenset({
    # Plain affirmatives
    "yes", "y", "yeah", "yep", "yup", "yea", "yas",
    "ok", "okay", "k", "kk", "alright", "alrighty",
    "sure", "absolutely", "definitely", "of course",
    "fine", "right", "correct",
    # Polite affirmatives
    "yes please", "please", "please do", "yes please do",
    "if you would", "if you could",
    # Direction
    "do it", "go ahead", "go", "go for it", "let's go",
    "lets go", "let's do it", "lets do it",
    # Skill-flavored
    "apply", "apply it", "fix it", "fix", "run it", "run",
    "make it so", "execute", "proceed",
    # Permission language
    "approved", "approve", "permission granted", "you have permission",
    "i approve", "go right ahead", "have at it",
    # Mild
    "sounds good", "works for me", "that works", "good idea",
    "why not", "i'm in", "im in", "count me in",
})

SUGGESTION_MAX_AGE_S = 300  # 5 minutes — same as standard cache windows

# Bare negative-confirmation phrases. Same shape as CONFIRMATION_PHRASES
# but for declining a pending suggestion. When matched, Samuel
# acknowledges politely and the suggestion is left to expire naturally.
NEGATIVE_CONFIRMATION_PHRASES = frozenset({
    # Plain negatives
    "no", "n", "nope", "nah", "naw", "negative",
    # Polite declines
    "no thanks", "no thank you", "not right now",
    "not now", "not yet", "later", "maybe later",
    "another time", "some other time",
    # Skip / cancel
    "skip", "skip it", "skip this", "pass",
    "cancel", "cancel it", "abort", "nevermind",
    "never mind", "forget it", "forget about it",
    # Hold
    "stop", "stop it", "wait", "hold up", "hold on",
    "hold off", "pause", "pause it",
    # Don't
    "don't", "do not", "dont", "don't do it", "dont do it",
})

# Per-skill trigger phrases. Lowercase, substring-matched.
# Keep these explicit and conservative — adding phrases is a code
# change + a test, not a config edit.
SKILL_TRIGGERS = {
    "preflight": [
        "preflight", "pre-flight", "pre flight check",
        "is the box ready", "is the system ready",
        "can i install", "ready to install",
        "environment check", "env check",
        "check my environment",
    ],
    "fix-firewall": [
        "fix the firewall", "fix firewall", "firewall fix",
        "firewall is broken", "firewall broken",
        "169.254", "rootless gateway",
        "pod can't reach host", "pod cant reach host",
        "container can't reach", "container cant reach",
        "ollama unreachable", "ollama not reachable",
        "host.containers.internal",
        "trust rootless", "trust the rootless",
    ],
    "fix-pod": [
        "fix the pod", "fix pod", "the pod is broken",
        "pod is broken", "pod is crashing", "pod crash",
        "recover the pod", "recover pod",
        "selinux fix", "selinux denial",
        "heal the pod", "heal pod",
        "pod state", "pod health",
        "is the pod up", "is the pod running",
        "is the pod healthy",
        "check the pod", "check pod",
        "look at the pod", "diagnose the pod",
    ],
    "lifecycle-test": [
        "lifecycle", "lifecycle test", "lifecycle tests",
        "run tests", "run the tests", "run lifecycle",
        "all tests", "do the tests pass", "are the tests green",
        "test pass count", "test status",
        "test everything", "test the system",
    ],
    "next-action": [
        "what should i do", "what should i ask", "what now",
        "what next", "now what", "where do i start",
        "i don't know what to ask", "i dont know what to ask",
        "i'm new", "im new", "first time", "just got here",
        "any suggestions", "any ideas", "give me a hint",
        "help me out", "i need a hint", "help me get started",
    ],
    "list-skills": [
        "what can you do", "what can you check", "what skills",
        "list your skills", "list skills", "what are your skills",
        "what commands", "what can you run", "what tools",
        "show me your skills", "show your skills",
        "what scripts can you run", "samuel skills",
    ],
    "explain-skill": [
        "tell me about", "what does", "what is", "explain",
        "describe", "details on", "details about", "how does",
    ],
    "recent-activity": [
        "what have you been doing", "what did you do",
        "recent activity", "what have you done",
        "your recent runs", "show me your activity",
        "what did you run", "show me what you ran",
        "samuel history", "your history",
        "recent ops", "your ledger", "show your ledger",
        "what's in your log", "whats in your log",
    ],
    "test-personas": [
        "test the personas", "test personas", "are the personas",
        "is carli alive", "is elias alive", "is carli responding",
        "is elias responding", "are carli and elias",
        "check carli", "check elias",
        "persona health", "personas working",
    ],
    "pod-stats": [
        "pod stats", "pod resources", "resource usage",
        "how hard is it working", "how hard is the qubi working",
        "how busy", "how loaded", "load average",
        "memory usage", "ram usage", "cpu usage",
        "container stats", "container memory",
        "what's the load", "whats the load",
    ],
    "diag": [
        "check everything", "check it all", "full check",
        "how's the qubi", "hows the qubi", "how is the qubi",
        "how's the box", "hows the box", "how is the box",
        "system health", "overall health", "health check",
        "full diagnostic", "full diagnostics", "complete diagnostic",
        "diag", "diagnose everything", "everything ok",
        "is everything ok", "is everything fine",
        "tell me about the system",
    ],
}


def match_intent(user_message: str) -> tuple[Optional[str], str]:
    """Match a user message to a skill_id + execution mode.

    Returns (skill_id, mode). If no match, (None, 'none').

    Mode rules:
    - Default is 'diagnose' (safer — dry-run first)
    - Promoted to 'apply' ONLY if an explicit apply hint appears as a
      whole-word match (so 'heal' matches 'heal the pod' but NOT
      'pod health'). Uses re.search with \\b word boundaries.
    - preflight + lifecycle-test are read-only: always diagnose.
    """
    if not user_message:
        return (None, "none")

    import re
    msg = user_message.lower().strip()

    # Find which skill matches (first match wins; skills ordered by
    # safety — preflight is safest, then lifecycle-test, then fix-pod).
    # Triggers are substring-matched because they're multi-word phrases
    # where natural whitespace prevents false positives.
    # Order matters: diag is checked first because its triggers are the
    # most specific composite phrases ("check everything", "how's the qubi")
    # and we don't want them to match a single sub-skill by accident.
    # list-skills is the meta-capability — checked first so introspection
    # phrases ("what can you do") never accidentally match a real skill.
    # explain-skill is special: it matches only when BOTH an explain
    # trigger ("tell me about", "what does", etc.) AND a known skill
    # target alias appear in the message. Otherwise "tell me about the
    # weather" would route here with nothing to explain. Checked first
    # so it beats real-skill matchers like "fix-pod" appearing inside
    # "what does fix-pod do".
    explain_target = detect_explain_target(msg)
    if explain_target:
        for trigger in SKILL_TRIGGERS["explain-skill"]:
            if trigger in msg:
                return ("explain-skill", "introspect")

    skill_id = None
    for candidate in ("next-action", "list-skills", "recent-activity", "test-personas", "pod-stats", "diag", "preflight", "lifecycle-test", "fix-firewall", "fix-pod"):
        for trigger in SKILL_TRIGGERS[candidate]:
            if trigger in msg:
                skill_id = candidate
                break
        if skill_id:
            break

    if not skill_id:
        return (None, "none")

    # Decide mode — apply only if a WHOLE-WORD apply-hint is present.
    # Multi-word hints (e.g. 'run it', 'go ahead') are phrase-matched.
    # Single-word hints (e.g. 'heal', 'fix', 'now') are word-bounded
    # so 'health' doesn't match 'heal' and 'fixed' doesn't match 'fix'.
    mode = "diagnose"
    for hint in APPLY_HINTS:
        if " " in hint:
            # Multi-word hint — substring match is safe
            if hint in msg:
                mode = "apply"
                break
        else:
            # Single-word hint — word-boundary match
            if re.search(r"\b" + re.escape(hint) + r"\b", msg):
                mode = "apply"
                break

    # Preflight has no apply mode (read-only). Force to diagnose.
    if skill_id == "preflight":
        mode = "diagnose"

    # lifecycle-test also has no apply mode — it's assertions, not changes
    if skill_id == "lifecycle-test":
        mode = "diagnose"

    # diag is composite read-only — never an apply
    if skill_id == "diag":
        mode = "diagnose"

    # pod-stats is read-only resource snapshot — never an apply
    if skill_id == "pod-stats":
        mode = "diagnose"

    # test-personas is read-only persona-chat self-test — never an apply
    if skill_id == "test-personas":
        mode = "diagnose"

    # list-skills + recent-activity + next-action are pure introspection
    if skill_id in ("list-skills", "recent-activity", "next-action"):
        mode = "introspect"

    return (skill_id, mode)


# ── Catalog reader ──────────────────────────────────────────────────

def load_catalog(path: Path = CATALOG_PATH) -> dict:
    """Read samuel_runnable_scripts.yaml and return the parsed structure.

    Raises FileNotFoundError if missing, ValueError if the YAML is
    malformed or the version is unexpected.
    """
    if yaml is None:
        raise RuntimeError("pyyaml not installed — install python3-pyyaml")
    if not path.exists():
        raise FileNotFoundError(f"skill catalog not found at {path}")
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        raise ValueError("catalog is not a YAML mapping")
    if data.get("version") != 1:
        raise ValueError(f"catalog version {data.get('version')} — expected 1")
    return data


def build_skill_list_summary(catalog: dict) -> str:
    """Render the catalog as a one-paragraph human listing.

    Used by the list-skills introspection meta-capability so users can
    discover what Samuel can actually run on their behalf.
    """
    entries = catalog.get("scripts", [])
    if not entries:
        return "I don't have any skills loaded right now."
    parts = []
    for e in entries:
        sid = e.get("id", "?")
        name = e.get("display_name", sid)
        parts.append(f"{sid} ({name})")
    return "I can run: " + "; ".join(parts) + ". Ask me to check, diagnose, or run any of them."


EXPLAIN_SKILL_TARGETS = {
    "preflight": ["preflight", "pre-flight", "pre flight"],
    "fix-pod": ["fix-pod", "fix pod", "fixpod", "pod fix"],
    "fix-firewall": ["fix-firewall", "fix firewall", "firewall fix"],
    "lifecycle-test": ["lifecycle-test", "lifecycle test", "lifecycle"],
    "diag": ["diag", "diagnostic", "diagnostics"],
    "pod-stats": ["pod-stats", "pod stats", "podstats"],
    "test-personas": ["test-personas", "test personas", "persona test"],
}


def detect_explain_target(msg: str) -> Optional[str]:
    """Return the skill_id the user is asking about, or None."""
    lowered = msg.lower()
    for sid, aliases in EXPLAIN_SKILL_TARGETS.items():
        for alias in aliases:
            if alias in lowered:
                return sid
    return None


def build_explain_summary(catalog: dict, target: str) -> tuple[str, dict]:
    """Render a single skill's catalog entry as a human explanation."""
    skill = find_skill(catalog, target)
    if not skill:
        return (f"I don't have a skill called '{target}' in my catalog.",
                {"state": "not_found", "target": target})
    name = skill.get("display_name", target)
    desc = (skill.get("description") or "").strip()
    # First non-empty paragraph is usually the headline
    headline = desc.split("\n\n", 1)[0].replace("\n", " ").strip() if desc else ""
    inv = skill.get("invocation", {}) or {}
    has_diagnose = bool(inv.get("diagnose"))
    has_apply = bool(inv.get("apply"))
    if has_apply:
        modes = "diagnose (dry-run) and apply (real fix)"
    elif has_diagnose:
        modes = "diagnose only — read-only, no apply phase"
    else:
        modes = "no callable modes"
    rate = skill.get("max_runs_per_hour")
    rate_str = f"{rate}/hour" if isinstance(rate, int) else str(rate or "unlimited")
    parts = [f"{target} ({name})."]
    if headline:
        parts.append(headline)
    parts.append(f"Modes: {modes}.")
    parts.append(f"Rate limit: {rate_str}.")
    return (" ".join(parts), {"state": "explained", "target": target})


def _strip_punct(msg: str) -> str:
    import re
    s = re.sub(r"[!?.,;:\s]+$", "", msg.strip()).lower()
    return re.sub(r"^[!?.,;:\s]+", "", s)


def build_next_action_summary(user_id: str, session_id: str) -> tuple[str, dict]:
    """Look at recent session activity and suggest a concrete next ask.

    Logic:
      - If the session has NO ledger rows at all → 'try how is the qubi'
      - If the most recent row is a dry_run_complete (pending suggestion)
        → 'say yes to apply, or no to skip'
      - If the most recent row is a verified diag → 'check pod-stats'
      - If the most recent row is anything else → 'try how is the qubi'

    Returns (human_summary, parsed_metadata).
    """
    if not OPS_LEDGER_FILE.exists():
        return ("You haven't asked me anything yet. Try: \"how's the qubi?\" — "
                "I'll run a full health check and tell you what's going on.",
                {"state": "blank_session", "rows": 0})

    rows = []
    try:
        with OPS_LEDGER_FILE.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except OSError:
        return ("I couldn't read my activity log. Try: \"how's the qubi?\"",
                {"state": "read_error", "rows": 0})

    # Filter to this session
    session_rows = [r for r in rows if r.get("user_id") == user_id and r.get("session_id") == session_id]

    if not session_rows:
        return ("This is the start of our conversation. Try: \"how's the qubi?\" "
                "— that runs the full health check and gives you a verdict in one sentence.",
                {"state": "blank_session", "rows": 0})

    last = session_rows[-1]
    last_skill = last.get("skill_id", "")
    last_state = last.get("state", "")
    last_mode = last.get("mode", "")

    # Pending suggestion?
    if last_mode == "diagnose" and last_state == "dry_run_complete":
        return (f"You have a pending suggestion from '{last_skill}'. "
                f"Say \"yes\" to apply it, or \"no\" to skip. "
                f"You don't have to remember the skill name.",
                {"state": "pending_suggestion", "rows": len(session_rows), "pending": last_skill})

    # Just ran diag — recommend a follow-up
    if last_skill == "diag":
        if last_state == "healthy":
            return ("Everything was green last time you checked. "
                    "If you want to see how hard the QUBi is working right now, ask: "
                    "\"how busy is the pod?\" — that runs pod-stats.",
                    {"state": "post_healthy_diag", "rows": len(session_rows)})
        else:
            return (f"Last diag was {last_state}. Re-run with \"how's the qubi?\" "
                    f"to see if anything changed, or check the suggestion in that reply.",
                    {"state": "post_nonhealthy_diag", "rows": len(session_rows), "last_diag_state": last_state})

    # Default — point at diag
    return ("If you want a fresh read on the system, try: \"how's the qubi?\" — "
            "that's the broadest single check I run.",
            {"state": "default_suggestion", "rows": len(session_rows)})


def normalize_confirmation(msg: str) -> Optional[str]:
    """If the entire message is a confirmation phrase, return it normalized.

    Returns None for anything that isn't a pure confirmation. 'yes'
    matches; 'yes fix the firewall' does NOT (it has skill content
    and should route through normal intent matching).
    """
    if not msg:
        return None
    stripped = _strip_punct(msg)
    if stripped in CONFIRMATION_PHRASES:
        return stripped
    return None


def normalize_negative_confirmation(msg: str) -> Optional[str]:
    """Symmetric to normalize_confirmation but for declining a suggestion."""
    if not msg:
        return None
    stripped = _strip_punct(msg)
    if stripped in NEGATIVE_CONFIRMATION_PHRASES:
        return stripped
    return None


def find_pending_suggestion(user_id: str, session_id: str, max_age_s: int = SUGGESTION_MAX_AGE_S) -> Optional[dict]:
    """Walk the ops ledger backwards looking for the most recent dry-run
    completion for this session, within max_age_s seconds. That row
    represents an unconfirmed suggestion the user can now confirm.

    Returns the parsed row, or None if no recent suggestion is pending.
    """
    if not OPS_LEDGER_FILE.exists():
        return None
    cutoff = time.time() - max_age_s
    try:
        rows = []
        with OPS_LEDGER_FILE.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        # Walk backwards
        for row in reversed(rows):
            if row.get("user_id") != user_id or row.get("session_id") != session_id:
                continue
            ts_str = row.get("ts", "")
            try:
                ts = time.mktime(time.strptime(ts_str[:19], "%Y-%m-%dT%H:%M:%S"))
            except (ValueError, TypeError):
                continue
            if ts < cutoff:
                return None  # any older row means no recent pending
            # The signal: a diagnose-mode run that returned a dry_run_complete
            # state. That means the script identified a fix it could apply
            # but didn't.
            if row.get("mode") == "diagnose" and row.get("state") == "dry_run_complete":
                return row
            # If we hit a successful apply or any blocked row first, there's
            # no longer a pending suggestion (it was either acted on or aborted)
            if row.get("mode") == "apply":
                return None
    except OSError:
        return None
    return None


def build_recent_activity_summary(limit: int = 5) -> tuple[str, dict]:
    """Read the last N rows of the skill_runner ledger and summarize.

    Returns (human_summary, parsed_metadata). Used by recent-activity
    introspection so users can ask 'Samuel, what have you been doing'
    and get an honest answer pulled from the audit trail itself.
    """
    if not OPS_LEDGER_FILE.exists():
        return ("I haven't run any skills yet — my ledger is empty.",
                {"state": "empty", "rows": 0})
    rows = []
    try:
        with OPS_LEDGER_FILE.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except OSError as e:
        return (f"I couldn't read my ledger: {e}.",
                {"state": "read_error", "rows": 0})

    if not rows:
        return ("My ledger exists but has no rows yet.",
                {"state": "empty", "rows": 0})

    last = rows[-limit:]
    parts = []
    for r in last:
        ts = r.get("ts", "?")[:19].replace("T", " ")
        sid = r.get("skill_id", "?")
        state = r.get("state") or r.get("blocked_reason") or "?"
        parts.append(f"{ts} {sid}={state}")
    summary = f"My last {len(last)} run(s): " + "; ".join(parts) + "."
    return (summary, {"state": "listed", "rows": len(rows), "shown": len(last)})


def find_skill(catalog: dict, skill_id: str) -> Optional[dict]:
    """Look up a skill by id in the parsed catalog."""
    for entry in catalog.get("scripts", []):
        if entry.get("id") == skill_id:
            return entry
    return None


# ── Safety gates ────────────────────────────────────────────────────

def check_emergency_stop() -> Optional[str]:
    """Return a reason string if the emergency stop file exists."""
    if EMERGENCY_STOP_FILE.exists():
        return f"emergency stop active at {EMERGENCY_STOP_FILE}"
    return None


def check_introspection_rate_limit(skill_id: str) -> Optional[str]:
    """Cap introspection meta-skills at INTROSPECTION_RATE_LIMIT_PER_HOUR.

    These skills don't fire subprocesses, so the catalog-driven
    check_rate_limit() doesn't apply (they have no catalog entry).
    But unbounded calls would still let a misbehaving client mine
    the catalog or pound the ledger.
    """
    if not OPS_LEDGER_FILE.exists():
        return None
    now = time.time()
    one_hour_ago = now - 3600
    count = 0
    try:
        with OPS_LEDGER_FILE.open("r", encoding="utf-8") as f:
            for line in f:
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if row.get("skill_id") != skill_id:
                    continue
                ts_str = row.get("ts", "")
                try:
                    ts = time.mktime(time.strptime(ts_str[:19], "%Y-%m-%dT%H:%M:%S"))
                except (ValueError, TypeError):
                    continue
                if ts >= one_hour_ago:
                    count += 1
    except OSError:
        return None
    if count >= INTROSPECTION_RATE_LIMIT_PER_HOUR:
        return f"introspection rate limit {INTROSPECTION_RATE_LIMIT_PER_HOUR}/hour exceeded ({count} in last hour)"
    return None


def check_rate_limit(skill_id: str, catalog: dict) -> Optional[str]:
    """Check per-skill rate limits against the ops ledger.

    Reads skill_runner.ndjson, counts recent invocations of this skill_id,
    compares against the catalog's max_runs_per_hour and max_runs_per_day.
    Returns a reason string if exceeded, None otherwise.
    """
    skill = find_skill(catalog, skill_id)
    if not skill:
        return None  # not in catalog, but we already checked this upstream

    per_hour = skill.get("max_runs_per_hour")
    per_day = skill.get("max_runs_per_day")
    if per_hour in (None, "unlimited") and per_day in (None, "unlimited"):
        return None

    if not OPS_LEDGER_FILE.exists():
        return None  # no history, nothing to count

    now = time.time()
    one_hour_ago = now - 3600
    one_day_ago = now - 86400

    count_1h = 0
    count_1d = 0
    try:
        with OPS_LEDGER_FILE.open("r", encoding="utf-8") as f:
            for line in f:
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if row.get("skill_id") != skill_id:
                    continue
                ts_str = row.get("ts", "")
                try:
                    ts = time.mktime(time.strptime(ts_str[:19], "%Y-%m-%dT%H:%M:%S"))
                except (ValueError, TypeError):
                    continue
                if ts >= one_hour_ago:
                    count_1h += 1
                if ts >= one_day_ago:
                    count_1d += 1
    except OSError:
        return None  # best-effort — ledger read failure is not a rate limit

    if isinstance(per_hour, int) and count_1h >= per_hour:
        return f"rate limit {per_hour}/hour exceeded ({count_1h} in last hour)"
    if isinstance(per_day, int) and count_1d >= per_day:
        return f"rate limit {per_day}/day exceeded ({count_1d} in last day)"
    return None


# ── Ops ledger ──────────────────────────────────────────────────────

def write_ops_ledger(
    *,
    skill_id: str,
    mode: str,
    user_id: str,
    session_id: str,
    exit_code: Optional[int],
    state: Optional[str],
    duration_ms: int,
    blocked_reason: Optional[str] = None,
) -> None:
    """Append one hash-chained row to skill_runner.ndjson.

    Matches the pattern fix-pod.sh --samuel mode uses: prev_hash is
    sha256 of the previous full row line, first row has prev_hash =
    '0' * 64.
    """
    OPS_LEDGER_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)

    prev_hash = "0" * 64
    if OPS_LEDGER_FILE.exists() and OPS_LEDGER_FILE.stat().st_size > 0:
        try:
            with OPS_LEDGER_FILE.open("rb") as f:
                f.seek(0, os.SEEK_END)
                size = f.tell()
                # Walk backwards to find the last newline
                chunk = min(4096, size)
                f.seek(size - chunk)
                tail = f.read(chunk).decode("utf-8", errors="replace")
                last_line = tail.rstrip("\n").rsplit("\n", 1)[-1]
            prev_hash = hashlib.sha256(last_line.encode()).hexdigest()
        except OSError:
            pass

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    row = {
        "ts": ts,
        "script": "skill_runner.py",
        "skill_id": skill_id,
        "mode": mode,
        "user_id": user_id,
        "session_id": session_id,
        "exit_code": exit_code,
        "state": state,
        "duration_ms": duration_ms,
        "blocked_reason": blocked_reason,
        "prev_hash": prev_hash,
    }

    line = json.dumps(row, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    flags = os.O_WRONLY | os.O_CREAT | os.O_APPEND
    fd = os.open(OPS_LEDGER_FILE, flags, 0o600)
    try:
        os.write(fd, (line + "\n").encode("utf-8"))
        os.fsync(fd)
    finally:
        os.close(fd)
    try:
        os.chmod(OPS_LEDGER_FILE, 0o600)
    except OSError:
        pass


# ── Summary builder ─────────────────────────────────────────────────

def build_summary(skill_id: str, mode: str, parsed: Optional[dict], exit_code: Optional[int]) -> str:
    """Turn a script's JSON output into a one-line natural-language summary.

    Samuel's reply folds this into his voice. The summary is concrete:
    it says what happened, not what could have happened.
    """
    if parsed is None:
        if exit_code is None:
            return "The script did not run."
        if exit_code == 0:
            return f"I ran '{skill_id}' and it completed cleanly."
        return f"I ran '{skill_id}' and it exited with code {exit_code}."

    state = parsed.get("state", "unknown")

    # Per-skill summary tuning
    if skill_id == "preflight":
        errors = parsed.get("errors", 0)
        warnings = parsed.get("warnings", 0)
        if state == "ready":
            return "The box is ready to install. Zero errors, zero warnings."
        if state == "ready_with_warnings":
            return f"The box is ready to install, with {warnings} warning(s) worth knowing about."
        if state == "not_ready":
            return f"The box is NOT ready to install. {errors} hard blocker(s) and {warnings} warning(s)."
        return f"Preflight state: {state}."

    if skill_id == "fix-firewall":
        if state == "pod_can_reach_host":
            return "Firewall trust rule is in place. Container can reach host services."
        if state == "no_action_needed":
            return "Firewalld already trusts the rootless gateway. Nothing to fix."
        if state == "dry_run_complete":
            return "I diagnosed the firewall. The rootless gateway 169.254.1.0/24 isn't trusted yet — I can fix it but need your word."
        if state == "must_run_as_root":
            return ("I'd need root to apply the firewall trust rule. "
                    "Run this exactly: sudo /s7/skyqubi-private/install/fix-firewall.sh "
                    "— then ask me again and I'll verify it stuck.")
        if state == "firewall_cmd_failed":
            return "I tried to apply the firewall fix but firewall-cmd failed. I rolled back."
        if state == "firewalld_not_active":
            return "Firewalld isn't active on this box — the container/host issue isn't a firewall problem."
        return f"Firewall fix state: {state}."

    if skill_id == "fix-pod":
        if state == "pod_already_running":
            return "The pod is already running. No fix needed."
        if state == "pod_healthy":
            return "I diagnosed the SELinux denial and fixed it. The pod is healthy again."
        if state == "dry_run_complete":
            return "I looked at the pod and identified the fix. I'm not applying it until you give the word."
        if state == "no_avc_denials":
            return "SELinux isn't the problem. The pod is failing for a different reason — I'd need to look at the container logs."
        if state == "nonroot_dry_run_no_audit":
            return ("I can only see part of the picture without root access. "
                    "Run this exactly: sudo /s7/skyqubi-private/install/fix-pod.sh --dry-run "
                    "— then ask me again and I'll have the full diagnosis.")
        return f"Pod fix state: {state}."

    if skill_id == "test-personas":
        if state == "all_responding":
            carli = parsed.get("carli", {}) or {}
            elias = parsed.get("elias", {}) or {}
            return (f"Both personas responded. Carli in {carli.get('latency_ms', '?')} ms, "
                    f"Elias in {elias.get('latency_ms', '?')} ms.")
        if state == "partial":
            carli = parsed.get("carli", {}) or {}
            elias = parsed.get("elias", {}) or {}
            return (f"Only one persona is alive. Carli: {carli.get('state', '?')}, "
                    f"Elias: {elias.get('state', '?')}.")
        if state == "all_down":
            return "Neither Carli nor Elias responded. The persona-chat service is up but the personas are silent — likely an upstream (Ollama, model load) issue."
        if state == "service_unreachable":
            return "I couldn't reach the persona-chat service at all. As of today it's substrate code, not yet wired to a live port — that's expected, not a bug."
        return f"Test-personas state: {state}."

    if skill_id == "pod-stats":
        if state == "ok":
            running = parsed.get("running", 0)
            total = parsed.get("containers", 0)
            cpu = parsed.get("cpu_total_pct", 0)
            mem = parsed.get("mem_total_mib", 0)
            top = parsed.get("top") or {}
            top_part = ""
            if top.get("name"):
                top_part = f" Heaviest container: {top['name']} at {top.get('mem_mib', 0)} MiB."
            return f"{running}/{total} containers running, {cpu}% CPU, {mem} MiB total RAM.{top_part}"
        if state == "pod_not_running":
            return "The pod isn't reporting any containers — it may be stopped or crashed."
        if state == "podman_missing":
            return "Podman isn't installed on this box — I can't read pod stats."
        return f"Pod stats state: {state}."

    if skill_id == "diag":
        # Composite has nested sub-results — surface the headline plus
        # the most useful one-line breakdown.
        pf = parsed.get("preflight", {}) or {}
        fp = parsed.get("fixpod", {}) or {}
        lc = parsed.get("lifecycle", {}) or {}
        pf_state = pf.get("state", "?")
        fp_state = fp.get("state", "?")
        lc_state = lc.get("state", "?")
        lc_pass = lc.get("pass", 0)
        lc_total = lc.get("total", 0)
        lc_part = f"{lc_pass}/{lc_total} tests" if lc_total else f"lifecycle {lc_state}"

        # Map preflight warning identifiers to human suggestions. If a
        # known actionable warning is present, surface the fix path so
        # the user (or Samuel) can act on it directly.
        actionable_hints = {
            "firewall_rootless_trust_missing":
                "ask me to fix the firewall (169.254 trust drift)",
            "selinux_no_fcontext_equiv":
                "ask me to fix the pod (SELinux fcontext rule)",
            "no_avc_source":
                "auditd is off — SELinux root-cause will be blind",
            "ollama_local_unreachable":
                "the local ollama listener is down — try 'sudo systemctl restart ollama'",
            "ollama_bind_too_broad":
                "ollama is exposed to the LAN — bind it to 127.0.0.1 only (see preflight output)",
            "podman_not_rootless":
                "podman is not in rootless mode — security model violation, needs reconfig",
            "no_subuid":
                "subuid mapping missing — run 'sudo usermod --add-subuids 100000-165535 s7'",
        }
        warned = pf.get("warned", []) or []
        hints = [actionable_hints[w] for w in warned if w in actionable_hints]
        hint_part = f" Suggestion: {hints[0]}." if hints else ""

        if state == "healthy":
            return f"Everything is green. Preflight ready, pod healthy, {lc_part} pass."
        if state == "degraded":
            return f"The QUBi is up but not perfect — preflight={pf_state}, pod={fp_state}, {lc_part}. No hard blockers.{hint_part}"
        if state == "failed":
            return f"There's a hard blocker — preflight={pf_state}, pod={fp_state}, {lc_part}. Something needs attention.{hint_part}"
        if state == "error":
            return f"I couldn't get a clean read on at least one component (preflight={pf_state}, pod={fp_state}, lifecycle={lc_state}). I'd need to look at the script output directly."
        return f"Diag state: {state} (preflight={pf_state}, pod={fp_state}, lifecycle={lc_state})."

    if skill_id == "lifecycle-test":
        if state == "verified":
            p = parsed.get("pass", 0)
            t = parsed.get("total", 0)
            return f"All {p} of {t} lifecycle tests pass. The system is green."
        if state == "failed":
            p = parsed.get("pass", 0)
            f_count = parsed.get("fail", 0)
            return f"{f_count} of the lifecycle tests failed. {p} still pass. I'd need to look at which ones."
        return f"Lifecycle state: {state}."

    return f"I ran '{skill_id}' — state: {state}."


# ── Runner ──────────────────────────────────────────────────────────

def run_skill(
    *,
    user_message: str,
    persona: str,
    user_id: str,
    session_id: str,
    catalog_path: Path = CATALOG_PATH,
    subprocess_runner=None,  # for tests: inject a fake that returns (exit_code, stdout, stderr)
) -> SkillResult:
    """End-to-end: match intent → load catalog → check gates → run → build result.

    In tests, pass subprocess_runner to avoid actually firing subprocess.run.
    """
    t0 = time.monotonic()

    # 1. Persona gate
    if persona != ALLOWED_SKILL_CALLER:
        return SkillResult(
            matched=False,
            skill_id=None,
            persona=persona,
            mode="none",
            attempted=False,
            exit_code=None,
            state=None,
            parsed=None,
            stderr_tail="",
            summary=f"Only Samuel may invoke skills. {persona.title()} can't run operator commands.",
            elapsed_ms=int((time.monotonic() - t0) * 1000),
            blocked_reason=f"persona {persona} not allowed to invoke skills",
        )

    # 2. Confirmation override: yes/no routing for pending suggestions.
    # The four cases:
    #   yes + pending  → route to pending.skill_id in apply mode
    #   yes + none     → graceful "no pending suggestion" reply
    #   no  + pending  → graceful "okay, holding off" reply
    #   no  + none     → fall through to normal intent matching
    # The 'yes + none' case used to surface a confusing "I don't have
    # a skill" message; now it's an explicit acknowledgment that the
    # suggestion (if any) has expired.
    confirmation = normalize_confirmation(user_message)
    negative = normalize_negative_confirmation(user_message)

    if confirmation:
        pending = find_pending_suggestion(user_id, session_id)
        if pending:
            skill_id = pending.get("skill_id")
            mode = "apply"
        else:
            # matched=True because the confirmation route DID handle
            # this turn — the user said yes, we explained why there's
            # nothing to apply. That's a meaningful reply, not a
            # fall-through.
            return SkillResult(
                matched=True,
                skill_id=None,
                persona=persona,
                mode="none",
                attempted=False,
                exit_code=None,
                state="no_pending",
                parsed=None,
                stderr_tail="",
                summary="I don't have a pending suggestion to confirm. If I offered to fix something earlier, that offer has expired (5-minute window). Ask me again and I'll take another look.",
                elapsed_ms=int((time.monotonic() - t0) * 1000),
            )
    elif negative:
        pending = find_pending_suggestion(user_id, session_id)
        if pending:
            return SkillResult(
                matched=True,
                skill_id=pending.get("skill_id"),
                persona=persona,
                mode="declined",
                attempted=False,
                exit_code=None,
                state="declined",
                parsed=None,
                stderr_tail="",
                summary=f"Okay, holding off on '{pending.get('skill_id')}'. The suggestion will expire on its own. Tell me when you want to revisit it.",
                elapsed_ms=int((time.monotonic() - t0) * 1000),
            )
        # else: fall through to normal intent matching — 'no' alone
        # without context is just a normal chat turn
        skill_id, mode = match_intent(user_message)
    else:
        # 2b. Intent match
        skill_id, mode = match_intent(user_message)
    if not skill_id:
        return SkillResult(
            matched=False,
            skill_id=None,
            persona=persona,
            mode="none",
            attempted=False,
            exit_code=None,
            state=None,
            parsed=None,
            stderr_tail="",
            summary="I don't have a skill that matches that request.",
            elapsed_ms=int((time.monotonic() - t0) * 1000),
        )

    # 3. Load catalog + verify skill is in it
    try:
        catalog = load_catalog(catalog_path)
    except (FileNotFoundError, ValueError, RuntimeError) as e:
        return SkillResult(
            matched=True,
            skill_id=skill_id,
            persona=persona,
            mode=mode,
            attempted=False,
            exit_code=None,
            state=None,
            parsed=None,
            stderr_tail=str(e),
            summary=f"I can't read the skill catalog: {e}.",
            elapsed_ms=int((time.monotonic() - t0) * 1000),
            blocked_reason=f"catalog unreadable: {e}",
        )

    # Introspection meta-skills share a single per-hour cap.
    if skill_id in ("list-skills", "explain-skill", "recent-activity", "next-action"):
        intro_rl = check_introspection_rate_limit(skill_id)
        if intro_rl:
            duration_ms = int((time.monotonic() - t0) * 1000)
            write_ops_ledger(
                skill_id=skill_id, mode="introspect", user_id=user_id,
                session_id=session_id, exit_code=None, state=None,
                duration_ms=duration_ms, blocked_reason=intro_rl,
            )
            return SkillResult(
                matched=True,
                skill_id=skill_id,
                persona=persona,
                mode="introspect",
                attempted=False,
                exit_code=None,
                state=None,
                parsed=None,
                stderr_tail="",
                summary=f"I've answered too many '{skill_id}' calls this hour. Wait a bit and ask again.",
                elapsed_ms=duration_ms,
                blocked_reason=intro_rl,
            )

    # next-action meta-capability: read recent ledger, suggest one
    # concrete next ask. Solves the blank-page problem for first-touch
    # users who don't know what to ask.
    if skill_id == "next-action":
        summary, meta = build_next_action_summary(user_id, session_id)
        duration_ms = int((time.monotonic() - t0) * 1000)
        write_ops_ledger(
            skill_id="next-action", mode="introspect", user_id=user_id,
            session_id=session_id, exit_code=0, state=meta["state"],
            duration_ms=duration_ms,
        )
        return SkillResult(
            matched=True,
            skill_id="next-action",
            persona=persona,
            mode="introspect",
            attempted=True,
            exit_code=0,
            state=meta["state"],
            parsed=meta,
            stderr_tail="",
            summary=summary,
            elapsed_ms=duration_ms,
        )

    # explain-skill meta-capability: render one catalog entry as prose
    if skill_id == "explain-skill":
        target = detect_explain_target(user_message.lower())
        summary, meta = build_explain_summary(catalog, target or "")
        duration_ms = int((time.monotonic() - t0) * 1000)
        write_ops_ledger(
            skill_id="explain-skill", mode="introspect", user_id=user_id,
            session_id=session_id, exit_code=0, state=meta["state"],
            duration_ms=duration_ms,
        )
        return SkillResult(
            matched=True,
            skill_id="explain-skill",
            persona=persona,
            mode="introspect",
            attempted=True,
            exit_code=0,
            state=meta["state"],
            parsed=meta,
            stderr_tail="",
            summary=summary,
            elapsed_ms=duration_ms,
        )

    # recent-activity meta-capability: read ledger, summarize, no subprocess
    if skill_id == "recent-activity":
        summary, meta = build_recent_activity_summary(limit=5)
        duration_ms = int((time.monotonic() - t0) * 1000)
        write_ops_ledger(
            skill_id="recent-activity", mode="introspect", user_id=user_id,
            session_id=session_id, exit_code=0, state=meta["state"],
            duration_ms=duration_ms,
        )
        return SkillResult(
            matched=True,
            skill_id="recent-activity",
            persona=persona,
            mode="introspect",
            attempted=True,
            exit_code=0,
            state=meta["state"],
            parsed=meta,
            stderr_tail="",
            summary=summary,
            elapsed_ms=duration_ms,
        )

    # list-skills meta-capability: read catalog, return summary, no subprocess
    if skill_id == "list-skills":
        summary = build_skill_list_summary(catalog)
        duration_ms = int((time.monotonic() - t0) * 1000)
        write_ops_ledger(
            skill_id="list-skills", mode="introspect", user_id=user_id,
            session_id=session_id, exit_code=0, state="listed",
            duration_ms=duration_ms,
        )
        return SkillResult(
            matched=True,
            skill_id="list-skills",
            persona=persona,
            mode="introspect",
            attempted=True,
            exit_code=0,
            state="listed",
            parsed={"state": "listed", "count": len(catalog.get("scripts", []))},
            stderr_tail="",
            summary=summary,
            elapsed_ms=duration_ms,
        )

    skill = find_skill(catalog, skill_id)
    if not skill:
        return SkillResult(
            matched=False,
            skill_id=skill_id,
            persona=persona,
            mode=mode,
            attempted=False,
            exit_code=None,
            state=None,
            parsed=None,
            stderr_tail="",
            summary=f"Skill '{skill_id}' is not in the catalog — I'm not authorized to run it.",
            elapsed_ms=int((time.monotonic() - t0) * 1000),
            blocked_reason="skill not in catalog",
        )

    # 4. Emergency stop gate
    stop_reason = check_emergency_stop()
    if stop_reason:
        write_ops_ledger(
            skill_id=skill_id, mode=mode, user_id=user_id, session_id=session_id,
            exit_code=None, state=None, duration_ms=int((time.monotonic() - t0) * 1000),
            blocked_reason=stop_reason,
        )
        return SkillResult(
            matched=True,
            skill_id=skill_id,
            persona=persona,
            mode=mode,
            attempted=False,
            exit_code=None,
            state=None,
            parsed=None,
            stderr_tail="",
            summary=f"I'm in emergency-stop mode. I can't run skills until {EMERGENCY_STOP_FILE} is removed.",
            elapsed_ms=int((time.monotonic() - t0) * 1000),
            blocked_reason=stop_reason,
        )

    # 5. Rate limit gate
    rl_reason = check_rate_limit(skill_id, catalog)
    if rl_reason:
        write_ops_ledger(
            skill_id=skill_id, mode=mode, user_id=user_id, session_id=session_id,
            exit_code=None, state=None, duration_ms=int((time.monotonic() - t0) * 1000),
            blocked_reason=rl_reason,
        )
        return SkillResult(
            matched=True,
            skill_id=skill_id,
            persona=persona,
            mode=mode,
            attempted=False,
            exit_code=None,
            state=None,
            parsed=None,
            stderr_tail="",
            summary=f"I've hit my rate limit on '{skill_id}' — {rl_reason}. Wait and try again.",
            elapsed_ms=int((time.monotonic() - t0) * 1000),
            blocked_reason=rl_reason,
        )

    # 6. Resolve invocation command from catalog
    invocation = skill.get("invocation", {})
    cmd_str = invocation.get(mode)
    if not cmd_str:
        return SkillResult(
            matched=True,
            skill_id=skill_id,
            persona=persona,
            mode=mode,
            attempted=False,
            exit_code=None,
            state=None,
            parsed=None,
            stderr_tail="",
            summary=f"'{skill_id}' has no {mode} command — it may be read-only or apply-only.",
            elapsed_ms=int((time.monotonic() - t0) * 1000),
            blocked_reason=f"no {mode} invocation defined",
        )

    # 7. Run (or mock-run) the subprocess
    timeout = DRY_RUN_TIMEOUT_S if mode == "diagnose" else DEFAULT_TIMEOUT_S
    if subprocess_runner is None:
        try:
            proc = subprocess.run(
                cmd_str,
                shell=True,
                capture_output=True,
                text=True,
                timeout=timeout,
                cwd="/s7/skyqubi-private",
            )
            exit_code = proc.returncode
            stdout = proc.stdout
            stderr = proc.stderr
        except subprocess.TimeoutExpired:
            return SkillResult(
                matched=True,
                skill_id=skill_id,
                persona=persona,
                mode=mode,
                attempted=True,
                exit_code=None,
                state="timeout",
                parsed=None,
                stderr_tail="subprocess timeout",
                summary=f"'{skill_id}' took longer than {timeout} seconds and I stopped it.",
                elapsed_ms=int((time.monotonic() - t0) * 1000),
                blocked_reason="timeout",
            )
        except Exception as e:
            return SkillResult(
                matched=True,
                skill_id=skill_id,
                persona=persona,
                mode=mode,
                attempted=True,
                exit_code=None,
                state="error",
                parsed=None,
                stderr_tail=str(e),
                summary=f"'{skill_id}' failed to run: {e}.",
                elapsed_ms=int((time.monotonic() - t0) * 1000),
                blocked_reason=f"run error: {e}",
            )
    else:
        exit_code, stdout, stderr = subprocess_runner(cmd_str)

    # 8. Parse JSON from stdout (scripts run with --samuel --json; stdout
    #    should be one JSON line)
    parsed = None
    if stdout:
        stdout_tail = stdout.strip().splitlines()[-1] if stdout.strip() else ""
        if stdout_tail:
            try:
                parsed = json.loads(stdout_tail)
            except json.JSONDecodeError:
                parsed = None

    state = parsed.get("state") if parsed else None

    # 9. Build natural-language summary
    summary = build_summary(skill_id, mode, parsed, exit_code)

    # 10. Write ops ledger row
    duration_ms = int((time.monotonic() - t0) * 1000)
    write_ops_ledger(
        skill_id=skill_id, mode=mode, user_id=user_id, session_id=session_id,
        exit_code=exit_code, state=state, duration_ms=duration_ms,
    )

    return SkillResult(
        matched=True,
        skill_id=skill_id,
        persona=persona,
        mode=mode,
        attempted=True,
        exit_code=exit_code,
        state=state,
        parsed=parsed,
        stderr_tail=(stderr or "")[-500:],
        summary=summary,
        elapsed_ms=duration_ms,
    )
