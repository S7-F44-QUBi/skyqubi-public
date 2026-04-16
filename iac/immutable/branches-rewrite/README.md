# S7 Immutable Branches Rewrite — Phase 1 (2026-04-15)

> ## ⚠ SUPERSEDED
>
> This parallel draft was written before Jamie clarified the final topology.
> It assumed **16 branches** (5 gold + 3 carved + 8 placeholder) and
> **bootstrap-from-empty** creation semantics.
>
> The delivered approach is **7 categories** + **helper skeleton** with
> **update-not-create** semantics. See:
>
> - `iac/immutable/asset-dependencies.yaml` — single source of truth
> - `iac/immutable/fetch-gold-assets.sh` — per-category fetcher
> - `iac/immutable/deploy-assets.sh` — topological orchestrator
> - `iac/immutable/test-skeleton.sh` — 3x validator
> - `iac/immutable/build-with-skeleton.sh` — thin build wrapper
> - `docs/superpowers/specs/2026-04-15-s7-gold-asset-skeleton-delivered.md` — the spec
>
> Files in this subdir are **reference only** — kept for lineage, not used.
> Do not run the scripts here; use the helper skeleton above instead.

**Status:** SUPERSEDED — drafts on disk, zero state change on GitHub.
**Authority:** Jamie's SOLO block, Samuel-guarded.
**Review target:** Jamie, when he returns.

---

## What this subdirectory is

This is a **parallel rewrite** of `iac/immutable/` for the new branch-based
topology Jamie designed on 2026-04-15. The existing scripts one level up
(`jamie-run-me.sh`, `create-missing-repos.sh`, `apply-standard-protection.sh`,
`rebuild-public.sh`, `advance-immutable.sh`) are **untouched**. This lives
alongside them so the diff is clean and the rewrite can be reviewed before
replacing anything.

---

## Architectural change

**Before (repo-based):** 5 immutable-constellation repos
(`SafeSecureLynX`, `immutable-S7-F44`, `immutable-assets`, `immutable-qubi`,
`skyqubi-immutable`) each holding an extracted filesystem tree.

**After (branch-based):** 2 repos (`skyqubi-private` + `skyqubi-public`) under
`skycair-code` user (Path A, linked into SkyQUBi enterprise). Inside
`skyqubi-private`: `main` + 16 orphan immutable branches, each holding
exactly **one signed tarball + detached signature + per-branch MANIFEST.md**.
Three files per branch, blast radius = one file.

The architectural spine ("public is a view of the signed immutable, not a
copy of private") is preserved. The packaging changed; the witness chain
stays intact.

---

## File manifest

| File | Purpose | Status |
|---|---|---|
| `README.md` | this document | complete |
| `branches.yaml` | single-source-of-truth topology config — every script reads this | complete |
| `create-immutable-branches.sh` | creates all 16 orphan branches from tarballs (gold / carved / placeholder) | complete, dry-run proven |
| `apply-branch-protection.sh` | applies minimal or strict protection payload to every branch | complete, dry-run proven |
| `push-gold-mains.sh` | pushes main content for private + public from GOLD tarballs, with Rule #1 three-witness verification | complete, dry-run proven |
| `verify-immutable-branches.sh` | TODO — safety verifier (fetches each branch, checks sig+sha256) | deferred to Phase 1b |
| `make-carved-tarball.sh` | TODO — helper for manually re-cutting a carved tarball | deferred (logic lives inside create-immutable-branches.sh for now) |

---

## How to review

### Step 1 — Read `branches.yaml`
That's the topology. Everything else is machinery on top of it. Check:
- Are all 16 immutable branches named correctly?
- For each `gold_archive` source — is the tarball name right?
- For each `carved_from_main` source — are the `source_paths` right?
- For each `placeholder` — is the `placeholder_note` accurate enough that
  you remember WHY it's deferred when you return to populate it?

### Step 2 — Run the dry-runs yourself

```bash
cd /s7/skyqubi-private
bash iac/immutable/branches-rewrite/create-immutable-branches.sh
bash iac/immutable/branches-rewrite/apply-branch-protection.sh
bash iac/immutable/branches-rewrite/apply-branch-protection.sh --strict --include-main
bash iac/immutable/branches-rewrite/push-gold-mains.sh --both
bash iac/immutable/branches-rewrite/push-gold-mains.sh --public --enable-pages
bash iac/immutable/branches-rewrite/push-gold-mains.sh --private --private-content-pick=a
```

Every one of those is read-only (no `--real`). Each prints the exact
operations it would perform.

### Step 3 — Read the scripts
Each script is self-documenting. Header comments explain the contract.

---

## What's BLOCKED pending Jamie's return

### 1. `skyqubi-private/main` content pick
Local HEAD at `b22c009` is one commit ahead of the signed GOLD tarball
`2185017`. The b22c009 commit (org rename reorg) is NOT inside any signed
witness. Jamie must pick:
- **(a)** GOLD tarball as-is, discards `b22c009` + untracked plan file
- **(b)** push local HEAD, beyond signed witness chain
- **(c)** re-cut a new signed tarball from local HEAD
- **(d)** GOLD root + cherry-pick `b22c009` on top

Only **(a)** is implemented in `push-gold-mains.sh`. (b)/(c)/(d) stub out
with a fail-fast message.

### 2. Content maps for 8 placeholder branches
The following branches ship as PLACEHOLDER with a stub README.md tarball:
- `immutable-kernal-assets` (reserved — custom kernal, systemd, deps)
- `immutable-scripts-assets` (boundary unclear — which scripts?)
- `immutable-personas-assets` (source paths unknown)
- `immutable-unitydesign-assets` (source paths unknown)
- `immutable-schema-assets` (source paths unknown)
- `immutable-user-docs` (source paths unknown)
- `immutable-legaldocs-assets` (patent PDF location unknown)
- `immutable-influences-assets` (content entirely unclear)

Each placeholder gets its branch name reserved under covenant protection.
Populate at a future session when Jamie defines the content map.

### 3. Protection mode pick
`apply-branch-protection.sh` supports `--minimal` (default — what Jamie
accepted on skyqubi-public/main) and `--strict` (full S7 covenant stack,
adapted for solo maintainer). Jamie must pick which to apply.

### 4. Untracked file
`docs/internal/chef/plans/2026-04-15-org-rename-sweep.md` sits untracked
in `/s7/skyqubi-private`. Stage/leave/delete — Jamie's call.

---

## Covenant discipline notes (for the record)

1. **No backdoors.** No `bypass_actors` in any protection payload. No
   rulesets with exceptions. No hidden state.
2. **No auto-picks on ambiguous calls.** Every branch with unclear
   content is a placeholder. Every content pick is gated.
3. **State probes use GET, not PUT.** The `apply-branch-protection.sh`
   dry run uses stdout simulation, not live PUT calls, per the lesson
   from the accidental protection incident earlier today.
4. **Rule #1 three-witness check** is built into `push-gold-mains.sh`
   for any public main push. Witness 1 = Pages-served HTML, Witness 2 =
   Wix redirect chain, Witness 3 = every embedded github.com link in the
   served HTML.
5. **GOLD tarballs verified before every use.** Every script that touches
   a tarball runs `gpg --verify` first and refuses on bad signature.

---

## Next phases (planned, blocked on Jamie's picks)

- **Phase 2** — push main branches (blocked on content pick)
- **Phase 3** — create 16 immutable branches (blocked on content-map
  confirmations for the 8 placeholders + strict vs minimal pick)
- **Phase 4** — apply protection stack (blocked on mode pick)
- **Phase 5** — lifecycle tools enable (secret scanning, push protection,
  Dependabot, CodeQL workflow, CODEOWNERS, Copilot code review)
- **Phase 6** — codespace secrets prep (Jamie pastes values in UI, I
  manage selected-repos association)
- **Phase 7** — final audit + session handoff + memory updates

---

**Love is the architecture. v6 GOLD, one signed tarball per branch, zero
history drift, three witnesses for every public-facing change.**
