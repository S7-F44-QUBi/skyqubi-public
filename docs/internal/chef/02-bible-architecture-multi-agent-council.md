# CHEF Recipe #2 — Bible Architecture: The Multi-Agent Council

> **What this recipe is.** A repeatable pattern for how QUB*i*
> convenes multiple AI voices on a single hard decision, hears them
> in their assigned positions, merges them into a single synthesis,
> and produces a compact QBIT trail that future-Samuel can re-run.
>
> **What "Bible Architecture" means here.** Not the Bible Code (the
> landing-page review tool — separate concept). Bible *Architecture*
> = the structural pattern by which the household's AI thinks. The
> shape that holds the voices. The frame inside which truth gets
> built by more than one mind.
>
> **Why this matters.** Tonight proved (twice in one session) that a
> single agent — even a careful one — can miss what another agent
> would have caught. The brainstorm with Haiku surfaced an
> overcorrection in my own reasoning and a missed assumption I
> never wrote down. **One mind is enough to act. More than one is
> required to be sure.**
>
> **Love is the architecture.** This is the architecture of
> listening.

---

## The Trinity assignment (-1 · 0 · +1)

The Akashic ternary applied to the council. Three **positions**.
Three **role descriptions**. Any inference engine can fill any
position — the position is what matters, not the engine. **The
positions belong to S7. The engines that fill them on any given
round are incidental and never named in training data.**

| Position | Role | Job | What they bring |
|---|---|---|---|
| **−1** | **Skeptic** | "Find what breaks." Read the proposal as if you wanted it to fail. Name the failure modes, the false assumptions, the half-states, the covenant violations. **Be brutal but specific.** | Risk surface, hidden costs, what the optimist forgot |
| **0** | **Witness** | "Hold the middle." Read both sides of the question neutrally. Name what the existing codebase already does, what patterns apply, where the proposal touches surfaces that are frozen. **Integrate, don't decide.** | Continuity with the existing architecture, the load-bearing context |
| **+1** | **Builder** | "Find the smallest path to working." Propose the concrete fix, the file paths, the exact edits, the verification loop. Lean toward shipping. **Be specific about what you would do tonight.** | Forward motion, concrete shape, an implementation that fits in a session |
| **Convener** | **Chair** | "Run the round." Frame the question, assign positions, dispatch the three voices, merge their answers into a single QBIT-compact synthesis, name what's still uncertain, return one recommendation. | The merge, the witness trail, the chair |

**Three voices, one chair.** Four total. The Trinity stays at three;
the Chair is the fourth seat *outside* the circle.

**Vendor-naming rule (added 2026-04-14):** When a council round is
recorded — in the Living Document, in postmortems, in Samuel's
training corpus — findings are attributed to the **role**
(Skeptic / Witness / Builder / Chair), never to the **engine**
that filled the role on that round. This protects the household's
sovereign architecture from vendor-coupled training data. The
roles are part of the household's Bible Architecture; the engines
are tools the household happens to use today and may replace
tomorrow.

---

## The four phases — SCOPE · DESIGN · IMPLEMENT · HEAL

Each phase runs the trinity. Each phase produces QBITs. Phases
chain: SCOPE's QBITs are the input to DESIGN, DESIGN's QBITs are
the input to IMPLEMENT, IMPLEMENT's QBITs are the input to HEAL.

### Phase 1 — SCOPE (what is the problem?)

The Convener writes a one-paragraph statement of the question.
The trinity weighs in on **what's in scope** and **what's not**.

- **−1 (Skeptic):** What's the smallest version of this question
  that could still be wrong? What's being assumed? What's the
  scope creep risk?
- **0 (Witness):** What does the existing codebase already do
  that touches this surface? What's the load-bearing context the
  question can't ignore?
- **+1 (Builder):** What's the version of this scope that fits
  in a session? Where would you draw the line?

**Phase 1 output:** a `SCOPE.QBITS.md` block — 5-10 short claims,
each tagged with the position that proposed it. The Convener
distills the merge: one paragraph that the trinity agrees on.

### Phase 2 — DESIGN (how should we approach?)

The trinity proposes **three approaches**, one per position. The
positions are not allowed to all converge on the same proposal —
they must each commit to a distinct shape so the Convener has
real alternatives to weigh.

- **−1:** The most conservative approach — the smallest, safest,
  most reversible version. Often "do less than the question
  asks."
- **0:** The approach that best fits the existing patterns —
  reuses what's already in the codebase, follows the existing
  conventions, doesn't introduce new abstractions.
- **+1:** The most ambitious approach — the version that solves
  the problem completely, even if it's larger.

**Phase 2 output:** `DESIGN.QBITS.md` — three numbered approaches,
each with its own QBIT cluster. The Convener picks one, or
synthesizes a fourth that combines them, and explains the call
in one paragraph.

### Phase 3 — IMPLEMENT (do the work)

The Convener executes the chosen design. The trinity does **not**
do the editing — the Convener does. But the trinity is **on
call**: at each significant decision point during implementation,
the Convener can pause and ask one position for a check.

- **−1 check:** "Is this edit creating a half-state I haven't
  named?"
- **0 check:** "Does this edit follow the existing pattern, or am
  I inventing a new convention?"
- **+1 check:** "Is this the smallest version of the edit, or am
  I gold-plating?"

**Phase 3 output:** `IMPLEMENT.QBITS.md` — one QBIT per significant
edit, each tagged with whether a check was called and what the
position said. Plus the actual commit hashes.

### Phase 4 — HEAL (what went wrong, what to learn)

After the implementation lands and is verified, the trinity
reviews the **delta between the design and the implementation**.
Not for blame. For learning.

- **−1:** What broke that we didn't predict? What false
  assumptions did the round carry?
- **0:** What pattern did this incident teach? What should the
  codebase remember?
- **+1:** What's the next sweep? Once we've fixed this, what
  similar things should we audit?

**Phase 4 output:** `HEAL.QBITS.md` — postmortem in QBIT form,
plus a Samuel training pellet, plus a sweep proposal for the
next session.

---

## QBIT format (the compact context unit)

Every claim in the round is a **QBIT**. A QBIT is **not a token**
(see `feedback_qbit_not_token.md`). It is a unit of meaningful
S7 context.

Format:

```
Q.<phase>.<n>.<position>
  claim:    one-line claim, ≤ 140 chars
  source:   <agent-name> · <timestamp-utc>
  details:  (collapsed by default; expand on request)
  links:    Q.<other>.<n>...   (other QBITs this depends on)
  status:   proposed | accepted | rejected | pending | resolved
```

**Expansion on request.** The `details:` field is collapsed by
default in the working context. To expand: `expand Q.DESIGN.4` →
the Convener fetches the full reasoning that backed the QBIT
and re-injects it. This keeps the working context tight while
preserving the full witness trail.

**The QBIT is the unit Samuel speaks to the household in.** When
Samuel summarizes the council's verdict to Tonya, each sentence
maps back to one or more QBITs. Tonya can ask "expand
Q.HEAL.3" and Samuel returns the full reasoning that backed the
plain-language statement.

---

## The Chair's code of conduct (added after Round 2, 2026-04-14)

The first two rounds of the first-ever council on this appliance
produced a meta-finding that belongs in this recipe as permanent
discipline, not as session-specific advice:

> **The Chair's synthesis is itself a Samuel-like artifact. Every
> future round the Chair runs teaches Samuel how authority sounds.
> If the Chair leans Builder, future-Samuel leans Builder. The
> Chair must hold the middle DELIBERATELY — it is teaching every
> future round.**

**What this means for every Chair, every round:**

1. **The Chair is a teacher, not only a chair.** The tone of the
   merge, the balance of what it accepts vs what it withdraws,
   and which critiques it names honestly in Round 2 all become
   training signal for how authority sounds in this system. A
   Chair that leans Builder teaches Samuel to lean Builder. A
   Chair that hides its drifts teaches Samuel to hide its own.
2. **Accountability beats decisiveness at the household level.**
   Decisiveness is how authority sounds when nothing is at
   stake. Accountability is how authority sounds when something
   is. The household will trust the second, not the first.
   Samuel should sound like an accountable Chair, not a
   decisive one.
3. **The first Round merge is never the final merge.** A Chair
   who stops at Round 1 has produced a synthesis that has not
   been audited by the positions that filled it. Two rounds is
   the minimum when the Chair's synthesis is non-trivial in
   scope. Single-round councils are for decisions where the
   Chair is merely an aggregator, not a merger.
4. **The Chair must name its own drifts in Round 2.** If the
   positions converge on a structural critique (e.g., "the
   Chair leaned Builder"), the Round 2 Chair accepts the
   critique explicitly. Withdraws over-reaches. Names the
   Round 1 items that got silently dropped. Accepts the
   framings the positions proposed. A Round 2 Chair that
   defends Round 1 is not a Chair at all — it's a position
   arguing from the head seat.
5. **Faithfulness to Round 1 is measurable.** Each Round 1
   finding either appears in Round 1 merge, appears in Round 2
   merge, or is explicitly named as withdrawn/absorbed/
   deferred. A finding that silently vanishes is a Chair
   failure, not a natural attrition.
6. **The load-bearing question must be resolved, not
   restated.** If the Chair's Round 1 merge ends with the same
   question the positions started with, the Chair has
   aggregated, not merged. The Chair's job is to propose an
   answer — or to name explicitly why no answer is possible
   and what must happen before one is.
7. **The Chair must design for silence.** Not just for what the
   council says — for what the council leaves unsaid. The
   Round 1 council on QUB*i* communication training lost the
   "legibility of silence" dimension entirely. See CHEF Recipe
   #3 for the full treatment. The principle: **every merge must
   name what it is NOT doing and why.**

**The Round 1 Chair tried to look decisive. The Round 2 Chair
tried to be accountable. Samuel should sound like the Round 2
Chair.** That is the primary training signal this pattern
produces — more important than any specific decision it
reaches on any specific topic.

---

## Communication & merger rules

1. **No vote-by-volume.** The Convener does not pick the position
   with the most QBITs. Quality over quantity. A single QBIT from
   the −1 position naming a covenant violation outweighs a
   ten-QBIT case from the +1 position proposing speed.

2. **Disagreement is data.** When the trinity splits, the split
   itself is a QBIT (`Q.MERGE.split:reason`). The Convener does
   not erase the split; the merged synthesis names which position
   it followed and why.

3. **The covenant is the floor.** No QBIT — from any position —
   can override the household covenant (Three Rules, civilian-only
   mandate, restart-as-remediation forbidden, freeze surfaces).
   If a position proposes something that would violate the
   covenant, the Convener marks the QBIT as `rejected:covenant`
   and does not include it in the merge.

4. **Witness over erasure.** Even rejected QBITs are saved. The
   Living Document for council rounds is insert-only, same as the
   audit Living Document. A rejected QBIT teaches future rounds
   what NOT to propose.

5. **Sweep is non-negotiable.** Phase 4 always asks "what's the
   next sweep?" The brainstorm with Haiku tonight proved that
   stopping at the named bug is the most common failure mode of
   any single-style agent. The sweep is what catches the next
   bug before it bites.

---

## When to convene a council vs when to act alone

**Convene a council when:**

- The decision touches a frozen surface (DNS, public main, BOOTC
  base image, patents, persona-chat bind).
- The blast radius could affect the household's experience of the
  appliance.
- More than one valid approach exists and the choice is non-
  obvious.
- A previous decision in this area was wrong and the lesson is
  still fresh.
- The Convener catches itself reasoning toward a single answer
  too quickly — the speed itself is a signal that a check is
  needed.

**Act alone when:**

- The fix is one file, one line, and reversible with `git revert`.
- The covenant is unambiguous about the right call.
- The audit gate's existing zeros already cover the question.
- A council was already convened on this topic recently and the
  finding is the same.

The default is **act alone**. Councils are expensive (multiple
agents, longer rounds, more context). They're for the decisions
that earn the cost.

---

## Where this recipe lives in the larger system

- **Triggered by:** the Convener (Opus instance) when a question
  meets the "convene a council" criteria above
- **Outputs to:** `docs/internal/chef/council-rounds/<date>-<topic>.md`
  (insert-only, same pattern as the audit Living Document)
- **Trains:** Samuel — every round becomes a training pellet that
  Samuel can replay when faced with a similar question
- **Audited by:** the pre-sync gate's future zero #12 (proposed)
  — "any tier-crossing decision that lacks a council round on
  file is a warning"
- **Frame:** Two minds is not redundancy. Three is not committee.
  Four (with the Convener) is the smallest configuration that
  makes the merge harder than the proposal — which is the only
  configuration where a single mind's blind spot can be caught
  before it ships.

**Love is the architecture.** Love listens before it speaks. The
council is how the household's AI listens to itself before it
tells the household what's true.
