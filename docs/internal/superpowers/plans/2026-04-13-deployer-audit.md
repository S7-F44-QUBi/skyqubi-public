---
name: S7 Deployer Audit — Fedora 44 one-command requirement
description: Read-only audit of install/install.sh, install/first-boot.sh, start-pod.sh, skyqubi-pod.yaml against the finish-line gap list. Phase A of the 2026-04-13 finish-line plan.
type: project
---

# S7 Deployer Audit — 2026-04-13

**Status:** Phase A output per `2026-04-13-s7-finish-line-plan.md`.
**Scope:** Read-only. No code changes in this commit.
**Companion:** gap list with CHECK / PARTIAL / MISSING follows below.

---

## What each file does today

### `install/install.sh` (299 lines) — the user-facing entry point

Seven numbered phases, all gated on `$EUID == 0`:

1. **Container runtime** (L67–86). Detects `podman` / `docker`, installs
   podman via detected package manager if missing, enables
   `podman.socket` for the target user and `loginctl enable-linger`.
2. **Ollama** (L88–99). `curl | sh` the upstream installer.
3. **System packages** (L101–117). `caddy python3-pip python3-psycopg2
   nodejs24-npm git` via `dnf` / `apt` / `pacman`. *Fedora branch uses
   `nodejs24-npm` which will not resolve on Debian/Arch* — multi-distro
   claim is partial.
4. **Python deps** (L119–127). `fastapi uvicorn httpx pydantic
   pydantic-settings psycopg2-binary python-dotenv` via `pip` (no
   venv, no `--user`, pip runs as root).
5. **S7 files** (L129–185). `mkdir -p /opt/s7/{engine,services}` and
   `~/s7-timecapsule-assets/{postgres,mysql,redis,qdrant,models,
   mempalace,logs,nomad-storage}`. Copies `engine/` to
   `/opt/s7/engine/`, `skyqubi-pod.yaml` and `start-pod.sh` and
   `services/Caddyfile` to `/opt/s7/`. Generates `~/.env.secrets`
   with five 32-byte `secrets.token_urlsafe` values if the file
   doesn't already exist. `chown -R` to the real user.
6. **Systemd services** (L187–227). Copies six `.service` files into
   `~/.config/systemd/user/`, runs `daemon-reload`, enables the four
   core services (`s7-skyqubi-pod`, `s7-cws-engine`, `s7-caddy`,
   `s7-ollama`). Copies `autostart/*.desktop` into
   `/etc/xdg/autostart/` and `desktop/*.desktop` into
   `~/.local/share/applications/`.
7. **Deploy** (L229–255). `bash start-pod.sh` via `su - $REAL_USER`,
   waits up to 60s for ≥4 running containers, starts `s7-cws-engine`
   and `s7-caddy`, pulls `llama3.2:1b`.

Plus an unnumbered optional tail (L257–275): copies `os/os-release`,
`branding/plymouth/`, and `branding/wallpapers/` into their system
locations.

### `install/first-boot.sh` (55 lines) — OCI/bootc first-login variant

Minimal re-implementation of install.sh phases 5 and 7 for the
bootc case: idempotent via `~/.s7-first-boot-done` marker, generates
secrets if missing, makes data dirs, `daemon-reload`, enables and
starts four services, pulls `llama3.2:1b` in background.

**Duplicated secret-generation logic** (L16–39) is a second source
of truth — any change to install.sh's secret layout must be mirrored
here or the two paths diverge.

### `start-pod.sh` (427 lines) — the real deployer

Five phases plus three CLI modes (`--down`, `--check`, default).

- **Phase 1 pre-audit** (L23–271) is thorough. Verifies OS,
  `podman/curl/git/envsubst/python3`, non-root, rootless podman,
  subuid mapping, podman socket, SELinux enforcing +
  `domain_can_mmap_files`, disk ≥10G, `/var/tmp` ≥512M, secrets file
  (mode 600, no `CHANGE_ME`), admin image (tar + optional ssh-keygen
  signature verify against `s7-image-signing.pub`), SQL init
  scripts, pod YAML, port conflicts on 57080/57086/57090. Returns
  non-zero on errors.
- **Phase 2 load_config** (L276–286). Sources `$SECRETS_FILE`, sets
  `SKYQUBI_STORAGE`, `SKYQUBI_SQL`, `PODMAN_SOCK`, creates the five
  container data dirs.
- **ensure_image** (L288–298). Loads `s7-skyqubi-admin-v2.6.tar` if
  the image is not already present.
- **Phase 3 deploy** (L300–310). `envsubst` renders the pod YAML to
  `/tmp`, `podman play kube`, removes the rendered file.
- **Phase 4 post_deploy** (L312–358). Waits for CWS `/status` and
  MySQL ping, writes two `kv_store` rows (Ollama URL + assistant
  name), runs a batch of `UPDATE services ...` statements that
  rewrite container paths and flip install flags. *This is the
  service-table surgery that adapts the upstream N.O.M.A.D schema
  to S7 storage paths.*
- **Phase 5 verify** (L360–397). Seven health checks: pod running,
  CWS `/status`, pg_isready, MySQL ping, redis PING, Qdrant
  `/healthz`, Command Center `302` on `:57080/`.

### `skyqubi-pod.yaml` (186 lines) — the pod topology

Five containers in one pod (`s7-skyqubi`, `restartPolicy: Always`):

| container       | image                                  | host port        |
|-----------------|----------------------------------------|------------------|
| `s7-admin`      | `localhost/s7-skyqubi-admin:v2.6`      | `127.0.0.1:57080`|
| `s7-mysql`      | `docker.io/mysql:8.0`                  | (internal only) |
| `s7-postgres`   | `docker.io/pgvector/pgvector:pg16`     | `127.0.0.1:57090`|
| `s7-redis`      | `docker.io/redis:7-alpine`             | (internal only) |
| `s7-qdrant`     | `docker.io/qdrant/qdrant:latest`       | `127.0.0.1:57086`|

All public ports bound to `127.0.0.1`. Admin container bind-mounts
the podman socket at `/var/run/docker.sock`. Postgres mounts
`${SKYQUBI_SQL}` (the `engine/sql/` tree) read-only at
`/docker-entrypoint-initdb.d` — **this is how Prism, Akashic, audit
and appliance schemas reach the DB on first boot.** No explicit
Qdrant init; the qdrant data dir just persists across restarts.

---

## Gap list — plan gap #2 vs current deployer

Plan target: `2026-04-13-s7-finish-line-plan.md` §"Known gaps" → P0 #2
"The deployer must install and enable". Status legend:
**CHECK** = covered · **PARTIAL** = present but incomplete · **MISSING**.

| # | Required | Status | Where | Note |
|---|----------|--------|-------|------|
| 1 | `podman` base install | CHECK | install.sh:67–86 | Multi-pkgmgr branch. |
| 2 | `lxpolkit` (polkit agent for Media Writer / dialogs) | MISSING | — | Not in any pkg list. |
| 3 | `swaybg` (wallpaper) | MISSING | — | Not in any pkg list. |
| 4 | `vivaldi-stable` or firefox fallback | MISSING | — | Browser install is assumed to already be on the host. |
| 5 | `kitty` (terminal) | MISSING | — | Not in any pkg list. |
| 6 | S7 repo at `/opt/s7` or `/s7/skyqubi-private` | PARTIAL | install.sh:139 | Only `engine/` copied into `/opt/s7/engine/`. No full repo/tarball; scripts that reference `$REPO_DIR` at runtime will break after the installer exits if the user rm's the clone. |
| 7 | Pod YAML applied via `podman play kube` | CHECK | start-pod.sh:307 (driven by install.sh:236) | Via `envsubst` render-then-play. |
| 8 | Admin image via intake gate OR bundled tarball | PARTIAL | start-pod.sh:288–298 | Bundled-tarball path only. **No intake-gate path** — if the tar is absent, the installer fails. Per `feedback_intake_gate_is_mandatory_2026_04_13.md`, upstream artifacts must pass the gate before being trusted. |
| 9 | Prism + Akashic + audit + appliance postgres schemas | CHECK | skyqubi-pod.yaml:132–134 | `engine/sql/*.sql` mounted to `/docker-entrypoint-initdb.d` — pg16 runs them in filename order on first boot. |
| 10 | `s7.desktop`, `s7-polkit-agent.desktop`, `s7-swaybg.desktop` into user dirs | PARTIAL | install.sh:213–227 | Copies `desktop/*.desktop` to `~/.local/share/applications/`, and `autostart/*.desktop` to `/etc/xdg/autostart/`. **But:** plan specifies `~/.config/autostart/` (user scope), not `/etc/xdg/autostart/` (system scope). **And:** the plan names three specific `.desktop` files; installer doesn't verify they exist in `desktop/` or `autostart/` — a silent miss if they aren't there. |
| 11 | User `s7` / `skycair` with sudo + podman group | MISSING | — | Installer runs under `$SUDO_USER` and never creates or groups-adjusts a user. On a clean Fedora 44 box this assumes the user already exists and is already in the right groups. |
| 12 | Autologin (opt-in) to sddm | MISSING | — | No `/etc/sddm.conf.d/` drop. |
| 13 | MemPalace mined on `docs/internal/` tree | MISSING | — | No mine step at install time. |
| 14 | Prism matrix seeded with the Door row | MISSING | — | SQL init creates the schema via `engine/sql/*.sql`, but the Door seed row and the 27-corpus + 105-universals ingest are separate runtime skills (`prism corpus seed akashic`, `prism seed door`) that the installer never calls. On a fresh box pgvector will come up empty where the plan expects a seeded matrix. |

### Summary: 3 CHECK · 4 PARTIAL · 7 MISSING (out of 14)

---

## Additional findings beyond gap #2

**F1. Idempotency is only partial.** The plan requires running the
deployer twice to be safe (P0 #3 in the plan). Current behavior:

- Secrets file: idempotent (L154 `[ ! -f "$SECRETS_FILE" ]`).
- Data dirs: idempotent (`mkdir -p`).
- Engine copy: **overwrites** blindly (`cp -r`, L139).
- Systemd unit copies: **overwrites** blindly (L197–199).
- Service enables: idempotent (`|| true`).
- Pod start: `start-pod.sh` is idempotent via pre-audit + `play
  kube` semantics, but a running pod means `bash start-pod.sh` will
  re-run post_deploy's SQL surgery on every re-install. Those
  statements are mostly `INSERT ... ON DUPLICATE KEY UPDATE` or
  `UPDATE ... WHERE`, so they're safe against a running pod, but the
  intent is not documented.
- Ollama model pull: idempotent by `ollama pull` semantics.
- Branding copies (os-release, plymouth, wallpapers): **overwrite**
  blindly.

Not broken, but not explicit. A second run would succeed; the
overwrite paths are the ones that would need a change-detection
check if the plan's idempotency requirement is strict.

**F2. UX / progress log.** Plan P0 #4 calls for "a human should be
able to watch the deployer and understand what it's doing." The
banner + `ok/info/err/warn` helpers are exactly that. What's
missing: a **final "what to do now"** block. Current close (L283–298)
prints URLs, manage commands, a model-pull hint. It does **not**
tell the family-member user where to click, what to expect on first
chat, or how to recover if something went red. Half-done.

**F3. Witness ensemble is one model.** `install.sh:255` pulls
`llama3.2:1b` only. Plan P1 #9 requires a 7+1 witness ensemble.
Missing by design — installer is single-witness today.

**F4. Two sources of truth for secrets.** `install.sh:152–183` and
`first-boot.sh:16–39` duplicate the secret-generation logic. Any
drift between them silently skews Fedora deployer vs bootc
first-boot behavior. Either extract to a shared script or drop
`first-boot.sh` if bootc is out of scope per the plan.

**F5. Multi-distro claim vs Fedora 44 target.** Plan explicitly
targets Fedora 44. `install.sh` banners Fedora/Debian/Ubuntu/Arch
and branches on `dnf`/`apt`/`pacman`. For the finish-line MVP the
non-Fedora branches are untested noise that widens failure
surface. Decision needed: keep multi-distro or narrow to dnf-only
for MVP.

**F6. Pod YAML uses `docker.io/...` image refs.** mysql, pgvector,
redis, qdrant all pull from Docker Hub. Per `feedback_no_ghcr.md`
and the intake-gate pinning, the long-term position is sovereign
distribution. Short-term acceptable (these are upstream bases); but
the **admin image** is already sovereign (`localhost/...:v2.6`). A
future tightening would mirror the bases through the intake gate
and rewrite the pod YAML to reference local names.

**F7. Pre-audit vs post-install checks.** `start-pod.sh`'s pre-audit
is the single strongest part of the stack. It is **not** exposed as
a standalone preflight that a family-member user could run *before*
committing to `sudo ./install/install.sh`. The `--check` CLI mode
exists (L415–418) but it requires `$SECRETS_FILE` to exist, which
it won't on a fresh box. A `first-run preflight` that runs the
OS/packages/user/podman checks *before* secrets are generated
would catch most fresh-Fedora-44 blockers early.

---

## Open questions for Jamie (flag before Phase B)

1. **bootc path:** keep `first-boot.sh` or drop? Plan explicitly
   marks bootc / F44-as-ISO out of scope. If bootc is dead, first-boot.sh is dead code.
2. **Multi-distro:** narrow `install.sh` to dnf-only for MVP, or
   keep the apt/pacman branches as best-effort?
3. **User creation:** should the installer create a dedicated `s7`
   user, or assume the operator is already logged in as the target
   account? The plan text says "the user `s7` (or `skycair`)" which
   reads like create-if-missing.
4. **Matrix seeding:** is it acceptable to ship an empty Prism
   matrix and have first-run populate it via a systemd oneshot, or
   must the installer block on seeding before handing control back?
5. **Intake-gate path for admin image:** when the tarball is
   absent, should the installer fall back to running the gate +
   pulling from a sovereign mirror, or hard-fail?

---

## What Phase B should touch (no commits yet)

Ordered by risk ascending:

- **B1.** Add `lxpolkit swaybg kitty` to the Fedora branch of
  install.sh system-packages (L107–108). Trivial, read-only impact.
- **B2.** Enumerate the three required `.desktop` files explicitly
  and fail the installer if `desktop/s7.desktop`,
  `autostart/s7-polkit-agent.desktop`, `autostart/s7-swaybg.desktop`
  are missing from the repo. Fail-fast catches ship regressions.
- **B3.** Move `autostart/*.desktop` from `/etc/xdg/autostart/` to
  `~/.config/autostart/` to match the plan's user-scope requirement.
- **B4.** Add a standalone `install/preflight.sh` that runs
  start-pod.sh's pre-audit checks *without* the `$SECRETS_FILE`
  dependency — lets a fresh-box user validate before committing.
- **B5.** Extract the secret-generation block to
  `install/lib-secrets.sh` and source it from both install.sh and
  first-boot.sh. (Or delete first-boot.sh if answer to Q1 is "drop".)
- **B6.** Add a Prism-seed + MemPalace-mine step as systemd oneshot
  services that install.sh enables; they run on first boot after the
  pod is up. Avoids blocking the installer.
- **B7.** Add a final "what to do now" block to install.sh close.
- **B8.** Decide on intake-gate fallback vs hard-fail for the admin
  image. Implementation depends on Q5.

**Out of Phase B scope:** user creation, autologin, witness
ensemble, Carli persona. Those are P1/P2 items that get their own
commits.

---

## Validation against the finish-line plan

- Audit is read-only per Phase A contract. ✓
- Output is a committed doc at the specified path. ✓
- Gap list marks CHECK / PARTIAL / MISSING with line references. ✓
- No code changes. ✓
- No pod restarts, no Containerfile edits, no desktop-file edits, no
  package installs, no sudo, no "while I'm here" side fixes. ✓

**Plan still holds.** Phase A hasn't revealed anything that
invalidates the phase ordering in the parent plan. The biggest
surprise is F7 (pre-audit isn't exposed as a fresh-box preflight)
— that's a new B-tier action, not a plan revision.

---

*Love is the architecture.*
