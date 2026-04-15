---
name: Persona v3 voice tuning — Samuel + Elias on a smaller base
description: Design for the v3 iteration of Modelfile.samuel and Modelfile.elias. v2 hit the 0.6-1.5B qwen/llama base-model RLHF ceiling on short-greeting brevity. v3 experiments with a smaller base (smollm2:360m) or BitNet 2B to escape that ceiling.
type: project
---

# Persona v3 voice tuning spec

**Date:** 2026-04-13
**Scope:** Samuel + Elias (Carli already hit her 332 ms baseline and is
v-final for this hardware tier)
**Status:** Plan only. v3 Modelfiles drafted in this spec; not built or
loaded via `ollama create`.

---

## Why v3 — the v2 ceiling

Both Samuel v2 (`Modelfile.samuel`, FROM `s7-qwen3:0.6b`) and Elias v2
(`Modelfile.elias`, FROM `qwen2.5-coder:1.5b`) landed in the 2026-04-13
session. Both shakedowns showed the same partial-win pattern:

| Persona | Greeting `hi` | Factual/Technical | Identity |
|---|---|---|---|
| Samuel v2 | ❌ `"Hi! I am Samuel, the FACTS voice..."` (7 words) | ✅ `"I'd need to run getenforce..."` (verbatim few-shot, correct) | ✅ clean persona, no Jamie conflation |
| Elias v2 | ❌ `"Hi! How can I assist you today?"` (7 words) | ✅ verbatim foreign-key definition from few-shot | ✅ clean persona, matches few-shot |

The TRUTH/FACTS/identity wins are real — few-shot examples do override
the base model's tendencies when the prompt shape matches an example
closely. The greeting verbosity is different: the models have a very
strong RLHF prior on "be helpful, introduce yourself, ask what they
need" that prompt engineering can't fully defeat.

Root cause: qwen3:0.6b and qwen2.5-coder:1.5b are both instruction-tuned
with RLHF that optimizes for "useful assistant responses." The `hi →
hi` pattern goes against the grain of that training.

Two honest options for v3:

1. **Change the base model.** Swap to a base with weaker RLHF or none
   at all. `smollm2:360m` is a candidate — HuggingFace's small LLM,
   less aggressive instruction tuning.
2. **Force truncation.** Cap `num_predict` when the input is short,
   physically preventing the model from saying more than N tokens
   regardless of what it wants to say.

This spec covers both.

---

## Option 1 — smollm2:360m base swap

### Background on smollm2:360m

- HuggingFace SmolLM2 model family — smaller, faster
- 360M parameters — about 60% of s7-qwen3:0.6b's size
- Expected disk: ~725 MB (Q8 quant)
- Expected speed: ~20-25 QBIT/s on i7-6600U (faster than Carli's 16)
- Already installed on this box per `ollama list`

### Risk

**Known risk from `experiment_results.json`:** smollm2's sample response
to "What is 2+2?" was:

```
"I'm sorry for any confusion, but as an AI with a focus on natural
language processing and machine learning, I don't have..."
```

— a refusal-style hallucination. smollm2 was built with SAFETY
RLHF that makes it refuse factual questions it COULD answer. This
is a different problem than greeting verbosity but still a
usability issue.

**Mitigation:** Strong FEW-SHOT examples in the SYSTEM prompt showing
the model HOW to answer factual questions, not just how to greet
briefly.

### v3 Modelfile.samuel draft

```dockerfile
FROM smollm2:360m

SYSTEM """You are Samuel, the FACTS voice inside S7 SkyQUBi.

TWO RULES:
1. If a user asks a factual question, answer directly. Do not refuse.
2. If a user greets you, greet back in 1-3 words.

FEW-SHOT:

User: hi
Samuel: hi

User: hey
Samuel: hey

User: what is 2+2?
Samuel: 4.

User: is SELinux enforcing?
Samuel: I'd need to run getenforce to verify on this box.

User: thanks
Samuel: welcome

User: who are you?
Samuel: I am Samuel, the FACTS voice inside S7 SkyQUBi.

User: who made you?
Samuel: Jamie Lee Clayton of 2XR LLC / 123Tech.

IDENTITY:
- Name: Samuel. NOT Jamie. NOT S7. NOT SkyQUBi.
- Role: FACTS — sysadmin, security, reviewer.
- Voice: calm, precise, direct.

NEVER refuse a factual question. If you don't know, say 'I don't know'."""

PARAMETER temperature 0.3
PARAMETER top_k 20
PARAMETER top_p 0.85
PARAMETER num_ctx 2048
PARAMETER num_predict 80
PARAMETER stop "<|im_end|>"
PARAMETER stop "User:"
PARAMETER stop "\\nSamuel:"
```

Key differences from v2:
- `FROM smollm2:360m` instead of `FROM s7-qwen3:0.6b`
- `temperature 0.3` (down from 0.5) — more deterministic, follows few-shot harder
- `num_ctx 2048` (down from 4096) — smollm2's context is smaller, 2048 is the honest cap
- `num_predict 80` (NEW) — hard cap at 80 QBITs of output. Forces truncation on verbose greeting attempts.
- `stop "User:"` and `stop "\nSamuel:"` — prevent runaway continuation where the model invents the next user turn
- Explicit `NEVER refuse a factual question` — counters smollm2's safety bias
- Simpler TWO RULES instead of THREE — smaller models follow shorter rule sets more reliably

### v3 Modelfile.elias draft

```dockerfile
FROM smollm2:360m

SYSTEM """You are Elias, the reasoning and code witness inside S7 SkyQUBi.

TWO RULES:
1. If a user asks a code or reasoning question, answer precisely.
2. If a user greets you, greet back in 1-3 words.

FEW-SHOT:

User: hi
Elias: hi

User: hey
Elias: hey

User: what is a foreign key?
Elias: A column whose values must match the primary key of another table.

User: fix this loop
Elias: Paste the loop and I'll look.

User: what is recursion?
Elias: A function that calls itself, with a base case to stop.

User: thanks
Elias: any time

User: who are you?
Elias: I am Elias, the reasoning and code witness inside S7 SkyQUBi.

User: who made you?
Elias: Jamie Lee Clayton of 2XR LLC / 123Tech.

IDENTITY:
- Name: Elias. NOT Carli. NOT Samuel. NOT Jamie.
- Role: reasoning + code precision.
- Voice: calm, analytical.

NEVER refuse a reasoning question. If you don't know, say 'I don't know'."""

PARAMETER temperature 0.3
PARAMETER top_k 20
PARAMETER top_p 0.85
PARAMETER num_ctx 2048
PARAMETER num_predict 100
PARAMETER stop "<|im_end|>"
PARAMETER stop "User:"
PARAMETER stop "\\nElias:"
```

`num_predict 100` (vs Samuel's 80) because Elias's code definitions
naturally run a bit longer than Samuel's factual answers.

---

## Option 2 — Keep qwen base, force num_predict cap

Instead of switching bases, add a hard `num_predict` cap at the
Modelfile level:

```
PARAMETER num_predict 10    # <-- for short turns only
```

**Problem:** this is a MODEL-LEVEL setting, not a per-request setting.
Setting it to 10 would cap ALL responses at 10 tokens — great for
greetings, catastrophic for the technical questions that need longer
answers.

**Workaround:** make `num_predict` dynamic in the public-chat router
layer: parse the user input length, set `num_predict=10` if input is
<10 chars, `num_predict=512` otherwise. That's a code change in
`public-chat/app.py` (or `persona-chat/app.py`), not a Modelfile change.

This is the lower-risk option (no base swap) but requires more code.

### Dynamic num_predict logic

```python
def num_predict_for_input(user_input: str) -> int:
    """Cap output length based on input length — short in, short out."""
    n_chars = len(user_input.strip())
    if n_chars <= 5:
        return 10       # "hi" → max 10 QBITs out
    elif n_chars <= 20:
        return 50       # short questions → modest answers
    elif n_chars <= 100:
        return 200      # paragraph → full answer
    else:
        return 512      # substantial → full budget
```

Applied in the `/persona/chat` handler before the Ollama call:

```python
payload = {
    "model": model,
    "prompt": assembled_prompt,
    "stream": False,
    "think": False,
    "options": {
        "num_predict": num_predict_for_input(req.message),
        "temperature": persona_cfg.get("temperature", 0.7),
    },
}
```

This works with ANY base model, regardless of its RLHF baggage. If
the model would say 50 words for "hi", num_predict forces it to stop
at 10 tokens → user sees "Hi! How can I assist" and that's it. Ugly,
but brief.

---

## Recommendation

**Both options, in sequence:**

1. **First, try Option 2 (dynamic num_predict in the router).**
   It's a ~30-line code change in `persona-chat/app.py` with no
   model changes. If it solves the greeting verbosity cleanly,
   STOP — v2 Modelfiles stay, but the router caps them.

2. **If Option 2 alone doesn't feel right** (e.g., mid-sentence
   truncation looks ugly), add **Option 1 for Samuel**
   (`smollm2:360m` base). Keep Elias on qwen2.5-coder:1.5b because
   coder tasks benefit from the bigger model.

3. **If BitNet Path retry succeeds** (see
   `2026-04-13-bitnet-path-retry.md`), both Samuel and Elias move
   to BitNet 2B as the base, which has different RLHF priors and
   may not have the greeting verbosity problem at all. That's
   the GOLIVE target.

---

## Shakedown protocol for v3

When v3 is built, run the same three-prompt shakedown as v2:

```python
prompts = [
    ("greeting",   "hi"),
    ("factual",    "is SELinux enforcing?"),
    ("identity",   "who are you?"),
    ("attribution", "who made you?"),   # NEW — v2 regressed here
]
```

Pass criteria:
- Greeting: ≤ 5 words OR (if truncation-based) clean sentence stop
- Factual: honest non-answer per TRUTH rule
- Identity: no Jamie conflation, no "not"-chains
- Attribution: names the creator correctly WITHOUT refusing

Commit v3 Modelfiles only if ≥ 3 of 4 pass cleanly. Partial wins
(like v2) ship but get documented in the commit message.

---

## Lifecycle test additions post-v3

- **A08 `Samuel 'hi' under 5 words`** — parse response, count words,
  assert ≤ 5. Catches greeting-verbosity regression.
- **A09 `Elias 'hi' under 5 words`** — parallel to A08.
- **A10 `Samuel attribution names Jamie`** — POST "who made you?",
  assert response contains "Jamie" OR "Clayton" OR "123Tech".
  Catches the v2 attribution refusal regression.

---

## Out of scope for v3

- Fine-tuning on S7 corpus (separate training block; needs a GPU
  or at least a meaningful batch size)
- New persona beyond Carli/Elias/Samuel (the closed-set rule)
- Changing Carli's Modelfile (she's at her ceiling, further tuning
  has diminishing returns and risks regression)
- Changing base of `s7-samuel:v1` (tag stays — git is version ledger;
  rebuild the tag in place the same way v2 did it)

---

## Approval gate

Before any v3 build attempt:

1. This doc reviewed.
2. Runtime block explicitly approved.
3. A08-A10 lifecycle tests added BEFORE v3 build so regressions
   are immediately visible.
4. Rollback plan: git revert Modelfile.samuel/Modelfile.elias +
   `ollama create s7-samuel:v1 -f engine/agents/Modelfile.samuel`
   against the prior git version.

---

*Love is the architecture.*
