---
name: GOLIVE Release 7 master checklist (2026-07-07)
description: Single-source punch list for everything that has to happen between 2026-04-13 and the 2026-07-07 07:00 CT public release. Organized by dependency — blockers first, polish last. Each item links to its detailed spec or the commit where it was fixed.
type: project
---

# GOLIVE Release 7 — master checklist

**Target:** 2026-07-07 07:00 CT (Public release, end of the current
two-tier freeze)
**Created:** 2026-04-13
**Status:** planning — execute in order, check off as each lands

---

## The three locks

Before any item on this checklist is worked, remember the three
surfaces that are frozen through the freeze window:

- **Base / desktop layer** — Fedora 44 base image + Budgie + labwc
  + Tonya-approved desktop. Changes only at Core Update days.
- **DNS** — skyqubi.com, 123tech.skyqubi.com, all catcher domains.
  Pin first, change last.
- **Public repo** — `skycair-code/SkyQUBi-public:main`. Syncs from
  private on Core Update days + critical patch windows.

"Frozen" means: no silent drift. Any change touches a surface
explicitly through an approved block.

---

## Phase 1 — Runtime unblocks (next immediate block after 2026-04-13)

These items are committed to git but not deployed. They're the
highest-leverage single block Jamie can run to move the system
forward.

### 1.1 Admin image v2.7 rebuild + pod flip

**Spec:** `docs/internal/superpowers/specs/2026-04-13-admin-v2.7-rebuild-plan.md`

**Content:**
- `engine/s7_server.py` — Pydantic UUID types for session_id
- `engine/s7_discernment.py` — session INSERT preamble
- `engine/s7_quanti.py` — session INSERT preamble
- `engine/s7_breaker.py` — consensus_session INSERT preamble

**Mechanism choice:** Option A (podman commit from v2.6) for quick
patch release. Option D (FROM registry.fedoraproject.org/fedora:44,
no s7-fedora-base dependency) for GOLIVE Release 7 proper.

**Blockers:** explicit runtime block approval from Jamie. Pod
restart window (avoid Tonya's chat testing hours).

**Estimated duration:** 30 minutes for Option A, 2-3 hours for
Option D.

**Success criterion:** lifecycle goes from 53/53 to 56/56 with
new tests E07 (/quanti), E08 (/discern verdict), E09 (/breaker).

**Rollback:** `sed -i 's|:v2.7|:v2.6|' skyqubi-pod.yaml && bash
start-pod.sh` — fast, known-good.

---

### 1.2 Witness persona seed verification

**Spec:** `engine/sql/s7-witness-personas-seed.sql`

**Content:** 12 rows in cws_core.witnesses for the current persona
roster (applied 2026-04-13 to the running postgres).

**Blockers:** none — already applied and verified via E06.

**Verification:** `SELECT COUNT(*) FROM cws_core.witnesses` should
return ≥ 26 (14 legacy + 12 personas). Currently 26.

**Ongoing:** any new persona or new base model needs a new row.
Check on every Modelfile commit.

---

## Phase 2 — Chat experience polish (before or at GOLIVE)

### 2.1 Persona v3 voice tuning

**Spec:** `docs/internal/superpowers/specs/2026-04-13-persona-v3-voice.md`

**Content:**
- Option 2 (dynamic num_predict cap in router) — small Python
  change in persona-chat/app.py, no Modelfile swap
- Option 1 (smollm2:360m base swap) for Samuel if Option 2 alone
  produces ugly truncation
- BitNet 2B as the GOLIVE target base (gated on BitNet Path retry
  succeeding — see 3.1)

**Blockers:** none (Option 2 is pure code); smollm2 is already
installed.

**Estimated duration:** 30 minutes for Option 2, +30 minutes if
Option 1 is also needed.

**Success criterion:** A08 (Samuel hi under 5 words), A09 (Elias
hi under 5 words), A10 (Samuel attribution names Jamie) all pass.

**Rollback:** git revert persona-chat/app.py + persona Modelfiles.

---

### 2.2 Samuel SkyAVi agent registration

**Spec:** (no dedicated spec — single-line task)

**Content:** verify `guardian` in the SkyAVi agent list is
Samuel's internal name, OR register Samuel as an explicit agent.
Currently cosmetic — Samuel is imported as a distinct class from
`engine.s7_skyavi` but the `/skyavi/core/status` endpoint lists
`['carli', 'elias', 'guardian']`. Clarify.

**Blockers:** depends on reading `engine/s7_skyavi.py` to see if
Samuel registers via a different mechanism.

**Estimated duration:** 20 minutes investigation + fix.

---

## Phase 3 — Speed target (BitNet Path)

### 3.1 BitNet Path compile + integration

**Spec:** `docs/internal/superpowers/specs/2026-04-13-bitnet-path-retry.md`

**Content:**
- Path 1a: flag-based GCC 16 warning suppression (30 min experiment)
- Path 2: Python 3.11 venv + sentencepiece for setup_env.py (60 min)
- Path 3: wait for Ollama ≥0.21 (passive)
- Integration wire-up: bitnet.cpp binary → s7-bitnet-mcp.service
  on :57091, env vars already set in skyqubi-pod.yaml

**Blockers:** open-ended compile (may hit new issues each attempt).

**Estimated duration:** 30 min to 3 hours.

**Success criterion:** bitnet-cli binary exists, s7-bitnet-mcp
service responds on :57091, a test prompt returns at ≥ 30 QBIT/s.

**Target:** 50 QBIT/s per Microsoft's paper. 30 is the
"clearly better than Ollama's 14 ceiling" floor.

**Gates:** flip Samuel's `persona_engine_map.yaml` entry from
`ollama` to `bitnet` only after benchmark confirms the floor.

---

## Phase 4 — Public surface (must land before 2026-07-07)

### 4.1 Public chat demo-fake handoff

**Spec:** `docs/internal/superpowers/specs/2026-04-13-public-chat-handoff.md`

**Content:**
- Tonya picks one of three options:
  - A: Coming-soon placeholder
  - B: Full persona-chat widget (needs Cloudflared tunnel)
  - C: Disclaimer banner on current demo
- Implementation on a staging branch
- Tonya + Trinity iPhone re-verify
- Merge + public sync

**Blockers:** Tonya's explicit design approval — `feedback_tonya_design_approved.md`.

**Estimated duration:** 30-90 minutes depending on option chosen.

**Success criterion:** R02 Public repo clean after sync, L01-L03
landing-page tests green.

---

### 4.2 Deploy path for fresh F44 boxes

**Content:**
- `install/install.sh` enhancements already landed this session
  (lxpolkit, swaybg, kitty, firefox, python3-pyyaml added to
  Fedora dnf path; autostart scope moved to user
  ~/.config/autostart; fail-fast on missing s7.desktop; "what
  to do now" close block)
- `install/preflight.sh` — standalone, runs without .env.secrets,
  catches blockers before sudo install.sh is invoked
- `install/fix-pod.sh` — Samuel-runnable ops script with --samuel
  JSON mode + ops ledger + two fix classes (setsebool bool,
  fcontext equivalence rule)
- Target: family-member can run
  ```
  git clone https://github.com/skycair-code/SkyQUBi-public.git
  cd SkyQUBi-public
  bash install/preflight.sh
  sudo bash install/install.sh
  ```
  and get a working QUBi on a fresh F44 box.

**Blockers:**
- The admin image — until v2.7 ships with the engine fixes, the
  deploy pulls v2.6 which has the /discern/quanti/breaker bugs
- The multi-distro vs F44-only question (deferred to finish-line
  plan, currently defaults to F44 primary with apt/pacman
  branches as best-effort)

**Estimated duration:** already substantially done — remaining is
the admin image rebuild gate.

**Success criterion:** a deploy test on a clean F44 VM completes
without human intervention.

---

### 4.3 Intake gate phase 2 — npm / pip / vuln-scan

**Spec:** `project_intake_gate.md` (memory), current implementation
only covers container image pulls.

**Content:** extend the intake gate to also cover:
- npm install supply-chain checks (package lock signing)
- pip install supply-chain checks (hash pinning)
- trivy vuln scan integration (already referenced in iac/intake/
  scan-reports/)
- clamav malware scan

**Blockers:** spec does not exist yet — needs one.

**Estimated duration:** 2-4 hours spec + 4-6 hours implementation.

**Deferred decision:** may push past 2026-07-07 if lower priority
items eat the budget.

---

## Phase 5 — Lifecycle + CI hardening

### 5.1 Coverage expansion

**Current:** 53 tests
**Post-v2.7:** 56 tests (add E07 /quanti, E08 /discern verdict,
E09 /breaker)
**Post-v3 voice:** 59 tests (add A08 Samuel brevity, A09 Elias
brevity, A10 Samuel attribution)
**Post-public-chat handoff:** 62 tests (add L01-L03 landing-page
regression)
**Post-BitNet:** 66 tests (add B02-B04 bitnet MCP + throughput,
A08 Samuel on BitNet branch)

**Success criterion:** 66/66 PASS at GOLIVE morning.

---

### 5.2 Samuel-runnable trifecta complete

**Current:** fix-pod.sh, preflight.sh, lifecycle-test.sh all emit
--json for Samuel's skill runner.

**Remaining:** Samuel's skill runner itself — a Python or Bash
wrapper that reads samuel_runnable_scripts.yaml and can fire
any catalog entry with the right flags. When Samuel the persona
is reachable via the real chat path, the user can ask "Samuel,
run fix-pod dry-run" and the runner fires.

**Blockers:** needs the persona-chat service wired into a real
endpoint that calls the runner. Gated on Samuel v3 + Phase 2.1.

---

### 5.3 Ops ledger with cross-script hash chain

**Current:** /s7/.s7-ops-ledger/fix-pod.ndjson has a per-row
SHA-256 chain (same pattern as audit.verify_chain).

**Remaining:** cross-script chain — if preflight.sh + fix-pod.sh
+ lifecycle-test.sh all run in one Samuel-triggered sequence,
the ops ledger should chain the three runs together so the
operator can reconstruct the exact sequence from the audit trail.

**Blockers:** design decision needed on the chain semantics.

---

## Phase 6 — Release 7 morning checklist (2026-07-07 06:00 CT)

One hour before GOLIVE, in order:

1. **Pre-audit:**
   ```
   bash install/preflight.sh --json
   ```
   Expect: `state=ready` or `ready_with_warnings` (no hard errors).

2. **Lifecycle:**
   ```
   bash s7-lifecycle-test.sh --json
   ```
   Expect: 66/66 PASS (or whatever count is current). Any FAIL
   blocks release.

3. **Public repo status:**
   ```
   cd /s7/skyqubi-public && git status --short
   curl -s https://github.com/skycair-code/SkyQUBi-public/branches/main
   ```
   Expect: clean working tree, main branch protected.

4. **Public DNS:**
   ```
   curl -sI -o /dev/null -w "%{http_code}\n" -L https://skyqubi.com
   curl -sI -o /dev/null -w "%{http_code}\n" https://123tech.skyqubi.com
   ```
   Expect: 200/200.

5. **Witness registry:**
   ```
   podman exec s7-skyqubi-s7-postgres psql -U s7 -d s7_cws \
       -c "SELECT COUNT(*) FROM cws_core.witnesses"
   ```
   Expect: ≥ 26.

6. **Pod health:**
   ```
   podman pod ps | grep s7-skyqubi
   podman ps --filter pod=s7-skyqubi --format '{{.Names}}' | wc -l
   ```
   Expect: Running, 6 containers.

7. **Chat round-trip:**
   ```
   CWS_TOKEN=$(grep CWS_ENGINE_TOKEN /s7/.env.secrets | cut -d= -f2)
   podman exec s7-skyqubi-s7-admin curl -s -X POST \
       http://127.0.0.1:7077/witness \
       -H "Authorization: Bearer $CWS_TOKEN" \
       -H 'Content-Type: application/json' \
       -d '{"session_id":"<uuid>","query":"hi","model":"s7-carli:0.6b"}'
   ```
   Expect: 200 + convergence field.

8. **Evidence capture:**
   - Screenshot of skyqubi.com desktop
   - Screenshot of skyqubi.com on iPhone (Tonya + Trinity verify)
   - Screenshot of lifecycle test 66/66
   - Commit the evidence to `evidence/2026-07-07/`.

9. **Tonya sign-off:** walk through the desktop + mobile experience
   one last time. Tonya says yes before we flip.

10. **Release flip:**
    - Tag private repo: `git tag r7 && git push origin r7`
    - Run full sync-public.sh (covers any last-minute fixes)
    - Tag public repo: same tag

11. **Post-release verification:** re-run steps 1-7 against the
    tagged state, confirm still green.

---

## Decision points between 2026-04-13 and 2026-07-07

Items that need Jamie's explicit call at specific times:

| Date-ish | Decision |
|---|---|
| Next session after 2026-04-13 | Phase 1.1 — admin v2.7 rebuild mechanism (A or D) + deploy window |
| Within 2 weeks | Phase 3.1 — BitNet Path attempt (which path, how much time) |
| By mid-May | Phase 2.1 — persona v3 voice option (dynamic cap, base swap, or BitNet target) |
| By early June | Phase 4.1 — public chat handoff option Tonya picks (A/B/C) |
| By late June | Phase 6 — release 7 morning checklist dry-run |
| 2026-07-07 | Release 7 go/no-go with Tonya final sign-off |

---

## What's NOT in GOLIVE Release 7

Out of scope — defer to Release 8 or later:

- Multi-appliance fleet sync
- GPU VRAM kernel for witness parallelism
- Persistent RAM tier (hardware-dependent)
- Full MemPalace backend migration from local ledger to postgres
- L3 long-term semantic search
- Samuel's 98-skill runtime surface (currently in the catalog but
  not all 98 are wired)
- BLOOM 176B witness (too big for 7 GB RAM)
- Vivaldi sandbox container rebuild with Wayland bind-mount
- Book chapters, patent filings (Jamie's side, not engineering)
- SkyLoop multiboot USB
- ALL PorteuX / S7-X27 work (deferred group)
- ALL Rocky / R101 work (deferred group)

Each of these is real work. None of it is finish work for Release 7.

---

## Approval gate

Before any Phase execution block starts:

1. This doc reviewed by Jamie in the context of the specific Phase.
2. The Phase's own spec doc reviewed.
3. Rollback plan acknowledged.
4. Lifecycle green before the block starts.
5. Runtime window appropriate (not during Tonya's test hours).
6. Samuel available or explicitly skipped per safe-QUBi carve-out.
7. Jonathan available for supervision if present.

---

*Love is the architecture. The finish line is 2026-07-07 07:00 CT.*
