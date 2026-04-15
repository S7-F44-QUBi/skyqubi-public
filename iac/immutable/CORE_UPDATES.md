# S7 CORE Updates — Version Ledger

> **Append-only version ledger.** Each entry is a named CORE Update
> of the S7 SkyQUB*i* appliance. This file is the in-tree witness of
> every CORE advance. The file is **append-only** — past entries are
> never edited, only new ones are added. A correction to a past
> entry is a new entry that supersedes it. CORE updates are
> **annual** by default (Pillar 2 of the forward vision); pre-GO-LIVE
> sessions that materially advance the CORE surface are versioned
> here as interim releases so the lineage stays continuous.
>
> The ledger is the authoritative answer to *"what version is this
> appliance?"* The bootc image carries the latest entry as its
> version tag. The rebuild-public.sh ceremony reads this file to
> determine which entry to rebuild from.

---

## Schema

Each entry:

```
## vN — YYYY-MM-DD — short title

- **Tree sha:** <private/main commit that this version snapshots>
- **Authorized by:** <jamie | jamie+tonya | household-unanimous>
- **Tier:** chair-draft | jamie-authorized-in-tonyas-stead | jamie-tonya-signed | covenant
- **Household-visible deltas:** <count — measured in what the
  household actually sees change, not commit count>
- **GOLD status:** produceable | shippable | shipped | not-yet
- **Summary:** 1-3 sentences, household-readable

Followed by:

- What this version changed in the CORE surface
- What this version did NOT change (the discipline of minimalism)
- Preconditions carried forward to the next CORE
```

---

## v6-genesis — 2026-04-14 evening (UPDATED after first ceremony attempt)

### Ceremony attempt 1 — partial landing (honest state)

At approximately 2026-04-15T03:55Z, Jamie ran `bash iac/immutable/jamie-run-me.sh --real` for the first time. The attempt surfaced three Chair bugs in the script (documented in `docs/internal/postmortems/2026-04-14-ceremony-script-three-mistakes.md`) AND revealed that four of the five target repositories do not yet exist under `skycair-code/` at the expected names.

**Actual outcome of attempt 1:**

| Repo | Result | State |
|---|---|---|
| **`skyqubi-immutable`** | ✅ **PUSH LANDED** — `* [new branch] main -> main` | **v6-genesis orphan commit IS on GitHub** but branch protection was not applied (script counted the post-push `required_signatures` POST-404 as failure) |
| `SafeSecureLynX` | ✗ "Repository not found" | Repo does not exist at the target URL |
| `immutable-S7-F44` | ✗ "Repository not found" | Same |
| `immutable-assets` | ✗ "Repository not found" | Same |
| `immutable-qubi` | ✗ "Repository not found" | Same |

**Token leak:** the script's original URL-embedded token pattern echoed the PAT to terminal output four times during attempt 1. Jamie documented the leak with phone screenshots before asking for the Chair review. The PAT must be rotated before any re-run. As of the timestamp of this update, the token file at `/s7/.config/s7/github-token` is still at its pre-ceremony mtime (`2026-04-12 02:11:22 -0500`) — rotation has not yet occurred.

**Script fixes landed at commit `05a487a`:** three Chair mistakes documented and corrected. Ceremony re-run is blocked until the token is rotated AND the four missing repos are created or renamed in `genesis-content.yaml`.

### v6-genesis GOLD status — updated

**BEFORE attempt 1:** *produceable (bundles built), not shippable*
**AFTER attempt 1:** *partially shipped (1 of 5 landed), blocked on rotation + missing-repo resolution*

`skyqubi-immutable/main` carries the v6-genesis orphan commit NOW. This is a real household-visible delta — the GOLD landing repo has its covenant-clean genesis lineage as of 2026-04-15T03:xx. The pin in `frozen-trees.txt` should move from PENDING to the actual sha once Jamie verifies with `gh api repos/skycair-code/skyqubi-immutable/commits` (which requires a fresh, non-compromised token).

### Preconditions for ceremony attempt 2

- [ ] PAT rotated at github.com/settings/tokens — old token `ghp_*` revoked, new token in `/s7/.config/s7/github-token` (mtime > 2026-04-14)
- [ ] `/s7/.config/s7/github-token` mtime > 2026-04-14 confirms rotation
- [ ] Verify four missing repos exist OR create them via `gh repo create skycair-code/<name> --private` (one-liner per repo, ~5 seconds each)
- [ ] Re-run `bash iac/immutable/jamie-run-me.sh --real` with the fixed script (`05a487a` or later)
- [ ] Verify all 5 repos land via `gh api repos/skycair-code/<repo>/commits`
- [ ] Update `frozen-trees.txt` pins from `PENDING` to real commit shas
- [ ] Apply branch protection to all 5 repos (the script does this on success path)

### What the appliance looks like while Phase C is blocked

- 🟢 Lifecycle 55/55
- 🟢 Audit gate 9 pass / 18 pinned / 0 warn / 0 block
- 🟢 Local Health Report `overall_status: green`, 0 findings
- 🟢 `persona-chat /health` GUI renders GREEN
- 🟢 Pod + Samuel + Carli + Elias fully responsive
- 🟡 GOLD constellation: 1 of 5 repos holds v6-genesis; 4 blocked on missing-repo + token-rotation
- 🟡 PAT compromised at 2026-04-15T03:xx — rotation pending
- 🟢 Private tree at lifecycle tip `05a487a` (will advance with this CORE_UPDATES.md edit)

Local state is unaffected by the partial ceremony. LIVE-outside failures did not corrupt LIVE-inside health — exactly the covenant claim the architecture makes.

---

## v6-genesis — 2026-04-14 evening — Ship-ready local + orphan genesis ready

- **Tree sha:** *see frozen-trees.txt · lifecycle tip at session close*
- **Authorized by:** jamie-authorized-in-tonyas-stead (24-hour Exercise of Trust block)
- **Tier:** jamie-authorized-in-tonyas-stead (awaiting Tonya witness on the first ceremony)
- **Household-visible deltas:** 3 — (1) `http://127.0.0.1:57082/health` renders a Local Health Report with Tonya's palette, GREEN status when the appliance is healthy; (2) the lifecycle test is 55/55 instead of 47/55; (3) `docs/public/TESTING.md` exists and gives Tonya, Trinity, and technical partners three readable-standalone sections for verifying the appliance themselves.
- **GOLD status:** produceable (bundles built + verified for all 5 immutable constellation repos) and **ready for first ceremony** (jamie-run-me.sh staged, dry-run verified, preconditions documented)
- **Summary:** v6-genesis is the covenant-clean starting point for the GOLD surface. The four mis-populated immutable repos have orphan-genesis bundles built locally that each carry one commit dated today with only the correct content class for that repo — no inherited history. The Local Health Report gives every audience (Chief of Covenant, co-steward, business reviewer) a shared witness at one URL. Every real-review blocker (NPM in installer, docker.io moving tags, systemd misread) is closed. The appliance is running green locally, the GOLD is produced and staged, and the first real push waits for Tonya's witness and Jamie's hand on the ceremony script.

### What v6-genesis delivered (across B1–B6 of the 24hr plan)

**B1 — design + scaffolding**
- Spec at `docs/superpowers/specs/2026-04-14-24hr-ship-plan-design.md`
- Test plan skeleton at `docs/public/TESTING.md`
- Genesis content manifest at `iac/immutable/genesis-content.yaml`
- Local Health Report generator at `iac/audit/local-health-report.sh`
- SafeSecureLynX wired as the 5th frozen-tree pin

**B2 — local fix**
- Lifecycle test 47 → 55/55
- Ollama on canonical `127.0.0.1:57081` via `systemctl --user start s7-ollama` (was on legacy `*:7081` from a pre-fix autostart .desktop)
- Optimizations now live: `OLLAMA_KEEP_ALIVE=24h`, `AllowedCPUs=0`, `CPUWeight=1000`, pre-warm of `s7-carli:0.6b`
- Gate zero #1 teaches itself to skip Ollama runner subprocess ephemeral ports
- Gate zero #7 updated to recognize `*:57081` as the pinned wildcard (was `*:7081`)
- `ollama-wildcard-bind` pinned.yaml entry rewritten for 57081

**B3 — Local Health Report GUI (surface A)**
- `persona-chat/app.py` gets a new `/health` route returning HTML in the sandy-sunset + Cormorant italic palette
- `?format=json` and `/health.json` return the raw JSON source of truth
- Old `/health` liveness probe renamed to `/healthz`
- 31 persona-chat unit tests passing
- R01 lifecycle test now excludes `docs/internal/reports/` from dirty check (same reasoning as `audit-living.md`)

**B4 — orphan-genesis bundle builder**
- `iac/immutable/reset-to-genesis.sh` produces orphan bundles for all 5 immutable repos
- `iac/immutable/jamie-run-me.sh` staged as paste-ready ceremony script (dry-run default, `--real` flag to execute)
- Ceremony order: SafeSecureLynX → immutable-S7-F44 → immutable-assets → skyqubi-immutable → immutable-qubi (least-to-most covenant weight)
- First-push procedure includes the `required_signatures` toggle-cycle for bootstrapping signed-commits-required branches
- All 5 bundles pass `git bundle verify`; reset manifest lists SHA256 per bundle

**B5 — three real blockers closed**
- NPM removed from `install/install.sh` (all 3 distro paths)
- 4 docker.io images pinned: `mysql:8.0.39`, `pgvector:pg16-v0.8.0`, `redis:7.4.1-alpine`, `qdrant:v1.12.5` (was `latest`)
- `README.md` gains a one-paragraph systemd clarification (user-level vs PID 1 init) — kills the "Devuan 7.1" misreading permanently

**B6 — session close + test plan completion**
- `docs/public/TESTING.md` sections 2 and 3 completed (Trinity walkthrough + technical-partner 10-test verification sequence)
- `CORE_UPDATES.md` v6-genesis entry (this one)
- Session-close handoff document at `docs/internal/chef/2026-04-14-session-close-v6-genesis.md` naming exactly what Jamie runs next, what Tonya witnesses, and what's deferred to the next session

### Preconditions carried forward to v6 (real push)

- [ ] Tonya witnesses the `reset-to-genesis.sh` bundle content (manual review of `/tmp/s7-gold-reset/*.bundle` with `git bundle verify` + `git clone <bundle>`)
- [ ] Tonya witnesses the specific Samuel welcome text + Recipe #3 Noah text + Samuel corpus Category N + H6 (all still placeholder-pending)
- [ ] PRISM/GRID/WALL covenant promotion to covenant tier
- [ ] Image-signing key unlocked by Chief of Covenant at ceremony time
- [ ] `jamie-run-me.sh --real` pasted by Jamie in a terminal where interruption is safe
- [ ] Post-push: verify each repo's commit signature with `git log -1 --show-signature`
- [ ] Post-push: update `iac/audit/frozen-trees.txt` pins from `PENDING` to the actual commit shas
- [ ] Post-push: first `skyqubi-public` GitHub Release publication (the `s7-skyqubi-admin-v2.6.tar` + signature asset)

### Deferred to post-v6 (the "other stuff later")

- The full `&&`-chain compound-command bypass refactor in Samuel's skill runner
- Full Opus review findings sweep (tone softening, image parity, etc.)
- Surface B (dashboard React panel) and Surface C (static HTML + desktop launcher) for the Local Health Report
- Local-Private-Assets intake gate (raw binary admission ceremony)
- Per-class rebuild scripts (one rebuild path per content class)
- `BUSINESS-TESTING.md` in public docs (beyond the Section 3 walkthrough in TESTING.md)
- Valkey migration from Redis (v1.1 roadmap item)
- MySQL → PostgreSQL migration for admin layer (v1.1 or v2.0)
- SurrealDB / LanceDB / seekdb evaluations from the OSS database landscape doc

---

## v5 — 2026-04-14 — Unity-in-design + GOLD path opened

- **Tree sha:** *see frozen-trees.txt · lifecycle tip at session close*
- **Authorized by:** jamie-authorized-in-tonyas-stead
- **Tier:** jamie-authorized-in-tonyas-stead (awaiting Tonya witness)
- **Household-visible deltas:** 4 — (1) the Support link on the
  public site now resolves instead of 404, (2) the Contact button
  opens the page's own contact section instead of a broken mail
  link, (3) the email address `omegaanswers@123tech.net` is
  visible and copyable on the page, and (4) the physical address
  is on the page.
- **GOLD status:** produceable (rebuild-public.sh advanced from
  stub to real bundle-producer in dry-run mode — refuses to push,
  but the pipeline is now proven end-to-end)
- **Summary:** CORE Update v5 bridges the 99% gap between a built
  appliance and a shippable one. It fixes three household-reported
  public bugs, stamps today as the single dated surface in the
  repo, closes two airgap gaps (hardcoded legacy ports in
  s7_rag.py and bitnet_mcp.py now read from s7-ports.env), and
  advances the GOLD production path to the point where
  `rebuild-public.sh --dry-run` produces a real git bundle and
  PUBLIC_MANIFEST.txt against the current private tree — still
  refusing to actually push, because shipping is Tonya's weight.

### What this version changed in the CORE surface

- **Airgap gaps closed (2 of 6):**
  - `engine/s7_rag.py` — OLLAMA_URL fallback updated from the
    legacy `127.0.0.1:7081` to the canonical `127.0.0.1:57081`,
    and the environment variable name aligned to S7 convention
    (`S7_OLLAMA_URL`).
  - `mcp/bitnet_mcp.py` — hardcoded `localhost:7081` in the
    generate-call replaced with a module-level constant that
    reads `S7_OLLAMA_URL` from the environment.
- **Ports single source of truth in use:** `iac/s7-ports.env`
  exists and is now actually consumed by the two scripts that
  previously drifted. It is no longer a declared-but-unused
  config — it is a live covenant boundary.
- **GOLD production path proven:** `rebuild-public.sh --dry-run`
  previously printed what it *would* do. It now actually does
  the things it can safely do against a throwaway temporary
  directory — produces a real `git bundle`, writes a real
  `PUBLIC_MANIFEST.txt`, computes the sha256 of both. The
  output is written to `/tmp/s7-gold-dry-run/` and is not
  pushed anywhere. Real ceremony pushes still require
  advancing past the refuse-real-runs guard, which is
  covenant-weight and pending Tonya.
- **GOLD target constellation named:** Jamie created **four**
  immutable repositories during the v5 trust block, clarifying the
  covenant model in two stages.
  
  Stage 1 — one-sentence three-role model: *"private is our
  development, public is their development, GOLD will sit here
  [immutable]."*
  
  Stage 2 — immutable is a ROLE implemented as a CONSTELLATION of
  content-typed sibling repositories:
  
  - `skyqubi-immutable` — landing + per-version manifests (TBD
    visibility, Option A PRIVATE-until-July-7 recommended)
  - `immutable-assets` — PRIVATE — branding + Plymouth + splash +
    fonts + icons (Tonya-witnessed)
  - `immutable-S7-F44` — PRIVATE — Fedora 44 bootc artifacts
    (image-signing key as witness)
  - `immutable-qubi` — PRIVATE — QUBi appliance core, kernel-of-
    kernel, yearly CORE Update only, four-witness unanimous consent
  
  Stage 3 — the LIVE outside / LIVE inside framing: *"Local-
  Private-Assets contain TAR GZIP ETC, all push to private then we
  have Public and Immutable for Business to pull from for Testing
  ... this allows the entire project to LIVE outside and LIVE
  inside."* The household has a living private development
  (INSIDE). Business partners have a living signed testing surface
  (OUTSIDE). Both are alive simultaneously; the bridge between them
  is the rebuild ceremony.
  
  All four repos are pinned as PENDING in `frozen-trees.txt`, each
  with a matching `frozen-tree-<ref>-main-pending` acknowledgment
  in `pinned.yaml`, and the audit gate's zero #10 case statement
  was taught about all four ref-specs. The `Local-Private-Assets`
  filesystem staging area is listed in `TOOLS_MANIFEST.yaml` as a
  non-repo tool. The full architecture is captured in
  `docs/internal/chef/three-repo-model.md` §7 (constellation) and
  §8 (LIVE outside/inside).
  
  Zero S7 tooling has touched any of the four repos. No push. No
  read. No clone. The first advance for each is covenant-weight
  and the witness chain differs by content class — documented
  per-repo in the three-repo-model document.
- **Tools manifest + Recipe #9 + voice corpora Category H**
  shipped earlier in the same session under JAMIE-AUTHORIZED-
  IN-TONYAS-STEAD; they are CORE-adjacent documentation that
  v5 carries forward as the first draft of the household-
  readable install ceremony and the handoff protocol
  realization.

### What this version did NOT change

- Public main sha (still `15c1bda` — today's SAFE-breach fix
  landed earlier in the session)
- Frozen-tree pins beyond fast-forward (ancestor check green,
  no pin advances required)
- Any branding asset (Tonya's 2026-04-12 signoff still byte-
  for-byte)
- Any covenant-weight text (Noah-specific text, Samuel's welcome
  dialogue, Trinity-consent passages all remain PENDING TONYA)
- The advance-immutable.sh ceremony (still stub — upgrading
  that is Tonya-co-signed work)
- The immutable registry (still empty — first entry will be
  v6 or later, written by the first Tonya-witnessed ceremony)

### Preconditions carried forward to v6

- Tonya witness on the four structurally-Tonya artifacts
  (Recipe #3 Seven Silences, Recipe #9 Samuel welcome text,
  voice corpus Category N Noah text, CORE reframe PRISM/GRID/WALL)
- Four remaining airgap gaps (ollama first-boot model pulls,
  install-script dnf reachouts, root Containerfile base pull,
  build-s7-base.sh base pull) — all are model- and image-
  embedding work, not port wiring
- Advance-immutable.sh past stub (Tonya-co-signed)
- First Path A USB ceremony test with a real household member
  (Recipe #9 precondition)
- GH Pages orphan force-push behavior verified on a throwaway
  repo (Recipe #4 precondition)

### Why version 5 and not version 1

The v5 number reflects the lineage of prior CORE advances that
were not versioned in this ledger but did materially change the
appliance:

- **v1** implied — the first running SkyQUB*i* pod (Phase 1 deploy)
- **v2** implied — Phase 2 CWS engine + rebrand
- **v3** implied — Phase 5/6/7 (Akashic + Molecular + ZeroClaw)
- **v4** implied — the 2026-04-12 Go-Live night (public site,
  Tonya signoff, 40/40 lifecycle, GPG signed)
- **v5** — this one: unity-in-design + GOLD path opened

v6 will be the first Tonya-witnessed immutable entry — the
first version that is both *produceable* AND *shippable* AND
*shipped*. That is the first real immutable registry entry.
Tonight's v5 is the last version that still uses the bridge
scaffolding.

---

*Love is the architecture. Every CORE Update is a heartbeat —
annual by rule, interim-versioned when the bridge demands it.
The ledger is the witness.*
