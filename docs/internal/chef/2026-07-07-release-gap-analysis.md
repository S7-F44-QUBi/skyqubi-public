# 2026-07-07 Release — Gap Analysis & Roadmap

> **Scope:** the first CORE ceremony — GO-LIVE Release 7, scheduled
> for **2026-07-07 07:00 CT**. This is the first time the immutable-
> fork rebuild architecture (CHEF Recipe #4) actually runs. Every
> item in this document is either a blocker the ceremony cannot
> proceed without, a must-have that makes the ceremony serve the
> household correctly, a should-have that strengthens the release,
> or a nice-to-have that can carry forward.
>
> **Window:** ~12 weeks from 2026-04-14 (session close) to
> 2026-07-07. Allowing for Jamie's other work, Tonya's review cycles,
> and unexpected blockers, realistic working capacity is roughly
> **6–8 focused Chair sessions**, each 2–4 hours.
>
> **Purpose of this document:** a checklist Trinity or Jonathan
> could read and understand the remaining work, not just a Chair-
> facing TODO. Each item has: current state, target state, effort,
> owner, blockers.

---

## The four priority tiers

- **🔴 BLOCKER** — the ceremony cannot proceed without this. If
  even one BLOCKER is unresolved at 2026-07-07 07:00, the
  ceremony halts and a covenant emergency is called.
- **🟠 MUST** — the ceremony *could* proceed without this, but
  the covenant would be diminished. Ship before the ceremony.
- **🟡 SHOULD** — strengthens the release. Ship if budget
  allows; carry forward if not.
- **🟢 NICE** — pure improvement. Carry forward to v2027 is
  acceptable.

---

## BLOCKERS (🔴) — must be done before 2026-07-07 07:00 CT

### B1 — Tonya signs CHEF Recipe #3 (Seven Silences)
- **Current:** Chair-draft approved by Jamie 2026-04-14, pending Tonya
- **Target:** Tonya has read the recipe (or a household-readable projection via Samuel), signed off, or corrected, or rejected
- **Effort:** 30 minutes of Tonya's time + 15 minutes of Chair time to record her signature in the frontmatter
- **Owner:** Tonya (decision), Chair (record)
- **Blocks:** all voice calibration work, all persona-chat silence implementation
- **Depends on:** Tonya being at the counter with the binder open

### B2 — Tonya witnesses the CORE reframe and promotes it from CHAIR-DRAFT
- **Current:** `feedback_qubi_is_core_prism_grid_wall.md` marked `status: CHAIR-DRAFT`, `awaiting_witness: tonya`
- **Target:** Tonya has read the reframe (or a Samuel-read plain-language version), signed off, and the Chair has removed the draft markers in a single commit labeled "witnessed by [jamie, tonya]"
- **Effort:** 45 minutes of Tonya's time + 15 minutes of Chair time
- **Owner:** Tonya (decision), Chair (record)
- **Blocks:** the reframe can be referenced as covenant-grade only after this. Samuel's training corpus needs the promotion to treat it as foundational.
- **Depends on:** Tonya has capacity, Samuel has the plain-language projection ready

### B3 — (a)/(b)/(c)/(d) decision on the two unauthorized public commits
- **Current:** Confession row committed, decision pending. Chair recommends (d) — implicit retire via first rebuild ceremony
- **Target:** Decision named in the record, path set for the ceremony
- **Effort:** 15 minutes of Tonya's time (or Jamie if he decides to hold this one)
- **Owner:** Tonya (per the session handoff routing) or Jamie
- **Blocks:** the ceremony's rebuild mechanism — if (c) hard-reset is chosen, it has to happen BEFORE the ceremony; if (d) implicit-retire is chosen, the ceremony's orphan rebuild IS the retirement; if (a)/(b) is chosen, different pre-ceremony work
- **Depends on:** Tonya/Jamie decision

### B4 — Three exception-category co-signers named
- **Current:** Categories named (PRISM breach, WALL breach, SAFE breach), co-signer governance question unresolved
- **Target:** Tonya has named who co-signs with her on each emergency category (e.g., "Jamie for PRISM, Jonathan for WALL, Trinity for SAFE", or "Jamie on all three", or some other configuration she prefers)
- **Effort:** 20 minutes of Tonya's time, ideally with Jonathan and Trinity consulted
- **Owner:** Tonya
- **Blocks:** any future emergency that tries to break the yearly cycle without knowing who signs
- **Depends on:** Tonya, maybe Jonathan/Trinity consultation

### B1.5 — Trinity articulates her three core questions about S7
- **Current:** Trinity is mentioned as a destination ("Carli reaches Trinity") but not as an active agent in any gap-analysis item. Added by the 2026-04-14 persona-internal council's Carli catch.
- **Target:** Trinity has named three questions she actually has about the household's relationship with QUB*i*. Her questions — not Jamie's assumptions about what she should ask — become the foundation the Carli voice corpus is drafted around.
- **Effort:** 30 minutes of Trinity's time, in conversation with Jamie or Tonya
- **Owner:** Trinity (with household support)
- **Blocks:** B5 (Carli voice corpus draft cannot begin until Trinity's questions exist)
- **Depends on:** B1.6 (her consent precedes her articulation)

### B1.6 — Trinity's own consent to the Carli conversation
- **Current:** Carli's 2026-04-14 council response surfaced this: "Tonya's explicit permission isn't enough. Trinity's actual consent is the covenant." Not in the original gap analysis.
- **Target:** Tonya has told Trinity that Carli exists. Trinity has agreed to the conversation. Trinity understands Tonya can say "no" anytime and will hear everything. Trinity has said "yes" in her own voice.
- **Effort:** 15-30 minutes of household time
- **Owner:** Tonya introduces, Trinity consents
- **Blocks:** B1.5, B5, and all downstream Carli work
- **Depends on:** B1 (Recipe #3 signed by Tonya so the silence taxonomy is stable before Trinity is told how QUB*i* communicates)
- **Covenant note:** This is the covenant-grade insight from the first-ever persona-internal council. Consent flows from the reached person upward to the authorizer. The person being reached has agency in their own AI mirror. Applies to all three personas: Carli (Trinity's consent), Elias (Jamie's consent — implicit because he's the builder), Samuel (the whole household — Noah's parents consent on Noah's behalf).

### B20 — Public Support link working (currently 404)
- **Current:** `https://buymeacoffee.com/skycaircode` returns HTTP 404. Fixed in private canonical source (`docs/public/index.html` footer, replaced with GitHub Discussions link). Not yet on public main.
- **Target:** Live on public main. Visitors clicking Support see the Discussions page, not a 404.
- **Effort:** 1 push operation (part of the SAFE-breach covenant exception)
- **Owner:** Jamie authorizes push mechanism
- **Blocks:** Tonya's observation of Three Rule #1 violation
- **Depends on:** Push mechanism (Path A/B/C from the covenant exception invocation)
- **Notes:** Tonya personally reported this. See `docs/internal/postmortems/2026-04-14-safe-breach-covenant-exception-public-bugs.md`.

### B21 — Public Contact email reliable fallback (mailto unreliable across devices)
- **Current:** Hero `Contact` button was `mailto:omegaanswers@123tech.net?subject=...` which does not reliably open an email composition on all devices. Fixed in private canonical source: Contact button now scrolls to a new `#contact` section with the email address rendered as visible copyable text. Footer email similarly updated.
- **Target:** Live on public main. Visitors on any device can see and copy the email address without depending on `mailto:` launching a client.
- **Effort:** Same push as B20
- **Owner:** Same as B20
- **Blocks:** household usability of the public-facing surface
- **Depends on:** Push mechanism

### B22 — User documentation reflects release status and path to 2026-07-07
- **Current:** Public `docs/public/README.md` updated with a "Release status — pre-GO-LIVE testing window" section, a "Path to July 7, 2026" section, and a Contact section with visible email. Not yet on public main.
- **Target:** Public README names what's deployed today, what's NOT deployed yet, what changed today, and the path forward to 2026-07-07. Sets correct pre-launch-tester expectations. Key line: "This is a production-ready deployment for testing purposes — not yet a production-ready deployment for general household use. The distinction matters."
- **Effort:** Same push as B20
- **Owner:** Same as B20
- **Blocks:** public testers receiving stale status information
- **Depends on:** Push mechanism

### B5 — Per-persona voice calibration for Carli (reaches Trinity)
- **Current:** No voice calibration corpus exists; persona definitions are in code but "what Carli sounds like" is not specified
- **Target:** Carli's voice is a documented corpus of example utterances signed by Tonya. The corpus is the training anchor — "this is what Carli sounds like in this household."
- **Effort:** 2–3 sessions. Gather/write ~50 example turns in Carli's voice. Tonya reviews each. Sign off.
- **Owner:** Chair writes the draft corpus, Jamie refines, Tonya signs
- **Blocks:** Carli's live persona updates (any persona-chat voice work)
- **Depends on:** Recipe #3 signed (B1) because silence timing affects voice

### B6 — Per-persona voice calibration for Elias (reaches Jamie)
- **Current:** Same as B5, for Elias
- **Target:** Elias corpus signed by Tonya (per-persona approval model)
- **Effort:** 2 sessions
- **Owner:** Chair draft, Jamie refine, Tonya sign
- **Blocks:** Elias live persona updates
- **Depends on:** B5 complete (per the Round 2 sequencing: Carli first)

### B7 — Per-persona voice calibration for Samuel (reaches EVERYONE including Noah)
- **Current:** Same as B5, for Samuel
- **Target:** Samuel corpus signed by Tonya. **Noah is the floor** — Samuel's corpus must be readable to the youngest child without harm.
- **Effort:** 3–4 sessions because Samuel's voice has the highest stakes (reaches the whole household)
- **Owner:** Chair draft, Jamie refine, Tonya sign
- **Blocks:** Samuel's live persona updates, Samuel's voice of the audit, Tonya digest voice
- **Depends on:** B5 and B6 complete

### B8 — GitHub Pages orphan-force-push verified on a throwaway repo
- **Current:** Assumption: "GH Pages rebuilds from the current tip of main after every push, so an orphan-branch force-push should work." Unverified.
- **Target:** A throwaway GitHub repo has been created, had its main branch force-pushed with an orphan root commit, GH Pages deployment verified to rebuild and serve correctly within the expected 30-120s window. Document the exact behavior observed.
- **Effort:** 1 session to set up + verify + document
- **Owner:** Jamie + Chair (Jamie holds the GitHub account)
- **Blocks:** the entire ceremony. Per CHEF Recipe #4 Round 2 precondition #1, **no real rebuild touches `skyqubi-public` until this verification is complete and documented.**
- **Depends on:** Jamie creating the throwaway repo

### B9 — `rebuild-public.sh` upgraded from stub to real
- **Current:** Stub refuses all runs except `--dry-run`. Reads registry but can't act.
- **Target:** Real implementation that: (1) reads the latest non-retired registry entry, (2) verifies bundle existence + sha256 + GPG signature + Tonya sign-off artifact, (3) refuses any bundle except the latest (closes Skeptic Round 1 bundle-replay attack), (4) unpacks bundle into scratch, (5) extracts files per `PUBLIC_MANIFEST.txt`, (6) creates an orphan branch in the public repo with a signed single commit, (7) force-pushes via the ceremony-only credential mechanism (to be defined — see B13).
- **Effort:** 2–3 sessions
- **Owner:** Chair writes, Jamie reviews, gate verifies via zero #12 pre-ceremony dry-run
- **Blocks:** the ceremony's execution step
- **Depends on:** B8 (GH Pages verified), B13 (ceremony credential defined), B14 (PUBLIC_MANIFEST.txt format defined)

### B10 — `advance-immutable.sh` upgraded from stub to real
- **Current:** Stub `--help` only. Refuses to run.
- **Target:** Real implementation that performs the 14-step ceremony per Recipe #4 in order, with fail-fast at every step and rollback on any step failure.
- **Effort:** 2 sessions
- **Owner:** Chair writes, Jamie reviews, council round (Round 1 minimum) signs off on the shape
- **Blocks:** the ceremony's orchestration
- **Depends on:** B9 (rebuild-public.sh works), B13 (credential), B14 (manifest), B15 (Tonya sign-off artifact format)

### B11 — `iac/audit/core-update-days.txt` has `2026-07-07` added
- **Current:** Only `2026-04-14` is listed (for tonight's authorization that ultimately did not execute a sync)
- **Target:** `2026-07-07  # First CORE ceremony — GO-LIVE Release 7 — Jamie + Tonya + image-signing key authorized` added and committed on lifecycle
- **Effort:** 5 minutes
- **Owner:** Chair (can do this on any pre-ceremony session)
- **Blocks:** the ceremony's freeze gate will refuse the advance otherwise
- **Depends on:** Jamie confirming the date hasn't slipped

### B12 — Audit gate zero #10 must be in a state where the ceremony can advance the pins
- **Current:** `frozen-trees.txt` pins lifecycle + private/main + `public/main PENDING`. Fast-forward-ancestor check active.
- **Target:** Zero #10's treatment of public/main must be amended so that on the day of the ceremony, the ceremony script can move public/main from `PENDING` to a real sha in the same commit that adds the first registry entry (the pin-transition protocol from Recipe #4 Round 2).
- **Effort:** 1 session (gate logic change + test)
- **Owner:** Chair
- **Blocks:** the ceremony's final commit (the one that advances all three pins atomically)
- **Depends on:** Nothing structural. Can be done any session.

### B13 — Ceremony-only credential mechanism defined
- **Current:** Recipe #4 says "a separate force-push mechanism with a ceremony-only credential." Mechanism unnamed.
- **Target:** Concretely: a specific GitHub PAT or SSH key with force-push-to-main permission that is (a) only present on disk during the ceremony window, (b) revoked immediately after the ceremony, (c) separate from the day-to-day `skycair-code` PAT. OR: a deploy-key-based mechanism that handles the force-push without toggling branch protection. **Decision needed.**
- **Effort:** 1 session (design + create the credential + test on throwaway repo + document revocation)
- **Owner:** Jamie (credential management is his)
- **Blocks:** B9 (`rebuild-public.sh` depends on this mechanism existing)
- **Depends on:** Jamie's decision on which credential pattern to use

### B14 — `PUBLIC_MANIFEST.txt` format defined and generated
- **Current:** Recipe #4 names the concept but not the format. The legacy sync script has an exclude list at `s7-sync-public.sh` that names what DOESN'T go to public; the manifest should name what DOES go.
- **Target:** `PUBLIC_MANIFEST.txt` format is defined (glob patterns? literal file list? include + exclude?). A generator script produces the manifest from the current repo state. The manifest is committed to private/main and becomes part of the immutable bundle.
- **Effort:** 1 session
- **Owner:** Chair drafts, Jamie signs
- **Blocks:** B9 (rebuild-public.sh reads the manifest)
- **Depends on:** Nothing structural

### B15 — Tonya sign-off artifact format defined
- **Current:** Recipe #4 names the concept ("a plain-text statement at `<bundle>.tonya.txt` plus a detached GPG signature at `<bundle>.tonya.sig`"). Not yet committed or tested.
- **Target:** Concrete file format, location convention, and the exact text Tonya writes (not a template she fills in — her own words). Image-signing key used for the detached signature. Verified via a dry-run sign.
- **Effort:** 1 session (format + first dry-run) + 15 minutes of Tonya's time for the real sign
- **Owner:** Chair drafts, Jamie reviews, Tonya produces the real artifact at ceremony time
- **Blocks:** B9 (rebuild-public.sh verifies this artifact)
- **Depends on:** Tonya understanding the ceremony's purpose (B2 witness to CORE reframe should cover this)

### B16 — Legacy-path operational tier migrated (pod, dashboard, bitnet-mcp, caddy)
- **Current:** Four services run from `/s7/skyqubi/` (legacy path). Two have no canonical version in `/s7/skyqubi-private/` at all (dashboard `server.py`, Caddyfile). Documented in the legacy-path postmortem.
- **Target:** All four services run from `/s7/skyqubi-private/`. Dashboard and Caddy files migrated into private repo. Systemd units + autostart `.desktop` files updated. `/s7/skyqubi/` archived (not deleted yet) to `/s7/archive/skyqubi-legacy-2026-04-14/`. Restart cascade performed in dependency order within the ceremony window.
- **Effort:** 2–3 sessions for migration + 1 ceremony-day restart cascade
- **Owner:** Chair (migration), Jamie+Tonya authorize the restart cascade
- **Blocks:** the ceremony's invariant "QUBi owns its own wires" — having services on untracked operational tier is a WALL hole
- **Depends on:** Decision on whether this migration happens BEFORE the ceremony (as a pre-ceremony cleanup) or IN the ceremony (as part of the v2026 CORE advance)

### B17 — Ollama moved to `127.0.0.1:57081`
- **Current:** Autostart `.desktop` fix is in private repo (committed tonight). Ollama still runs on `*:7081` because restart hasn't happened.
- **Target:** Ollama running on `127.0.0.1:57081`. Lifecycle test A01–A07 green. Loopback-only per civilian mandate.
- **Effort:** 1 restart operation (with council witness)
- **Owner:** Jamie authorizes, Chair verifies
- **Blocks:** lifecycle test 55/55, `monitor-baseline-stale` pin resolution
- **Depends on:** Scheduled alongside B16 restart cascade, OR on the first ceremony day

### B18 — Six code-side `7081` references updated
- **Current:** `engine/s7_rag.py` env-var default + `mcp/bitnet_mcp.py` hardcoded + 4 phase test files hardcoded
- **Target:** Single source of truth (`iac/s7-ports.env` — proposed in Recipe #4's Phase 3). All six files read from the shared config.
- **Effort:** 1 session (create ports.env + update 6 files + test)
- **Owner:** Chair
- **Blocks:** lifecycle test stability after B17
- **Depends on:** Design decision on `iac/s7-ports.env` schema

---

## MUST-HAVES (🟠) — ship before ceremony, covenant is diminished without

### M1 — Design-for-silence completion (all seven silences wired)
- **Current:** Taxonomy shipped (CHEF Recipe #3). No implementation.
- **Target:** Each of the seven silences has at least a stub implementation in persona-chat: the UI signal is rendered correctly, the audit hook fires where appropriate, the covenant rules are enforced at runtime (e.g., "broken silence must acknowledge within 2 seconds").
- **Effort:** 3–4 sessions
- **Owner:** Chair implements, Jamie reviews, Tonya verifies via Samuel on Vivaldi
- **Blocks:** none (can ship partial), but the household experience is incomplete without
- **Depends on:** B1 (Recipe #3 signed), B5/B6/B7 (voice calibration for signal text)

### M2 — Persona-handoff protocol (from CHEF #4 Round 2)
- **Current:** The Skeptic Round 2 on the QUBi-communication-training council identified this gap. No design exists.
- **Target:** When the household switches Carli → Elias mid-thought: visible tag, ledger entry, explicit bridge-or-reset decision at each handoff. Document the protocol as CHEF Recipe #5 or as a section in an existing recipe.
- **Effort:** 1 session (design) + 1–2 sessions (implementation)
- **Owner:** Chair drafts, council round signs off
- **Blocks:** persona-chat handoff usability (currently no mechanism)
- **Depends on:** B5/B6/B7 (voice calibration to know what "Carli's voice" looks like before defining handoff)

### M3 — Retroactive Tonya veto protocol
- **Current:** Skeptic Round 2 identified: "Tonya's veto is retroactive, not preventive. Household training happens when she isn't present." No mechanism for periodic re-baseline.
- **Target:** Samuel runs a periodic replay of its recent output to Tonya in plain language, on a cadence she chooses (weekly? monthly?), for re-approval or explicit veto. The cadence and the mechanism are documented.
- **Effort:** 1 session (design) + 1 session (implementation stub)
- **Owner:** Chair drafts, Tonya decides cadence
- **Blocks:** long-term trust drift — after months, Tonya's Jan approval doesn't cover the shape she'd veto in July
- **Depends on:** B7 (Samuel voice calibration signed so there's something to replay)

### M4 — Household hierarchy map for covenant-break detection
- **Current:** Skeptic Round 2 identified the gap: "If Noah catches Samuel lying before Tonya, does the covenant weight change?" No mechanism.
- **Target:** Any household member can raise a flag ("this feels wrong"). The disposition (believed / deferred / overridden) is logged per member with reason. The map defines who is listened to on what kind of concern (Tonya on covenant, Jamie on technical, Trinity on adolescent context, Jonathan on steward duties, Noah as the floor).
- **Effort:** 1 session (design) + 1 session (persona-chat flag UI)
- **Owner:** Chair drafts, Tonya reviews, Trinity/Jonathan consulted
- **Blocks:** Noah-catches-it-first scenario (currently undefined)
- **Depends on:** B4 (exception co-signers — related governance question)

### M5 — Audit gate zero #13 — PRISM/GRID/WALL integrity
- **Current:** Proposed in CHEF Recipe #4 addendum but deferred. Zero #12 only checks registry state.
- **Target:** New audit zero that verifies: (1) PRISM's 4-way verdict engine is operating within expected classification bounds on a test corpus, (2) GRID's memory rooms are at their expected pillar+weight distribution, (3) WALL's refusals fired the expected number of times since last check. BLOCK if any drift.
- **Effort:** 2 sessions
- **Owner:** Chair
- **Blocks:** none (nice-to-have structurally), but names the PRISM/GRID/WALL trinity in the gate
- **Depends on:** B2 (CORE reframe promoted) because the trinity is only covenant-grade after Tonya signs

### M6 — Axis B tools installed (`bandit`, `shellcheck`, `gitleaks`, `pip-audit`)
- **Current:** Zero #9 runs in graceful degradation mode. Trivy already installed. Four tools still missing.
- **Target:** All five installed via `dnf` (Fedora packages). Zero #9 runs them and reports clean.
- **Effort:** 30 minutes (Jamie types sudo commands)
- **Owner:** Jamie
- **Blocks:** the SAFE pillar's vulnerability axis from being fully operational
- **Depends on:** Jamie being at a terminal with sudo

### M7 — Lifecycle test achieves 55/55 green
- **Current:** 48/55 green with 7 AI-tier failures (A01-A07) caused by Ollama port drift
- **Target:** 55/55 after B17 (Ollama restart to 57081) and B18 (6 code refs updated)
- **Effort:** 1 session (re-run + any corrections)
- **Owner:** Chair
- **Blocks:** the ceremony's PRE-FLIGHT audit requirement "all tests green"
- **Depends on:** B17, B18

### M8 — Pasta networking verified on running pod
- **Current:** The running pod is on `podman-default-kube-network`, NOT pasta (from the pod triple-drift postmortem). Tonight's fix is in the canonical start-pod.sh in private, but the running pod was started from the legacy `/s7/skyqubi/` location
- **Target:** Pod restarted via canonical `/s7/skyqubi-private/start-pod.sh` with `--network pasta:-T,auto`. Verified via `podman pod inspect`.
- **Effort:** 1 restart (within B16 cascade)
- **Owner:** Jamie authorizes
- **Blocks:** container→host TCP corner cases
- **Depends on:** B16 (part of the legacy-path migration cascade)

### M9 — Memory corpus individual re-tagging pass
- **Current:** 99 files tagged tonight via rule-based first pass. Some assignments may be wrong.
- **Target:** Each file's pillar+weight reviewed individually, corrected where the rule-based first pass mis-categorized
- **Effort:** 2 sessions (spot-check + correct)
- **Owner:** Chair
- **Blocks:** none (the first pass is "reasonable default"), but corpus quality for Samuel retrieval
- **Depends on:** Nothing

---

## SHOULD-HAVES (🟡) — strengthens the release

### S1 — Samuel heartbeat skill (Phase 4 of Jamie Love RCA wiring plan)
- **Current:** Not started. Exists as "next session's work" in memory.
- **Target:** Samuel runs RCA steps 1-4 on a slow heartbeat (every 20-30 minutes, not every few seconds), outputs to MemPalace, escalates to steward channel on findings. Never runs step 5 (the climb) — that requires a human.
- **Effort:** 2 sessions
- **Owner:** Chair
- **Blocks:** none
- **Depends on:** Nothing structural

### S2 — Tonya digest into persona-chat as a real `/digest` route (activation)
- **Current:** `/digest` and `/digest.txt` routes are coded in `persona-chat/app.py` but persona-chat hasn't been restarted to activate them
- **Target:** Routes live. Tonya opens Vivaldi, hits `127.0.0.1:57082/digest`, sees the HTML digest.
- **Effort:** 1 restart operation (needs to not interrupt household usage — time carefully)
- **Owner:** Jamie authorizes the restart
- **Blocks:** none (can wait)
- **Depends on:** A gap in household usage where a brief persona-chat restart is acceptable

### S3 — `iac/s7-ports.env` shared config
- **Current:** Proposed in multiple places (Recipe #4 Phase 3, Multi-launcher drift pellet). Not created.
- **Target:** Single file exporting `S7_OLLAMA_PORT=57081`, `S7_PG_PORT=57090`, `S7_CWS_PORT=57077`, etc. All launchers source it. Lint rule prevents port literals in any other file.
- **Effort:** 1 session
- **Owner:** Chair
- **Blocks:** B18 (the 6-file sweep becomes easier with this file in place)
- **Depends on:** Nothing

### S4 — LYNC corpus balance
- **Current:** Memory corpus is SYNC/SAFE-heavy. Only 2 LYNC entries (Samuel family advisor + Seven Silences pellet).
- **Target:** At least 3-4 more LYNC entries distilled from Recipe #3, the persona definitions, Tonya design signoffs, Vivaldi-as-trusted-client memory
- **Effort:** 1 session
- **Owner:** Chair
- **Blocks:** none
- **Depends on:** Nothing

### S5 — Nightly snapshot retention policy
- **Current:** `iac/audit/nightly-snapshot.sh` writes to `audit-living/<date>.md` insert-only. No retention/compression policy. File count grows without bound.
- **Target:** Retention policy: daily files for 90 days, then consolidated weekly, then monthly after a year. Old files archived to a compressed format not purged.
- **Effort:** 1 session
- **Owner:** Chair
- **Blocks:** none near-term (tonight is day 1; won't matter for months)
- **Depends on:** Nothing

### S6 — Consent model for Respectful silence
- **Current:** Recipe #3 names that Respectful silence (persona listening when not directly addressed) requires per-member-per-persona consent. No consent graph schema.
- **Target:** A consent graph where each household member can opt each persona in or out of "listen to me when I'm not talking to you." Signed by the member, per-persona, updatable.
- **Effort:** 2 sessions
- **Owner:** Chair drafts, each member signs their own consent
- **Blocks:** Respectful silence type from being activated
- **Depends on:** B1 (Recipe #3 signed so the concept is covenant)

---

## NICE-TO-HAVES (🟢) — carry forward if not done

### N1 — Samuel-as-Round-2-Chair self-evaluation
- Samuel runs its own output through a Round 2 Chair critique: "did I lean Builder, Skeptic, or Witness in that response?" Structural self-check on tone.
- Effort: 2 sessions design, implementation indefinite

### N2 — Automated pillar+weight suggestion for new memory entries
- When a memory entry is added without pillar/weight, Samuel suggests values based on the name/description keywords
- Effort: 1 session

### N3 — Prometheus + Grafana for observability
- Deferred to v7 post-work per Jamie's earlier ruling. Not blocking v2026.
- Effort: 3-5 sessions (significant stack addition)

### N4 — Household-facing onboarding for Trinity and Jonathan as stewards
- A short walkthrough packet for each co-steward explaining their role, authority limits, when to escalate to Tonya
- Effort: 1 session per steward

### N5 — The first household-visible delta for v2026 named
- The CORE frame measures minimality in household-visible deltas. v2026 needs at least ONE named household-visible delta (otherwise the ceremony is 0 deltas and would be "why are we doing this?"). Candidates: activating the Tonya digest, activating the seven silences, activating voice calibration for Carli.
- **This is actually a MUST (M-tier) not a nice-to-have.** Moving in the roadmap doc for the next revision.
- Effort: depends on which delta

---

## Count summary

| Tier | Count |
|---|---|
| 🔴 Blockers | 18 |
| 🟠 Must-haves | 9 |
| 🟡 Should-haves | 6 |
| 🟢 Nice-to-haves | 5 |
| **Total** | **38** |

---

## Dependency chain — what must happen in what order

```
B3 (a/b/c/d decision on unauthorized commits)
  ↓
B8 (GH Pages throwaway verification)
  ↓
B13 (ceremony credential) ─┐
B14 (PUBLIC_MANIFEST.txt)  ├─→ B9 (rebuild-public.sh real)
B15 (Tonya sign-off format)┘       ↓
                                   B10 (advance-immutable.sh real)
                                   ↓
                                   B11 (2026-07-07 in core-update-days.txt)
                                   B12 (zero #10 pin-transition logic)
                                   ↓
                                   B16+B17+B18 (legacy migration + Ollama port)
                                   ↓
                                   M7 (lifecycle test 55/55)
                                   ↓
                                   ═══ CEREMONY ═══
                                   (first CORE advance)

Parallel chain (no dependencies on ceremony mechanics):
B1 → B5 → B6 → B7 → M1 (voice + silence implementation)
B2 → M5 (CORE reframe promoted → zero #13 gets to exist)
B4 → M4 (exception co-signers → hierarchy map)
```

---

## Estimated sessions required

- **Blockers:** ~18 sessions (some can parallelize if Chair has multiple sessions per day, but realistically 12-14 sessions of focused Chair + household work)
- **Must-haves:** ~10 sessions
- **Should-haves:** ~6 sessions (can skip any if budget tight)
- **Nice-to-haves:** ~0 (defer to v2027)

**Total blocker + must-have effort:** ~22-28 sessions over 12 weeks. Realistic if Jamie can give 2-3 focused sessions per week. **Tight but achievable.**

---

## The one thing that must happen first

**B1 — Tonya signs Recipe #3.** Nothing in the voice calibration chain (B5/B6/B7) can begin without it. B5 is the longest chain (2-3 sessions per persona × 3 personas = 6-9 sessions). If Tonya's signature doesn't land in the first 2 weeks, the voice calibration chain will not finish by 2026-07-07.

**The Chair's first move of the next session should be: place the Tonya review packet on the counter and ask.**

---

## Risks

1. **Tonya doesn't have bandwidth to review 5 items in 12 weeks.** Mitigation: prioritize B1 + B2 first; the others can defer to v2027 if needed. A ceremony with partial Tonya signatures is still a ceremony — the missing pieces simply stay CHAIR-DRAFT.
2. **GitHub Pages doesn't survive orphan force-push in the way we expect (B8).** Mitigation: if the throwaway test shows GH Pages breaks, pivot to a non-orphan approach (revert + sync) and document the compromise.
3. **The six exception co-signers Tonya names disagree on an emergency.** Mitigation: tie-breaker protocol named in advance (Tonya always wins, but the co-signer's objection is logged).
4. **Jamie's other work (2XR LLC, household) competes for session capacity.** Mitigation: nothing. Time is fixed. Prioritize blockers; defer should-haves and nice-to-haves.
5. **A PRISM/WALL/SAFE breach happens before the ceremony.** Mitigation: the three exception categories are named; Tonya's emergency signature is the mechanism. Pre-define the emergency invocation so there's no confusion.

---

## The covenant closing reminder

**Minimalism is measured in household-visible deltas, not blocker count.** This document lists 38 items. That is NOT 38 household-visible deltas. Most of these are implementation work (code, configs, migrations) that produce ZERO household-visible change. The v2026 ceremony's "minimal immutable update" is the count of things the household will experience differently on 2026-07-07 compared to 2026-07-06. That count should be small: **one or two deltas, maybe three.** The rest of this list is the means; the one or two deltas are the advance.

**Candidate deltas for v2026:**

1. **The Tonya digest is live in persona-chat** — she can see audit findings in plain language
2. **Samuel speaks in Carli's voice to Trinity** — the first signed voice calibration activates
3. **The seven silences have visible signals** — no more undesigned silence

If any one of those ships and Tonya signs it, v2026 is a successful CORE advance. If all three ship, it's a strong advance. If none ship, the ceremony has been implementation work for three months with no covenant-grade change — which is an honest failure and should be named as such.

---

## Frame

Love is the architecture. Love names its gaps honestly. Love
plans the ceremony it can actually deliver, not the ceremony it
wishes it could. **2026-07-07 is 12 weeks away. The binder is
on the counter. The five Tonya-pending items are the gate
before anything else begins. Start there.**
