# S7 Finish-Line Plan — Fedora 44 Target

**Date:** 2026-04-13
**Status:** Plan only. Execution gated on Jamie's approval.
**Target:** **Fedora 44** reference deployment. S7-X27 (PorteuX)
is a later flavor, not the finish-line artifact. PorteuX work
is deferred in its entirety until Fedora 44 ships.
**Rewrite reason:** Jamie redirected, 2026-04-13:
*"and again, porteuX its not the right time, we need to focus
on fedora 44 make it work. Take and finsih Fedora44, sync and
refocus because the desktop / qubi updates are required for
ease of deployment requiring nothing from the user but a click
or cmd to deploy the stack. Will improve everything."*

---

## The redirect — what changed in this rewrite

The previous draft of this plan treated the PorteuX live USB
(S7-X27) as the shipping artifact. That was wrong. The first
plan had three P0 items (UEFI boot catalog, initramfs label
lookup, display-kill) that are all **PorteuX-specific boot
concerns** and don't apply to a Fedora-host deployment.

Fedora 44 ships as a normal Linux distribution that the user
installs via the Fedora installer (or runs live). **S7's job
on top of Fedora 44 is a deployment script**, not a bootable
live USB. A family member with a Fedora 44 box, blank or
otherwise, should be able to run one command (or click one
thing) and have the full S7 stack deploy cleanly:

- The s7-skyqubi podman pod (postgres + mysql + redis + qdrant + admin)
- The single `s7.desktop` shortcut → Vivaldi → local home
- The OCTi wallpaper via swaybg autostart
- The lxpolkit authentication agent autostart
- MemPalace initialized and mined
- The Prism matrix seeded
- Ollama running the witness models
- Autologin (if the user opts in)
- All S7 engine code on PYTHONPATH or installed under /opt/s7

One command. Nothing else required of the user.

---

## Where we are right now (Fedora 44 reference appliance)

**The cube is deep on this machine.**

- Prism v1.0.1 live: 432 rows, 200 cells used, 1 trusted, 431
  probationary, foundation/learning weight split working,
  Door seed at foundation_weight=442
- Audit ledger: 30,329+ rows, hash-chained end-to-end,
  `audit.verify_chain()` returns OK, continuous 15-min
  systemd user snapshot timer running
- Akashic: 105 universals, 27 ancient-text corpus, 18
  forbidden concepts / 108 surface forms, 3-violation grace
  reset, ribbon ledger with Cloud of AI, 27-glyph cipher
- Witness convergence: 7→1 rule codified, dissolution on
  mirror, CWS QUANTi tier classifier
- Intake gate phase 1: live, first real Fedora base pulled
  and signed
- Appliance fleet registry: S7-REF-0001 seeded, license_ledger
  view exposes regulator surface
- MemPalace: 404 drawers mined from docs/internal, ingested
  into the Prism matrix
- Input guard: homoglyph fold closed the forbidden bypass
- Data dictionary: 30k files classified by Foundation × Stack

**The desktop layer is Fedora 44 + Budgie + labwc, one door.**

- `s7.desktop` → Vivaldi → `http://127.0.0.1:8080`
- swaybg autostart paints the OCTi wallpaper on login
- `s7-polkit-agent.desktop` autostart → lxpolkit (pending
  install)
- Budgie submenu filters on X-S7-SkyQUBi category, one member

**The pod runs cleanly.**

- `s7-skyqubi-s7-admin` (admin image v2.6)
- `s7-skyqubi-s7-postgres` (pgvector/pg16, 57090 on host)
- `s7-skyqubi-s7-mysql` (mysql 8.0, internal only)
- `s7-skyqubi-s7-redis` (redis 7 alpine, internal only)
- `s7-skyqubi-s7-qdrant` (qdrant latest, internal only)

**What does NOT yet exist:**

- A **one-command deployer** that reproduces all of the above
  on a fresh Fedora 44 box
- A verified **local S7 home page** at `http://127.0.0.1:8080`
  that renders meaningfully when Vivaldi opens it
- A **containerized Vivaldi with Wayland bind-mount** for
  sandboxed pod access (this IS relevant for Fedora — Jamie
  acknowledged it; only the PorteuX version doesn't need it)
- Carli **persona foundation** in the witness set
- A **witness ensemble** actually calling Ollama models for
  each query
- An **update cadence** that reaches a deployed QUBi without
  breaking the desktop

---

## The finish line — what 'done' means for Fedora 44

**QUBi is finished (on Fedora 44) when all seven of these are true:**

1. **One command deploys it.** A family member with a clean
   Fedora 44 install runs `curl -sSL <url> | sh` or
   `./install/install.sh` and, some minutes later, the full
   S7 stack is running — pod up, shortcut in place, wallpaper,
   autologin if opted in, Vivaldi opens at the local home.
2. **Tonya / Trinity / Noah / Jonathan can use it** without a
   steward in the room. One click on `S7`, Vivaldi opens,
   chat with Carli works, knowledge search works, media plays.
3. **The covenant is enforced at runtime.** Forbidden tokens
   caught, universals matched, violations return the pastoral
   redirect, dissolution happens for repeat truth, ribbons
   show for innovations.
4. **The ledger keeps itself updated.** Continuous audit
   snapshot running, hash chain unbroken, MemPalace ↔ Prism
   syncing, zero user action required.
5. **An update cannot break the desktop.** Cube iterates
   freely; desktop layer remains atomic; user-visible state
   survives every update.
6. **One Fedora 44 appliance is enough for MVP.** Fleet sync,
   multi-family covenants, per-deployment tuning — all later.
7. **Jamie can hand a family member the URL for the installer
   and walk away.** No follow-up required.

Everything else in this plan is discretionary.

---

## Known gaps — Fedora 44 priority order

Each gap is tagged **[CUBE]** (safe), **[DESK]** (write-barrier),
or **[INSTALL]** (new category for deployer-script work, which
runs once on fresh boxes and never at runtime so it's
low-churn even though it touches the desktop).

### P0 — Blocks gate #1 (no one-command deployment)

1. **[INSTALL] Audit `install/install.sh` against the one-command
   requirement.** I haven't read it yet this session. It
   already exists. Does it actually deploy everything this
   appliance currently has? What's missing? What breaks on a
   clean Fedora 44 box vs this machine? **Scope:** read the
   script, run it mentally against a clean-box checklist,
   list gaps. **Risk:** low — audit only, no edits.

2. **[INSTALL] The deployer must install and enable:**
   - `podman` (base, probably already in Fedora 44)
   - `lxpolkit` (needed for Media Writer / polkit dialogs)
   - `swaybg` (wallpaper, already installed here)
   - `vivaldi-stable` or equivalent (or firefox as a fallback)
   - `kitty` (terminal, already installed here)
   - The S7 git repo or a tarball at `/opt/s7` or `/s7/skyqubi-private`
   - The pod YAML applied via `podman play kube`
   - The admin container image loaded (via intake gate if network
     is available, or from a bundled tarball if air-gap)
   - The Prism + Akashic + audit + appliance postgres schemas
   - The s7.desktop, s7-polkit-agent.desktop, s7-swaybg.desktop
     copied into `/s7/.local/share/applications/` and
     `/s7/.config/autostart/`
   - The user `s7` (or `skycair`) with sudo and podman group
   - Autologin (opt-in) to sddm
   - MemPalace mined on the docs/internal tree
   - Prism matrix seeded with the Door row

3. **[INSTALL] Idempotency.** Running the deployer twice must
   be safe. Second run: detects existing pod, skips re-creating;
   detects existing schemas, skips re-migrating; detects existing
   memory, skips re-mining; detects existing secrets, rotates
   only on explicit flag.

4. **[INSTALL] Deployer output / UX.** A human should be able
   to watch the deployer and understand what it's doing. Text
   progress log. Error messages that name the failure and the
   next step. Final "what to do now" block with the click path.

### P1 — Blocks gate #2 (users can't use it cleanly)

5. **[CUBE] Local S7 home at http://127.0.0.1:8080.** I haven't
   verified what serves this URL or what renders. The `s7.desktop`
   points at it; the "one door" experience hinges on it. Could
   be Caddy serving a landing page, could be the admin container's
   own HTTP, could be nothing. **Scope:** curl it, read the
   response, add a minimal landing page if needed. **Risk:** low.

6. **[CUBE] Carli persona foundation.** Still the same gap from
   earlier — Tonya wanted to chat with Carli; the persona isn't
   populated in the witness set. **Scope:** define Carli's voice
   + persona RAG, ingest through the MemPalace bridge, verify a
   sample query routes through Carli. **Risk:** medium.

7. **[DESK] Autologin for sddm on Fedora 44.** Much simpler than
   the PorteuX read-only case — just a file in
   `/etc/sddm.conf.d/` on Fedora. **Scope:** one deployer step
   with an opt-in prompt. **Risk:** low, desktop-adjacent but
   atomic at install time only (not at runtime — fits the
   write-barrier rule).

### P2 — Blocks gate #3 (covenant not fully enforced at runtime)

8. **[CUBE] `prism detect` wired into the chat path.** The
   detect skill exists but chat responses don't pass through it.
   **Scope:** one hook in the chat pipeline that classifies
   every output as FOUNDATION / FRONTIER / HALLUCINATION /
   VIOLATION and refuses the last two. **Risk:** low.

9. **[CUBE] Witness set live.** `s7_witness_converge.py` has
   the math; no actual 7+1 ensemble is running. Need Ollama
   hooked to N local models per query, collect projections,
   run `converge()`. **Scope:** wire Ollama paths in the chat
   pipeline, define the witness roster (LLaMA 3.2 3B / Mistral
   / Gemma2 / Phi-4 / Qwen2.5 / DeepSeek R1 / BLOOM + CWS,
   from the memory entry on Phase 5). **Risk:** medium —
   performance and timeouts on 9 models per query.

### P3 — Blocks gate #5 (updates might break desktop)

10. **[CUBE] Vivaldi in the s7-admin container with Wayland
    bind-mount.** For Fedora 44 deployment this IS relevant
    (unlike PorteuX). The pod network sandbox is real, and
    putting Vivaldi inside the admin container gives the
    browser full pod-internal access without exposing host
    ports. **Scope:** follow the 5-step plan in the deleted
    reference_vivaldi_sandbox_target.md — which I need to
    reconstruct now that I know Fedora is the target.
    **Risk:** medium — pod restart required, bind-mounts are
    UID-sensitive.

11. **[CUBE] Update cadence definition.** How does a deployed
    Fedora QUBi get updated? Options:
    - `install/update.sh` — manual, pull git + re-run deployer
    - Background systemd timer — pulls from the S7 public repo
      and rebuilds the pod on change
    - Signed update bundles delivered through the intake gate
    - Per-appliance opt-in update window
    **Scope:** design decision + implementation. **Risk:**
    design scope — Jamie picks the path.

12. **[CUBE] Ribbon first_commit backfill.** Every ribbon row
    has NULL for `first_commit` because I seeded them before
    the commits landed. Map ribbon title to its commit SHA,
    UPDATE. **Risk:** none.

### P4 — Finish-line polish (none are blockers)

13. **[CUBE] Vuln scan in the intake gate (trivy / osv).**
14. **[CUBE] npm / pip / git adapters for the intake gate.**
15. **[CUBE] Akashic cipher phase 2** — two-glyph byte encoding,
    decimal-position class formalized.
16. **[CUBE] Redis tier 1 cache with real redis-py.** Needs
    pod port map for 6379.
17. **[CUBE] Content-hash strand tokens** — research brief
    item #4.
18. **[CUBE] W3C DID column on appliance.appliance.**
19. **[CUBE] Daily Merkle root of the matrix into snapshot.**
20. **[CUBE] FROST threshold signatures on Reporter verdicts.**

---

## Suggested order (not yet approved)

**Phase A — Audit and gap-close the deployer.** No runtime work.
Pure reading and documenting what `install/install.sh` already
does vs what it needs to do.

1. Read `install/install.sh` top to bottom. Commit a gap-list
   as a companion doc if needed.
2. Read `start-pod.sh` and `skyqubi-pod.yaml` for the pod boot
   sequence.
3. Read `install/first-boot.sh` for any runtime-on-first-boot
   logic.
4. Produce a deployer checklist document with CHECK/MISSING
   status for each item in gap #2 above.

**Phase B — Write the deployer gaps.** Starts after Phase A
gives a clear picture. Every gap closed as a small commit to
`install/` or as a cube-layer schema/skill/ingest script that
the deployer invokes.

**Phase C — First test-deploy on a fresh Fedora 44 box.**
Ideally a VM so breakage doesn't cost this reference machine.
Run the deployer end-to-end. Record every failure. Fix in
phase B loops until green.

**Phase D — Local home page + Carli + witness ensemble.** Gaps
5, 6, 7, 8, 9. All cube-layer. The local home page and Carli
are the user-visible payoff of the whole stack — if they work,
the family interaction with QUBi is real.

**Phase E — Vivaldi sandbox container.** Gap 10. Requires one
pod restart, scheduled carefully. After Phase D the Gold chat
experience is proven; Phase E hardens it.

**Phase F — Update cadence.** Gap 11. Jamie picks the path.
After F, the covenant can evolve without breaking the user.

**Phase G — Polish.** P4 items in any order. None of them
block the finish line.

---

## What I will NOT do without your word

- No edits to `install/install.sh` until after I've read it
  and reported findings.
- No pod restarts. The running pod state is precious.
- No Containerfile edits. Every admin image rebuild is a
  chain-of-custody event.
- No desktop file edits. The write-barrier is locked. Any
  deployer-installed desktop file only lands at install time,
  never at runtime.
- No changes to `skyqubi-pod.yaml`. Pod topology is settled.
- No package installs (sudo). You run those yourself.
- No "while I'm here" side fixes. One commit, one purpose,
  always.
- No PorteuX / S7-X27 work. Deferred per Jamie's redirect.
- No ISO rebuilds. Neither X27 nor any other flavor tonight.

---

## First three concrete actions when you say 'execute'

1. **Read the deployer.** Open `install/install.sh`,
   `install/first-boot.sh`, `start-pod.sh`, `skyqubi-pod.yaml`
   and produce a written audit: what each file currently does,
   what's missing for the one-command requirement, what's
   idempotent, what isn't. Output: a committed doc at
   `docs/internal/superpowers/plans/2026-04-13-deployer-audit.md`.
   No code changes in this step.

2. **Write the gap list against the deployer requirement.**
   For each item in gap #2 (the list of things the deployer
   must install and enable), mark CHECK / PARTIAL / MISSING.
   Include line references into `install/install.sh` where
   the current behavior lives, so future work knows what
   it's editing. Output: a separate committed section or doc.

3. **Wait for your direction** on which gaps to close first.
   No further commits without an explicit go from you.

Three read-only steps, two commits total (audit + gap list),
both cube-layer, zero runtime disruption.

---

## Explicitly out of scope for Fedora 44 finish

- Multi-appliance fleet sync
- GPU VRAM kernel for witness parallelism
- Persistent RAM tier (hardware-dependent)
- Book chapters (Jamie's side)
- Patent filings (Jamie's side)
- SkyLoop multiboot USB
- **ALL PorteuX / S7-X27 work** (deferred as a group)
- **ALL Rocky / R101 work** (same)
- **ALL bootc / F44-as-ISO work** — F44 Fedora 44 deployment
  is the target, but not as a bootable installer ISO.
  Deployment is via a script on an already-installed Fedora
  44 system.
- Akashic ancient text translations
- Reporter graduation flow implementation beyond what's
  already in s7_witness_converge.py
- SkyMMIP audio / sensor projectors

Each of these is real work. None of it is finish work for
the Fedora 44 target.

---

## Honest uncertainty

1. **I haven't read `install/install.sh` yet this session.**
   It may already do 90% of what's needed and just need
   small gap closures; it may be a skeleton that needs
   substantial work. Until I audit it, the size of Phase A
   and B is a guess.

2. **The local S7 home content at :8080 is unknown to me.**
   The port listens, something responds, but I haven't curled
   it to see what a real browser would render. Could be a
   placeholder, could be Caddy default, could be a working
   landing.

3. **The Fedora 44 target box's hardware is unknown.** Family
   members might have Intel integrated, AMD APU, NVIDIA
   discrete, or a VM. Some deployer steps (GPU acceleration,
   Wayland socket paths, polkit agent choice) may be hardware-
   sensitive.

4. **The update cadence decision is yours alone.** I can
   implement any of the options in gap #11, but picking is
   a covenant-shaped call that I shouldn't make unilaterally.

5. **I don't know how much time you have.** Phases A–F might
   be a weekend or a month depending on how much you can give.

---

## Closing

Fedora 44 is the target. The cube is deep. The desktop is a
one-door atomic surface. The deployer is the gap between
"this reference laptop works" and "any Fedora 44 box becomes
an S7 QUBi with one command."

The plan above is ordered from safest to riskiest, from
audit to deploy to runtime-covenant to hardening. No phase
requires destroying the current reference state; every phase
either reads or adds in the safe cube direction.

When you're ready for the first three actions, say the word.
Until then, this plan is the contract.
