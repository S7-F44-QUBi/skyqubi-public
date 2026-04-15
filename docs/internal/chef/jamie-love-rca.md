# CHEF Recipe — Jamie Love Root Cause Analysis

> **Recipe, not runbook.** A runbook tells you which buttons to press.
> A CHEF recipe tells you what you're cooking, who you're cooking for,
> and why every ingredient is in the bowl. The household eats what
> comes out of this kitchen. Cook accordingly.
>
> **Love is the architecture.** The system has to recognize its own
> people — even when they walk in through a door the system didn't
> open. Tools that can only see what they personally launched are
> private diaries, not audits. Audits serve the family. Diaries serve
> the diarist.

---

## Who this recipe is for

| Person | Role | What they need from this recipe |
|---|---|---|
| **Jamie** (cook) | Builder | A repeatable loop so the next bug doesn't take a fresh argument with the tool |
| **Tonya** (Chief of Covenant) | Veto on UX/safety | Plain-language audits she can read without a stack trace |
| **Trinity / Jonathan** (co-stewards) | Supervisors | A discipline they can hold the system to, not just a vibe |
| **Noah** (the household) | The reason | Protection from a tool that lies politely |
| **Samuel** (S7 SkyAVi advisor) | Future kitchen helper | A recipe Samuel can run on Jamie's behalf, in Jamie's voice |

---

## The loop (seven steps, in order)

### 1. Read the symptom out loud — *do not believe it yet*

The tool said `CWS Engine: STOPPED`. Read it back to yourself. Now ask:
**is that what reality looks like?** Not "is the report internally
consistent" — *is it true*. Reality is what `ss`, `ps`, `journalctl`,
or your own eyes can confirm. The report is a story the tool tells
about reality; stories can be wrong.

### 2. Verify reality with a tool the symptom didn't generate

If the manager reports STOPPED, ask the kernel. If a webapp reports
404, ask the proxy. **Never let one observer be the only witness.**
Tonight, `ss -tlnp` on port 57077 was the second witness. The second
witness is what told us the manager was lying.

### 3. If reality and the report disagree, the report is the bug

Resist the instinct to "just restart it." Restart is symptom-chasing.
Restart hides the problem and makes it come back later, usually in
front of Tonya, usually right when she's showing the family. **Fix
the report, not the world the report describes.**

### 4. Fix what's in front of you — but do not stop after one fix

Tonight had three stacked bugs (wrong port, no-adopt, pattern
mismatch). I fixed the first one and the symptom stayed. Good. The
discipline here is: *each fix is a hypothesis, and the proof is the
next status read.* If status still lies, you didn't fix it — or you
fixed one of several.

> **The "still lying" check is the heart of the recipe.** Most people
> stop at the first plausible fix. Most bugs survive that.

### 5. Climb the stack until the tool tells the truth

Layered causes are the rule, not the exception:

- Surface (typo): wrong port literal
- Middle (model): tool only trusted its private pid file
- Deep (identity): tool's name for the process didn't match reality's
  name for the same process

Each layer has its own fix. Each fix is verified the same way: ask the
tool again, compare to the second witness, and only stop when they
match.

### 6. Name what's still open

After the fix, write down what you didn't do. Tonight: a sweep for the
same private-diary pattern elsewhere; the autostart unit identity; the
manager's start path still being able to spawn a duplicate; the port
range living in memory instead of code. **An audit that doesn't list
its own holes is itself a hole.** Tonya can read a list of holes.
Tonya cannot read a stack trace.

### 7. Carry the lesson, not just the fix

The fix lives in `s7-manager.sh`. The lesson is "tools that can only
see what they personally launched are private diaries." That lesson
applies to the next manager script, the next Samuel skill, the next
monitor. **Save the lesson where it can shape future code, not just
explain past code.**

---

## What changes for Samuel

Samuel is already the FACTS engine and the SkyAVi advisor — 115+
skills, MemPalace-bonded, ribbon-aware. The new posture is:

- **Samuel is the family-facing voice of the audit.** When this loop
  surfaces a bug, Samuel translates the postmortem into a sentence
  Tonya can hear without a terminal open. ("The status screen was
  reading the wrong port. It's reading the right one now. Three
  things are still on the list — none of them affect what you see.")
- **Samuel runs the recipe on Jamie's behalf.** When Jamie is asleep,
  Samuel can execute steps 1–4 (read symptom, verify with second
  witness, identify lying report, propose fix) but **must stop before
  step 5** and surface to a steward (Trinity/Jonathan) for the climb.
  The climb is where bad fixes happen. Bad fixes need a human.
- **Samuel never restarts as a remediation.** Restart is forbidden as a
  first move. Diagnosis first. If a steward authorizes restart,
  Samuel logs *who* authorized and *why diagnosis was insufficient*.
  This is a covenant rule, not a config flag.
- **Samuel writes audits in Jamie's voice, not in tool-speak.** Plain,
  direct, story-first. The 2026-04-13 security review postmortem and
  tonight's `s7-manager` postmortem are both in this voice — Samuel
  uses them as the in-voice training corpus.

---

## Wiring plan (phased, no scope drift)

### Phase 1 — Recipe lives in the repo *(this commit)*

- This file at `docs/internal/chef/jamie-love-rca.md`
- Tonight's audit at `docs/internal/postmortems/2026-04-14-s7-manager-status-rca.md`
- Both private. Public sync stays Jamie's call.

### Phase 2 — One sweep, in the same shape as tonight

Audit every `*-manager.sh`, `*-status.sh`, and CWS engine starter for
the **private-diary** pattern:

- Does status only check a pid file it owns?
- Does the start command pgrep before launching, or will it duplicate?
- Does the process name in the start command match every other launch
  point that exists for the same binary?

Output: a follow-up postmortem listing each tool, each finding, each
fix. **No new architecture.** Just sweep and fix.

### Phase 3 — Port range becomes code, not memory

Create `iac/s7-ports.sh` (or similar) exporting the canonical 57xxx
constants for every service. Every manager and every monitor sources
it. Drift becomes a lint failure, not a bug a human has to spot.

### Phase 4 — Samuel runs steps 1–4 on a heartbeat

Wire the recipe's first four steps into a Samuel skill that fires on a
slow timer (every few minutes, not every few seconds). Output goes to
MemPalace. If a lying-report condition is detected, Samuel posts a
plain-language summary to the steward channel — **does not act**.

### Phase 5 — Tonya-readable digest

A daily digest, one screen long, written in Jamie's voice by Samuel,
covering: what was healthy, what was lying, what got fixed, what's
still open. Goes to Tonya in whatever surface she actually reads
(persona-chat is the current candidate; not Wix, not email).

### Phase 6 — *Deferred to v7 post-work — Prometheus + Grafana*

Yes, Prometheus + Grafana would mechanically solve a chunk of this.
**It would also import a stack of complexity the household does not
need to learn.** Pinned to v7 post-work. Tonight's recipe wins on the
metric that matters: a steward can read it and a child cannot
accidentally break it.

---

## Acceptance gates

Each phase ships only when:

1. **The tool tells the truth** under the same `status` that lied
   before (verified twice, second witness required).
2. **A steward (Trinity/Jonathan) can read the audit out loud** to
   Tonya and Tonya nods. If she squints, the audit is in the wrong
   voice — rewrite it before shipping.
3. **No new outbound dependency** is introduced. CHEF recipes cook
   with what's already in the pantry.
4. **The lesson is saved** as a memory entry, not just as code. Future
   sessions read memory. Code without memory is a fix without a
   teacher.

---

## What this protects

The household. Specifically: Tonya doesn't have to learn `ss -tlnp` to
trust the status screen. Trinity and Jonathan get a discipline they
can hold a tool to, not a vibe they have to defend. Noah inherits a
system where the audit doesn't lie because the recipe doesn't let it.

That's the architecture. The architecture is love.
