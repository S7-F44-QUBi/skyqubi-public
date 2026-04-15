---
title: Session Close — 2026-04-14 / v6-genesis handoff
date: 2026-04-14 evening (24hr Exercise of Trust block end-of-ship)
status: JAMIE-AUTHORIZED-IN-TONYAS-STEAD
purpose: Single-entry-point handoff document for the next session start and for Jamie's ceremony paste when he's ready
---

# Session Close — 2026-04-14 · v6-genesis

One document. Read the top, stop where it tells you to stop. Everything below the stop line is reference.

---

## FIXED 2026-04-15 ~06:00 — branch protection applied to public repos

Jamie returned mid-SOLO with "fix now" + "create the organization policy or owner setting to have same settings by default." The Chair applied strict branch protection using the compromised PAT (Jamie authorized: fixing protection with a leaked token is a defensive ratchet — it makes the leak less exploitable). Results:

| Repo | Visibility | Protection status |
|---|---|---|
| `SkyQUBi-public` / `main` | PUBLIC | 🟢 **applied** (enforce_admins, linear_history, no force-push, no deletions, 1 PR review required, conversation resolution required) |
| `SkyQUBi-public` / `old-main` | PUBLIC | 🟢 applied (same settings) + confirmed default branch reset from `old-main` back to `main` |
| `skyqubi-immutable` / `main` | PUBLIC | 🟢 **applied** (same settings) |
| `SkyQUBi-private` / `main` | PRIVATE | 🔴 **BLOCKED by GitHub Free tier.** Private repo branch protection requires GitHub Pro ($4/month). This is a platform limit, not a script bug. |

**New covenant recommendation: upgrade `skycair-code` to GitHub Pro.** Until that happens, the private repo's main branch relies on Chair discipline alone for protection. Any leaked PAT can force-push, delete, or rewrite history on private/main. Rule 3 of the Three Rules ("protect the QUBi") depends on this being fixed.

**New helper script:** `iac/immutable/apply-standard-protection.sh`

- Applies S7's standard protection to any named repo or `--all` for every skycair-code repo
- Detects the Free-tier limit and reports it cleanly
- Detects the default_branch and applies protection to that branch (not hardcoded to `main`)
- Idempotent — running twice is safe
- Intended to be run EVERY TIME a new repo is created, because `skycair-code` is a User account (not an Organization) and GitHub does not provide a "default protection for all new repos" setting for user accounts

**Attempted and refused:** Organization-level rulesets. `skycair-code` is a User account, not an Org. The org rulesets API returns 404. Repository-level rulesets are also Pro-gated on private repos.

**The real fix for "set-once default protection":** convert `skycair-code` from a User account to an Organization. GitHub supports this via account settings. Once converted, org-level rulesets become available and the protection becomes a one-time setup instead of a per-repo-per-run thing. Flagged for Jamie's next administrative session.

## NEW FINDING 2026-04-15 ~05:45 — skyqubi-public branch protection OFF

During a routine lifecycle re-run late in the SOLO block, test **S06 "Branch protection"** failed:

```
curl -s https://api.github.com/repos/skycair-code/SkyQUBi-public/branches/main
→ {"protected": false, ...}
```

This is the public repo (`SkyQUBi-public`), not any of the new immutable siblings. The `main` branch there has NO protection applied. `protected: false` means anyone with push access (which is just the `skycair-code` account) can force-push, delete, or rewrite history on the public repo without any branch-level guard.

**Why this matters:** the "don't break public links" rule from the pinned memory `feedback_three_rules.md` depends on public `main` being stable and protected. A force-push or delete could break the Wix iframe origin at `123tech.skyqubi.com` (which IS `github.io/skycair-code/SkyQUBi-public`). The protection is the second witness after Chair discipline.

**When this became false:** unknown. S06 was passing earlier in this session but the Living Document doesn't snapshot per-test lifecycle results, so the earliest failure timestamp isn't tracked. It is failing now. Either:
1. A recent ceremony attempt or manual operation accidentally removed the protection
2. Protection was never applied after a previous force-push recreated main
3. The protection was applied to a different ref spec (e.g., `master` instead of `main`) and the expected ref was never protected

**How to fix it (when the PAT rotates):**

```bash
# Verify the current state first:
gh api repos/skycair-code/SkyQUBi-public/branches/main \
  --jq '{protected: .protected, name: .name}'

# Apply strict protection — same settings as jamie-run-me.sh uses
# for the immutable constellation:
gh api -X PUT repos/skycair-code/SkyQUBi-public/branches/main/protection \
  -f 'required_status_checks={"strict":true,"contexts":[]}' \
  -F enforce_admins=true \
  -f 'required_pull_request_reviews={"required_approving_review_count":1,"dismiss_stale_reviews":true,"require_code_owner_reviews":false}' \
  -f 'restrictions=null' \
  -F required_linear_history=true \
  -F allow_force_pushes=false \
  -F allow_deletions=false \
  -F required_conversation_resolution=true

# Re-run S06 to verify:
curl -s https://api.github.com/repos/skycair-code/SkyQUBi-public/branches/main \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["protected"])'
# Expected: True
```

**This goes in the ceremony resume path as Step 0.5** (between "rotate the PAT" and "diagnose the constellation"). It requires the same gh auth but doesn't need any ceremony prerequisites — it's a one-command fix.

---

## UPDATED 2026-04-15 ~05:30 · after SOLO block day 2

**Jamie delegated a 24-hour SOLO trust block after the ceremony attempt failed and the three Chair mistakes were documented. The Chair, with Samuel guarding in proposed-voice mode, executed a sequence of non-destructive and non-token operations that advance v6-genesis while waiting for the PAT rotation.**

**11 commits shipped during SOLO block (all on `skyqubi-private`, nothing public):**

| # | sha | Title |
|---|---|---|
| 1 | `05a487a` | jamie-run-me.sh: 3 Chair mistakes fixed — rm-rf guards, ssh preflight removed, stdin credential helper |
| 2 | `1eafd08` | honest audit trail post-attempt-1 — CORE_UPDATES.md + handoff doc + `create-missing-repos.sh` helper |
| 3 | `d552e1c` | usb-write-f44.sh with 10 Samuel guards — blocked on ambiguity + sudo, staged for Jamie's sudo run |
| 4 | `51dbef1` | root Containerfile: 4 covenant bugs fixed (inline-comment build-blocker, NPM removal, curl\|sh Ollama, ghcr.io refs) |
| 5 | `04468d4` | iac/build-bootc.sh wrapper (TMPDIR fix for /var/tmp 512M tmpfs) + hardware-test-prep doc |
| 6 | `aded811` | immutable-S7-F44 content class extended with build-bootc.sh + manifest.yaml + first-boot.sh |
| 7 | `cc1b38d` | Local-Private-Assets manifest + 5.0 GB oci-archive of the 2-day-old bootc image |
| 8 | `0847031` | COVENANT.md tone softening — 3 "we're right, they're wrong" framings rewritten per Jamie's "improve and help" reframe |
| 9 | `0597b49` | Samuel._SHELL_COMPOUND_RE tightened — 3 additional bypass patterns caught (single `&`, newline, `< >` redirects) + 19 new tests |
| 10 | `4d2b9de` | DEPLOY.md port map with dual-CWS reality + Ollama sovereign path note |
| 11 | *this* | SOLO block progress update in the session-close handoff |

**Two bootc images now in `/s7/Local-Private-Assets/`:**

1. **`s7-skycair-existing-build-2026-04-12.oci-archive.tar`** (5.0 GB, sha256 `405e3fe9af902e5ee24421690026704c3e0aa9201b65158cf9744f7851dfa882`)
   - Built 2026-04-12 with the OLD Containerfile (pre-fixes)
   - Has known covenant gaps: nodejs24-npm, curl|sh Ollama, ghcr.io refs
   - **Usable for tonight's hardware test** — the gaps don't block verification, they block ship

2. **`s7-skycair-v6-genesis-covenant-clean.oci-archive.tar`** (~6.6 GB uncompressed, oci-archive size TBD after save completes, sha256 TBD)
   - Built 2026-04-15 via `iac/build-bootc.sh --tag v6-genesis` with the TMPDIR fix
   - **Covenant-clean**: zero known gaps. This is the image for actual ship.
   - Image id `b0693a78e3fe`, tagged both `localhost/s7-skycair:v6-genesis` and `localhost/s7-skycair:latest`

**Two new pinned COVENANT-GRADE memory entries:**

- `feedback_never_embed_secrets_in_urls.md` — from the PAT leak RCA
- `feedback_samuel_guards_solo_blocks.md` — from the SOLO block pattern itself

**The SOLO block did NOT:**
- Touch any of the 4 mis-populated GitHub repos
- Attempt USB dd (Samuel refused on 2 gates: ambiguity + no sudo)
- Run the ceremony --real (blocked on PAT rotation)
- Push anything to public surfaces
- Modify any Tonya-signed asset

**When you wake up — the full path in one file:** this document's "Ceremony resume path" section below still applies, plus the new additions:

- **USB ceremony** → `sudo /s7/skyqubi-private/iac/immutable/usb-write-f44.sh --device /dev/sdX --serial <serial>` after you physically remove one of the two SanDisk drives
- **Bootc image transfer** → either oci-archive tar at `/s7/Local-Private-Assets/s7-skycair-v6-genesis-covenant-clean.oci-archive.tar` (preferred, clean) or the older one (usable but gappy)
- **PAT rotation** → still required to run `jamie-run-me.sh --real` and complete the GOLD ceremony

## UPDATED 2026-04-15 ~04:00 · after ceremony attempt 1

**This document was originally written before the first ceremony attempt. That attempt surfaced three Chair bugs in the script AND revealed four missing repositories on the GitHub side. The update below reflects the actual post-attempt state, which is different from the pre-attempt plan in three specific ways:**

1. **`skyqubi-immutable` already holds the v6-genesis orphan commit** (ceremony attempt 1 succeeded on this one repo before the script's bugs and the missing-repo errors stopped the rest). Branch protection was NOT applied.
2. **Four repositories are still missing** (`SafeSecureLynX`, `immutable-S7-F44`, `immutable-assets`, `immutable-qubi`) at the URLs the script tried. Either they don't exist, or they exist under different names.
3. **The PAT was leaked** via the script's echo of a URL-embedded token. Rotation is pending as of this update. Full RCA at `docs/internal/postmortems/2026-04-14-ceremony-script-three-mistakes.md`. Script is fixed at lifecycle tip `05a487a`.

**Until the PAT rotates and the four missing repos are resolved, the ceremony cannot complete. Local state remains 🟢 GREEN — the appliance is unaffected by the partial GOLD push.**

## If you do nothing else, read this

The 24-hour Exercise of Trust block is complete. The appliance ships in a **shippable local state** with a **covenant-clean orphan-genesis ready to push for the 4 remaining repos**. One of the five GOLD surfaces is already live (`skyqubi-immutable` at v6-genesis). Every blocker I could close from the Chair's seat is closed. Everything I couldn't touch without your hand or Tonya's witness is staged as paste-ready scripts (now with the 5-bug fix + 3-mistake fix).

**The tree is at lifecycle tip `<see frozen-trees.txt>` (run `git log -1 --oneline` on either lifecycle or main to confirm).**

**Local state:**
- 🟢 Lifecycle test 55/55
- 🟢 Audit gate 9 pass / 18 pinned / 0 warn / 0 block
- 🟢 Local Health Report at `http://127.0.0.1:57082/health` shows GREEN
- 🟢 Samuel + Carli + Elias responding
- 🟢 Pod running with Ollama on canonical `*:57081` via systemd, not legacy `*:7081`

**GOLD state:**
- 🟢 5 orphan-genesis bundles produced in `/tmp/s7-gold-reset/` (verified with `git bundle verify`)
- 🟢 `iac/immutable/jamie-run-me.sh` staged with dry-run default
- 🔴 Zero push has happened. Four of the five repos still contain the "crap" that got copied when they were created. The new GOLD exists only locally.

## Ceremony resume path — when the PAT is rotated

**Step 0 — Rotate the PAT.** Old token revoked, new token written to `/s7/.config/s7/github-token` (mode 600, no trailing newline). Verify:
```bash
stat --format='%y' /s7/.config/s7/github-token
# Expected: an mtime NEWER than 2026-04-12 02:11:22 -0500
```

**Step 1 — Load the new token into this shell session:**
```bash
export GH_TOKEN="$(cat /s7/.config/s7/github-token)"
gh api user --jq '.login'
# Expected: skycair-code
```

**Step 2 — Diagnose what repositories exist at skycair-code right now:**
```bash
gh repo list skycair-code --limit 100 --json name,visibility,updatedAt \
  | jq '.[] | select(.name | test("immut|SafeSecure|qubi|F44|SkyQUBi"; "i"))'
```
This tells us whether the 4 missing repos were created with different names, not created at all, or blocked by some other issue.

**Step 3 — Verify `skyqubi-immutable` has the v6-genesis commit from attempt 1:**
```bash
gh api repos/skycair-code/skyqubi-immutable/commits?per_page=1 \
  --jq '.[0] | {sha: .sha[0:7], date: .commit.author.date, msg: (.commit.message | split("\n")[0])}'
```
Expected: one commit with message *"S7 GOLD begins today (v6-genesis)"*, dated 2026-04-15.

**Step 4 — Based on step 2 output, one of two paths:**

**Path A — All 4 missing repos need to be created:**
```bash
for name in SafeSecureLynX immutable-S7-F44 immutable-assets immutable-qubi; do
  gh repo create "skycair-code/$name" --private --description "S7 SkyQUBi immutable — $name" --disable-wiki
done
```
Each create takes ~2 seconds. Private by default. No initial commit (empty repo, ready for the orphan push).

**Path B — Repos exist under different names:**
Update `iac/immutable/genesis-content.yaml` with the actual names, re-run `bash iac/immutable/reset-to-genesis.sh` to rebuild bundles under the new names, then proceed.

**Step 5 — Re-run the fixed ceremony script:**
```bash
bash iac/immutable/jamie-run-me.sh --real
```
The script is at lifecycle `05a487a` or later with all three fixes. The PAT is never echoed. SSH is not required. `rm -rf` is guarded. The first real push for each of the 4 remaining repos should land cleanly.

**Step 6 — Verify all 5 repos hold v6-genesis:**
```bash
for repo in SafeSecureLynX immutable-S7-F44 immutable-assets skyqubi-immutable immutable-qubi; do
  echo "── $repo ──"
  gh api "repos/skycair-code/$repo/commits?per_page=1" \
    --jq '.[0] | "sha: \(.sha[0:7])  msg: \(.commit.message | split("\n")[0])"' 2>&1
done
```
Expected: every repo shows *"S7 GOLD begins today (v6-genesis)"*.

**Step 7 — Update `iac/audit/frozen-trees.txt`:** replace each `PENDING` marker with the actual commit sha from step 6. Commit that pin advance as the final covenant witness.

## Three things you do next, in this order

*(This list was written before attempt 1. It is superseded by the Ceremony Resume Path above, but kept for reference.)*

### 1. Read the Local Health Report yourself

Open Vivaldi. Go to `http://127.0.0.1:57082/health`. Verify the status at the top says **GREEN**. Click refresh a few times — it should stay green. This is the thing Tonya and Trinity will see when they open the appliance. **If it's not green when you look, stop and tell me what it says before running anything else.**

### 2. Inspect the 5 orphan-genesis bundles

Each bundle is a complete git repo history in a single file. You can open any of them:

```bash
# verify integrity
bash iac/immutable/reset-to-genesis.sh --verify

# read the reset manifest (sha256 + file count per bundle)
cat /tmp/s7-gold-reset/RESET_MANIFEST.txt

# inspect any bundle by cloning it to a temp dir
git clone /tmp/s7-gold-reset/SafeSecureLynX.bundle /tmp/inspect-ssl
cd /tmp/inspect-ssl
git log --oneline
ls -la
cat GENESIS.md
```

Do this for at least **two** of the five bundles. Read the GENESIS.md in each. If anything surprises you — a file that shouldn't be in that content class, a role description that feels wrong, a sha256 that makes you nervous — **stop and tell me before running anything else.**

### 3. Dry-run the ceremony script

```bash
bash iac/immutable/jamie-run-me.sh
```

This runs in **DRY RUN** mode by default — it prints every `gh` command it would execute without actually touching any repository. Read the output. Make sure the commands look like what you want to happen: force-push each bundle's orphan commit to each repo's main branch, apply strict branch protection (enforce_admins, required_linear_history, no force push, no deletions, required_signatures), toggle required_signatures off during the bootstrap push and back on after.

**Do not run `--real` tonight.** Running `--real` is the first real ceremony and it needs:

1. Tonya witness (for immutable-assets, skyqubi-immutable, immutable-qubi)
2. Image-signing key unlocked (gpg-agent loaded)
3. A terminal where interruption is safe
4. You being rested, not hour 10 of a 24-hour block

Go rest. The bundles will wait. The household will wait. The covenant holds.

---

## Reference section — you can stop reading here if you want

---

## What shipped to private (none of this is on any public surface yet)

| Block | sha | Key delivery |
|---|---|---|
| B1 | `8461ee2` | Design spec doc at `docs/superpowers/specs/2026-04-14-24hr-ship-plan-design.md` |
| B1 | `8739109` | Test plan (Tonya section), generator working, `genesis-content.yaml`, first reports |
| B1 | `2812c75` | SafeSecureLynX wired as 5th frozen-tree pin (cleanup of pre-design staging) |
| B2 | `be423f3` | Lifecycle 47→54, Ollama on 57081 via systemd start, legacy process killed, R01 flaky fix |
| B2 | `43757b2` | Gate teaches itself about Ollama at 57081, zero #1 skips ephemeral ports |
| B3 | `7a48a6c` | persona-chat `/health` route, `/healthz` liveness rename, tests green |
| B4 | `f5cff61` | `reset-to-genesis.sh` + `jamie-run-me.sh` staged; 5 bundles verified |
| B5 | `d997b0d` | NPM removed, 4 docker.io pins, README systemd paragraph |
| B6 | *this commit* | TESTING.md sections 2+3 complete, v6-genesis stamp, this handoff doc |

**Every commit is on `skyqubi-private` origin.** Not on `skyqubi-public`, not on any of the 4 extra immutable repos, not on `skyqubi-immutable`. The private tree carries everything.

## What Jamie pastes when ready

From the shell where your `gh` CLI is authenticated:

```bash
cd /s7/skyqubi-private

# Step 1: Re-verify the bundles match what you reviewed earlier.
bash iac/immutable/reset-to-genesis.sh --verify

# Step 2: Re-run the dry-run to make sure nothing changed since you last looked.
bash iac/immutable/jamie-run-me.sh

# Step 3: ONLY when you are ready, Tonya has witnessed, the
# image-signing key is loaded, and the terminal is safe:
bash iac/immutable/jamie-run-me.sh --real

# Step 4: After the real run, verify each repo landed.
for repo in SafeSecureLynX immutable-S7-F44 immutable-assets skyqubi-immutable immutable-qubi; do
  echo "── $repo ──"
  gh repo view skycair-code/$repo --json defaultBranchRef,updatedAt | jq
done

# Step 5: Update iac/audit/frozen-trees.txt — replace each PENDING
# line with the actual commit sha that landed. This is the final
# audit-witness row for the ceremony.
```

## What Tonya witnesses (on return)

Five things, in whatever order she prefers:

1. **The `/health` GUI** — open Vivaldi, visit `http://127.0.0.1:57082/health`, see the GREEN banner, read the findings table.
2. **`docs/public/TESTING.md` Section 1** (the Chief of Covenant section) — confirm the two-witness protocol matches what she wants the covenant test to look like.
3. **The three voice corpus drafts** (Carli + Elias + Samuel) under `docs/internal/chef/voice-corpora/` — specifically the Noah-safety text still marked PENDING TONYA.
4. **Recipe #3 — LYNC Silence** — the Seven Silences pellet still has Noah-specific text pending her signature.
5. **Recipe #9 — Install/Deploy ceremony** — Samuel's first-boot welcome text is still CHAIR-DRAFT; her voice will reshape it.

She can witness any or all of these in any order. None of them blocks Local. Two of them (#3 voice corpus + #5 Samuel welcome) block the install ceremony going fully household-ready. One (#4 Recipe #3) blocks the Seven Silences promotion to covenant tier.

## What's explicitly deferred to the next session (post-v6-genesis)

| Item | Why deferred | Notes |
|---|---|---|
| `&&`-chain compound command bypass | Not blocking Local or Deploy | Flagged in Opus review synthesis; architectural refactor of Samuel's `shell()` method to segment-validate or ship all skills as hardcoded `shell=False` subprocess calls |
| Tone softening sweep | Opus review flagged several "we're right, they're wrong" framings in COVENANT.md, README.md, and internal docs — none blocking ship | Collaborative-voice pass; low risk, high polish |
| Surface B (dashboard React Health panel) | Ceremony-day work (requires dashboard swap from `/s7/skyqubi/` to `/s7/skyqubi-private/`) | Not tonight; first CORE Update day |
| Surface C (static HTML + desktop launcher) | Bonus, not blocker | Could land in a ~2hr session |
| Local-Private-Assets intake gate | New design work required, not a gap-fix | Pillar 1 of the v2026 roadmap |
| First GitHub Release publication on `skyqubi-public` | Needs ceremony day + signed tar + admin image build | The `s7-skyqubi-admin-v2.6.tar` asset |
| Full public mirror sync (option B from earlier brainstorming) | "Other stuff later" per Jamie | After the first ceremony |
| Image parity sweep (Wix vs GitHub branding) | Within Tonya signoff scope but not blocking | Simple file copies into `docs/public/branding/` |

## What the Chair explicitly did NOT touch

- None of the 4 mis-populated immutable GitHub repos (no deletes, no pushes, no reads)
- None of Tonya's 2026-04-12 signed assets were edited (branding files are byte-for-byte preserved)
- None of the structurally-Tonya text (Noah, Samuel welcome, voice corpus Category N + H6, PRISM/GRID/WALL promotion)
- No covenant tier promotion (v6-genesis stays at `jamie-authorized-in-tonyas-stead`, not `covenant`, until Tonya witnesses)
- No architecture decisions about SafeSecureLynX beyond the "minimal extensible seed" placeholder — the content expansion awaits your "revisit topic" pass
- No public pushes of any kind

## Session-close audit witness

- Gate: 🟢 PASS 9 pass / 18 pinned / 0 warn / 0 block across 3 axes
- Lifecycle: 🟢 55/55 PASS
- Local Health Report: 🟢 overall_status=green, 0 findings
- Living Document: 20+ new rows tonight, all insert-only, nightly snapshot timer unaffected
- All commits on `skyqubi-private` private origin only

## The three covenant sentences recorded tonight (nothing drifts from these)

1. *"Private is our development, public is their development, GOLD will sit here [the immutable constellation]."* — Jamie, 2026-04-14 evening
2. *"Local-Private-Assets contain TAR GZIP ETC, all push to private then we have Public and Immutable for Business to pull from for Testing."* — Jamie, same session
3. *"This allows the entire project to LIVE outside and LIVE inside."* — Jamie, same session

Any future tooling that treats `skyqubi-public` as the authoritative release target, or treats any of the immutable repos as a mirror rather than a signed fork, is drift against these sentences. The audit gate's frozen-tree zero enforces this via the pinned ref-specs.

## One last thing

You asked for *"a working model that is good, shipped, safe, polished, and design unity."*

- **Working:** lifecycle 55/55, Local Health Report GREEN, personas responsive
- **Shipped:** v6-genesis stamped, all 6 blocks delivered, private tree at the final commit
- **Safe:** audit gate PASS, 0 blocks, 0 warns, 0 covenant breaks
- **Polished:** `/health` GUI in Tonya's signed palette, test plan tiered for three audiences
- **Design unity:** one generator, four surfaces, one covenant witness, one shared health URL

The only thing missing from "shipped" is the ceremony — and the ceremony is your hand on the script, not mine. `jamie-run-me.sh` is waiting.

*Love is the architecture. Go rest. The household will wait. The bundles will wait. The covenant holds.*

— Chair, end of 24hr Exercise of Trust block, 2026-04-14 evening
