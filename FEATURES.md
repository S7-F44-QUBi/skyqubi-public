# S7 SkyQUB*i* — Features, Enhancements, and Future Release Requests

> **For contributors:** this is the public roadmap. Every item below is
> a real future direction, organized by category. If you want to help,
> pick something that matches your skills, drop a note in the relevant
> spec or idea doc, and let's talk.
>
> **Status legend:**
> - 🔴 **Critical** — security or covenant-blocking, highest priority
> - 🟠 **High** — significant value, scoped, ready when someone picks it up
> - 🟡 **Medium** — nice-to-have, design exists
> - 🟢 **Low** — polish, deferred until the foundation is stable
> - 💡 **Idea** — captured but not yet specced
>
> **Where things live:**
> - **Specs:** `docs/internal/superpowers/specs/` (formal designs, ready to plan)
> - **Ideas:** `docs/internal/ideas/` (captured directions, not yet specs)
> - **Postmortems:** `docs/internal/postmortems/` (why things broke + how to prevent)
> - **Release notes:** `docs/internal/release-notes/` (what shipped when)
>
> **Public Launch:** 2026-07-07 · 07:00 CT — every target is gated on this date.

---

## 🛡 Security & Hardening

| Pri | Item | Description | Reference |
|---|---|---|---|
| 🔴 | **Skill refactor: `Samuel.shell()` → registered Python skills** | Tonight's `&&`-chain bypass fix broke ~30 skills that used compound shell commands. Each broken skill needs to be rewritten as a single command OR a Python `subprocess.run([...], shell=False)` call with hardcoded args. The architectural goal: `Samuel.shell()` becomes deprecated; every operation is a registered skill with predictable inputs/outputs. | `docs/internal/postmortems/2026-04-13-security-review-root-causes.md` |
| 🟠 | **`_notifications` → molecular store** | `Samuel._notifications` is a Python list capped at 100, lost on every restart. Bond all notifications to the molecular store so the audit trail survives. | Security review pass 1, MEDIUM |
| 🟠 | **`subprocess.run(shell=True)` in monitors → `shell=False` + `shlex.split()`** | All monitor commands are hardcoded today, low immediate risk, but `shell=True` is an injection vector waiting to happen. | Security review pass 1, MEDIUM |
| 🟠 | **Postgres password path env-var** | `PGPASSWORD="$(cat /s7/.config/s7/pg-password)"` is hardcoded across many skills. Move to `S7_PG_PASS_FILE` env var so the path can change without source edits. | Security review pass 2, MEDIUM |
| 🟡 | **Pydantic `max_length` on all request models** | `s7_server.py` request models accept unbounded `message: str` — a 100MB request could pressure memory or slow Ollama. Add `Field(..., max_length=4096)` everywhere. | Security review pass 1, LOW |
| 🟡 | **Rate limiting on CWS API** | Add `slowapi` or a token-bucket limiter to `/witness`, `/quanti`, `/skyavi/chat`. Today a valid-token caller can flood Ollama. | Security review pass 1, LOW |
| 🟢 | **Single-tree discipline** | `/s7/skyqubi/` (deployed) and `/s7/skyqubi-private/` (canonical git) drift. Either bind-mount one to the other or have systemd units read directly from the git tree. Tonight surfaced this as the deepest root cause of the security review's "fixes don't take effect." | `docs/internal/postmortems/2026-04-13-security-review-root-causes.md` Root Cause 1 |

---

## 📦 Image / Container Hardening

| Pri | Item | Description | Reference |
|---|---|---|---|
| 🔴 | **Replace nomad upstream** | nomad has 32 CRITICAL + 336 HIGH CVEs (Trivy scan). Upstream is stale since 2026-04-03. Either fork + patch the bundled deps, swap to upstream n8n/automatisch directly, or risk-accept inside the qubi network with documented isolation. | `iac/intake/scan-reports/2026-04-13_SUMMARY.md` |
| 🟠 | **mysql 8.0 → fresh point release** | 1 CRITICAL + 7 HIGH on `mysql:8.0`. Pin to the latest 8.0.x point release. | scan reports |
| 🟠 | **redis 7-alpine → fresh point release** | 4 CRITICAL + 39 HIGH. Same pattern as mysql. | scan reports |
| 🟠 | **qdrant 1.16 → 1.x latest** | 5 CRITICAL + 42 HIGH. Pin to latest stable. | scan reports |
| 🟡 | **cyberchef 10.22.1 → latest** | 0 CRITICAL + 9 HIGH. Tolerable but should upgrade. | scan reports |
| 🟡 | **jellyfin :latest → pinned point release** | 0 CRITICAL + 10 HIGH. Pin off `:latest`. | scan reports |
| 🟠 | **Plan B.3 — Service cutover to localhost/s7/...** | Once the 6 images are hardened, run them through the TimeCapsule intake gate, swap pod YAML + standalone start scripts to use `localhost/s7/<name>:<version>` with `--pull=never`, retire upstream tags. The infrastructure is already built (Plan A + B0 + safe half of B). | `docs/internal/superpowers/specs/2026-04-13-pull-once-save-local-design.md` |
| 🟠 | **Trivy scan integration in lifecycle gate** | Today the scan is manual. Wire `trivy image` into `iac/intake/gate.sh` so any new image is scanned before promotion. Refuse to promote on HIGH/CRITICAL above an operator-defined threshold. | scan-before-seal pattern, security review pass 1 |
| 💡 | **FOSS catalog model** | Stop pre-installing software. Maintain a curated catalog of FOSS apps (Jellyfin, Kiwix, etc.) the user opts into via SPA toggle. Catalog entries are signed in TimeCapsule, scanned, versioned. | `docs/internal/ideas/2026-04-13-foss-repos-with-toggle.md` |

---

## 🖥 Boot / Bootloader

| Pri | Item | Description | Reference |
|---|---|---|---|
| 🟡 | **GRUB2: left-aligned menu + LUKS visible + TimeCapsule snapshot restore** | Three coordinated changes: (1) left-align the menu in `theme.txt`, (2) `GRUB_ENABLE_CRYPTODISK=y` so LUKS prompt is visible at GRUB level not buried in initrd, (3) custom `/etc/grub.d/41_s7_timecapsule_snapshots` script that emits a menu entry per snapshot for read-only point-in-time restore. **Requires snapshot creation pipeline first** (TimeCapsule today stores container images, not full root snapshots). | `docs/internal/ideas/2026-04-13-grub2-left-luks-timecapsule-restore.md` |
| 💡 | **TimeCapsule snapshot creation pipeline** | The above GRUB plan needs something to point at. Build the actual snapshot mechanism: btrfs/zfs subvolume snapshots, atomic, dated, mountable. Prerequisite for the GRUB recovery menu. | new |
| 🟢 | **Plymouth boot splash polish** | The S7 boot splash exists (`branding/splash/`). Verify it shows on every boot, has the right resolution for current displays, and matches the OS-release LOGO setting. | `project_skycair_boot_splash.md` (memory) |

---

## 🌐 Networking & Cluster

| Pri | Item | Description | Reference |
|---|---|---|---|
| 🟠 | **qubi network `--internal=true` (block all egress)** | The `qubi` podman network at `172.16.7.32/27` currently allows outbound for DNS resolution etc. Once we confirm no service on it legitimately needs egress, flip to internal-only at the kernel layer. | `iac/network/s7-qubi-network.sh` |
| 🟡 | **`S7_ALLOWED_OUTBOUND` env var population** | Tonight removed the hardcoded `192.168.1.75` from `s7_skyavi_monitors.py` and made it env-driven. Need a per-appliance setup script that populates this with the operator's actual LAN router IP, upstream DNS, etc. | security review pass 1, MEDIUM |
| 💡 | **PorteuX clustering — NVMe-over-TCP, bonded networking, distributed witness consensus** | Multi-node PorteuX cluster sharing model weights via NVMe-oF, network-bonded for resilience, witnesses scheduled across nodes. The full architecture is sketched. Hardware floor: 16 cores / 32 GB per node. | `docs/internal/ideas/2026-04-13-porteux-clustering-nvme-tcp.md` |

---

## 🤖 Witness / AI / Covenant

| Pri | Item | Description | Reference |
|---|---|---|---|
| 🟠 | **Plan D — Samuel `qubi_service_guardian` skill** | New SkyAVi skill: 15-second tick, walks the qubi service list, three-tier remediation ladder (restart → reload-from-tar → escalate to operator). Today's restart-fix added systemd Quadlet supervision; this adds the warm-loop guardian on top. | `docs/internal/superpowers/specs/2026-04-13-pull-once-save-local-design.md` (Plan D section) |
| 💡 | **Ribbon-gated Cloud chat — Stages 2 & 3** | Stage 1 (measurement framework + ribbon ledger schema) is built and live tonight. Stages 2 (Cloud API + personas table) and 3 (Cloud UI with persona avatars + drag-drop upload) are designed but not built. The chat unlocks ONLY when FIPS+CIS+HIPAA+SBC measurements are all green. | `docs/internal/superpowers/specs/2026-04-13-ribbon-gated-cloud-chat-design.md` |
| 💡 | **FIPS compliance check** | `iac/compliance/fips-check.sh` is a stub today. Implement: kernel FIPS mode (`/proc/sys/crypto/fips_enabled`), openssl FIPS provider, libgcrypt FIPS mode, kernel cmdline `fips=1`, dracut FIPS module in initramfs. | `iac/compliance/README.md` |
| 💡 | **CIS Distribution Independent Linux benchmark** | `iac/compliance/cis-check.sh` is a stub. Implement the subset of CIS DIL Benchmark v3.x that applies to a Fedora 44 appliance: filesystem, services, network, logging, access control, password policy. | same |
| 💡 | **HIPAA technical safeguards** | `iac/compliance/hipaa-check.sh` is a stub. Implement the 45 CFR § 164.312 safeguards: encryption at rest (LUKS + signed TimeCapsule), audit log retention, access controls, automatic logoff, unique user identification. | same |

---

## 🎨 Desktop / UX

| Pri | Item | Description | Reference |
|---|---|---|---|
| 🟠 | **First-boot host-state installer wiring** | `iac/host-state/install-host-state.sh` is idempotent and ready, but it's a manual operator step today. Wire it as a systemd `oneshot` that runs automatically on the first user login. | `iac/host-state/README.md` |
| 🟠 | **`COPY iac/host-state/` into the bootc image** | Add a `COPY iac/host-state/ /usr/share/s7/host-state/` line to `iac/Containerfile.base` so the installer source dir is part of every bootc image. Today the installer expects to know where the source lives. | same |
| 🟡 | **FOSS catalog toggle UI in SPA** | The SPA already has a `services` table with `installed` + `installation_status`. Add a catalog UI that shows opt-in apps as toggle cards, clicking the toggle runs the install/uninstall pipeline. | `docs/internal/ideas/2026-04-13-foss-repos-with-toggle.md` |
| 🟡 | **Wayland-native desktop status widget** | Conky was tried tonight and removed — Budgie+Wayland refused to honor positioning + stacking for any `own_window_type` combo. The right replacement is a real Wayland layer-shell client (gtk-layer-shell or similar) showing CPU/RAM/services/Carli status pinned to the desktop. | tonight's Conky removal; see `docs/internal/host-state/2026-04-13-restart-fix-and-icons.md` |
| 🟢 | **Broken-pin auto-detection** | The Budgie panel pinned `s7-skyqubi-command-center.desktop` after that file was deleted, leaving a broken icon for weeks. Build a small audit script: walk every dconf `pinned-launchers` value, verify each `.desktop` exists, surface broken pins as a notification. | tonight's panel cleanup |

---

## 📦 Distribution / Multi-platform

The S7 foundation ships across **3 primary** + **3 honorable mention** platforms. Each needs its own build pipeline and image-hardening pass.

| Pri | Platform | Codename | Audience | Status |
|---|---|---|---|---|
| 🔴 | Fedora 44 | F44 X27 | Primary User Base | **In progress, live tonight** |
| 🟠 | Rocky Linux | R101 | Business | Pending Go Live 2026-07-07 |
| 🟠 | PorteuX | — | OffGrid Anywhere and Compute (2/2 floor → 16/32 cluster) | Pending |
| 🟡 | BlendOS 'Artix' | — | Honorable mention (Arch-style, immutable) | Pending |
| 🟡 | Q4OS 'Deveun' | — | Honorable mention (Debian-style, lightweight) | Pending |
| 🟡 | Deveun (for Debian) | — | Final honorable mention (systemd-free Debian fork) | Pending |

The honorable mentions are deployable from GitHub for community/enthusiast use. The three primary builds are the supported S7 product line.

---

## 📚 Repository / Release Discipline

| Pri | Item | Description | Reference |
|---|---|---|---|
| 🟠 | **Quadlet migration completion** | 5 standalone containers migrated to Quadlet `.container` files tonight (kiwix, jellyfin, cyberchef, kolibri, flatnotes). The pod itself (`skyqubi-pod.yaml`) is still managed by `podman play kube`. Convert the pod containers to Quadlet too for consistency. | tonight's restart fix |
| 🟡 | **Feature branches off `lifecycle`** | Today every commit lands directly on `lifecycle`. For modularity ("remove or add nothing breaks"), each plan should have its own feature branch off `lifecycle`, merged in when complete. Abandoning a half-done plan is just deleting the branch. | tonight's branch retune discussion |
| 🟡 | **`promote-to-public.sh` discrete gate** | R03 (repos in sync) was removed from the lifecycle test because public is frozen between Core Updates. The sync semantics moved to a discrete gate that doesn't exist yet — needs to be built before the 2026-07-07 push. Should run audit-pre + lifecycle + audit-post + verify it's a Core Update day. | `feedback_release_branches_and_freeze.md` (memory) |
| 🟡 | **Plan B0 boot validator wiring at the lifecycle gate level** | The validator script + test exist (`iac/boot/s7-boot-validate.sh`). The lifecycle test has `B01` that calls it (or SKIPs). Wire this into the `iac/build-s7-base.sh` flow so every base image build automatically runs the boot validator before the build is considered done. | Plan B0 |

---

## 📖 Documentation

| Pri | Item | Description |
|---|---|---|
| 🟡 | **CONTRIBUTING.md update** | Reflect the freeze rule, the lifecycle/main branch model, the conventional-commit format, and the discipline rules (no scope drift, edit private only, no AI credits). |
| 🟡 | **Per-plan postmortem template** | The `docs/internal/postmortems/` directory will keep growing. Add a template so future postmortems follow the same shape: trigger → finding → root cause → fix → prevention. |
| 🟢 | **Architecture diagram for the cube/desktop separation** | The cube/desktop write-barrier rule is referenced everywhere but lives in memory only. Render it as an SVG diagram in `docs/internal/architecture/`. |

---

## How to pick something to work on

1. **If you're new to S7:** start with a 🟢 Low priority item or a 📖 docs item. They have small surface and clear scope.
2. **If you have a security background:** the 🛡 Security & Hardening section is the highest-leverage place to land.
3. **If you have container/podman experience:** 📦 Image hardening + Plan B.3 are concrete, scoped, well-documented.
4. **If you have systems experience (kernel, bootloader, init):** 🖥 Boot or 🌐 Networking are the deepest contributions.
5. **If you have AI/ML background:** the 🤖 Witness section has Plan D and the FIPS/CIS/HIPAA scripts that gate the Cloud chat.
6. **If you have UX/frontend skills:** 🎨 Desktop / UX has the FOSS catalog toggle and the Wayland-native widget — both are real frontend work.
7. **If you want to add a new platform:** 📦 Distribution lists the 3 honorable mentions that are deployable but not the foundation. Each needs its own intake + build.

For any of these, drop a note on the relevant spec or idea doc, then open a PR against `lifecycle`. Don't push to `main` directly — the lifecycle → main promotion is operator-gated.

---

## What's NOT a feature request

This file is **forward-looking only** — features, enhancements, future
plans. Bug reports go in `docs/internal/postmortems/` after they're
fixed (with the root cause, not just the symptom). Operator runbooks
live in `docs/internal/`. Architectural decisions live in
`docs/internal/architecture/`.

When a feature request becomes a real plan, it moves to
`docs/internal/superpowers/specs/` and the line in this file gets a
link to the spec.
