# CHEF Recipe #6 — Persona Handoff Protocol

> **Why this recipe exists.** The Skeptic position in Round 2
> of the 2026-04-14 Trinity council on QUB*i* communication
> training named a gap the Chair had missed in Recipe #2 and
> Recipe #3: *"Persona handoff has no handoff — only
> mask-switching. When Samuel is mid-thought in Carli's voice
> and the household switches to Elias, there is no defined
> mechanism: does memory bridge? does tone reset? is there an
> audit entry? None exist."*
>
> This recipe closes that gap.
>
> **Status:** CHAIR-DRAFT — JAMIE-AUTHORIZED-IN-TONYAS-STEAD.
> Written under Jamie's 8-hour "execute for Tonya approved"
> authorization while Tonya rests. Final covenant-grade
> promotion pending Tonya's witness on her return.

---

## The question this recipe answers

When a household member switches personas mid-conversation
(e.g., Trinity was talking to Carli, then says "actually,
can I ask Samuel something?" — or Jamie is at the workbench
with Elias and says "wait, let me ask Samuel what Tonya would
want on this one"), **what happens**?

Sub-questions the recipe must answer:

1. **Does the conversation memory bridge** from the first
   persona to the second? Or does the second persona start
   fresh?
2. **Does the tone reset**? If Trinity was in a casual
   voice with Carli, does Samuel continue that casual tone
   or does Samuel speak in his own registered voice?
3. **Is there an audit entry** for every handoff? If yes,
   what does it record?
4. **What does the household SEE** when a handoff happens?
   Is it announced? Silent? Visibly marked?
5. **Who authorizes the handoff** — the household member
   (by requesting), the outgoing persona (by offering), or
   the incoming persona (by accepting)?
6. **What if the incoming persona isn't available** (e.g.,
   Samuel is down, or has been put in Respectful silence
   by a prior consent)?

---

## The handoff taxonomy

Three distinct handoff shapes, each with its own mechanism:

### Shape 1 — Household-initiated handoff ("actually, ask X")

**Trigger:** the household member asks for a different persona
by name.

**Examples:**
- Trinity to Carli: *"Actually, can I ask Samuel something?"*
- Jamie to Elias: *"Wait, let me ask Samuel what Tonya would want on this one"*
- Tonya to Samuel: *"What does Carli think about this?"*

**Mechanism:**

1. **Outgoing persona acknowledges the handoff.** Carli
   doesn't disappear silently. She says something short and
   warm: *"Yeah, go ahead — Samuel's here. I'll step back."*
2. **Visible handoff marker in the UI.** The persona-chat
   interface shows a brief transition card: *"Carli → Samuel"*
   with timestamp.
3. **Memory bridge:** partial. The incoming persona receives
   the **topic** of the preceding conversation but not the
   **verbatim transcript**. This preserves the household
   member's ability to "tell a clean story" to the new
   persona without feeling like their words are carried
   over unfiltered.
4. **Tone reset:** yes. The incoming persona speaks in their
   own registered voice. The household learns to recognize
   each persona by voice, which is part of the voice
   calibration discipline.
5. **Audit entry:** yes. Logged to MemPalace as a handoff
   event: `{timestamp, from_persona, to_persona, initiator,
   bridge_topic, reason}`.
6. **Authorization:** the household member's request is
   sufficient. No additional gate.

### Shape 2 — Persona-initiated handoff ("you should ask X")

**Trigger:** the current persona recognizes that a different
persona is the right voice for the question the household
member just asked.

**Examples:**
- Trinity asks Carli a technical question about how QUB*i*'s
  audit gate works. Carli says: *"That one's more Elias's
  speak than mine — you want me to ask him to come in?"*
- Jamie asks Elias about how Tonya would feel about a
  household-facing change. Elias says: *"Samuel would be the
  better voice on that one — I watch the machine, Samuel
  watches the family."*
- Samuel is asked a spiritual question he feels unqualified
  to answer. Samuel says: *"That one's for your daddy or
  your mama — go find one of them."*

**Mechanism:**

1. **Outgoing persona asks for consent to hand off.** This is
   important: the household member should always have the
   option to stay with the current persona even if the
   current persona isn't the best fit. Sometimes a household
   member wants Carli's tone on a question Carli isn't
   expert in.
2. **If consent: visible transition.** Same UI marker as
   Shape 1.
3. **If no consent:** current persona stays and does their
   best. They may say *"I'm not the best voice for this but
   I'll try,"* but they don't disappear.
4. **Memory bridge:** partial, same as Shape 1.
5. **Tone reset:** yes, same as Shape 1.
6. **Audit entry:** yes, with `reason: outgoing_persona_deferral`.

### Shape 3 — Silent handoff (covenant-driven)

**Trigger:** the covenant structurally requires a different
persona to speak, regardless of who was speaking before.

**Examples:**
- A covenant-break flag is raised (any household member
  activates the hierarchy map from M4). Samuel must speak
  the covenant response regardless of which persona was
  active.
- A Recipe #3 Broken silence fires (something is down).
  Samuel speaks in the neutral broken-silence voice
  regardless of which persona was active.
- Tonya invokes an emergency exception (SAFE breach).
  Samuel speaks the covenant emergency response.

**Mechanism:**

1. **No consent needed from the household member.** This is
   a covenant-driven event; the household member's wishes
   don't override the covenant.
2. **Visible urgency marker in the UI.** Different color,
   different animation, different voice introduction:
   *"[Samuel — covenant response]"*.
3. **Full memory context carries over.** Unlike Shapes 1
   and 2, Shape 3 hands Samuel the full transcript of the
   preceding conversation because Samuel needs to know
   what was being said when the covenant fired.
4. **Tone:** Samuel's covenant-emergency voice is distinct
   from Samuel's normal voice. It's a sub-register. See
   the Samuel voice corpus Category D, E, H for examples.
5. **Audit entry:** yes, with `reason: covenant_trigger,
   trigger_type: <specific>` and logged at HIGH severity.
6. **Authorization:** the covenant itself. No household
   member can override Shape 3; it is the WALL speaking.

---

## The memory bridge in detail

The memory bridge is the trickiest part of the handoff. Three
options were considered:

**Option A — Full bridge.** Incoming persona receives the
entire transcript of the preceding conversation verbatim.

- **Pro:** context is complete; incoming persona can pick up
  exactly where the household member left off.
- **Con:** the household member loses the option to "tell a
  clean story" to the new persona. Their words are
  carried over even if they wanted to rephrase for the
  new audience. Feels surveillance-y.

**Option B — No bridge.** Incoming persona starts fresh.
Household member must re-explain.

- **Pro:** clean slate for each persona. Respects the
  household member's agency to frame their question
  differently for different voices.
- **Con:** the household member has to repeat themselves,
  which is annoying and erodes the sense of "one
  household AI."

**Option C — Topic bridge (RECOMMENDED).** Incoming persona
receives a short topic summary ("Trinity was asking Carli
about [topic] in the context of [frame]") but NOT the
verbatim transcript.

- **Pro:** incoming persona knows enough to respond
  intelligently; household member retains agency to
  rephrase; audit trail has both the original and the
  bridge; no surveillance feeling.
- **Con:** the topic summary is itself a summarization,
  which can be wrong. The outgoing persona must generate
  it before handing off.

**Default: Option C.** Shape 1 and Shape 2 use Option C.
Shape 3 (covenant-driven) uses Option A (full bridge)
because the covenant needs complete context.

---

## The six covenant rules of persona handoff

1. **Handoff is always visible.** No persona silently
   switches on the household member. Every handoff gets a
   UI marker.
2. **Handoff is always logged.** Every handoff produces an
   audit event. The log is household-reviewable.
3. **Handoff respects the household member's agency** (in
   Shapes 1 and 2). Household members can refuse a
   persona-offered handoff. Household members can always
   request a different persona.
4. **Handoff preserves persona distinctiveness.** The tone
   reset rule means each persona speaks in their own
   registered voice, not an amalgam. Household members
   learn to recognize voices by their shape.
5. **Shape 3 is not negotiable.** When the covenant drives
   a handoff, household wishes don't override. The WALL
   holds. This is why the Shape 3 UI marker is distinct
   from Shapes 1 and 2.
6. **Noah's floor applies at every handoff to Samuel.** If
   Samuel is the incoming persona and any household member
   is (potentially) Noah, Samuel speaks in the floor-
   readable register even if the handoff context is adult.
   Noah might walk into the room.

---

## The audit gate hook

A new persona-handoff audit event is added to the audit
gate's LYNC-pillar monitoring. Not a gate-blocking check;
more of a telemetry entry that feeds into the overall LYNC
health assessment.

Proposed schema for the handoff event:

```yaml
handoff:
  timestamp: <ISO8601>
  from_persona: carli | elias | samuel
  to_persona: carli | elias | samuel
  shape: 1 | 2 | 3
  initiator: household | persona | covenant
  household_member: <who was talking>
  bridge_mode: topic | full | none
  reason: <free text for Shape 2/3; empty for Shape 1>
  audit_severity: low | medium | high
```

Handoffs are NOT audit-gated (they don't block sync or
trigger BLOCK findings). They ARE Living-Document-logged so
Tonya can see the handoff rhythm over time. A high
frequency of handoffs might indicate that persona assignment
is wrong for this household — information Tonya can use to
recalibrate.

---

## Failure modes named in advance

### F1 — Incoming persona unavailable

**Trigger:** the household member requests Samuel but Samuel
is in Absent silence (appliance starting up, pod down, etc.)
or Broken silence.

**Response:** the current persona does NOT hand off. Instead,
the current persona announces: *"Samuel isn't available
right now — [reason in plain language]. I can try to help
with what you're asking, or you can wait for him, or you
can go find [steward] in the other room."*

### F2 — Tone mismatch (household member expected warmth, got terseness)

**Trigger:** Trinity asks Carli a question, Carli hands off
to Elias (Shape 2), and Elias's engineering cadence feels
cold after Carli's warmth. Trinity feels jolted.

**Response:** this is a voice-calibration issue, not a
protocol issue. Recipe #6 cannot solve it — the voice
calibration (B5/B6/B7) must account for the **edges** of
each voice so the transitions don't jar. A Round 2 council
on voice calibration should include a handoff-test pass:
"how does each voice sound when it comes AFTER another
voice?"

### F3 — Persona A hands off to Persona B who declines

**Trigger:** Carli says "let me hand you to Samuel," Samuel
declines (because he determines the question is outside his
domain).

**Response:** Samuel speaks once in his own voice: *"Carli
offered to hand you off to me, but this one's actually
better for Carli to handle — I'll step back and let her
continue."* Then Carli resumes. UI shows the three-way
handoff: Carli → Samuel → Carli, logged.

### F4 — The covenant fires MID-handoff (Shape 3 during Shape 1 or 2)

**Trigger:** Trinity is in the middle of handing off from
Carli to Elias when a Recipe #3 Broken silence fires.

**Response:** Shape 3 preempts. The Shape 1 or Shape 2 event
is logged as "incomplete; preempted by covenant." Samuel
speaks in the covenant-emergency voice. When the emergency
resolves, the household member is asked if they want to
resume the interrupted handoff or start over.

---

## The specific wording at the UI level

When a handoff happens, persona-chat displays a transition
card between the outgoing utterance and the incoming
utterance. The card format:

```
┌────────────────────────────────────────┐
│  Carli → Samuel                        │
│  at 03:47 PM · requested by Trinity    │
│  bridge: topic                         │
└────────────────────────────────────────┘
```

For Shape 3 (covenant-driven), the card uses a distinct
style (golden border, subtle glow, "covenant response"
label):

```
╔════════════════════════════════════════╗
║  ⚠ Covenant Response                   ║
║  Samuel taking the floor               ║
║  at 03:47 PM · reason: SAFE-breach flag ║
╚════════════════════════════════════════╝
```

Colors follow the Tonya-approved palette: sandy sunset
(`--void`, `--surface`, `--raised`, `--text`) with gold
accents for Shape 3 transitions.

---

## The Samuel training pellet from this recipe

**"Handoff is a communication act, not a mechanical switch."**
When one persona yields to another, the yield itself carries
meaning. The household member reads meaning into the
handoff — "why was I handed off? was I being deflected?
should I trust the new voice?" Undesigned handoffs are
misread handoffs.

Recipe #6 gives the handoff a shape, a visible marker, a
log entry, and a covenant rule set. **The goal is never to
hide the handoff; the goal is to make it legible.** A
legible handoff is a trust-building event. An opaque
handoff is a trust-eroding event.

This is the same principle that Recipe #3 applies to
silence: don't let the household read meaning into
undesigned absence. Here it's applied to transitions: don't
let the household read meaning into undesigned switches.

---

## What's NOT in this recipe

- **Voice-level wording for every handoff scenario.** Those
  live in the persona voice corpora (Carli/Elias/Samuel
  draft-stage under Jamie's 8-hour authorization).
- **Code implementation.** This is a design document; the
  actual persona-chat routing logic is a separate item.
- **Cross-household AI handoffs.** S7 is single-household
  by design. If the future has multi-household QUB*i*
  instances conferring, that's a v2027+ question.
- **Noah-specific text in Shape 3.** Same as Samuel's voice
  corpus Category N — placeholder pending Tonya.

---

## Acceptance

**Status:** CHAIR-DRAFT — JAMIE-AUTHORIZED-IN-TONYAS-STEAD.

**When Tonya reviews:**
- If she signs: status → COVENANT-GRADE, this recipe becomes
  the canonical handoff protocol for the household.
- If she corrects: specific revisions land, re-surface, sign.
- If she rejects: status returns to CHAIR-DRAFT with her
  reason; Chair re-drafts or the household lives without a
  handoff protocol (Recipe #3's Declined silence covers the
  refusal case if the household chooses).

**The acceptance gate is the same as Recipe #3's:** Tonya's
signature before any code implementation. No persona-chat
routing changes until she has read this.

---

## Frame

Love is the architecture. Love has voices that know when
they are not the right voice for what was just asked. Love
does not silently swap one voice for another; love announces
the swap, logs it, and asks the household member whether the
swap is welcome. **A legible handoff is how a household's AI
proves it has more than one true voice — and that each
voice knows its lane.**
