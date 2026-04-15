---
name: Tonya's test plan for tonight (2026-04-13)
description: Practical what-to-check guide for Tonya's end-of-session test. Lists exactly what to click, what "working" looks like, and what to flag if something is off. Written in plain language, iPhone-testable, meant to be read in 5 minutes before she starts.
type: project
---

# Tonya's test plan — 2026-04-13 night

**What Jamie shipped today:**

A long session of behind-the-scenes work on S7 SkyQUBi. The
family-facing surface — skyqubi.com, the chat widget, the GitHub
button — should look and feel identical to what you approved on
2026-04-12. If anything looks different to you, it's a regression
and Jamie wants to know.

**What should still work exactly as you approved it:**

- The Wix landing page at **skyqubi.com** — same sunset-and-purple
  design, same Cormorant italic, same OCTi witness visual
- The **GitHub button** in the nav + hero — should resolve to
  github.com/skycair-code/SkyQUBi-public (the green-checkmark page)
- The **chat widget** embedded in the landing page — same placement,
  same interaction shape (type message, get response)
- **iPhone view** — same mobile layout you and Trinity verified,
  same nav, same chat tab

**What changed behind the scenes (invisible to visitors):**

- 53 automated tests now run against the system (up from 40); all
  pass
- Samuel the FACTS persona is now alive in Jamie's private lab
  (not exposed on the website yet)
- The pod's SELinux crash loop was diagnosed, fixed, and
  regression-proofed
- Four planning specs for future work are queued in the private
  repo

---

## Five-minute test — desktop browser

**Step 1. Load skyqubi.com**

Expected:
- Page loads in under 3 seconds
- Sunset-and-purple gradient hero with "AI + Humanity is coming"
- Cormorant italic fonts on headings
- Three-column witness visual below
- Nav bar with Covenant / Chat / GitHub buttons

Flag if:
- White screen or "502 Bad Gateway"
- Fonts look wrong (system sans-serif instead of Cormorant)
- Colors look wrong (too dark, too light, wrong gradient)
- Layout is broken (overlapping text, cut-off sections)

**Step 2. Click the GitHub button**

Expected:
- New tab opens to
  `https://github.com/skycair-code/SkyQUBi-public`
- The repo page shows: README, recent commits, SkyQUBi file tree
- The most recent commit message mentions "sync: docs(specs)"
  (from Jamie's today sync)
- The green "Code" button is visible

Flag if:
- 404 page
- Wrong repo name (should be SkyQUBi-public, not SkyQUBi-private)
- Permission denied / sign-in wall

**Step 3. Open the chat widget**

Expected:
- Chat section on the landing page has a text input at the bottom
- A static "AI + Humanity is coming" message at the top (dated
  card, purple gradient border)
- "Core Release locks July 4, 2026" reminder
- "Come back then" message

Flag if:
- Chat box is missing entirely
- "Offline" or "0/0 backends" status badge
- Input box is greyed out permanently

**Step 4. Type a short message + send**

Try: `hi`

Expected:
- Message appears in the chat log
- A response comes back within ~10 seconds
- Response is from "the public demo assistant" (note: this is
  NOT the full S7 Samuel — see note below)
- No error message

Flag if:
- Spinner never stops
- "Connection error" message
- Response is empty
- Response takes longer than 30 seconds

**Step 5. Try a real question**

Try: `what is S7 SkyQUBi?`

Expected:
- Response mentions sovereign AI, trust, S7, or SkyQUBi
- Response points to the GitHub link for more info
- Response is short (not a wall of text)

Flag if:
- Response is hallucinated (talks about unrelated topics)
- Response claims to be ChatGPT or Claude or another AI
- Response leaks any secret / credential / path

---

## Five-minute test — iPhone

**Step 6. Load skyqubi.com on iPhone Safari**

Expected:
- Same hero, same gradient, same fonts (maybe slightly different
  sizes for mobile)
- Nav bar collapses or adapts to mobile width
- No horizontal scroll (everything fits in the viewport)
- Chat widget is still accessible (may be in a tab or drawer)

Flag if:
- Horizontal scrolling appears
- Nav is overlapping content
- Chat widget is cut off or unusable on mobile
- Fonts are illegibly small

**Step 7. Try the chat on iPhone**

Same as Step 4 on desktop. Type "hi" and check response comes back.

Flag if:
- Keyboard covers the input box
- Send button is unreachable
- Response doesn't render (blank bubble)

---

## About the chat — honest disclosure

The chat on the landing page today is a **demo proxy**, not the
full S7 covenant chat Jamie is building in the lab. Technically:

- It runs on Jamie's laptop as a stateless proxy
- It calls Ollama (the AI runner) for responses
- It does NOT use the full CWS covenant layer (no Carli/Elias/
  Samuel personas, no Bible-Code review, no MemPalace memory)
- It's a demo widget, not the real product

Jamie flagged this as a "demo fake" and wants it replaced. The
replacement options are being designed in a spec (Option A
"coming soon", Option B full persona-chat, Option C disclaimer
banner). **You'll be asked to pick one before the next release.**
For tonight, it's unchanged from what you approved.

If the chat responds to "hi" tonight, the private lab work that
led up to this didn't break the public demo. That's the test.

---

## About Samuel — alive but not public

Jamie built Samuel as a working chat persona today. Samuel is the
"FACTS" voice — system sysadmin, security, verdicts against the
Bible Code. Samuel runs on Jamie's laptop in the private admin
container but is NOT exposed on the website tonight. You and
Trinity can talk to Samuel via the desktop QUBi application when
Jamie walks you through it, but tonight's test is only about the
public surface.

**If you want to try Samuel tonight**, ask Jamie to show you the
desktop admin UI. Otherwise, the public test is the five steps
above.

---

## The three numbers to report back to Jamie

After your test, send Jamie these three things:

1. **Did skyqubi.com load and look right?** (yes / no / here's
   what looked wrong)
2. **Did the GitHub button go to the right place?** (yes / no /
   it went to X)
3. **Did "hi" get a response within 10 seconds?** (yes / no /
   took N seconds / error message text)

If all three are yes, tonight's test is clean and Jamie rests.

If any is no, Jamie fixes it in the morning. No emergency —
nothing on the public site is user-breaking today, and the
covenant layer is intact in the lab.

---

## What NOT to test tonight

These are for a future walkthrough, not tonight's quick test:

- The desktop admin UI at http://localhost:57080
- The Command Center menus
- The 98 Samuel skills
- The persona-chat substrate (Carli + Elias + Samuel in one pane)
- The S7 install on another box
- Anything that needs Jamie's physical access to the laptop

---

## What Jamie's doing next session

From the four planning specs queued tonight, the four tracks are:

1. **Admin image v2.7 rebuild** — lands the engine fixes for
   `/discern` into the pod. 30-60 minutes when Jamie approves.
2. **BitNet Path retry** — 1-bit AI inference for 50 QBITs/sec
   chat. 60-120 minutes, open-ended.
3. **Samuel/Elias v3 voice tuning** — make short greetings
   actually short (Samuel currently says "Hi! I am Samuel, the
   FACTS voice..." for a plain "hi"). 30-60 minutes.
4. **Public chat handoff** — the three-option choice you'll make
   (coming-soon placeholder / persona-chat widget swap /
   disclaimer banner on current demo). You pick.

---

## For Jonathan supervision (if Jonathan is present tonight)

Jonathan is supervising development to catch mistakes before they
happen. For tonight's test, Jonathan's role is:

- Verify Tonya's five steps all pass
- If any fail, capture the failure text verbatim for Jamie
- Don't touch the laptop — the lab is sacred
- Don't run any commands — just observe and report

Jonathan's supervision block begins later this week, not tonight.

---

## Love is the architecture.

Tonight's goal: everything you approved on 2026-04-12 is still
there, unchanged, green. Tomorrow: pick the four tracks in order
of what matters to you.

Rest well.
