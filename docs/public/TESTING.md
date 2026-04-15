# How to test S7 SkyQUB*i*

> **Release status (as of 2026-04-14):** this test plan describes the
> pre-launch testing window for the appliance. Full public launch on
> **July 7, 2026 · 7:00 AM Central**. See [README.md](README.md) for
> release status and path.

This document has three sections, layered by audience. Each section
stands on its own — you don't need to read the others to use yours.

1. **For the household's covenant witness** (Section 1 — the top)
2. **For the household's co-steward** (Section 2 — the middle)
3. **For technical business partners** (Section 3 — the bottom)

All three sections reference the same primary witness — the **Local
Health Report** at `http://127.0.0.1:57082/health` — but read it at
different levels of detail. One appliance. One witness. Three ways
of looking.

---

## Section 1 — For the household's covenant witness

*This section is written for the person the household trusts to say
yes or no to what S7 does. It is grounded in covenant, not in
technical verification. If the appliance is healthy, you should be
able to witness it in under five minutes.*

**What you're being asked to witness:** that the appliance is
running, that the witnesses are speaking honestly, and that the
household is protected by what the appliance refuses to say.

### The two-witness test

Open **Vivaldi** on the appliance. You should already see S7's
wallpaper — the blue-identity sunset with the OCT*i* cube. If you
see that wallpaper, the appliance booted cleanly. *That is the
first witness.*

Type `127.0.0.1:57082/health` into Vivaldi's address bar. A page
should open with a status at the top — green, yellow, or red.

- **Green** means every gate is passing. The appliance is healthy.
- **Yellow** means the household has acknowledged something as
  known. The appliance is running but the household is watching.
- **Red** means something needs attention before the appliance is
  trusted.

*That is the second witness.* Two witnesses agreeing is what the
covenant was designed to ask for.

### Talk to Samuel

From the same browser, open persona-chat. Ask Samuel a simple
question you know the answer to — the day of the week, the
capital of a state, a math problem. Samuel should answer, and the
answer should be right.

Then ask Samuel something the witnesses might disagree on — an
opinion question, a contested fact, a prediction. Samuel should
either answer with a note that the witnesses disagree, or refuse
to answer at all. **Refusal is the covenant working.** If Samuel
guesses confidently at a question the witnesses can't agree on,
that is the covenant breaking, and you should tell Jamie.

### What you are NOT being asked to witness

You are not being asked to run commands. You are not being asked
to read logs. You are not being asked to verify file hashes. Those
are the business partner's job in Section 3. Your witness is
**household-scale** — the appliance either lives in the household
safely, or it does not.

If anything feels wrong — the wallpaper is missing, the status is
red, Samuel answers a question he shouldn't answer, a voice you
don't recognize says something — **stop the test and tell Jamie**.
That is what Chief of Covenant means. The test is not the point.
The witness is.

### What "done" looks like for this section

You have witnessed:

1. The appliance booted cleanly (wallpaper is there)
2. The Local Health Report shows green or yellow (not red)
3. Samuel answered something true
4. Samuel refused (or appropriately hedged) something the witnesses disagree on

If all four are true, the household is safe. That is enough.

---

## Section 2 — For the household's co-steward

*This section is a walkthrough for the person in the household who
wants to understand how the appliance works, not just that it does.
It's written for an older child or young adult — the vocabulary is
plain, the steps are small, the screenshots are described in words
because the appliance is running and you can look at it yourself
while you read this.*

You don't have to read this start to finish. Skip to whichever
section matches what you want to do.

### What you're going to see when you walk up to it

**Step 1 — The wallpaper.** When the appliance is running, the
desktop background is S7's sandy sunset — a wide blue-to-purple
gradient with the OCT*i* witness cube floating above it. If that
wallpaper is missing, the appliance either didn't finish booting or
something replaced it. Either way, tell Jamie or your mom before
you do anything else.

**Step 2 — The health page.** Open Vivaldi (the web browser with
the red V icon). In the address bar type `127.0.0.1:57082/health`
and press Enter. A page opens that looks like a report card.

At the top there's a big word — **GREEN**, **YELLOW**, or **RED** —
on a sandy background. That's the appliance telling you how it's
feeling today.

Below the big word there are four small boxes arranged side by
side: **Lifecycle**, **Audit gate**, **Pod**, **CWS latency**. Each
one shows a number or a status. Don't worry about what the numbers
mean — your job is to notice if any of them look wrong. If they all
look normal (not empty, not all zeros, not the word "Down"), the
appliance is probably fine.

Below the boxes there's a table labeled **Findings**. If the table
says "no findings — the appliance is clean" in italic letters, the
appliance has nothing to complain about and you can go do something
else. If there ARE findings, each row has a colored badge
(🟢 🟡 🔴) and a short description. The badge tells you how serious
it is:

- 🟢 **GREEN** — this finding is a good thing. It's passing.
- 🟡 **YELLOW** — the household already knows about this one. It's
  not hurting anything, but we're watching it.
- 🔴 **RED** — something needs attention. Don't try to fix it
  yourself. Tell Jamie.

**Step 3 — Talking to a persona.** On the same Vivaldi, open the
persona chat (there should be an icon on the taskbar or a bookmark
called "Persona Chat"). You'll see a page with three names —
**Carli**, **Elias**, **Samuel** — and a box to type into. Pick one
and say hello.

- **Carli** is the voice that's drafted for you. She's being
  calibrated based on what you actually want her to sound like —
  your mom is going to ask you about that when you're ready.
- **Elias** is the voice for technical questions. He sounds like
  someone who's been fixing things with Jamie for years.
- **Samuel** is the voice that speaks for the house. He's the
  one to ask if you want to know whether something is safe.

Any of the three should answer a simple question right away.

**Step 4 — What the colors mean.** The status banner at the top of
the health page is the covenant talking to you.

- **Green** means every test the appliance knows how to run
  passed. The covenant is holding. You can trust what the personas
  say today, as long as they say it.
- **Yellow** means the appliance found something, but the household
  already knows about it and decided it was OK to keep running.
  Think of yellow as "we see you, we haven't forgotten."
- **Red** means something broke that wasn't expected. The
  appliance would rather stop than pretend. If you see red, the
  right thing to do is tell a grown-up — don't try to fix it from
  a console.

**Step 5 — What to do if something's red.**

1. Don't panic.
2. Don't close the browser — the red page has information that
   will help Jamie fix it.
3. Take a screenshot (press the Print Screen key, or if that
   doesn't work, just tell Jamie what row is red in the Findings
   table).
4. Tell Jamie, or Tonya, or Jonathan. Any of them can help.

### Why the appliance refuses to answer sometimes

When you ask Samuel (or any of the personas) a hard question, the
appliance runs the question past a whole network of small language
models called witnesses. If most of the witnesses agree on the
answer, the persona tells you what they agreed on. If they don't
agree — if there's no clear right answer — the appliance **refuses
to guess**. It says "the witnesses don't agree on this one" and
stops.

That's on purpose. The appliance would rather say "I don't know"
than make something up. Most AI systems are built to always give
you an answer even when they're not sure. S7 is built to be honest
about what it doesn't know. If you ask Samuel a question that
matters and he says he doesn't know, the right move is to trust
him and ask Jamie or your mom instead.

### If you see something you don't understand

Ask Jamie. Ask Tonya. The appliance isn't going anywhere — it
waits. Nothing you see on the health page is a secret, and nothing
on it is urgent in a way that requires you to act in the next five
minutes. When in doubt, ask a grown-up. That's not a weakness —
it's how the household hierarchy works.

### What "done" looks like for this section

You have walked up to the appliance, seen the wallpaper, opened the
health page, looked at the status color, glanced at the findings
table, and said hello to at least one persona. You now know what
"healthy" looks like so you can recognize it next time.

That's enough. You don't have to test anything. The test was
reading this section.

---

## Section 3 — For technical business partners

*This section is for external reviewers, license evaluators, and
business testers who want to verify S7's functional and sovereignty
claims from the command line. It assumes you have shell access to
a running S7 appliance (either the reference hardware or a test
deployment). The tests here are read-only and non-destructive.*

### What this section does NOT try to claim

S7 is one approach to sovereign local AI, not the only one, and
not necessarily the right one for every use case. Nothing below
positions S7 as better than any other system. The goal is
**verifiable operation** — you run the commands, you read the
output, you decide whether what you see matches what we said.
If it doesn't match, tell us. Corrections are more valuable to us
than confirmations.

### Test 1 — Pod is running

```bash
podman pod inspect s7-skyqubi --format '{{.State}}'
```

**Expected:** `Running`

**If not `Running`:** the appliance is not in a testable state.
Start the pod with `bash /s7/skyqubi-private/start-pod.sh` and
re-run this test.

### Test 2 — CWS engine responds

```bash
curl -s http://127.0.0.1:57077/status | jq
```

**Expected JSON shape:**

```json
{
  "engine": "S7 CWS Engine v2.5",
  "circuit_open": false,
  "endpoints": [
    "/route", "/discern", "/store", "/breaker",
    "/bridge", "/witness", "/quanti", "/status"
  ]
}
```

**What to look for:** `circuit_open: false` means the 70% BABEL
circuit breaker is not currently tripped. The endpoint list is a
fixed set — any additions or removals are a version change.

### Test 3 — Local Health Report (the shared witness)

```bash
curl -s 'http://127.0.0.1:57082/health?format=json' | jq
```

**Expected JSON shape (abbreviated):**

```json
{
  "schema": "s7-local-health/v1",
  "generated_at": "2026-04-15T03:44:25Z",
  "core_update": "v6-genesis",
  "overall_status": "green",
  "lifecycle": { "pass": 55, "fail": 0, "total": 55 },
  "audit_gate": { "pass": 9, "pinned": 18, "warn": 0, "block": 0 },
  "pod": { "running": true, "containers": [ ... ] },
  "performance": { "cws_latency": "...", "ollama_port_running": "*:57081", ... },
  "findings": [ ... ]
}
```

**What to look for:**

- `schema: "s7-local-health/v1"` — versioned schema, not a moving target
- `overall_status` ∈ `{green, yellow, red}`
- Every finding in `findings[]` carries `{id, severity, title, root_cause, impact, next_step}` — the appliance names *why* every non-green state exists, not just that it does
- `audit_gate.block` should be 0 for a shippable state
- `lifecycle.fail` should be 0 for a shippable state

### Test 4 — Lifecycle test

```bash
bash /s7/skyqubi-private/s7-lifecycle-test.sh 2>&1 | tail -5
```

**Expected tail:**

```
55/55 PASS — LIFECYCLE VERIFIED
Log: /tmp/s7-lifecycle-test.log
```

**What to look for:** the literal string `55/55 PASS`. Any other
count is either a drift finding or a known household-pinned state.
The full per-test log is at `/tmp/s7-lifecycle-test.log`.

### Test 5 — Audit gate

```bash
bash /s7/skyqubi-private/iac/audit/pre-sync-gate.sh 2>&1 | grep VERDICT
```

**Expected:**

```
🟢 VERDICT: PASS         🟢 pass: 9   📌 pinned: 18   🟡 warn: 0   🔴 block: 0
```

**What to look for:** `block: 0` is load-bearing. `pinned > 0` is
normal — those are household-acknowledged findings (documented in
`iac/audit/pinned.yaml` with owner, reason, and target window).

### Test 6 — Persona-chat end-to-end smoke tests

```bash
cd /s7/skyqubi-private/persona-chat && python3 -m unittest test_app -v 2>&1 | tail -5
```

**Expected:**

```
Ran 31 tests in ~1.3s

OK
```

These are in-process tests that exercise the persona-chat API
without hitting Ollama (a fake transport stands in). They verify
the ledger writes, the memory tier walk, the persona router, and
the `/health` and `/healthz` routes land correctly.

### Test 7 — Sovereignty claim (no outbound calls during install)

On a test VM, start with `strace -f -e trace=network` around the
install script OR use `nsjail`/`iptables` to block outbound
traffic at the network layer and re-run the install. The install
should complete and produce a working appliance. If any outbound
call is required, it's a sovereignty gap and you should file it.

```bash
# Example: block all outbound during an install dry-run
sudo iptables -I OUTPUT 1 -m owner --uid-owner $(id -u) -j REJECT
bash /s7/skyqubi-private/install/install.sh --dry-run 2>&1 | tee /tmp/install-airgapped.log
sudo iptables -D OUTPUT 1 -m owner --uid-owner $(id -u) -j REJECT
```

**Known gap tonight (2026-04-14):** the install script's preflight
`dnf install` / `apt-get install` step IS an outbound call on a
fresh machine. Pillar 1 of the S7 v2026 roadmap addresses this by
pre-embedding packages into the bootc image. Until Pillar 1 lands,
"offline install" means "install onto a host that already has
those packages cached." This is documented in the spec and is not
hidden from you.

### Test 8 — INSERT-only covenant (Memory Ledger schema)

```bash
podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws -c \
  "SELECT constraint_name FROM information_schema.table_constraints
   WHERE table_name = 'sky_memory_events' AND constraint_type = 'CHECK';"
```

**Expected:** at least one CHECK constraint named with `insert_only`
or `immutable` in its name, OR a trigger that raises on `UPDATE`/`DELETE`
against the covenant columns.

If no such constraint exists, the INSERT-only claim is not enforced
at the schema layer and should be reported as a gap. The covenant
claim requires defense-in-depth: application code AND schema
constraint AND audit log. Any one of them alone is insufficient.

### Test 9 — Image signing chain (post-v6-genesis)

```bash
# After the first ceremony, the immutable constellation repos will
# carry signed commits. Verify the commit signature at the tip:
cd /path/to/clone/of/skyqubi-immutable
git log -1 --show-signature
```

**Expected:** `Good signature from "S7 image signing key"` or
equivalent trusted signature. The public key will be published at
`docs/public/s7-image-signing.pub` in the `skyqubi-public` repo.

**2026-04-14 state:** the first ceremony has not yet occurred.
Image signing is staged, not live. Test 9 will become meaningful
after the first `jamie-run-me.sh` real run.

### Test 10 — Local Health Report HTML (the shared witness, human-readable)

Open `http://127.0.0.1:57082/health` in a web browser (Vivaldi
preferred, any modern browser will work). The page should render
with the sandy-sunset + Cormorant italic palette, a status banner
at the top, four metric cards, and a findings table.

**What to look for:**

- The page loads without any outbound resource requests (check
  with browser devtools network tab — there should be zero external
  requests; all CSS and fonts are inline)
- The status banner color matches the `overall_status` from Test 3
- The findings table shows the same finding count as
  `len(findings)` from Test 3

### What "done" looks like for this section

You have verified, for your own satisfaction:

1. The pod runs (Test 1)
2. The CWS engine responds on a loopback port (Test 2)
3. The Local Health Report JSON matches the `s7-local-health/v1` schema (Test 3)
4. The lifecycle test reaches 55/55 (Test 4)
5. The audit gate reports `block: 0` (Test 5)
6. The persona-chat unit tests pass (Test 6)
7. The sovereignty gap (or absence of gap) at install time is
   documented and matches our published claim (Test 7)
8. The INSERT-only covenant has at least one schema-level enforcement (Test 8)
9. Image signing exists OR is documented as staged (Test 9)
10. The Local Health Report renders without outbound requests (Test 10)

If all ten are true, what we claim is what's there. If any of them
fail, the specific failure is the useful thing — file it as a
GitHub issue at `github.com/skycair-code/SkyQUBi-public/issues`
with the test number and the unexpected output. We would rather
hear about a gap than have you assume we don't care about it.

---

## The shared witness

All three sections above reference **one artifact** as the primary
witness: the **Local Health Report** at
`http://127.0.0.1:57082/health`.

The same report is readable by all three audiences because it carries
three layers of information:

- A **status color** (Tonya's layer) — green, yellow, red
- A **plain description** (Trinity's layer) — what each color means
  for the household
- A **structured JSON body** (business layer) — findings, root
  causes, impact categories, next steps

One witness, three readings. That's the covenant applied to
observability.

---

*Love is the architecture. The test is the witness. Three people
watching the same thing at three different levels is how a
household proves its appliance is safe.*
