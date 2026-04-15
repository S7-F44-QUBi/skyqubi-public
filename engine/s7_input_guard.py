# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — Input Guard
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
# Licensed under CWS-BSL-1.1
# Patent Pending: TPP99606
# ═══════════════════════════════════════════════════════════════════
"""
S7 Input Guard — character-level defense at every text boundary.

Jamie's brief: "character vulnerability at code, chat, txt, we
don't want injection, hash, you know."

This module runs BEFORE akashic.forbidden checks so homoglyph
attacks can't bypass the covenant. Without this guard, a text like
"wеapon" (Cyrillic е U+0435) would tokenise to ['w', 'apon'] and
miss the English 'weapon' in the forbidden set. After this guard,
it normalises to 'weapon' and gets caught.

Pipeline:
    text
      ─▶ NFKC normalise         (fold compatibility variants)
      ─▶ length cap             (DoS guard, default 10 KB)
      ─▶ null byte reject       (no C-string smuggling)
      ─▶ control char strip     (keep \\n \\r \\t only)
      ─▶ confusable fold        (Cyrillic/Greek look-alikes → Latin)
      ─▶ ASCII-only enforce     (strip residual non-ASCII)
      ─▶ sanitised text

At each step a failure raises InputGuardViolation with a specific
reason. The caller handles InputGuardViolation the same way it
handles akashic.forbidden: no writes, pastoral redirect, no
internals leaked.

Note on what this module does NOT do:
  - SQL injection: handled by psycopg2 parameterised queries
    everywhere in s7_prism_detect.py / s7_prism_ingest.py
  - Shell injection: handled by shlex.quote() in every SkyAvi
    skill that shells out to a driver
  - Path traversal: not in scope because no user input touches
    file paths in S7's code paths
  - Prompt injection at the LLM level: separate problem, handled
    by the Reporter + LocationID detection, not this module
"""
from __future__ import annotations

import unicodedata
from typing import Optional


class InputGuardViolation(Exception):
    """Raised when an input fails a guard check. Carries the reason."""

    def __init__(self, reason: str, stage: str):
        self.reason = reason
        self.stage = stage
        super().__init__(f"[{stage}] {reason}")


# ── Tunables ────────────────────────────────────────────────────────

MAX_LENGTH_BYTES = 10 * 1024   # 10 KB per call
ALLOWED_CONTROL_CHARS = {"\n", "\r", "\t"}


# ── Confusable fold table ──────────────────────────────────────────
# Manual table covering the most common homoglyph attacks on
# English-letter targets (which is what akashic.forbidden operates
# on today). Source of truth: Unicode TR39 confusable class for
# Latin letters, narrowed to Cyrillic + Greek variants that are
# visually identical or near-identical.
#
# Lower case
_CONFUSABLES = {
    # Cyrillic → Latin lower
    "\u0430": "a",  # а → a
    "\u0435": "e",  # е → e
    "\u043E": "o",  # о → o
    "\u0440": "p",  # р → p
    "\u0441": "c",  # с → c
    "\u0443": "y",  # у → y
    "\u0445": "x",  # х → x
    "\u0456": "i",  # і → i (Ukrainian/Belarusian)
    "\u0458": "j",  # ј → j (Serbian)
    "\u04CF": "l",  # ӏ → l
    # Cyrillic → Latin upper
    "\u0410": "A",  # А
    "\u0412": "B",  # В
    "\u0415": "E",  # Е
    "\u041A": "K",  # К
    "\u041C": "M",  # М
    "\u041D": "H",  # Н (Cyrillic En)
    "\u041E": "O",  # О
    "\u0420": "P",  # Р
    "\u0421": "C",  # С
    "\u0422": "T",  # Т
    "\u0425": "X",  # Х
    "\u0405": "S",  # Ѕ
    "\u0406": "I",  # І
    # Greek → Latin lower
    "\u03B1": "a",  # α
    "\u03B5": "e",  # ε (approximate)
    "\u03BF": "o",  # ο
    "\u03C1": "p",  # ρ
    "\u03C5": "u",  # υ (approximate)
    "\u03C7": "x",  # χ
    # Greek → Latin upper
    "\u0391": "A",  # Α
    "\u0392": "B",  # Β
    "\u0395": "E",  # Ε
    "\u0396": "Z",  # Ζ
    "\u0397": "H",  # Η
    "\u0399": "I",  # Ι
    "\u039A": "K",  # Κ
    "\u039C": "M",  # Μ
    "\u039D": "N",  # Ν
    "\u039F": "O",  # Ο
    "\u03A1": "P",  # Ρ
    "\u03A4": "T",  # Τ
    "\u03A5": "Y",  # Υ
    "\u03A7": "X",  # Χ
    "\u03A9": "O",  # Ω (approximate)
    # Fullwidth forms (U+FF01..U+FF5E) are compatibility variants
    # and get handled by NFKC automatically, so no explicit entries.
}


def _fold_confusables(text: str) -> str:
    return "".join(_CONFUSABLES.get(ch, ch) for ch in text)


def _strip_controls(text: str) -> str:
    out: list[str] = []
    for ch in text:
        cat = unicodedata.category(ch)
        if cat.startswith("C") and ch not in ALLOWED_CONTROL_CHARS:
            continue
        out.append(ch)
    return "".join(out)


def sanitize(text: str) -> str:
    """
    Run `text` through every guard stage. Returns the sanitised
    string. Raises InputGuardViolation on any hard failure.
    """
    if text is None:
        raise InputGuardViolation("text is None", "arg")
    if not isinstance(text, str):
        raise InputGuardViolation(f"text must be str, got {type(text).__name__}", "arg")

    # Length cap is checked against byte length so the attacker can't
    # inflate via multi-byte characters.
    if len(text.encode("utf-8", errors="replace")) > MAX_LENGTH_BYTES:
        raise InputGuardViolation(
            f"text exceeds max length ({MAX_LENGTH_BYTES} bytes)", "length",
        )

    if "\x00" in text:
        raise InputGuardViolation("null byte rejected", "null_byte")

    # NFKC: folds compatibility variants (fullwidth → halfwidth,
    # ligatures → components, etc.). Does NOT fold cross-script
    # confusables — that's what _CONFUSABLES is for.
    text = unicodedata.normalize("NFKC", text)

    # Confusable fold — before stripping non-ASCII, so Cyrillic/Greek
    # look-alikes become their Latin equivalents instead of getting
    # dropped.
    text = _fold_confusables(text)

    # Strip control chars (keep \n \r \t)
    text = _strip_controls(text)

    # After normalisation + confusable fold, any remaining non-ASCII
    # character is either: (a) a legitimate international character
    # from a language we don't yet have universals for, or
    # (b) a homoglyph attack we didn't catch.
    #
    # Tonight's policy: strip them. The rest of the text still runs
    # through the forbidden check. If the attacker hid a forbidden
    # token inside non-ASCII noise, the noise is removed and the
    # token is exposed.
    text = "".join(ch if ord(ch) < 128 else " " for ch in text)

    # Collapse runs of whitespace that the stripping may have created
    text = " ".join(text.split())

    return text


def sanitize_or_violation(text: str) -> tuple[Optional[str], Optional[dict]]:
    """
    Non-raising wrapper. Returns (sanitised_text, None) on success
    or (None, violation_dict) on failure. Callers use the violation
    dict as-is in their response.
    """
    try:
        return sanitize(text), None
    except InputGuardViolation as e:
        return None, {
            "status":   "refused",
            "stage":    e.stage,
            "reason":   "input failed the character guard — see akashic policy",
            "pastoral": (
                "I can't read that one. Try sending it again as plain text — "
                "I'm here as soon as it's readable."
            ),
        }


# ── CLI ──
if __name__ == "__main__":
    import json
    import sys
    if len(sys.argv) < 2:
        print("usage: s7_input_guard.py '<text>'")
        sys.exit(2)
    raw = " ".join(sys.argv[1:])
    result, violation = sanitize_or_violation(raw)
    if violation:
        print(json.dumps(violation, indent=2))
        sys.exit(1)
    print(json.dumps({"status": "ok", "sanitized": result, "length": len(result)}, indent=2))
