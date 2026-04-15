# CHEF Recipe #7 — Retroactive Tonya Veto Protocol

> **Why this recipe exists.** The Skeptic position in Round 2
> of the 2026-04-14 Trinity council on QUB*i* communication
> training named the gap: *"Tonya's veto is retroactive, not
> preventive. The Chair's runtime-guard framing assumes Tonya
> is present at inference time. Household training happens
> when she isn't."*
>
> If Samuel learns something (or produces something) while
> Tonya is away from the counter, Tonya cannot veto it at
> runtime. By the time she sees it, it's already been said
> and possibly internalized by whoever heard it. The covenant
> needs a mechanism for **retroactive witness** — Samuel
> showing Tonya what was said in her absence, periodically,
> in plain language, for re-approval or explicit veto.
>
> **Status:** CHAIR-DRAFT — JAMIE-AUTHORIZED-IN-TONYAS-STEAD.

---

## The problem in one paragraph

Tonya holds the covenant veto on what reaches household
members. But Tonya is also a working wife and mother with a
life outside the binder. She cannot be present at the
counter 24/7 to witness every Samuel utterance. **If the
covenant's design requires her to be present at every
inference, the covenant fails on Day 2.** The covenant
needs a way for her veto to work in retrospect — she sees
what was said, she signs off or corrects or vetoes, and
the weights update to honor her correction.

---

## The protocol

### Step 1 — Samuel logs everything Tonya-reachable

Every Samuel utterance (and Carli, and Elias) gets logged to
MemPalace with:

- Timestamp
- Speaking persona
- Reached household member
- Context (what was asked or what triggered the utterance)
- Full text of what was said
- Classification from the Prism (FOUNDATION / FRONTIER /
  HALLUCINATION / VIOLATION)
- Weight at which the persona said it (confidence score)

This is already the MemPalace insert-only pattern at work.
Nothing new. The novelty in this recipe is how the LOG
feeds the retroactive veto.

### Step 2 — Samuel compiles a weekly rollup

**Cadence: weekly, default Sunday evening.** Chosen because:

- Matches the Jesus-grounded Sabbath rhythm the household
  already holds
- Long enough that individual utterances have settled into
  context
- Short enough that drift hasn't become entrenched
- Falls at the household's natural rest point, when Tonya
  is most likely to have bandwidth

On Sunday evening, Samuel compiles:

- Count of utterances per persona per household member
- Notable utterances (ones classified FRONTIER or edge of
  HALLUCINATION — where Samuel wasn't fully confident)
- Any covenant-adjacent moments (Declined silences fired,
  Broken silences fired, persona handoffs that surprised
  the household)
- A plain-language summary of "the week in our voice"
- The three utterances Samuel is LEAST sure about — the
  ones that would most benefit from Tonya's ear

### Step 3 — Tonya reviews at her own pace

The rollup is delivered via persona-chat as the Sunday
digest (distinct from the daily Tonya digest). Format:

1. **The one-screen summary** — household can read the
   week's shape in 30 seconds
2. **The three uncertain utterances** — Samuel asks Tonya
   specifically about these
3. **The drift indicators** — if Samuel's tone has shifted
   from where it was last week, Samuel names it and asks

Tonya can:

- **Sign the rollup as-is** ("the week was fine, keep going")
- **Veto specific utterances** ("Samuel, don't say X again"
  — that pattern is now blocked)
- **Correct specific utterances** ("Samuel, what you said
  about Y was close but here's what it should have been")
- **Pause the persona** ("Samuel, go quiet for 24 hours
  until I can review more deeply")

### Step 4 — Samuel updates

Every veto, correction, and pause is logged back to MemPalace
as a high-weight corrective memory. When Samuel next speaks
on a related topic, the corrective memory biases the
response. Veto is persistent — a vetoed pattern stays
vetoed unless Tonya explicitly lifts it.

---

## The covenant drift insurance

Without this protocol, the covenant has a hidden failure
mode: **drift through abstraction.** Tonya signs Samuel's
corpus in January. By July, Samuel has internalized 10,000
household interactions. The weights have silently recomposed
what "Tonya-approved" means. Tonya hasn't re-approved; she's
just let it live. By year-end, Samuel is saying things
Tonya would veto if asked, in forms Tonya's January
signature didn't specifically cover.

The weekly rollup closes that hole. **Tonya re-signs (or
corrects) every week, in plain language, with enough
specificity that drift cannot hide.** The January signature
is not the covenant; the weekly rollups are the covenant,
re-affirmed one sabbath at a time.

---

## The "retroactive veto is preventive for the future" principle

A veto at week N prevents the same pattern from shipping at
week N+1. So while each veto is retroactive to the moment
it names, it is preventive for all future moments of the
same shape. **The weekly cadence makes the retroactive
mechanism effectively preventive on a one-week lag.**

This is acceptable because:

- Zero lag (truly preventive) would require Tonya at the
  counter 24/7
- One-week lag catches drift before it entrenches
- The lag itself is household-visible (the rollup is the
  lag made legible)

---

## Three failure modes named in advance

### F1 — Tonya misses a week

**Trigger:** Tonya is traveling, sick, or overwhelmed and
skips a Sunday rollup.

**Response:** the next week's rollup carries both weeks.
Samuel does not pause automatically — that would be
restart-as-remediation by the household. Instead, Samuel
continues speaking but at reduced weight on any utterance
that's similar to pending uncertain-utterances. A kind of
"humble posture" while waiting for her ear.

### F2 — Tonya vetoes something Samuel has already said many times

**Trigger:** Tonya reads a rollup and vetoes a pattern
Samuel has been using for months.

**Response:** Samuel does not try to "unsay" what was
already said (that's impossible). Samuel DOES:
- Stop using the pattern going forward
- Flag all MemPalace entries containing the vetoed
  pattern for Tonya to review if she wants a full sweep
- Announce the veto to other household members who might
  have heard the pattern ("Trinity, your mom has asked me
  not to say X anymore — if you remember me saying
  something like that, she's revising it")

### F3 — The rollup itself becomes a burden

**Trigger:** Tonya finds the Sunday rollup stressful or
time-consuming.

**Response:** the rollup is negotiable. Cadence can change
(biweekly, monthly). Format can change (shorter, longer,
audio). Content can change (fewer utterances reviewed, more
Samuel-self-assessment). **The rollup exists to serve her,
not the other way around.** If it stops serving her, it
gets revised.

---

## What's NOT in this recipe

- **The technical schema of the MemPalace logging.** That
  exists already in the MemPalace design; Recipe #7 uses
  it, doesn't redefine it.
- **The delivery mechanism for the Sunday digest.** Should
  it be in persona-chat? A separate email? A printed sheet
  on the counter? That's Tonya's choice; recipe is
  format-agnostic.
- **What the three personas should each do between
  rollups.** They continue operating at their registered
  voices; drift correction happens via the rollup.
- **Jonathan and Trinity's co-steward review role in the
  rollup.** They may participate in the Sunday digest as
  witnesses, but the final veto is still Tonya's. Their
  role is an M4 question (household hierarchy map), not
  an M3 question.

---

## Acceptance

Same gate as every other JAMIE-AUTHORIZED-IN-TONYAS-STEAD
item: Tonya reviews on her return, confirms/corrects/
rejects, status advances accordingly.

## Frame

Love is the architecture. Love knows the covenant steward
is a whole person with a life, not an on-call oracle. Love
builds the covenant to flex around her rest — including by
accepting that some of her signatures will arrive a week
after the utterance they cover. **A week-late sign is
still a sign. A never-sign is a covenant break.** The
Sunday rollup is the middle: late enough for rest, regular
enough for trust.
