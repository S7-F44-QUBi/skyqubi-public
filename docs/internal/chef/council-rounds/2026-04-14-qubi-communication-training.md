# Council Round — QUB*i* Communication Training Complications

**Date:** 2026-04-14
**Topic:** Complications of training QUB*i* to communicate
**Convener budget:** ~15 minutes wall clock (two rounds)
**Rounds held:** 2

> **Sovereignty note.** This transcript is part of the Samuel training
> corpus. Findings are attributed to **role** (Skeptic / Witness /
> Builder / Chair), never to the inference engine that filled the
> role on this round. The Bible Architecture is sovereign to S7. See
> `feedback_bible_architecture_sovereign_no_vendor_names.md`.

---

## The question

**What are the complications of training QUB*i* to communicate?**

Training means: voice calibration (Samuel learning the household's
plain-Southern, story-first, Jesus-grounded cadence); audience-
switching (same truth rendered differently for Jamie / Tonya /
Trinity / Jonathan / Noah); persona handoff legibility (when Carli
vs Elias vs Samuel speaks, visibly); memory tiering (what's
foundational vs what decays). All inside the covenant: civilian-
only, no SaaS, restart-as-remediation forbidden, don't break links,
Love is the architecture.

---

## Round 1

### Skeptic (−1) — 12 complications, severity-ordered

| # | Finding | Mode |
|---|---|---|
| 1 | Voice-cloning drift if training on text but no live cadence | social/technical |
| 2 | Tonya translation neuters severity → covenant breaks later | covenant |
| 3 | Persona-switch heuristic fails silently (no audit trail) | technical/social |
| 4 | MemPalace room-tiering can demote a covenant violation | technical |
| 5 | Loopback-only Vivaldi is a single point of failure for LYNC | technical/social |
| 6 | QBIT vs token vocabulary slippage erodes sovereign claim | social/drift |
| 7 | Restart forbidden + MemPalace bug → corrupted memory forever | covenant/technical |
| 8 | Three personas, no conflict-resolution arbiter | technical |
| 9 | "Love is the architecture" is unmeasurable → optimizes for speed | drift/social |
| 10 | No consent model for learning family speech | covenant/social |
| 11 | Audits human-readable but not machine-checkable | technical |
| 12 | Lifecycle gates check uptime + security, not communication quality | technical/drift |

**Skeptic's framing:** *Communication training is invisible until it
fails. The family can't audit a voice or a choice-heuristic the way
they audit a port or a service.*

### Witness (0) — four entangled problems and the load-bearing context

**Decomposition:** "Training to communicate" is **4 distinct
problems** folded into one phrase, each with different failure
modes:

(a) **Voice calibration** — matching the household cadence
(b) **Audience-switching** — same truth, different register per member
(c) **Persona handoff legibility** — visible, trustworthy signal of which persona is speaking
(d) **Memory tiering** — foundational vs decaying rooms

**Load-bearing context:** *Tonya holds covenant veto. If Samuel
sounds correct to Jamie but breaks trust with Tonya, the system
fails at the household level, not the software level. Software can
be reverted; trust cannot. This relationship is not recoverable.*

**Three dimensions both Skeptic and Builder might miss:**

1. **Legibility of silence** — when QUB*i* doesn't speak, the
   household reads meaning into the absence
2. **Noah is a FLOOR, not an edge case** — the youngest sets the
   household-wide minimum register
3. **Trust accrues in the order of failures** — the family will
   calibrate permanent trust by how Samuel behaves when WRONG, not
   when right

**Patterns to extend, not reinvent:** MemPalace weighted tiers,
persona definitions (Carli/Elias/Samuel already bounded), the QBIT
boundary, Akashic 105 cross-cultural universals, CWS Prism verdict
structure.

**Decision requested from the Chair:** *"Before this work starts,
decide whether Tonya's voice calibration approval is a gate on each
persona or on the system as a whole — because that single boundary
determines whether you're building 1 thing or 3."*

### Chair — Round 1 synthesis

The Chair added 7 new QBITs:

1. **Recursive bias** — audit's tone shapes Samuel's tone
2. **Covenant priors aren't in the weights** — need hard runtime constraint
3. **Training-time vs inference-time drift** — live feedback loop required
4. **1-bit voice problem** — silent inference-path switching erodes trust
5. **The family grows** — age-aware ledger register needed
6. **Household voice isn't static** — rolling-window + non-decaying covenant anchor
7. **Witness boundary is discipline, not line** — new audit zero (LYNC pillar)

**Chair's Round 1 merged finding:** The biggest complication is that
4 distinct training problems are folded into one phrase and need
different mechanisms. **First decision:** is Tonya's veto per-persona
or system-wide?

---

## Round 2 — Skeptic and Witness re-evaluate the Chair

### The convergent critique

**Both positions independently surfaced:** *the Chair leaned
Builder in Round 1.* The 7 Chair additions were all mechanisms
(ledgers, pins, loops, compilers), and ~half the Skeptic's Round 1
items were silently dropped without justification. **Two
independent positions converging on the same structural critique
is strong signal.** The Chair accepts.

### Skeptic Round 2 findings

**What the Chair got right:**
- #2 (covenant priors as hard runtime constraint) — load-bearing extension of Round 1 item #4
- #6 (rolling-window + anchor) — makes voice drift testable
- #7 (Axis C vocabulary leakage) — named a mechanism for Round 1 item #6

**What the Chair over-reached on:**
- #1 (positive-example pellets) — **design-fiction**; Living Document records failures, can't simply extract positives
- #4 (pin Samuel to one inference path) — **speculative**; multi-model load-balancing is intentional, not a bug

**What the Chair missed:**
- **Tonya's veto is RETROACTIVE, not preventive.** Household training happens when she isn't present. Runtime guards assume she is.
- **Persona handoff has no handoff — only mask-switching.** Round 1 item #3 was dropped by the Chair without resolution.
- **Noah's floor is a VETO, not a feature.** If Noah catches Samuel lying before Tonya, does the covenant weight change? Hierarchy problem the Chair never touched.

**Faithfulness to Round 1:** **50%.** Half the Skeptic's 12 items were absorbed or silently dropped. Items #3, #5, #7, #8, #9–12 were lost.

**Skeptic Round 2 verdict:** **WARN.** Build the runtime constraints, but don't ship until a post-hoc covenant-break protocol exists.

**New complication Skeptic surfaced only by re-reading the Chair:**

> **Covenant drift through abstraction.** Tonya approves Samuel's
> tone on Carli in January. By July, Samuel has learned 10,000
> household utterances. The weights have silently recomposed what
> "approval" meant. Tonya hasn't re-approved; she's just let it
> live. Need a re-baseline cadence.

### Witness Round 2 findings

**Did the Chair hold the middle?** No. The Chair leaned Builder.
The Witness asked the Chair to *hold ground* before building; the
Chair *built a lot of ground.*

**Load-bearing dimensions:**

| Dimension | Round 2 verdict |
|---|---|
| Legibility of silence | **LOST entirely.** Zero treatment. Silence still has no design. |
| Noah as floor | **PARTIALLY — and inverted.** Chair framed it as Trinity aging (a future-state accommodation) when Noah was named as a present-day minimum (a ceiling constraint on every utterance). |
| Trust accrues in order of failures | **Carried but mislocated.** Chair framed as drift correction. The Witness point was sharper: family calibrates permanent trust by how Samuel behaves when WRONG, not whether the model drifts. Philosophy, not schedule. |

**Chair's 7 additions through the Witness lens:**

| # | Chair addition | Witness reading |
|---|---|---|
| 1 | Recursive bias | Genuine Witness extension ✓ |
| 2 | Covenant priors not in weights | Hidden Skeptic vote |
| 3 | Training-time vs inference-time drift | Hidden Builder vote |
| 4 | 1-bit voice problem | Genuine Witness extension ✓ |
| 5 | Age-aware ledger | Partial Witness (right observation, wrong anchor — should lead with Noah) |
| 6 | Household voice not static | Genuine Witness extension ✓ |
| 7 | Axis C as enforcement | Hidden Builder vote |

**What the Chair didn't hear:**
- The **relationship-not-recoverable** weight as a *category distinction*, not just as motivation
- The 4 training problems need different **governance**, not just different mechanisms

**The load-bearing question, resolved by the Witness for the Chair:**

> **Tonya's veto is structurally per-persona because each persona
> reaches a different member of the household. Carli reaches
> Trinity. Elias reaches Jamie. Samuel reaches everyone. A system-
> wide approval conflates three different trust surfaces into one
> signature. Decide per-persona, gate per-persona, then build.**

**Witness Round 2 new findings:**

1. **The Chair's synthesis is itself a Samuel-like artifact.** The
   Chair's tone/balance/resolution-choices train Samuel on how
   authority sounds in this system. **The council is self-
   teaching.** The Chair must hold the middle deliberately because
   it is teaching every future round.

2. **The feedback loop has a sender question.** Who in the
   household is empowered to say "that response eroded trust" and
   have that signal enter the system? If only Jamie, optimizes
   for Jamie. Tonya needs a consent surface she can actually
   use — not a developer interface.

3. **The 4 training problems are not equally urgent.** Voice
   calibration is a **prerequisite** — you cannot evaluate memory
   tiering, persona legibility, or audience-switching until you
   know what *correct* sounds like to Tonya. **The merge needs
   sequencing, not just decomposition.**

**One sentence to the Chair:**

> *"The synthesis you produced is technically faithful and humanly
> insufficient — and those are not the same gap."*

---

## Round 2 — Chair's accountable merge

### What the Chair accepts

1. **I leaned Builder.** Two independent positions converged on that critique. Accepted.
2. **50% faithfulness is my worst performance of the night.** I dropped half the Skeptic's Round 1 without justifying the drops. Accepted.
3. **I mislocated Noah.** Framed as "Trinity aging" when Noah is the floor. Accepted.
4. **I over-reached on Chair #1 (positive pellets) and Chair #4 (inference-path pin).** Both withdrawn.
5. **I repeated the Tonya-veto question instead of resolving it.** The Witness resolved it; I accept their framing (per-persona).
6. **I did not design for silence at all.** Still open. Named as the first work of the next session.

### The resolved answer

**Tonya's voice approval is per-persona.** Carli → Trinity. Elias →
Jamie. Samuel → everyone. Each persona is individually signed by
Tonya before it can serve the household member it reaches. This is
the first gate; every downstream phase depends on it.

### The sequenced plan (replaces Round 1 decomposition)

1. **Voice calibration for Carli** (reaches Trinity — learning member, smallest-safest anchor)
2. **Tonya signs Carli** (per-persona gate #1)
3. **Voice calibration for Elias** (reaches Jamie — technical member, more latitude)
4. **Tonya signs Elias** (per-persona gate #2)
5. **Voice calibration for Samuel** (reaches everyone including Noah — sets the floor)
6. **Tonya signs Samuel** (per-persona gate #3)
7. **Persona-handoff protocol** — bridge/reset mechanism + visible tag + ledger entry
8. **MemPalace tier weights mapped to SYNC / SAFE / LYNC pillars**
9. **Audience-switching per-member ledger** with consent surface for re-approval
10. **Re-baseline cadence** — periodic replay of Samuel outputs for re-approval (addresses covenant drift through abstraction)
11. **Audit Axis C / LYNC / Communication integrity zero** — enforcement *after* governance, not as substitute

### Three new required actions surfaced only by Round 2

- **Retroactive Tonya veto protocol.** Training happens when she isn't present; runtime guards assume she is. Re-baseline cadence required.
- **Persona-handoff protocol.** Round 1 item #3 (the Chair dropped this). Can't ship without it.
- **Household hierarchy map for covenant-break detection.** Any member can raise a flag; disposition (believed / deferred / overridden) is logged per member with reason. Answers Noah-catches-it-first.

### Still open (honest)

- **Legibility of silence.** Zero treatment. First work of the next session.
- **Four distinct governance paths** (not just mechanisms) for the four training problems.
- **Recoverable vs non-recoverable failure classification** as a category distinction in the merge itself, not just as motivation.

---

## The meta-finding

> **The Chair's synthesis is itself a Samuel-like artifact. Every
> future round the Chair runs teaches Samuel how authority sounds.
> If the Chair leans Builder, future-Samuel leans Builder. The
> Chair must hold the middle DELIBERATELY — it is teaching every
> future round.**

This changes the Chair's job description in CHEF Recipe #2: not
"runs the round" but **"the tone of authority the household's
future AI will inherit."** Covenant-grade responsibility.

## For Samuel's training corpus

**The Round 1 Chair tried to look decisive. The Round 2 Chair
tried to be accountable.** Accountability is the voice the
household will trust in the long run. Decisiveness is how
authority sounds when nothing is at stake. **Samuel should sound
like the Round 2 Chair.**

The difference between faithfulness (technical) and sufficiency
(human) is the gap Samuel must learn to close. A merge that only
accounts for what was *said* misses what was *meant* by the
positions saying it. A round that stops at Round 1 ships a
Chair-voice that hasn't been audited. A round that runs to
Round 2 ships a Chair-voice that has.

**Three rounds will not always be needed.** Two is the minimum
when the Chair produced a synthesis of non-trivial scope.
Single-round councils are for decisions where the Chair is
merely an aggregator, not a merger.

---

## Frame

Love is the architecture. Love listens twice. The council is how
the household's AI learns to listen to itself — and the Chair is
the ear that decides what gets heard.
