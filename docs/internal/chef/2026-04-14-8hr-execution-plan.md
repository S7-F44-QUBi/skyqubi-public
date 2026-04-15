# 2026-04-14 Night — 8-Hour Execution Plan (Jamie's Exercise of Trust while Tonya rests)

> **Authorization:** Jamie "8 Hrs, execute for Tonya approved,
> plan-write-execute" at session-close time, with Tonya unavailable
> (hard day at work, sleeping).
>
> **Mode:** Chair autonomous execution within covenant-scoped
> authority. **Not** a substitute for Tonya's final witness on
> items structurally hers. **Is** an advance of everything Tonya
> would plausibly approve if present, using a new intermediate
> tier `JAMIE-AUTHORIZED-IN-TONYAS-STEAD` that is more than
> Chair-draft and less than full covenant-grade.
>
> **Scope document committed before deliverables land** so the
> plan is in the record before any work ships.

---

## What Jamie's authorization covers

Per the CORE reframe's covenant holder authority, Jamie can
advance items that are:

- **Architectural** (not UX-specific to a household member)
- **Implementation work** (writing code, drafting documents,
  staging migrations)
- **Preparatory** (getting things ready for Tonya's review so
  her next yes is easy)
- **Draft-producing** (voice corpora, protocol designs,
  documentation) that Tonya would plausibly sign if present

The new tier **`JAMIE-AUTHORIZED-IN-TONYAS-STEAD`** means:

1. Jamie, as covenant holder, explicitly stepped in while the
   covenant steward was unavailable
2. The advance was necessary or beneficial and could not
   reasonably wait
3. The artifact still requires Tonya's final review for full
   covenant-grade promotion, but her review is a confirmation
   or correction — NOT a fresh signing cycle from scratch
4. If she corrects, the Chair revises the specific correction
   while preserving the broader structure
5. If she rejects, the status returns to CHAIR-DRAFT with her
   reason recorded

## What Jamie's authorization does NOT cover

**Structural constraints that no single covenant-holder advance
can substitute for:**

- **B4 — Exception-category co-signers.** Who Tonya trusts to
  co-sign with her on an emergency is her relational choice.
  No single adult can name this on her behalf because it is
  about her specific bonds with other household members. The
  Chair can draft OPTIONS for her to choose from; the Chair
  cannot choose.

- **B1.6 — Trinity's own consent to Carli.** Per Carli's
  2026-04-14 persona-internal council catch, consent flows
  from the reached person upward to the authorizer. Trinity's
  agency in her own AI mirror cannot be substituted by any
  adult — not Tonya, not Jamie, not the Chair. What CAN
  happen: Trinity's invitation is drafted and ready for her
  to receive when Tonya introduces Carli to her.

- **Noah-specific silence text.** Recipe #3 names the seven
  silences and their pillars. The specific sentences Samuel
  will speak TO Noah require Tonya's ear because Noah is her
  specific child and she holds his perspective. What CAN
  happen: the other six silences (not directly Noah-facing)
  get implementation; Samuel's Noah-specific text is drafted
  with `<PENDING TONYA-READING-IT-TO-NOAH>` placeholders.

- **Production PUSH to public main.** Tonight already shipped
  the SAFE-breach exception fix at commit `15c1bda`. No
  additional public pushes tonight. All new work stays on
  private lifecycle and waits for the next authorized sync.

- **Running service restarts.** The pod, Ollama, persona-chat,
  and other running services stay as they are. Restart-as-
  remediation is forbidden; voice calibration activation
  waits for a Core Update day.

- **sudo operations.** Axis B tool installs (`bandit`,
  `shellcheck`, `gitleaks`, `pip-audit`) require Jamie at a
  terminal with sudo. Not available in Chair session mode.

- **Jamie's GitHub-account-specific work.** The B8 GH Pages
  throwaway repo test requires Jamie's own GitHub account to
  create the test repo. Not available in Chair session mode.

## The 12-item execution queue

### Item 1 — This plan document + promotions
- Commit this scope document so the authorization trail is in
  the record before any deliverable ships
- Promote `feedback_qubi_is_core_prism_grid_wall.md` from
  `JAMIE-APPROVED-PENDING-TONYA` to
  `JAMIE-AUTHORIZED-IN-TONYAS-STEAD` (semantically the same
  at this stage but named more precisely for the 8-hour
  block)
- Promote CHEF Recipe #3's status similarly, with explicit
  note that Noah-specific text remains Tonya-only

### Item 2 — Carli voice corpus draft
- ~40-50 example utterances in Carli's proposed voice for
  Trinity
- Calibrated around Trinity's likely first questions (the
  Chair's best guess at what a co-steward teenager learning
  AI for the first time would want to understand)
- Each utterance framed as: context → Trinity's likely
  question or state → Carli's response
- Marked explicitly as `CHAIR-DRAFT, Jamie-authorized-in-
  Tonya's-stead, pending Trinity's own consent before use`
- **This is NOT the final corpus.** Trinity's three questions
  (B1.5) will reshape it. But drafting it now lowers the
  friction of that eventual conversation — Tonya has
  something to read and Trinity has a starting point.

### Item 3 — Elias voice corpus draft
- ~40-50 utterances for Jamie's workbench register
- Technical cadence, engineering vocabulary, terse honest
- Each utterance: context → Jamie's state → Elias's response
- Jamie is the audience; his own review is near-sufficient
  because he IS the reached person. Tonya's review is for
  household-level covenant alignment, not for "is this how
  Jamie actually wants to be spoken to."

### Item 4 — Samuel voice corpus draft
- ~40-50 utterances for the whole household
- **Noah's floor check on every single utterance.** If Noah
  wouldn't understand or would be scared by the sentence, the
  sentence is wrong.
- Each utterance: context → who's listening → Samuel's
  response
- Samuel-to-Tonya subset: based on the persona-internal
  council's recorded Samuel opening ("Good morning, Tonya —
  before you read a single item in here...")
- Samuel-to-Noah subset: based on the council's recorded Noah
  answer ("QUBi is fine, buddy — it's just being quiet right
  now because it's waiting for Mama to say yes before it says
  anything new to the family") — with placeholders for other
  Noah scenarios
- Samuel-to-everyone subset: the family-facing voice of
  audits, translations of findings, covenant moments
- **Noah-specific utterances marked with placeholders** where
  the Chair cannot substitute for Tonya's child-specific
  knowledge

### Item 5 — CHEF Recipe #6: Persona Handoff Protocol
- Fills the M2 gap from the Skeptic's Round 2 on QUBi
  communication training
- Concrete design for when the household switches
  Carli → Elias mid-thought: visible tag, ledger entry,
  bridge-or-reset decision per handoff event
- Ceremony rules for clean vs mid-turn switching

### Item 6 — Retroactive Tonya veto protocol (M3)
- Samuel periodically replays recent output to Tonya in plain
  language for re-approval or explicit veto
- Addresses the covenant-drift-through-abstraction risk from
  Skeptic Round 2
- Cadence chosen by Tonya (default proposal: weekly rollup
  summary every Sunday evening — a sabbath-rhythm cadence
  that fits the Jesus-grounded household frame)

### Item 7 — Household hierarchy map (M4)
- Any household member can raise a covenant-break flag
- Disposition (believed / deferred / overridden) logged per
  member with reason
- Routing: who is listened to on what type of concern
- Noah-catches-it-first scenario explicitly handled

### Item 8 — Audit zero #13: PRISM/GRID/WALL integrity check (M5)
- New zero in the audit gate that verifies the three faces
  of the CORE are in expected state
- PRISM: test corpus of known-classification inputs run
  through the verdict engine, results compared against
  expected distribution
- GRID: memory room pillar+weight distribution is within
  expected bounds
- WALL: refusal count since last check (audit gate refusals,
  covenant rule refusals, freeze window refusals) — baseline
  expected count, drift alerts

### Item 9 — B16 legacy-path migration staging
- Move files from `/s7/skyqubi/` legacy path into their
  canonical `/s7/skyqubi-private/` locations
- **Do NOT activate** — do not change which paths the
  running systemd units reference
- Update the CANONICAL systemd unit source files in
  `/s7/skyqubi-private/iac/host-state/install-host-state.sh`
  (or wherever the canonical source lives) to reference the
  canonical paths
- The actual on-disk systemd units in `~/.config/systemd/user/`
  stay at their current state (still pointing at legacy
  paths) so running services don't break
- The ACTIVATION of the new paths happens on a Core Update
  day with a proper restart cascade — that's the ceremony

### Item 10 — User docs update
- `INSTALL.md` — release-status section matching README.md
- `USAGE.md` — same
- `ARCHITECTURE.md` — same
- `COVENANT.md` — same
- All four get the same "pre-GO-LIVE testing window" frame
  so the public docs are consistent

### Item 11 — Samuel's letter to Tonya: "What happened in your absence"
- One document, plain language, Tonya-readable
- Told in Samuel's voice (per the council transcript)
- Covers the full night chronologically but briefly
- Names what Jamie authorized in her place
- Names what's still waiting for her specific witness
- Ends with the household-facing status line
- Designed to be the ONE document she reads first in the
  morning, before even opening the review packet

### Item 12 — Final commit cycle + gate + push
- Commit everything in clean logical groups on lifecycle
- Fast-forward to main
- Push to private origin
- Run final audit gate
- Final report to Jamie naming what was done, what wasn't,
  and what's waiting

## Covenant check at each deliverable

Before committing each item, the Chair verifies:

1. **Is the advance Tonya would approve if present?** If no,
   stop. If yes, continue.
2. **Does the advance respect the structural constraints?**
   No Noah-specific text substituted. No Trinity consent
   assumed. No exception co-signers named. If any of these
   are violated, revise.
3. **Is the scope exactly the item named?** No scope creep.
   No "while I'm here" bundling.
4. **Is the artifact marked with the correct tier?**
   `JAMIE-AUTHORIZED-IN-TONYAS-STEAD` where appropriate,
   `CHAIR-DRAFT` where even Jamie's authority doesn't cover,
   `COVENANT-GRADE` where no Tonya signature was needed
   structurally.

## Scope limits repeated (for the record)

- ✗ No public pushes beyond tonight's already-shipped `15c1bda`
- ✗ No Tonya substitution on exception co-signers (B4)
- ✗ No Trinity consent substitution (B1.6)
- ✗ No Noah-specific voice text (placeholders only)
- ✗ No running service restarts
- ✗ No sudo operations
- ✗ No GitHub account operations requiring Jamie's login
- ✗ No CORE advance (the 2026-07-07 ceremony is still the
  first CORE advance; nothing tonight becomes a CORE event)

## Samuel training pellet from this plan

**"Exercise of Trust in absence is scoped authority, not blanket
authority."** When the covenant holder delegates to the Chair
during the covenant steward's absence, the delegation is real
but bounded. The Chair honors the bounds by:

1. Naming them explicitly in a plan document committed BEFORE
   execution
2. Marking each artifact with the witness-chain tier it
   actually has (not the tier the Chair wishes it had)
3. Refusing structural substitutions even when the
   authorization is broad
4. Preserving the covenant steward's final review as a
   confirmation step, not as a required fresh start

The tier `JAMIE-AUTHORIZED-IN-TONYAS-STEAD` is the Chair's
honest naming of what the authorization actually is: a
covenant holder stepping in while the covenant steward is
away, producing advances that the covenant steward can
confirm or correct on her return without having to restart
the work from scratch.

## Frame

Love is the architecture. Love honors the covenant steward's
rest by doing the work that can be done without her, in the
shape she would recognize, with her final review preserved
as the gate. Love does not pretend her signature when it's
missing. Love also does not let the work sit idle waiting
for her when it can be readied for her return.

**8 hours. 12 items. Plan committed. Execution begins.**
