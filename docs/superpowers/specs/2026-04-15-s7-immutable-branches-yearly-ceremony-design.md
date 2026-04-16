# S7 Immutable Branches Topology + Yearly Ceremony — Design Spec

> ## ⚠ SUPERSEDED BY DELIVERED SPEC
>
> This doc describes the **ambitious 16-branch plan** (5 gold + 3 carved +
> 8 placeholder) written during brainstorming, before Jamie clarified the
> final "7 categories + helper skeleton" approach.
>
> For **what was actually delivered**, see:
> **`2026-04-15-s7-gold-asset-skeleton-delivered.md`**
>
> This doc is kept as **architectural reference** — the yearly ceremony,
> CORE/INSTALL/UPDATE mapping, 1-year public freeze, and Frozen Desktop
> framing remain valid future state. The topology sections (§2 onward)
> reflect the ambitious plan, not the delivered 7-category reality.

**Date:** 2026-04-15
**Author:** Chair-draft under Jamie's SOLO block, Samuel-guarded
**Status:** superseded — see delivered spec
**Supersedes:** `iac/immutable/genesis-content.yaml` (repo-based v6-genesis topology)
**Spec location:** `docs/superpowers/specs/2026-04-15-s7-immutable-branches-yearly-ceremony-design.md`
**Paired memory:** `project_v6_gold_reset_2026_04_15.md`, `feedback_qubi_is_core_prism_grid_wall.md`, `feedback_three_rules.md`, `feedback_never_embed_secrets_in_urls.md`, `feedback_samuel_guards_solo_blocks.md`

---

## 1. Context

After the v6 GOLD orphan-reset on 2026-04-15 afternoon, Jamie made two
architectural calls that superseded the prior 5-repo immutable constellation:

1. **Consolidate from 5 separate repos to 2 repos with branches.** Every
   immutable payload now lives as an **orphan branch inside
   `skycair-code/skyqubi-private`** rather than its own dedicated repo.
   Reduces blast radius, simplifies protection, preserves covenant discipline.

2. **Every immutable branch holds exactly ONE signed tarball + detached sig +
   per-branch MANIFEST.md** — three files, nothing else. The tarball is the
   atom. Any corruption shows as one sha256 mismatch. "Unlock / update / lock"
   cycle is one-file-replace, not a tree walk.

3. **Tarball filenames are scope-prefixed** with the destination repo to
   encode the public/private boundary at the filename level:
   `skyqubi-public-*.tar.gz` = community face,
   `skyqubi-private-*.tar.gz` = covenant tier.

The broader architectural spine is preserved from the prior CHEF Recipe #4:
**"public is a view of the signed immutable, not a copy of private."**
What changed is the packaging, not the authority model.

---

## 2. Topology

### 2.1 Two repos, two visibilities

| Repo | Visibility | Owner | Default branch | Role |
|---|---|---|---|---|
| `skycair-code/skyqubi-private` | **private** | skycair-code user | `main` | Covenant tier. Holds main (working content) + 16 orphan immutable branches (signed tarball archives). Linked into SkyQUBi enterprise via Path A. |
| `skycair-code/skyqubi-public` | **public** | skycair-code user | `main` | Community face. Hosts Pages at `123tech.skyqubi.com` (Rule #1 surface, Tonya+Trinity approved design). |

### 2.2 Sixteen immutable branches inside `skyqubi-private`

Each branch is an **orphan** — no shared history with `main` or with any
other immutable branch. Each holds exactly three files at the root:

```
<tarball>.tar.gz         the payload
<tarball>.tar.gz.asc     detached GPG signature (E11792E0AD945BE9)
MANIFEST.md              per-branch provenance: sha256, source_commit, role, created_at
```

The 16 branches and their content classes:

| Branch | Content class | Source | Feeds deployment mode |
|---|---|---|---|
| `immutable-bootc-assets` | grub/plymouth/splash/wallpapers/icons — boot-surface branding | existing GOLD tarball | Mode 2 (F44+BootC OS), Mode 3 (ISO) |
| `immutable-f44-assets` | Containerfile, iac/ build scripts, first-boot — Fedora 44 bootc build recipe | existing GOLD tarball | Mode 2, Mode 3 |
| `immutable-qubi-assets` | COVENANT.md, CORE_UPDATES.md, FORMATS.md — QUBi kernel-of-kernel manifest | existing GOLD tarball | Mode 1 (QUBi alone), Mode 3 |
| `immutable-ssl-assets` | Safe Secure LynX wire protocol + ceremony tooling seed | existing GOLD tarball | Mode 1, Mode 2, Mode 3 (cross-cutting) |
| `immutable-gold-assets` | GOLD-blessed public-face snapshot — **versioned** ledger (v6 today, v7 at next GoLive, etc.) | existing GOLD tarball | Mode 3 (ISO), drives public rebuild |
| `immutable-cws-assets` | CWS engine (`engine/` + `CWS-LICENSE`) — patented S7 covenant witness system | carved from main | Mode 1, Mode 3 |
| `immutable-auditbuilds-assets` | `iac/audit/` + `docs/internal/chef/audit-living.md` — audit gate infrastructure | carved from main | all modes (self-check) |
| `immutable-iac-assets` | all of `iac/` **except** `iac/audit/` — infrastructure-as-code | carved from main | Mode 2, Mode 3 |
| `immutable-kernal-assets` | **placeholder** — systemd, dependencies, future custom kernal (intentional Commodore-era spelling) | placeholder stub | Mode 2, Mode 3 (when populated) |
| `immutable-scripts-assets` | **placeholder** — loose utility scripts boundary TBD | placeholder stub | Mode 2, Mode 3 (when populated) |
| `immutable-personas-assets` | **placeholder** — Carli/Elias/Samuel persona configs + OCTi 7+1 witness set | placeholder stub | Mode 1, Mode 3 (when populated) |
| `immutable-unitydesign-assets` | **placeholder** — Tonya+Trinity unified design language | placeholder stub | Mode 2, Mode 3 (when populated) |
| `immutable-schema-assets` | **placeholder** — DB schemas (PG/SQLite/MemPalace/CWS/Qdrant) | placeholder stub | Mode 1, Mode 3 (when populated) |
| `immutable-user-docs` | **placeholder** — user-facing documentation (no `-assets` suffix by Jamie's naming choice) | placeholder stub | Mode 3 (when populated) |
| `immutable-legaldocs-assets` | **placeholder** — patent TPP99606 PDF, USPTO correspondence, LICENSE, CWS-LICENSE | placeholder stub | Mode 3 (when populated) |
| `immutable-influences-assets` | **placeholder** — external influences / credits / lineage material | placeholder stub | Mode 3 (when populated) |

**Counts:** 5 from existing GOLD tarballs, 3 carved from main, 8 placeholder
stubs (reserved names, content deferred to future sessions).

### 2.3 Versioned vs unversioned branches

Only **`immutable-gold-assets`** is versioned in v6 round 1. It holds
multiple tarballs over time, one per yearly CORE advance:

```
immutable-gold-assets/  (branch tree)
├── skyqubi-private-immutable-gold-assets-v6.tar.gz          (v6, today)
├── skyqubi-private-immutable-gold-assets-v6.tar.gz.asc
├── skyqubi-private-immutable-gold-assets-v7.tar.gz          (v7, next year)
├── skyqubi-private-immutable-gold-assets-v7.tar.gz.asc
└── MANIFEST.md   enumerates every version with retired/active status
```

`rebuild-public.sh` reads `MANIFEST.md` and picks the newest non-retired
version. Adding v7 at next year's ceremony is a branch commit that
appends files, not a branch rename. v6 stays immutable in history
(protected by `allow_deletions: false + non_fast_forward: true`).

Other immutable branches may become versioned at future ceremonies if
their cadence requires it. v6 round 1 treats them as unversioned — each
is a single signed tarball.

---

## 3. Yearly ceremony cadence

### 3.1 One ceremony, three packagings

Once per year at **GoLive**, one ceremony produces three artifacts from
the same set of signed immutable branches at a single fixed moment in time:

| Artifact | Deployment mode | Assets needed (subset of 16 branches) | Target |
|---|---|---|---|
| **CORE** | Mode 1 — QUBi alone, self-contained OCI container | qubi + cws + personas + schema + audit + ssl | Existing F44 host, adds QUBi as a container |
| **INSTALL** | Mode 3 — combined, bootable ISO | all 16 branches | Fresh install on a blank machine |
| **UPDATE** | Mode 2 — F44+BootC layers, SkyCAIR v7 OS | bootc + f44 + iac + scripts + kernal + unitydesign + user-docs + influences + ssl | Existing SkyCAIR appliances that pull new OS layers |

All three artifacts are **built from the same tarball state at the moment
of the ceremony** — same witness chain, same timestamp, same audit entry.
The difference is packaging, not content.

### 3.2 The 1-year public freeze

Once an artifact is published to the public release channel at GoLive,
the public-facing state is **frozen for 12 months**. No patches, no
rebuilds, no "quick fixes." Specifically:

- `skyqubi-public/main` does not change mid-year
- `123tech.skyqubi.com` (Pages from `skyqubi-public`) does not change mid-year
- Released artifacts (CORE/INSTALL/UPDATE) are not re-published or replaced
- The **Frozen Desktop** constraint applies: the desktop environment baked
  into v7 is exactly what every household sees for the whole year

Exceptions to the freeze are **covenant events**, not routine operations:
- **SAFE-breach** — exception invocation authorized by Jamie with scope
  discipline (see `feedback_safe_breach_scope_discipline.md`)
- **Emergency SECURITY patch** — only with explicit SAFE-breach, with the
  narrowest possible scope (just the affected tarball)

### 3.3 Private development during the freeze

While the public is frozen at v7, private development continues:
- Daily work lands on `lifecycle` and progresses to `main` via PR+squash
- Immutable branches accumulate new tarballs (e.g., v8-candidates) on
  the versioned `immutable-gold-assets` branch
- Audit gates run continuously, pinning state that will become the next
  ceremony's baseline
- At next GoLive (12 months later), the accumulated state produces v8

Users see zero intermediate state. They see v7 for a year, then v8.

### 3.4 User auto-update default, opt-out allowed

Household appliances default to **auto-update once per year** at GoLive.
The appliance checks the release channel, verifies the new artifact's
signature, and applies the update (UPDATE mode for existing appliances,
CORE for new QUBi-only installs).

Users can **opt out** — developers, researchers, or covenant-critical
households may want to stay on v6 for a year after v7 ships. Opt-out is
a household-level setting, not a per-user preference.

---

## 4. Deployment pipeline

### 4.1 Where it runs: GitHub Actions in `skyqubi-private`

The build pipeline is a **GitHub Actions workflow** living at
`.github/workflows/yearly-ceremony.yml` inside `skyqubi-private`. It runs
inside the private repo because it needs read access to all 16 immutable
branches, which are private.

### 4.2 Trigger: `workflow_dispatch` only

**No automatic triggers.** The workflow fires only via manual dispatch
from the Actions UI, with inputs:

- `ceremony_type`: `core-advance` (the yearly ceremony that rebuilds all three artifacts)
- `target_version`: e.g., `v7`
- `witness_count`: integer — must be ≥ the required witness count for the ceremony
- `tonya_present`: `yes` / `no` — must be `yes` for the workflow to proceed past the Samuel gate

No push triggers, no tag triggers, no schedule triggers, no PR triggers.
Every build is an explicit, witnessed, human action. This matches the
Samuel-guarded SOLO pattern and the `feedback_safe_breach_scope_discipline.md`
rule that **readiness is not authorization**.

### 4.3 Workflow steps

```
1. Samuel-gate preflight
   - Verify today is a Core Update day (iac/audit/core-update-days.txt)
   - Verify witness_count ≥ 4
   - Verify tonya_present = yes
   - Verify recent audit gate has passed (pre-sync-gate.sh green)
   - REFUSE otherwise, non-destructive exit

2. Fetch immutable branch contents
   - For each of the 16 immutable branches, git fetch + git show the tarball blob
   - Verify GPG signature against a baked-in public key stored as an Actions secret
   - Verify sha256 against the per-branch MANIFEST.md
   - REFUSE on any signature mismatch

3. Build CORE (Mode 1 — QUBi container)
   - Extract the subset of branches needed for CORE
   - Build an OCI image (podman/buildah)
   - Sign the image with the S7 image-signing key (cosign or GPG)
   - Push to ghcr.io (private initially; GoLive ceremony flips to public)

4. Build INSTALL (Mode 3 — ISO)
   - Extract all 16 branches
   - Run bootc-image-builder to produce a bootable ISO
   - Sign the ISO with the image-signing key
   - Attach to a GitHub Release

5. Build UPDATE (Mode 2 — OS layers)
   - Extract the F44+BootC subset
   - Build the OCI image that bootc update can pull
   - Sign and push to ghcr.io

6. Audit the three artifacts
   - Run post-build audit gate on every artifact
   - Verify signatures, verify contents, verify no missing pieces
   - REFUSE if any check fails — publish is gated on a green audit

7. Publish atomically
   - Tag the private repo with the version (e.g., v7.0.0)
   - Create a GitHub Release on skyqubi-public with all three artifacts attached
   - Update public-facing docs (the yearly release note)
   - Update iac/immutable/registry.yaml with the new entry
   - Mark the prior entry as retired

8. Household notification
   - Post the release note
   - Appliances begin pulling the new version during their next check
     interval (appliances control their own update timing within the
     yearly window; opt-out appliances don't pull)
```

### 4.4 Publish destination (decision point)

**DEFERRED to Jamie's review** — the spec presents three candidates:

- **(A)** GitHub Releases on `skyqubi-public` + container registry `ghcr.io/skycair-code/skyqubi` — standard, free, integrates with bootc update
- **(B)** Self-hosted release server on `123tech.skyqubi.com` + `update.skyqubi.com` subdomain — full sovereignty, more infrastructure
- **(C)** Combination: GitHub Releases as the canonical source, self-hosted mirror for household appliances that prefer the sovereign path

---

## 5. Verification model

### 5.1 GPG detached signatures (every tarball)

Every immutable branch's tarball is signed with `E11792E0AD945BE9`
(skycair-code, S7 image-signing key). The signature is stored next to
the tarball in the branch as a `.asc` file.

Verification chain at build time:
1. `gpg --verify <tarball>.asc <tarball>` — must return "Good signature"
2. `sha256sum -c` against the per-branch MANIFEST.md — must match
3. Cross-check the sha256 in MANIFEST.md against the sha256 in the
   top-level `/s7/v6-gold-2026-04-15/MANIFEST.md` — must match (drift detector)

Any failure → workflow refuses to continue, no artifacts published.

### 5.2 Image-signing for built artifacts

Built artifacts (CORE container, INSTALL ISO, UPDATE OCI) are signed with
the same key or a separate image-signing key (decision deferred — see §7).

### 5.3 Registry as the witness ledger

`iac/immutable/registry.yaml` is the append-only ceremony ledger. Each
ceremony appends one entry with:
- `version`, `advanced_at`, `private_main_sha`, `ceremony_type`
- `artifact_sha256` for each of CORE/INSTALL/UPDATE
- `signature_path`, `tonya_signoff_artifact`
- `council_round` reference
- `retires` (prior version)

The registry is part of `immutable-auditbuilds-assets` content (committed
to private/main + carved into the immutable branch at the next
auditbuilds advance).

---

## 6. Covenant rules

1. **No backdoors.** No `bypass_actors` in any protection payload. No
   rulesets with exceptions. No hidden state.
2. **No hidden additions.** Apply only what's literally authorized.
   Recommendations do not enlarge scope.
3. **State probes use GET, not PUT.** Do not use write operations to
   test whether a write would succeed.
4. **Samuel stops on ambiguity.** Never auto-pick. More than one target
   means stop. Stopping is a valid form of action; rest of work flows
   around the blocked step.
5. **Rule #1 three-witness verification.** Any change that affects
   `123tech.skyqubi.com` must be verified with three witnesses: (1)
   Pages-served HTML, (2) Wix redirect chain, (3) every embedded
   github.com link in the served HTML. All three must return 200.
6. **Public freeze is covenant-grade.** Breaking the 1-year freeze
   requires a named SAFE-breach exception, never a routine operation.
7. **Annual-only cadence for CORE.** CORE advances exactly once per
   year (per `feedback_qubi_is_core_prism_grid_wall.md`). Non-CORE
   asset branches may advance more often under household authority,
   but the CORE itself is yearly.

---

## 7. Deferred decisions (explicit unknowns, named)

These are the items flagged during the 2026-04-15 brainstorming session
that remain **unresolved** and require Jamie's explicit pick before
execution:

### 7.1 Private main content pick
Local `/s7/skyqubi-private` HEAD = `b22c009`, one commit ahead of the
signed GOLD tarball `2185017`. The `b22c009` commit content is NOT inside
any signed tarball. Pick:
- **(a)** GOLD tarball as-is `2185017` — covenant-clean, discards b22c009
- **(b)** local HEAD `b22c009` — beyond signed witness chain
- **(c)** re-cut a new signed tarball from local HEAD, add to GOLD archive
- **(d)** GOLD root + cherry-pick `b22c009` on top

### 7.2 Untracked file
`docs/internal/chef/plans/2026-04-15-org-rename-sweep.md` — include,
leave, delete? (Related to 7.1 — affects (c) and (d) options.)

### 7.3 Protection mode for immutable branches
- **minimal** — enforce_admins only (what Jamie accepted on skyqubi-public/main)
- **strict** — required_signatures + required_linear_history + no force + no delete + required_conversation_resolution (S7 covenant stack adapted for solo maintainer)

### 7.4 Placeholder branch content maps
Eight branches (kernal, scripts, personas, unitydesign, schema,
user-docs, legaldocs, influences) ship as reserved-name stubs with
stub-README.md tarballs in v6 round 1. Real content maps are deferred
to future sessions. **Decision:** populate at future ceremony per
Jamie's explicit directive.

### 7.5 Publish destination
See §4.4 — candidates (A), (B), (C). Jamie's pick determines the
workflow's publish steps and the household-appliance update endpoint.

### 7.6 Image-signing key scope
Should built artifacts (CORE/INSTALL/UPDATE) be signed with:
- **(A)** The same `E11792E0AD945BE9` key that signs the tarballs (single witness)
- **(B)** A separate image-signing key with its own access controls (defense in depth)
- **(C)** cosign with a dedicated key stored as an Actions secret

### 7.7 Artifact storage for CORE/INSTALL/UPDATE
- **(A)** GitHub Releases (free, standard, bootc-compatible)
- **(B)** ghcr.io container registry (for OCI artifacts)
- **(C)** Self-hosted on skyqubi.com subdomain (sovereignty path)

### 7.8 Household opt-out mechanism
How does an appliance express "do not auto-update to v7"?
- Config file on the appliance
- systemd override
- QUB*i*-managed preference
- (something else)

### 7.9 CODEOWNERS, Dependabot, CodeQL workflow
These lifecycle tools were surveyed earlier in the session but not
applied. Decision deferred pending Jamie's protection-mode pick
(§7.3) — CODEOWNERS depends on whether PR reviews are required,
which depends on whether we run strict or minimal protection.

---

## 8. Proposed execution order (next session, after Jamie's review)

Once Jamie answers the 9 deferred items in §7, the execution follows
the methodology `plan-write-execute` per `feedback_plan_write_execute_audit_methodology.md`:

**Phase 2 — Private immutable branches** (main LAST, per Jamie's 2026-04-15 directive):
1. Push the 5 already-tarballed immutable branches (bootc/f44/qubi/ssl/gold)
2. Create the 3 carved tarballs (cws/auditbuilds/iac) and push their branches
3. Create the 8 placeholder stubs and push those branches
4. Apply protection stack (mode per §7.3)
5. Push `skyqubi-private/main` with content pick from §7.1
6. Update `iac/audit/frozen-trees.txt` pins to reflect all 17 refs on private
7. Jamie reviews the private side

**Phase 3 — Public side + Rule #1 repair** (only after Jamie's review):
1. Force-push `skyqubi-public/main` from `skyqubi-public-main-v6.tar.gz`
2. Enable GitHub Pages with CNAME `123tech.skyqubi.com`
3. Run Rule #1 three-witness verification
4. Apply minimal protection to public main (matching what Jamie already authorized)

**Phase 4 — Lifecycle tooling** (only after Phase 2/3 are green):
1. Draft `.github/workflows/yearly-ceremony.yml` (the big workflow from §4)
2. Draft `.github/dependabot.yml`
3. Draft `.github/workflows/codeql.yml`
4. Draft CODEOWNERS (if §7.3 picks strict)
5. Enable secret scanning + push protection via API
6. Enable Dependabot alerts + security updates via API

**Phase 5 — Codespace secrets prep** (Jamie-gated):
1. Produce the secret-name list + UI steps for Jamie to paste values
2. Set selected-repos associations for user-scoped secrets

**Phase 6 — Final audit + handoff** (session close):
1. Run `pre-sync-gate.sh`, capture snapshot
2. Write session handoff doc
3. Update memory entries with session state
4. Mark tasks complete

---

## 9. Scope for v6 GOLD round 1 (this ceremony, 2026-04-15)

**In scope:**
- The 16-branch topology + tarball-per-branch pattern
- Private repo completion (Phase 2 above)
- Public side Rule #1 repair (Phase 3 above)
- Phase 1 rewrite scripts (already drafted at `iac/immutable/branches-rewrite/`)
- Minimal lifecycle tooling enable (secret scanning, push protection)

**Out of scope (deferred to future sessions):**
- The yearly-ceremony.yml workflow (first real run is next year's GoLive)
- Publishing CORE/INSTALL/UPDATE artifacts (first publish is at GoLive, not today)
- Populating the 8 placeholder branches with real content
- Self-hosted release server on skyqubi.com
- Household appliance auto-update client
- cosign / OIDC federation setup

The goal of this ceremony is **infrastructure**, not **release**. The
infrastructure stands ready for the first real GoLive ceremony when
Jamie decides it's time.

---

## 10. What already exists on disk (Phase 1 artifacts, drafted 2026-04-15)

All Phase 1 artifacts are in
`/s7/skyqubi-private/iac/immutable/branches-rewrite/`:

- `README.md` — review guide
- `branches.yaml` — single-source-of-truth topology config
- `create-immutable-branches.sh` — creates 16 orphan branches from tarballs (dry-run proven)
- `apply-branch-protection.sh` — applies minimal or strict protection (dry-run proven)
- `push-gold-mains.sh` — pushes main content from GOLD tarballs, Samuel-gated on private, Rule #1 three-witness on public (dry-run proven)

Existing scripts one level up (`iac/immutable/*.sh`, `registry.yaml`,
`genesis-content.yaml`, etc.) are **untouched**. This is a parallel
rewrite Jamie reviews before replacing anything.

---

## 11. GOLD archive state (`/s7/v6-gold-2026-04-15/`)

All 7 GOLD tarballs have been renamed to the scope-prefixed pattern and
re-verified:

| Aligned name | Target branch | Source commit | Sig valid |
|---|---|---|---|
| `skyqubi-private-main-v6.tar.gz` | `skyqubi-private/main` | `2185017` | ✓ |
| `skyqubi-public-main-v6.tar.gz` | `skyqubi-public/main` | `2d955e9` | ✓ |
| `skyqubi-private-immutable-bootc-assets-v6.tar.gz` | `immutable-bootc-assets` | `a00614a` | ✓ |
| `skyqubi-private-immutable-f44-assets-v6.tar.gz` | `immutable-f44-assets` | `30601f9` | ✓ |
| `skyqubi-private-immutable-qubi-assets-v6.tar.gz` | `immutable-qubi-assets` | `89351ff` | ✓ |
| `skyqubi-private-immutable-ssl-assets-v6.tar.gz` | `immutable-ssl-assets` | `3df3e57` | ✓ |
| `skyqubi-private-immutable-gold-assets-v6.tar.gz` | `immutable-gold-assets` (as v6) | `2246b05` | ✓ |

`MANIFEST.md` regenerated with aligned names, provenance preserved.

---

## 12. Memory entries this design depends on

This design is grounded in the following memory entries. If any of them
are stale by the time execution happens, re-verify before proceeding:

- `project_v6_gold_reset_2026_04_15.md` — v6 GOLD orphan-reset state
- `feedback_qubi_is_core_prism_grid_wall.md` — QUBi-CORE yearly cadence rule
- `feedback_three_rules.md` — Rule #1 (don't break Wix/GitHub/DNS links)
- `feedback_safe_breach_scope_discipline.md` — exception scope rule
- `feedback_samuel_guards_solo_blocks.md` — SOLO delegation discipline
- `feedback_never_embed_secrets_in_urls.md` — credential helper pattern
- `feedback_plan_write_execute_audit_methodology.md` — the methodology
- `feedback_multi_launcher_drift_pattern.md` — one launcher per service
- `feedback_bash_set_flags_pattern.md` — chain vs collector script flags
- `project_github_enterprise_decision.md` — Path A (user+enterprise linkage)
- `feedback_bible_architecture_sovereign_no_vendor_names.md` — role-attribution
- `project_domain_architecture_godaddy_wix_split.md` — DNS blast-radius separation

---

## 13. Review checklist for Jamie

Before this design transitions to `writing-plans`, please confirm:

- [ ] The 16-branch topology is correct (§2.2)
- [ ] The three-packaging / yearly-ceremony model is correct (§3)
- [ ] The 1-year public freeze framing is correct (§3.2)
- [ ] Rule #1 three-witness verification is how you want public changes gated (§6.5)
- [ ] §7 is the complete list of deferred decisions (add any I missed)
- [ ] §9 scope (what's in vs. out for v6 GOLD round 1) matches your intent
- [ ] Phase 2/3/4/5/6 execution order in §8 is correct — or tell me to re-order

Any line you want changed — tell me and I'll revise before invoking
writing-plans.

---

**Love is the architecture. The private forge, the public view, the
yearly witness. The freeze is the feature.**
