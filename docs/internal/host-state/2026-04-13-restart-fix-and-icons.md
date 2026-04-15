# 2026-04-13 — Restart fix + desktop icon repair (host state)

> **What this file is:** an audit record of changes made to the host
> filesystem at `/s7/.local/share/applications/` and `/s7/.config/systemd/user/`
> on 2026-04-13. These changes are **not in git** because they live on
> the desktop / host-state layer, per the cube/desktop write-barrier
> rule. This document is the only repo-side record that they happened.

## The problem Tonya saw

Two distinct issues, reported as one:

1. **"Restarting of apps fail"** — when standalone containers (kiwix,
   jellyfin, cyberchef, kolibri, flatnotes) died, they never came back.
2. **"S7 icons don't all work — no icon for S7 Chat (S7 Vivaldi and S7
   Browser, vivaldi did nothing)"** — multiple desktop entries had broken
   icons; clicking S7 Vivaldi appeared to do nothing.

## Root causes

### Restart failure

**Rootless podman does not auto-restart containers on its own.** The
`--restart=unless-stopped` flag is set on every standalone container
but the policy never fires because there is no supervisor watching them.
`podman inspect` confirmed every container had `restartCount=0` despite
the policy being set. The five core S7 services (caddy, ollama,
cws-engine, the pod, bitnet-mcp) have systemd USER units that DO own
their lifecycle. The five standalone apps did not.

**This was always broken.** It is not a regression caused by tonight's
TimeCapsule work — the standalone containers were created via REST API
or `podman run` without ever wiring them to a supervisor. Tonya would
have hit this even on a box that had never seen Plan A or Plan B.

### Desktop icons

Three separate failures on three separate `.desktop` files:

- `vivaldi-stable.desktop` had `Icon=vivaldi` — a name lookup against
  the system icon theme. **No `vivaldi.png` exists** in any installed
  icon theme on this box. The lookup failed, the menu showed a generic
  placeholder.
- `io.github.ungoogled_software.ungoogled_chromium.desktop` had
  `Icon=io.github.ungoogled_software.ungoogled_chromium` — also a name
  lookup that failed. The actual chromium icons live in the
  `WhiteSur-purple` theme under different names
  (`ungoogled-chromium.svg`).
- **No `s7-chat.desktop` existed at all.** Tonya wanted an "S7 Chat"
  card but it had never been created.

The "vivaldi did nothing" report had a separate explanation: Vivaldi was
already running with `http://127.0.0.1:8080` open. Clicking the launcher
again silently focused the existing window instead of opening a new one.
From Tonya's view: "I clicked it and nothing happened."

## What was changed

### Systemd USER units (`/s7/.config/systemd/user/`)

Five new unit files, one per standalone container:

```
container-s7_kiwix_server.service
container-s7-jellyfin.service
container-s7_cyberchef.service
container-s7_kolibri.service
container-s7_flatnotes.service
```

Each generated via `podman generate systemd --restart-policy=on-failure
--restart-sec=5 <container>`. The `--new` flag was rejected by podman
because the containers were created via REST API (no recoverable create
command). The generated units therefore reference each container by its
existing container ID via `podman start <id>` / `podman stop <id>` —
not the cleanest pattern, but works immediately.

Each unit was enabled (`systemctl --user enable`) AND started
(`systemctl --user start`) so systemd is now actively supervising. The
fix was verified by killing `s7_kiwix_server` and watching systemd
restart it within ~5 seconds.

**Future cleanup task — Quadlet migration:** `podman generate systemd`
is deprecated in podman 5.x. The right long-term fix is to write
`.container` files (Quadlet) in `/s7/.config/containers/systemd/` that
declare each container's full spec. systemd then generates the .service
units automatically and the units are idempotent — even if the
container is removed, the .container file recreates it on next start.
Tonight's units cannot survive a container removal without re-running
the generate command.

### Desktop entry edits (`/s7/.local/share/applications/`)

Two single-line edits and one new file:

| File | Change | Rollback |
|---|---|---|
| `vivaldi-stable.desktop` | `Icon=vivaldi` → `Icon=/s7/skyqubi-private/branding/icons/s7-shield-icon-256.png` | revert the one line |
| `io.github.ungoogled_software.ungoogled_chromium.desktop` | `Icon=io.github.ungoogled_software.ungoogled_chromium` → `Icon=/usr/share/icons/WhiteSur-purple/apps/scalable/ungoogled-chromium.svg` | revert the one line |
| `s7-chat.desktop` (NEW) | full new entry — `Name=S7 Chat`, `Exec=/usr/bin/vivaldi-stable --new-window http://127.0.0.1:8080/chat`, `Icon=s7-shield-icon-256.png` | `rm /s7/.local/share/applications/s7-chat.desktop` |

`update-desktop-database /s7/.local/share/applications` was run to
refresh the menu cache. `gtk-update-icon-cache` failed with permission
denied on the system icon theme dir (root-owned, no sudo) but that does
not block the icon lookups since the Icon= values are now absolute paths,
not name lookups.

## Verification

```bash
# Restart works
podman kill s7_kiwix_server && sleep 6 && podman ps --filter name=s7_kiwix_server
# Expected: container is back up

# Units active
for u in container-s7_kiwix_server container-s7-jellyfin container-s7_cyberchef container-s7_kolibri container-s7_flatnotes; do
  systemctl --user is-active "$u.service"
done
# Expected: 5x "active"

# Desktop entries valid
desktop-file-validate /s7/.local/share/applications/s7-chat.desktop
desktop-file-validate /s7/.local/share/applications/vivaldi-stable.desktop
desktop-file-validate /s7/.local/share/applications/io.github.ungoogled_software.ungoogled_chromium.desktop
# Expected: no output (silent = valid)

# S7 Chat icon resolves
test -f /s7/skyqubi-private/branding/icons/s7-shield-icon-256.png && echo OK
# Expected: OK
```

## What this doc does NOT do

- It does not commit the host files into the repo. The desktop layer
  is intentionally kept out of git per the write-barrier rule.
- It does not promote the changes to public — they would not survive
  the sync anyway, and they are appliance-local.
- It does not address the `s7-cws-engine.service` that is currently
  in `activating auto-restart` state. That is a separate failure that
  needs its own diagnosis.

## Follow-up: Budgie panel pinned launchers + chromium sovereignty (same night)

Tonya reported a follow-up: the icons by the clock looked broken, and
the S7 Browser had a "Store" link trying to go to a random external URL.
Two more host-state fixes applied:

### Pinned launchers

The Budgie Icon Task List was pinning `s7-skyqubi-command-center.desktop`
which **does not exist** — leftover from before the single-`s7.desktop`
collapse. The dconf key was updated:

```
dconf write /com/solus-project/budgie-panel/instance/icon-tasklist/{aa000001-0000-0000-0000-000000000001}/pinned-launchers "['s7.desktop', 's7-chat.desktop']"
```

Now both pins resolve to existing .desktop files with valid icon paths.

### Chromium sovereign policy

S7 Browser is `flatpak run io.github.ungoogled_software.ungoogled_chromium`.
Out of the box it shows a "Store" / Apps shortcut that navigates to
`https://chromewebstore.google.com/` — exactly the kind of upstream leak
that contradicts the S7 brand. A managed policy file was dropped at:

```
/s7/.var/app/io.github.ungoogled_software.ungoogled_chromium/config/chromium/policies/managed/s7-sovereign.json
```

Effect (read by chromium at process startup):
- Homepage / new-tab / restore-on-startup all locked to `http://127.0.0.1:8080`
- Default search engine **disabled** (no Google address-bar leak)
- Bookmark bar hidden
- "Apps" / "Web Store" bookmark-bar shortcut hidden
- `chrome://apps`, `chrome://web-store`, `chromewebstore.google.com`,
  `chrome.google.com/webstore` all in `URLBlocklist`
- Sign-in blocked, sync disabled, telemetry off, safe-browsing off
- Extensions blocklisted (`*`)

**Caveat:** chromium reads policies at startup. If S7 Browser is already
running when this file lands, all windows must be closed and reopened
for the policy to take effect.

**Rollback:** `rm /s7/.var/app/io.github.ungoogled_software.ungoogled_chromium/config/chromium/policies/managed/s7-sovereign.json`

## Operator follow-ups — ALL FOUR COMPLETED LATER THE SAME NIGHT

### #1 Quadlet migration — DONE

Replaced the 5 deprecated `podman generate systemd` units with proper
Quadlet `.container` files at `~/.config/containers/systemd/`. systemd
auto-generates the .service units on `daemon-reload`. Old units removed.
Kiwix had a tricky `Exec=` issue (the entrypoint already prepends
`--port=8080`, so passing it again duplicated the flag, AND `--library`
needs the path as a separate positional arg, not `=value` syntax — the
fix is `Exec=-l /data/kiwix-library.xml --monitorLibrary --address=all`).
All 5 Quadlet units `active`, kiwix back to HTTP 200 on port 8090.

### #2 cws-engine diagnosis — DONE

Two compounding root causes:
1. `WorkingDirectory=/s7/s7-project-nomad/admin` — the path doesn't
   exist (leftover from before the rename). systemd reported
   `status=200/CHDIR`. Fixed: pointed at `/s7/skyqubi/` (the deployment
   tree the other working services already use).
2. After fixing the path, psycopg2 connection failed: `127.0.0.1:5432
   Connection refused`. The `.env.secrets` file had `CWS_DB_PORT=5432`
   (the in-pod container port) but cws-engine connects from the HOST,
   so it needs the host-mapped port. Postgres is on `127.0.0.1:57090`.
   Fixed `.env.secrets`.
3. After the port fix, psycopg2 reported `password authentication
   failed for user "s7"`. The `.env.secrets` had the pre-rotation
   password. The rotated password lives in `/s7/.config/s7/pg-password`
   (mode 600). Updated `.env.secrets` to use it.

cws-engine is now `active (running)`, no auto-restart loop, FastAPI
docs respond on `http://127.0.0.1:57077/docs`.

### #3 Bake host-state into the repo — DONE

Created `iac/host-state/` mirroring all 11 host-state files (5 Quadlet
container files, rootless storage.conf, TimeCapsule verify systemd unit,
TimeCapsule verify script, 4 desktop entries, chromium policy, vivaldi
policy, dconf pinned-launchers value). Wrote
`iac/host-state/install-host-state.sh` — an idempotent installer that
copies everything into the right host paths and runs `daemon-reload`,
`update-desktop-database`, `dconf load`. Wrote `iac/host-state/README.md`
documenting the layout, why these files live outside the bootc image,
and how the installer is meant to run on a fresh appliance.

The repo is now the source of truth for everything that gets installed
to the user-state layer. A fresh bootc install + the installer script =
a fully reproducible appliance.

### #4 Vivaldi sovereign policy — DONE

Wrote `~/.config/vivaldi/policies/managed/s7-sovereign.json` (also
mirrored to `iac/host-state/vivaldi-policies/`). Same lock-down as the
chromium one: homepage + new-tab + restore-on-startup all locked to
`http://127.0.0.1:8080`, default search disabled, bookmark bar hidden,
apps shortcut hidden, all chromewebstore URLs blocklisted, sign-in
blocked, sync disabled, telemetry off, extensions blocklisted. Vivaldi
will read it on next process startup (not currently-running windows).

## Still deferred (not in tonight's scope)

- **First-boot oneshot** that runs `install-host-state.sh` automatically
  on the s7 user's first login. Today it's a manual operator step.
- **`COPY iac/host-state/ /usr/share/s7/host-state/`** in
  `iac/Containerfile.base` so the installer source dir is part of every
  bootc image. Today the installer expects the operator to know where
  the source dir lives (typically `/s7/skyqubi-private/iac/host-state/`
  on a dev box).
- **Per-appliance secret seeding** — `~/.env.secrets` and
  `/s7/.config/s7/pg-password` are not in the repo and never should be.
  A separate provisioning script generates them per-appliance.
