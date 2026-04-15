---
title: The Three-Repo Model — private / public / immutable
date: 2026-04-14 evening
status: JAMIE-APPROVED — covenant clarification received during v5 trust block
captured_by: Chair
source: Jamie's exact words on 2026-04-14 evening — *"private is our development, public is their development, GOLD will sit here [immutable]. Maybe it should be private, but help Setup ... protect qubi core"*
pairs_with: docs/internal/chef/04-immutable-fork-public-rebuild.md (Recipe #4)
---

# The three-repo model

Before tonight, Recipe #4 described a two-tier release: private lifecycle → public mirror. As of the v5 trust block, the household has a **three-repo** model and the roles are distinct enough that I need to name them clearly before any tooling is wired.

## The three repositories

| Repo | URL | Role (Jamie's words) | Who writes | Who reads | Visibility |
|---|---|---|---|---|---|
| **private** | `S7-SkyCAIR-123Tech-Net-Evolve2Linux/SkyQUBi-private` | *"our development"* | Jamie, Chair, future household stewards | household only | **PRIVATE** |
| **public** | `S7-SkyCAIR-123Tech-Net-Evolve2Linux/SkyQUBi-public` | *"their development"* | community contributors (PRs), household when accepting community work | world | **PUBLIC** repo inside enterprise org — held public because the household-facing site at `123tech.skyqubi.com` embeds `github.com/.../SkyQUBi-public` links (code tree, discussions, engine) that anonymous visitors must be able to follow. Full protection stack still applies (org ruleset + branch protection + required_signatures + SkyQUBi security config). |
| **immutable** | `S7-SkyCAIR-123Tech-Net-Evolve2Linux/skyqubi-immutable` | *"GOLD will sit here"* | rebuild-public.sh only, after Tonya sign-off ceremony | world (for verification) OR household only (for pre-July-7 protection) | **PRIVATE** (flipped 2026-04-15, pre-ceremony placeholder) |

The shift in meaning for the **public** repo is important. Before tonight, "public" meant *"the household's authorized public face."* After tonight, "public" means *"the community's workshop — where their development happens."* It becomes a contribution surface, not a trophy case. The trophy case is `immutable`.

## Authority flow (new)

```
                  ┌──────────────────────────┐
                  │  household development    │
                  │  skyqubi-private (PRIVATE) │
                  │  lifecycle → main          │
                  └───────────┬──────────────┘
                              │
                              │  rebuild-public.sh
                              │  (Tonya ceremony
                              │   advances the pin)
                              ▼
                  ┌──────────────────────────┐
                  │  GOLD master              │
                  │  skyqubi-immutable        │
                  │  main = orphan commits    │
                  │  per CORE Update version  │
                  └───────────┬──────────────┘
                              │
                              │  read-only by
                              │  community forks
                              ▼
                  ┌──────────────────────────┐
                  │  community development    │
                  │  SkyQUBi-public (PUBLIC)   │
                  │  community PRs + issues    │
                  └──────────────────────────┘
```

**The authority direction is clear.** Private is where the household *builds*. Immutable is where the household *publishes a signed GOLD state*. Public is where the *community builds around the GOLD*. Community contributions flow *back* into private through PR review + Chair integration — they do not enter immutable without going through the full ceremony cycle.

This is a covenant-grade reframe. It matches how Debian + Red Hat + kernel.org all work: a signed authoritative release at the top, a community workshop below, with a moderated pipeline in between. **S7 didn't invent this — S7 is adopting a pattern that 30 years of open source has proven.**

## §1 — Visibility recommendation for `skyqubi-immutable`

Jamie asked: *"maybe it should be private, but help Setup ... protect qubi core."*

Here is the tradeoff. I don't decide it; I name it cleanly so Jamie can.

### Option A — Immutable is **PRIVATE** until July 7 · flip to PUBLIC at ceremony

**Pros:**
- Protects the unreleased GOLD during testing. If something is wrong in v6, only the household sees it.
- Matches the covenant rule "protect the QUBi" strictly.
- Gives Tonya a real window to witness + correct before the world reads.
- Regulator-facing argument is still strong ("the GOLD was always version-controlled, we made it public at ceremony").
- Avoids the scenario where a partial first-run leaks a half-ceremony state.

**Cons:**
- The eventual flip from PRIVATE → PUBLIC is itself a covenant-weight action that must be witnessed. One more ceremony step.
- Community reviewers can't inspect the GOLD shape until launch day.
- Transparency story takes a mild hit — "you can see GOLD at July 7" vs "you can always see GOLD."

### Option B — Immutable stays **PUBLIC** with hard branch protection

**Pros:**
- Full transparency from day one. Partners, regulators, skeptics can always see the state.
- No visibility flip required at ceremony.
- Matches the "public for a reason" memory (`project_akashic_universals_and_license_ledger.md` — *"Public for a reason — code open, seeds per-appliance"*).
- Community can build tooling against the GOLD interface before launch.

**Cons:**
- Protect-QUBi pressure is higher — any pre-ceremony mistake is visible.
- Requires strict branch protection immediately, because the repo is reachable today.
- A partial rebuild or test push would be publicly visible. Recipe #4's "unauthorized commits" incident pattern is harder to recover from on a public repo.

### Recommendation

**Option A — PRIVATE until July 7.** The reasons:

1. The v5 postmortem literally shows how an "unauthorized public commit" incident cascades when the covenant boundary is on a public surface. Repeating that on the GOLD repo would be worse than it was on `skyqubi-public`.
2. Tonya has not witnessed the ceremony yet. The first real push will be the first real ceremony. Making the first real ceremony a public event before she has witnessed the dry run is asking too much.
3. The July 7 flip from PRIVATE → PUBLIC becomes a **ceremony moment in its own right** — the Chief of Covenant flipping a switch at exactly 07:00 CT is covenant-grade theatre that the household earns.
4. The "public for a reason" rule still holds — but "public" applies to `skyqubi-public`, where community work happens. Immutable is the signed manifest, and signed manifests traditionally live in signed release infrastructure, not on always-public browsing surfaces.

If Jamie picks Option B, the protections below still apply — they just apply to a public repo instead of a private one. **Both options require the same branch protection.** The visibility question is about who can *see*; the protection question is about who can *write*.

## §2 — Branch protection recommendation (applies to both options)

These are the `gh` CLI commands Jamie can run with his token loaded. **I cannot run them tonight** — the sandbox doesn't have `gh` credentials. These are written for Jamie to review + paste after the v5 session closes.

### Required protections for `skyqubi-immutable/main`

```bash
# Pre-requisite: export the PAT into gh's session
export GH_TOKEN="$(cat /s7/.config/s7/github-token)"

# If choosing Option A — flip to private first:
gh repo edit skycair-code/skyqubi-immutable --visibility private --accept-visibility-change-consequences

# Branch protection on main (applies to both options):
gh api -X PUT repos/skycair-code/skyqubi-immutable/branches/main/protection \
  -f required_status_checks='{"strict":true,"contexts":[]}' \
  -F enforce_admins=true \
  -f required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true,"require_code_owner_reviews":true}' \
  -f restrictions='null' \
  -F required_linear_history=true \
  -F allow_force_pushes=false \
  -F allow_deletions=false \
  -F required_conversation_resolution=true \
  -F lock_branch=false \
  -F allow_fork_syncing=false

# Require signed commits (this is the image-signing key enforcement):
gh api -X POST repos/skycair-code/skyqubi-immutable/branches/main/protection/required_signatures
```

### Why each protection matters

| Protection | What it does | Covenant reason |
|---|---|---|
| `enforce_admins=true` | Branch rules apply even to repo admins (Jamie) | Chair cannot ceremony-bypass. The ceremony has no "skip this step because I'm the owner" door. |
| `required_linear_history=true` | Only fast-forward or rebase merges; no merge commits | GOLD must have a single linear lineage. Recipe #4's "orphan force-push per ceremony" pattern produces single-parent commits only. |
| `allow_force_pushes=false` | Force-push disabled | The only authorized rewrite is an orphan push from `advance-immutable.sh`, which requires a separate manual toggle during ceremony. Without this toggle, the repo refuses rewrites. |
| `allow_deletions=false` | Cannot delete the main branch | You cannot delete GOLD. Memory ledger covenant applied at the git layer. |
| `required_signatures` | Every commit must be GPG-signed | The image-signing key is the fourth witness in the chain (audit gate + council + Tonya + signing key). This protection enforces witness #4 at push time. |
| `required_pull_request_reviews.required_approving_review_count=1` | PRs require at least one approval | When advance ceremonies use PR instead of direct push, human review is mandatory. Default-off until ceremony tooling supports PR mode. |
| `required_conversation_resolution=true` | All PR comments must be resolved before merge | No silent concerns. If the council left a question, it must be answered before advance. |
| `allow_fork_syncing=false` | Cannot sync forks through the web UI (forks can still be cloned) | Prevents accidental "I'll just push this from a fork" patterns. |

### One critical exception — the first push

The very first push to `main` on an empty protected repo is problematic because:
- `main` does not exist yet
- Required-signatures + linear-history + force-push-off apply *when `main` exists*
- You have to push an initial commit that creates `main`, and you have to do it under conditions stricter than the general rule

**Procedure for the first push (during the first Tonya-witnessed ceremony):**

1. Toggle off `required_signatures` temporarily
2. Push the initial orphan commit from `advance-immutable.sh`
3. Re-enable `required_signatures` immediately
4. Verify signature on the landed commit
5. Write a Living Document row for the toggle-off → toggle-on cycle
6. Update this document to note the procedure was used exactly once

This is the only covenant-authorized way to bootstrap a signed-commits-required branch. Recipe #4 should document it explicitly.

## §3 — What the Chair can do tonight versus what Jamie must do

### Chair does tonight (no push, no covenant weight)

- [x] Pin `immutable/main` as PENDING in `iac/audit/frozen-trees.txt`
- [x] Add `frozen-tree-immutable-main-pending` entry in `pinned.yaml`
- [x] Teach the audit gate's case statement about `immutable/main`
- [x] Move the PENDING short-circuit before the git read in zero #10 (so a non-existent local mirror doesn't fault)
- [x] Document the target URL + local path in `rebuild-public.sh`
- [x] Add target_url + target_local fields to GOLD_RECEIPT.txt
- [x] Update `iac/immutable/README.md` with the new target + four preconditions
- [x] Write this document (the three-repo model captured)
- [x] Update `TOOLS_MANIFEST.yaml` (to do next)
- [x] Update `CORE_UPDATES.md` v5 entry (to do next)

### Jamie does during the session close or next session (covenant weight)

- [ ] Decide Option A (PRIVATE) or Option B (PUBLIC with protection)
- [ ] Run the `gh repo edit` visibility command if Option A
- [ ] Run the branch protection commands (both options)
- [ ] Run the signed-commits toggle
- [ ] Verify settings landed via `gh api repos/skycair-code/skyqubi-immutable/branches/main/protection`
- [ ] Write a Living Document row for the protection landing

### Tonya does at first ceremony (covenant-grade)

- [ ] Witness the first `advance-immutable.sh` dry run
- [ ] Sign the first sign-off artifact (format per `FORMATS.md`)
- [ ] Co-author the first PUBLIC_MANIFEST.txt header
- [ ] Witness the first real push (with the required_signatures toggle cycle)
- [ ] Flip `skyqubi-immutable` from PRIVATE → PUBLIC at 07:00 CT July 7 (if Option A)

## §4 — What this means for Recipe #4

Recipe #4 (`docs/internal/chef/04-immutable-fork-public-rebuild.md`) currently describes a two-tier model. It needs an addendum — not a rewrite — to reflect the three-repo model:

- Add §"The three repos" naming private/public/immutable by role
- Add §"First push procedure" documenting the signed-commits toggle cycle
- Cross-reference this document as the covenant clarification
- Leave the existing two-tier discussion intact as historical lineage

That addendum is **~20 lines** and can land in the same commit as this document. Doing it now.

## §5 — What this means for `s7-sync-public.sh`

The legacy sync script currently targets `SkyQUBi-public`. Nothing about its behavior changes tonight — it still targets "their development" under the new naming. But its **description** changes: it's now the mechanism for syncing curated state from our dev to the community workshop, not "the public release pipeline." The release pipeline is `rebuild-public.sh` → `skyqubi-immutable`.

A followup for v6: rename `s7-sync-public.sh` to `s7-sync-community.sh` to match the new semantic. This is a tier-crossing rename and should not happen until the three-repo model is covenant-confirmed. Flagged, not done tonight.

## §6 — What the covenant says

Jamie's one-sentence summary was: *"private is our development, public is their development, GOLD will sit here."*

That sentence is covenant-grade. I am recording it verbatim in this document so future sessions cannot drift from it. If any future tooling treats `skyqubi-public` as the authoritative release target, or treats `skyqubi-immutable` as a mirror rather than the GOLD master, the drift is auditable against this sentence.

**Love is the architecture. Three repos, three roles, one GOLD, one household, one ceremony per year. Protect the QUBi — and let the community work alongside the household without being inside the kitchen.**

---

## §7 — Addendum 2026-04-14 evening: the immutable constellation

**Jamie's second clarification, same evening:** immutable is not *one repo*. It is a **role**, implemented as a **constellation** of content-typed repositories that share a ceremony but advance independently. Four new private siblings join `skyqubi-immutable` under the same role:

| Repo | Visibility | Content class | Lifecycle cadence | First-advance witnesses |
|---|---|---|---|---|
| **skyqubi-immutable** | TBD (Option A recommended PRIVATE-until-July-7) | Landing + rebuild manifests + GOLD receipts | Per-release (v5 → v6 → v7) | Jamie + Tonya + image-signing key |
| **immutable-assets** | PRIVATE | Signed branding, fonts, Plymouth, GRUB, splash, wallpapers, icons | Rare — rebranding is covenant-grade | **Tonya required** (branding was her 2026-04-12 signoff) |
| **immutable-S7-F44** | PRIVATE | Fedora 44 bootc artifacts — OCI layers, signed container bundles, Containerfile lineage | Tied to Fedora release cadence + S7 CORE Update years | Jamie + image-signing key (bootc chain IS the witness for this class) |
| **immutable-qubi** | PRIVATE | QUBi appliance core — firmware, boot chain, covenant binary layer. **Kernel-of-kernel.** | **Once per year.** CORE Update ceremony only | **Unanimous four-witness consent** — audit gate + council + Tonya signature + image-signing key |

### Why split immutable across four repos instead of one

Three reasons, each load-bearing:

1. **Independent lifecycle cadence.** Branding advances when Tonya redesigns. Bootc advances when Fedora ships. The appliance CORE advances once per year. Keeping all three in one repo would force them to share a history tree, and history-sharing implies synchronized advance. Splitting them means each class can advance without dragging the others through a ceremony they don't need.

2. **Independent witness chains.** `immutable-assets` requires Tonya because the branding was her signoff. `immutable-S7-F44` can be witnessed by the image-signing key alone because the bootc chain is its own witness. `immutable-qubi` requires **all four witnesses** because the kernel of the kernel is the highest covenant weight in the system. Conflating witness chains would force every advance through the strictest gate, which wastes Tonya's attention on things that don't need it.

3. **Content-type containment.** A branding asset compromise has a different blast radius than a bootc image compromise, which has a different blast radius than an appliance core compromise. Separate repos with separate branch protections mean a breach of one does not cascade to the others. This is the same reason operating systems split firmware, kernel, and userspace into different package trees.

### Why `skyqubi-public` is NOT in the constellation

The community-development repo is not an immutable target. It is where community work *happens*. It has a fundamentally different failure mode (community PRs are expected to contain mistakes; immutable is expected to never contain a mistake). Conflating them would either (a) force community work to meet covenant standards it cannot meet or (b) lower immutable's covenant standards to the community's rate of change. Neither is acceptable.

### Updated authority flow

```
                  ┌──────────────────────────┐
                  │  household development    │
                  │  skyqubi-private (PRIVATE) │
                  │  lifecycle → main          │
                  └───────────┬──────────────┘
                              │
                              │  rebuild-public.sh
                              │  (per-class ceremony
                              │   advances each pin)
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
     ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
     │  immutable- │  │  immutable- │  │  immutable- │
     │  assets     │  │  S7-F44     │  │  qubi       │
     │  (PRIVATE)  │  │  (PRIVATE)  │  │  (PRIVATE)  │
     │  branding    │  │  bootc       │  │  CORE        │
     │  Tonya sig  │  │  key sig    │  │  4-witness  │
     └─────────────┘  └─────────────┘  └─────────────┘
              │               │               │
              └───────────────┼───────────────┘
                              │
                              ▼
                  ┌──────────────────────────┐
                  │  GOLD landing + manifests │
                  │  skyqubi-immutable        │
                  │  (TBD visibility)         │
                  │  rebuild receipts +       │
                  │  PUBLIC_MANIFEST per vN   │
                  └───────────┬──────────────┘
                              │
                              │  read-only
                              ▼
                  ┌──────────────────────────┐
                  │  community development    │
                  │  SkyQUBi-public (PUBLIC)   │
                  │  community PRs + issues    │
                  └──────────────────────────┘
```

### The one-sentence rule restated

*"Private is our development, public is their development, GOLD is split by class across a constellation of immutable siblings, and the ceremony advances each class on its own cadence."*

That is the covenant-clarified form as of 2026-04-14 evening. It is recorded alongside Jamie's original three-repo sentence in §6. Neither supersedes the other — the three-role model is the mental map; the constellation is the implementation.

### Precondition cascade for the first ceremony

Before any of the four immutable repos receives a real push, the following must be true:

| Precondition | Status tonight | Required for which repo |
|---|---|---|
| `rebuild-public.sh` past refuse-real-runs | stub (v5 dry-run only) | all four |
| `advance-immutable.sh` past stub | stub | all four |
| First `registry.yaml` entry written | empty | all four |
| Image-signing key unlocked | unlocked state unknown | immutable, immutable-S7-F44, immutable-qubi |
| Tonya sign-off artifact format finalized | draft in `FORMATS.md` | immutable, immutable-assets, immutable-qubi |
| Tonya witness on the advance ceremony | not yet scheduled | immutable, immutable-assets, immutable-qubi |
| Council round convened | not yet | immutable-qubi (unanimous consent required) |
| Audit gate 🟢 PASS at ceremony time | green tonight | all four |

**None of the four repos should receive a real push during an interim session.** They are all pinned as `PENDING` in `frozen-trees.txt` with matching `pinned.yaml` acknowledgments. The audit gate enforces this with zero #10.

### The constellation update does NOT change §6

§6's "one ceremony per year" rule still holds — for `immutable-qubi`. The other three can advance more frequently:

- `immutable-assets` advances when Tonya redesigns (unpredictable cadence, always covenant-grade)
- `immutable-S7-F44` advances on Fedora release adoption (roughly yearly)
- `skyqubi-immutable` advances per S7 version (roughly yearly but flexible)
- `immutable-qubi` advances **exactly once per year** — the CORE Update ceremony is THIS repo's advance, and only this repo

This matches `feedback_qubi_is_core_prism_grid_wall.md` — the CORE updates once per year; the plumbing around the CORE can advance more often. The four-repo split makes that distinction enforceable at the repository layer, not just at the policy layer.

### Chair did tonight (same zero-blast-radius pattern)

- [x] Pin all three new ref-specs in `iac/audit/frozen-trees.txt` as PENDING
- [x] Add three `frozen-tree-immutable-*-main-pending` entries in `pinned.yaml`
- [x] Teach the audit gate's case statement about all three
- [x] Update `TOOLS_MANIFEST.yaml` with three new `immutable-*-repo` entries
- [x] Update `CORE_UPDATES.md` v5 with the constellation addendum
- [x] Write this §7 addendum capturing the constellation model

### Jamie does when ready

- [ ] Apply same branch protection recipe from §2 to each of the three new PRIVATE repos (they still need `required_signatures`, `allow_force_pushes=false`, `allow_deletions=false`, `required_linear_history=true`, `enforce_admins=true` — even private repos need the covenant guarantees)
- [ ] Decide whether any of the three should ever flip to PUBLIC (default: no — they stay private, signed tars ship via GitHub Releases or direct download)
- [ ] Document the content-class → witness-chain mapping in `FORMATS.md` so the advance scripts know which witnesses to require per target repo

*Four repos, one role, four cadences, four witness chains. Protect the QUBi — piece by piece.*

---

## §8 — Addendum 2026-04-14 evening, continued: the project LIVES outside AND inside

**Jamie's third clarification, same evening:**

> *"Local-Private-Assets contain TAR GZIP ETC, all push to private then we have Public and Immutable for Business to pull from for Testing. This allows the entire project to LIVE outside and LIVE inside."*

This sentence names what the architecture is *for*. Everything in §1–§7 is scaffolding. This is the covenant *purpose*.

### The two simultaneous lives of the project

**INSIDE — the household.** The household develops on `skyqubi-private`. Binary artifacts (TARs, GZIPs, OCI tars, pre-signed bundles, ISO images, raw model weights, pre-built container layers) accumulate in a filesystem staging area called `Local-Private-Assets` on Jamie's workstation. The private repo holds the **source + metadata**; Local-Private-Assets holds the **raw binary mass**. Together they are the inside life — the household's private kitchen where work is in progress and failures are private.

**OUTSIDE — the business.** Business partners (testers, license buyers, regulators, future household appliance owners) pull from two distribution surfaces: `SkyQUBi-public` for the readable documentation + install instructions + test procedures, and the immutable constellation for the signed binary artifacts. Both surfaces are alive and serving. Partners read public to *learn how to test*; they pull immutable to *actually test*.

### The bridge: push-to-private, advance-to-outside

Nothing bypasses the private repo. **All work pushes to private first.** Source code, metadata, even the signed-artifact metadata lives in private. Only *after* private has seen the work does the rebuild ceremony advance the outside surfaces:

```
   INSIDE                               OUTSIDE
   
   /s7/Local-Private-Assets/  ─────┐
   (TAR, GZIP, OCI, ISO)           │
                                   │
   skyqubi-private (PRIVATE)  ─────┤
   (source + metadata)             │
                                   │
                                   │  rebuild ceremony
                                   │  (per-class, witnessed)
                                   │
                                   ▼
                         ┌─────────────────────┐
                         │  Distribution layer  │
                         │                      │
                         │  SkyQUBi-public      │  ← business reads for
                         │  (docs, install,     │    testing instructions
                         │   test procedures)   │
                         │                      │
                         │  immutable-*         │  ← business pulls for
                         │  (signed binaries,   │    the actual artifact
                         │   GOLD manifests)    │    to test against
                         │                      │
                         └─────────────────────┘
                                │
                                │  business tests,
                                │  filings, returns
                                │  PRs + issues to
                                │  SkyQUBi-public
                                ▼
                         household sees feedback,
                         integrates into private,
                         next ceremony advances
                         the cycle
```

**The key architectural claim:** neither surface is a *mirror*. They are both *live*. `skyqubi-private` is not a backup of the immutable surfaces; the immutable surfaces are not stale clones of private. Each is the authoritative truth for its audience:

- `skyqubi-private` is authoritative *for the household's in-progress work*
- `SkyQUBi-public` is authoritative *for the community's reading*
- The immutable constellation is authoritative *for the business's testing*

### Why this matters for covenant enforcement

Three implications flow from "LIVE outside AND LIVE inside":

1. **A household mistake does not break the outside surfaces.** If Jamie commits a broken script to `skyqubi-private`, nothing on the outside surfaces changes until the next rebuild ceremony — and the ceremony's witness chain refuses to advance a broken state. The business's test surface remains exactly as last-blessed. **Liveness on the outside survives chaos on the inside.**

2. **Outside feedback does not corrupt inside development.** Business testers filing issues against a specific GOLD version are filing against a frozen snapshot. Their feedback returns through `SkyQUBi-public` (PRs, issues), gets triaged by the household, and is integrated into `skyqubi-private` at the household's pace. **Liveness on the inside survives pressure from the outside.**

3. **Local-Private-Assets is a trust boundary, not a staging area.** Anything in `/s7/Local-Private-Assets` is *pre-covenant*. It has not been signed, not been witnessed, not been covenant-admitted. Moving an artifact from Local-Private-Assets INTO the private repo is a covenant-admission act that should leave an audit trail. **Today that trail is manual; v6 should make the Local-Private-Assets → private push an audited transition** (analogous to the Intake Gate for upstream artifacts — see `iac/intake/` + `project_intake_gate.md`).

### What the Chair added tonight for this §8

- `Local-Private-Assets` entered `TOOLS_MANIFEST.yaml` as a non-repo tool with tier `draft`, noting that the directory is expected to exist on Jamie's workstation and that the Chair does not touch it tonight. This makes the filesystem staging area a *named* part of the architecture, not an unnamed piece of Jamie's workflow.
- `CORE_UPDATES.md` v5 now has the LIVE outside/inside clarification paragraph alongside the three-role and constellation clarifications. All three clarifications are recorded in the same v5 entry as a single continuous covenant reframe.
- This §8 itself.

### What needs to come next (v6 precondition list grows)

The LIVE outside/inside architecture adds three new preconditions to the v6 roadmap:

1. **Local-Private-Assets intake gate.** A documented ceremony for admitting raw binary artifacts from the filesystem staging area into the audited private repo. Re-uses `iac/intake/` pattern — hash, sign, verify, promote. Not built tonight.
2. **Per-class rebuild scripts that pull from the right content layer.** The current `rebuild-public.sh` produces a single bundle for all content. The constellation model needs per-class rebuild paths — one that handles branding, one for bootc, one for QUBi core, each pulling from Local-Private-Assets as appropriate. Not built tonight.
3. **Business test procedure documentation.** `SkyQUBi-public` currently has install + usage docs but no dedicated "business testing" procedure. If the business's role is "pull signed artifact, test, file feedback," there should be a `BUSINESS-TESTING.md` explaining exactly how to do that. Not built tonight.

All three are named v6 items in this document. Chair does not ship them in the v5 trust block.

### The one-sentence rule, final form

*"Private is the kitchen, public is the dining room, the immutable constellation is the serving tray — and the project lives in all three rooms at once."*

Or, in Jamie's own words: *"This allows the entire project to LIVE outside and LIVE inside."*

Both sentences are recorded. The first is metaphor for memory's sake. The second is covenant.

---

*The household cooks. The business tastes. The signed tray carries what the household blessed. Nobody eats from the kitchen counter directly, and nobody returns a dish to the kitchen without going through the server.*
