---
title: 24-Hour Ship Plan — Exercise of Trust v5→v6-genesis
date: 2026-04-14
approved_by: Jamie (plan-write-execute signal after three clarifying rounds)
approach: 1 (ship the minimum, layer from there)
tier: JAMIE-APPROVED — executing under the 24hr Exercise of Trust block
---

# 24-Hour Ship Plan (v5 → v6-genesis)

## One-sentence goal

*Prove the appliance works locally, publish a Local Health Report that says so with its own GUI, and stage a covenant-clean orphan-genesis reset of the GOLD surface so the first real push on ceremony day starts from today rather than inheriting yesterday's mistakes.*

## Four deliverables

1. **Working Local appliance** — lifecycle 47→55, pod healthy, Samuel responsive
2. **Local Health Report generator** — one script; JSON source-of-truth; markdown snapshot; persona-chat `/health` HTML route (Surface A)
3. **Orphan-genesis bundles** for the 5 mis-populated immutable repos — produced locally in `/tmp/s7-gold-reset/`, refuse real pushes, handed off as `iac/immutable/jamie-run-me.sh`
4. **Tiered test plan** at `docs/public/TESTING.md` — Tonya / Trinity / technical-partner, each readable standalone

## Scope boundary

**IN tonight:** the four deliverables above + the blockers that block Local or Deploy (NPM removal, docker.io bundle, qdrant digest pin) + `v6-genesis` stamp in `CORE_UPDATES.md`.

**OUT tonight (deferred):** Surface B (dashboard swap), Surface C (static HTML + desktop launcher as bonus), tone softening, full public mirror, SafeSecureLynX content expansion, structurally-Tonya items, the `&&`-chain security fix.

**Constraints:** zero pushes to public surfaces. Zero touches to the 4 mis-populated GitHub repos. Private origin only. Audit gate 🟢 PASS throughout.

## Architecture (three parts)

### Part A — Local Health Report generator

```
[sources] → collector → JSON → renderers → {markdown, persona-chat HTML}

sources:
  - iac/audit/pre-sync-gate.sh findings
  - s7-lifecycle-test.sh output
  - Samuel skills via CWS engine API (:57077/skyavi/skills)
  - podman pod inspect s7-skyqubi
  - ss -tlnp port state
  - perf metrics (curl latency, memory headroom)

generator: iac/audit/local-health-report.sh

outputs:
  - docs/internal/reports/local-health-<ts>.json  (source of truth)
  - docs/internal/reports/local-health-<ts>.md    (committed markdown snapshot)
  - persona-chat /health route                   (HTML surface A, Tonya palette)
```

**Every finding carries**: id, severity (red/yellow/green), title, root_cause (Jamie Love RCA), impact (household-visible / covenant / cosmetic / blocks-deploy), next_step. Matches Jamie's exact words: *"output report chart metrix performance root of issue suggest impact."*

### Part B — Orphan-genesis bundle builder

**New file:** `iac/immutable/genesis-content.yaml` — names the content class for each of the 5 immutable repos.

**Builder:** `iac/immutable/reset-to-genesis.sh` — for each entry, stages content into `/tmp/s7-gold-reset/<repo>/`, `git init`s an empty repo, creates one orphan commit dated today with message *"S7 GOLD begins today (v6-genesis)"*, produces a git bundle, computes sha256, writes to `RESET_MANIFEST.txt`. **Refuses real pushes.**

**Handoff script:** `iac/immutable/jamie-run-me.sh` — exact `gh` commands for Jamie to paste: branch protection, `required_signatures`, `allow_force_pushes=false`, `allow_deletions=false`, and the orphan force-push sequence with the one-time `required_signatures` toggle-cycle for bootstrapping.

### Part C — Tiered test plan

`docs/public/TESTING.md` — three sections:
- **Tonya** (~200w) — covenant-grounded prose, two witnesses ("visit /health, talk to Samuel")
- **Trinity** (~300w) — walkthrough with screen descriptions
- **Technical partner** (~400w) — exact commands, byte hashes, sovereign verification steps

All three reference the Local Health Report GUI as the primary shared witness.

## Execution sequence (the 24-hour spine)

| Block | Hours | What lands | Commits |
|---|---|---|---|
| B1 | H0–4  | Test plan skeleton + generator JSON schema + `genesis-content.yaml` | 2 |
| B2 | H4–8  | Local fix — Ollama port adoption, lifecycle 47→55 | 2 |
| B3 | H8–12 | Generator runs E2E, markdown output committed, persona-chat `/health` route ships | 3 |
| B4 | H12–16| Orphan bundles produced in `/tmp/`, `jamie-run-me.sh` staged, dry-run verified | 2 |
| B5 | H16–20| Blockers: NPM removal, docker.io bundle, qdrant pin | 3–5 |
| B6 | H20–24| Trinity + technical-partner test plan sections, session-close handoff, `v6-genesis` stamp | 2 |

**Commit cadence:** ~12–15 commits, each on `lifecycle` → FF `main` → push `skyqubi-private` only. Audit gate 🟢 PASS after every commit.

## Success criteria

**Hard:**
- [ ] `docs/public/TESTING.md` exists, three readable-standalone sections
- [ ] `iac/audit/local-health-report.sh` produces valid JSON
- [ ] At least one Local Health Report markdown snapshot committed
- [ ] `persona-chat/app.py` `/health` route verified via curl
- [ ] Lifecycle test measurably improved (target 55/55)
- [ ] 5 orphan bundles in `/tmp/s7-gold-reset/` with RESET_MANIFEST.txt
- [ ] `jamie-run-me.sh` staged with paste-ready `gh` commands
- [ ] NPM removed, docker.io strategy chosen, qdrant pinned
- [ ] `CORE_UPDATES.md` stamped `v6-genesis`
- [ ] Audit gate 🟢 PASS at session close

**Soft (bonus if time):** Surface C, perf metrics populated, Release draft commands staged.

**Non-goals:** Surface B swap, tone softening, full mirror, any GitHub touch.

## Authority map

- **Chair executes** all local work (lifecycle, audit, pod, Samuel, docs, scripts, recipes, test plan) and pushes to `skyqubi-private` only
- **Jamie pastes** when ready: `gh` force-pushes of orphan genesis, `gh release create`, branch protection, `required_signatures`
- **Tonya witnesses** on return: the final test plan, the first real push, the `v6-genesis` stamp

## Covenant hold

Three sentences Jamie said tonight are recorded in `docs/internal/chef/three-repo-model.md` §6/§7/§8. This design honors them without claiming to replace anything:

1. *"Private is our development, public is their development, GOLD will sit here."*
2. *"Local-Private-Assets contain TAR GZIP ETC, all push to private then we have Public and Immutable for Business to pull from for Testing."*
3. *"This allows the entire project to LIVE outside and LIVE inside."*

Love is the architecture. Ship the minimum that works, document it honestly, hand Jamie the paste-ready commands, and let the covenant hold the rest.
