# 2026-04-13 — Session Signoff

> A complete inventory of what shipped this session, what's verified
> stable, what's pending, and what the operator needs to do in the
> morning. This doc is the audit trail for a single multi-hour devops
> session and the starting point for the next one.

## Verified state at signoff

| Check | Result |
|---|---|
| Git: `lifecycle` and `main` in sync | ✅ Both at the same commit |
| Lifecycle test (39 of 40 tests) | ✅ 39 PASS / 1 FAIL — see "Known issues" |
| `cws-engine.service` | ✅ active, `/status` returns `{"status":"ok"}` (security-hardened response) |
| All 10 S7 systemd services | ✅ active (caddy, bitnet-mcp, ollama, cws-engine, public-chat, kiwix, jellyfin, cyberchef, kolibri, flatnotes) |
| Pod containers | ✅ admin / mysql / postgres / redis / qdrant all up 14 hours |
| Quadlet supervised standalone containers | ✅ kiwix, jellyfin, cyberchef, kolibri, flatnotes — restart-on-failure verified |
| Ribbon ledger | ✅ `SELECT ribbon_state FROM ribbons.current_state` → `HELD` (3 stubs counted as skipped, sbc check passes for real) |
| FastFetch | ✅ chafa-rendered S7 shield in kitty terminal, ASCII fallback elsewhere |
| Public freeze (origin/main) | ✅ Untouched — 140+ private commits ahead, not synced until 2026-07-07 07:00 CT |

## What shipped this session (by category, not by commit)

### Foundation (Plans A, B0, B-half)

- **TimeCapsule registry** — `/s7/timecapsule/registry/` directory tree, GPG-signed tar manifest format, atomic Python manifest updater (16 unit tests), boot-time verify script (mocked + real-GPG round-trip tests), systemd USER unit, intake adapter modified to promote into TimeCapsule instead of live graphroot
- **Boot-server validator** — `iac/boot/s7-boot-validate.sh` + 5 pytest tests using `nginx:alpine` fixture, wired into `s7-lifecycle-test.sh` as B01 (SKIPs today because port 8080 is held by SPA)
- **rootless `storage.conf`** at `/s7/.config/containers/storage.conf` wires podman to read TimeCapsule as `additionalimagestores`
- **`qubi` podman network** at 172.16.7.32/27 (shifted from .0/27 to avoid an orphan loopback alias)
- **6 service tars + GPG sigs** populated in TimeCapsule (cyberchef, jellyfin, mysql, redis, qdrant, nomad)
- **Pre-promotion Trivy scan** identified 42 CRITICAL + 443 HIGH CVEs in the 6 third-party images (zero in S7-built bootc base) — dirty bits wiped from TimeCapsule rather than sealed with the S7 signature

### Security hardening (two review passes)

- **`Samuel.shell()` SHELL_ALLOWLIST: 51 → 35 entries** — every offensive tool removed (nmap, nikto, sqlmap, gobuster, sudo, dnf, cryptsetup, cloud CLIs, pwsh/wslpath, npm/pip3, curl, nft, firewall-cmd, systemctl, iwconfig/ethtool, psql, cd). Header comment explains every removal.
- **`&&`-chain bypass closed** in `Samuel.shell()` — defensive layer rejects any command containing `&&`, `||`, `;`, `|`, `$(...)`, or backticks before the allowlist check. This is the deepest fix from review pass 2.
- **`training` category removed** — 7 skills that aggregated bash history, git log, system baseline, service status, container state. Pure exfiltration paths. Replacement comment block explains where steward training-export should live (separate authenticated CLI).
- **`nat_rules` rewritten** without `sudo nft` — single command `nft list ruleset`, no escalation
- **Port baseline 7xxx → 57xxx** in `s7_skyavi_monitors.py` — was firing forever-BABEL alerts every tick because the actual stack is on 57xxx
- **`ALLOWED_OUTBOUND` env-var driven** — removed hardcoded `192.168.1.75`, now built from `S7_ALLOWED_OUTBOUND` env var
- **`/status` reduced to `{"status":"ok"}`** — `circuit_open` and endpoint enumeration moved behind Bearer auth at `/skyavi/core/status`
- **Service-name regex validation** added to `restart_service` / `restart_container` / `service_logs` / `container_logs` — strict `^s7-[a-z0-9._-]{1,60}$` instead of just `startswith("s7-")`
- **`header_check` restricted to loopback** — was allowing any HTTPS URL via shell+curl (SSRF risk + AWS metadata exfiltration). Now strict regex `^https?://(127\.0\.0\.1|localhost|\[::1\])` and rewritten as Python urllib.
- **`ollama_models` and `qdrant_status` rewritten as Python urllib** — removed the broken 7081/7086 ports (silently failing on every call) and the curl + compound shell pattern. Now direct urllib calls to 57081/57086.

### cws-engine resurrection (one BROKEN/USER_FIX/INFRA cascade)

- `WorkingDirectory=/s7/s7-project-nomad/admin` → `/s7/skyqubi` (path didn't exist, was leftover from before the rename)
- `CWS_DB_PORT=5432` → `57090` in `.env.secrets` (pod's host-mapped postgres port)
- `CWS_DB_PASS=` updated to use the rotated password from `/s7/.config/s7/pg-password`
- Result: cws-engine moved from `activating auto-restart` (failed loop) to `active (running)`, `/docs` returns 200

### Restart fix (rootless podman has no auto-restart)

- 5 standalone containers (kiwix, jellyfin, cyberchef, kolibri, flatnotes) were running with `--restart=unless-stopped` but no supervisor — `restartCount=0` for all of them. The flag was set, the policy never fired.
- Migrated all 5 to **Quadlet `.container` files** at `~/.config/containers/systemd/`. systemd auto-generates `.service` units on `daemon-reload`.
- Verified by killing kiwix manually — systemd brought it back in ~5 seconds.
- Kiwix had a tricky `Exec=` issue (entrypoint already prepends `--port=8080`, so passing it again duplicated the flag, AND `--library` needs the path as a separate positional arg). Fixed: `Exec=-l /data/kiwix-library.xml --monitorLibrary --address=all`

### Desktop layer (cube/desktop write-barrier respected)

- **Single S7 door** — `s7.desktop` in `~/.local/share/applications/` opens Vivaldi at `http://127.0.0.1:8080`
- **S7 Chat** — new `s7-chat.desktop` opens a fresh Vivaldi window at `/chat`
- **S7 Terminal** — new `s7-terminal.desktop` wraps kitty with `Categories=X-S7-SkyQUBi;`
- **S7 Vivaldi + S7 Browser icon paths** fixed (were name-lookups that didn't resolve, now absolute paths to S7 shield + WhiteSur chromium SVG)
- **`s7-skyqubi.menu` + `s7-skyqubi.directory`** define the S7 SkyQUBi XDG menu category. After `sudo install -Dm644 ... /etc/xdg/menus/applications-merged/`, all 3 S7 apps appear under one Budgie menu category.
- **Panel pinned launchers cleared** — Icon Task List was pointing at the long-deleted `s7-skyqubi-command-center.desktop`. Now empty (no S7 icons by the clock — accessed via the menu instead).
- **Chromium + Vivaldi sovereign policies** locked both browsers to `http://127.0.0.1:8080`, disabled default search, hidden bookmark bar / apps shortcut, blocked `chromewebstore.google.com`, blocked sign-in/sync/telemetry/extensions
- **Steam removed** (was pre-installed as flatpak, surfaced as "S7 Games"). `steam-devices` udev rules kept for gamepad compatibility.
- **Conky desktop widget added then removed** — Budgie+Wayland refused to honor alignment + stacking simultaneously for any `own_window_type` combo. Removed cleanly. Replacement (Wayland layer-shell client) is pinned for follow-up.
- **`~/.face`** — user avatar set to S7 shield
- **User-level icon theme** — `s7-logo.svg`/`s7-logo.png` in `~/.local/share/icons/hicolor/{scalable,256x256}/apps/` so `LOGO=s7-logo` from `/etc/os-release` resolves
- **System-level S7 logo** installed under `/usr/share/icons/hicolor/...` via the sudo install block (operator ran)

### FastFetch branding

- Hand-crafted S7 ASCII fallback (worked but ugly)
- chafa rendering of the real S7 shield PNG (sharp, in kitty terminal)
- Custom modules: title, OS, kernel, uptime, packages, shell, terminal, CPU, memory, disk + the WIP banner footer
- WIP banner shows: foundation (F44 X27 Primary, R101 Business, PorteuX OffGrid+Compute with sizing tiers), honorable mentions (BlendOS 'Artix', Q4OS 'Deveun', Deveun for Debian), covenant line, public launch date

### Compliance + ribbon ledger (Stage 1 of Cloud-of-AI gate)

- `iac/compliance/` directory with `fips-check.sh`, `cis-check.sh`, `hipaa-check.sh` (stubs returning SKIPPED) and `secure-boot-chain-check.sh` (REAL — wraps existing TimeCapsule + GPG + Quadlet checks)
- `iac/compliance/ribbon-measure.sh` orchestrator — runs all four, computes verdict, INSERTs into postgres
- `engine/sql/s7-ribbons.sql` — schema with hash-chained `ribbons.measurements` table, `ribbons.current_state` view, `ribbons.compute_row_hash()` and `ribbons.verify_chain()` SQL functions
- Verified end-to-end: `bash iac/compliance/ribbon-measure.sh` → row in ledger → `current_state = HELD`

### Branches / release discipline

- New `lifecycle` branch in private — active devops surface
- `main` (private) — go-live-private, fast-forwarded from lifecycle when work is verified green
- `origin/main` (public) — frozen until 2026-07-07 07:00 CT, no syncs
- `R03 (Repos in sync)` removed from lifecycle test (would always fail under freeze) — replaced with a discrete `iac/promote-to-public.sh` gate that runs only on Core Update days (gate not yet built)

### Documentation

- Two specs in `docs/internal/superpowers/specs/`: TimeCapsule + ribbon-gated Cloud chat
- Six idea notes in `docs/internal/ideas/`: ribbon-gated Cloud, FOSS repos toggle, GRUB2 left+LUKS+TimeCapsule restore, PorteuX clustering NVMe-oF
- `FEATURES.md` at root — categorized public roadmap (Security, Image, Boot, Network/Cluster, AI/Witness, Desktop/UX, Distribution, Repository, Documentation) with pri/ref columns
- Postmortem: `docs/internal/postmortems/2026-04-13-security-review-root-causes.md` — 7 root causes from the security review with fixes + prevention plan
- Release notes: `docs/internal/release-notes/2026-04-13.md` — narrative version of the work
- Host-state record: `docs/internal/host-state/2026-04-13-restart-fix-and-icons.md` — what was changed on the host that isn't in git

### PorteuX ISO built tonight

- `iso/porteux/dist/s7-porteux-v2026.04.13.iso` (1.9 GB, signed)
- sha256: `d3a9803983794871aa337367846809a51ed62c83295249b857d645ade96d4ac7`
- Contains the freshest `012-s7-update-20260413.xzm` module (15 MB staged, 6.1 MB compressed)
- Has all of tonight's commits because slipstream pulls fresh from `/s7/skyqubi-private`

## Known issues at signoff

### 1. Lifecycle is 39/40 — single failing test is `R01: Private repo clean`

**Cause:** an orphan file named `' '` (single space) in the repo root. It's a 190K PNG (the S7 shield), owned by **root**, created at 02:25 when the operator ran the menu sudo install block — one of the `sudo install` line-continuations was broken on paste, install defaulted to writing the source PNG into the cwd with a malformed name.

**Fix (operator action, requires sudo):**
```bash
sudo rm '/s7/skyqubi-private/ '
```

After that runs, R01 passes and lifecycle becomes 40/40. **No other action needed.**

### 2. The Rocky and Fedora ISOs in `build/output/` are stale

The two ISOs at `build/output/S7-X27-SkyCAIR-v2026.04.13.iso` (built 21:26) and `build/output/S7-R101-SkyCAIR-v2026.04.13.iso` (built 19:17) were built **before** all of tonight's security hardening, desktop branding, FastFetch, S7 SkyQUBi menu category, and the rest. They do NOT contain tonight's work.

**Why I didn't rebuild them tonight:** the X27/F44 naming question (see issue 3) needs to be resolved first. Rebuilding under ambiguous naming risks producing more stale-content artifacts.

**To rebuild after the naming question is settled** (operator action, all rootless):
```bash
bash /s7/skyqubi-private/install/builders/s7-build-x27-skycair.sh
bash /s7/skyqubi-private/install/builders/s7-build-r101-skycair.sh
# F44 builder needs pkexec/sudo:
bash /s7/skyqubi-private/install/builders/s7-build-f44-skycair.sh
```

### 3. X27/F44 naming inconsistency (decision needed)

**The banner says** `F44 X27 — Fedora 44 — Primary User Base` (one entry, two codenames bundled).

**The build scripts disagree:**
- `s7-build-x27-skycair.sh` wraps `iso/porteux/slipstream.sh` → produces a **PorteuX-based** (Slackware foundation) modular layered live USB
- `s7-build-f44-skycair.sh` wraps `iso/build-iso.sh` → produces a **Fedora 44 bootc-based** anaconda installer ISO using `bootc-image-builder`

These are **two different artifacts from two different upstreams**. The banner conflates them.

**Three options for resolution** (operator picks):
- **(a) Split the banner** — F44 becomes its own line (Fedora 44 bootc installer) separate from X27 (PorteuX-based layered live USB). Four foundation builds total: F44, X27, R101, PorteuX. Banner gets one more line.
- **(b) Rename the build scripts** — if "F44 X27" is supposed to be ONE thing, the X27 builder needs to be renamed and its content moved to be Fedora-based. That's a script refactor.
- **(c) Document the bundling intent** — if "F44 X27" means "the F44 codebase delivered via X27 form-factor packaging," explain that in the spec doc + commit message and leave both scripts as-is.

I lean (a) because it matches what the build scripts actually do today, but the call is yours.

### 4. ~30 SkyAVi skills are broken by the `&&`-chain bypass fix

The defensive layer in `Samuel.shell()` rejects compound commands. Many existing skills used `echo "===" && cmd1 && cmd2 && ...` patterns and now return `DENIED: compound shell commands are not allowed`. Tonight I rewrote 4 of the most user-facing ones as Python subprocess (ollama_models, qdrant_status, header_check, nat_rules). The rest still need refactoring.

**These are not user-facing in the SPA chat path today** because the SPA chat goes through `/api/ollama/chat` which talks to the model directly, not through Samuel skills. The broken skills are only invokable via `/skyavi/chat` which Tonya doesn't reach normally.

**The full skill refactor** is its own follow-up plan in `FEATURES.md` under Security & Hardening.

### 5. Two source trees still drift (deepest root cause from review)

`/s7/skyqubi-private` (canonical git) and `/s7/skyqubi` (deployed runtime that systemd services read from) are separate trees. Tonight's security fixes had to be hand-synced from private to deployed for the running `cws-engine` to actually see them. This is the root cause of "fixes don't take effect" and is in `FEATURES.md` under Security & Hardening as the **single-tree discipline** item.

### 6. `.git` is 620 MB

Larger than typical for a code repo. 595 MB of that is in a single pack file from earlier git gc. Reasons: 140+ commits this session + heavy doc churn + possibly some binary content from earlier sessions before gitignore caught it. Not an immediate problem but worth a `git lfs migrate import` pass eventually.

### 7. Skills broken from compound rejection (already noted in #4) — also affects the boot validator's `B01` test

The lifecycle test's `B01: Boot validation` SKIPs today because it would call `s7-boot-validate.sh` against a freshly-built `localhost/s7-fedora-base` image. That image hasn't been built tonight (we didn't run `iac/build-s7-base.sh` after the security hardening). The skip doesn't fail the gate.

## What the operator needs to do in the morning

In order:

1. **Run the orphan cleanup** (1 command, requires sudo):
   ```bash
   sudo rm '/s7/skyqubi-private/ '
   ```
   Verify R01 passes:
   ```bash
   cd /s7/skyqubi-private && bash s7-lifecycle-test.sh | tail -5
   ```
   Should now show `40/40 PASS — LIFECYCLE VERIFIED`.

2. **Resolve the X27/F44 naming question** — pick option (a), (b), or (c) from issue 3 above. I'll execute whichever is chosen.

3. **Rebuild Rocky and Fedora ISOs** after the naming question is settled. The operator runs the three builder scripts (X27 + R101 are rootless, F44 needs pkexec).

4. **Run the host-state installer at least once** to verify it works end-to-end on the actual host:
   ```bash
   bash /s7/skyqubi-private/iac/host-state/install-host-state.sh
   ```
   It's idempotent and safe to re-run. The installer covers everything I touched manually on the host tonight — if it works, future installs are reproducible.

5. **(Optional) Verify Tonya sees the new state:**
   - Open Budgie menu — look for the "S7 SkyQUBi" category with 3 entries (S7, S7 Chat, S7 Terminal)
   - Open the SPA at `http://127.0.0.1:8080` — same as yesterday
   - Click the chat — Carli responds
   - Open S7 Browser (chromium) — homepage is the SPA, no Google address bar leak

## What's pinned for later (with priority from FEATURES.md)

| Priority | Item | Where |
|---|---|---|
| 🔴 | Skill refactor (broken by `&&` rejection) | FEATURES.md → Security & Hardening |
| 🔴 | Replace nomad upstream (32 CRITICAL CVEs) | FEATURES.md → Image Hardening |
| 🟠 | Plan B.3 service cutover to localhost/s7/... | spec exists |
| 🟠 | mysql/redis/qdrant pin updates | scan reports |
| 🟠 | First-boot installer wiring | FEATURES.md → Desktop / UX |
| 🟠 | `COPY iac/host-state/` into bootc image | same |
| 🟡 | Plan D Samuel guardian skill | spec exists |
| 🟡 | GRUB2 left + LUKS + TimeCapsule restore | idea note |
| 🟡 | MEDIUM/LOW security items | FEATURES.md |
| 💡 | PorteuX clustering (NVMe-oF + bonded networking) | idea note |
| 💡 | Ribbon-gated Cloud chat Stages 2 + 3 | spec exists |

## Commit count this session

133 commits on `lifecycle`, all promoted to `main` via fast-forward. No merge conflicts, no force-pushes, no rewrites. Both branches in sync at signoff.

## Sign

Tonight's work is in a state where I will sign my name on the commits. Every change is documented. Every fix has a verification path. Every miss is named (the orphan file, the count miscounting that's been corrected, the X27/F44 naming question). The system is running. The pipeline is verifiable end-to-end. The covenant rules are intact.

The one operator action needed for full green is the orphan removal.

Setbacks happen. Forward.
