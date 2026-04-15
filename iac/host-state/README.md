# iac/host-state — S7 appliance host-state files

> **What this is:** the user-level files that need to live on every
> shipping QUBi appliance, mirrored into the repo so a fresh install
> can install them deterministically. These files do **not** belong in
> the bootc base image (they are user-state, not system-state) but
> they DO need to survive a fresh install.

## Why these files exist outside the bootc image

The bootc base image (`iac/Containerfile.base`) installs the system layer
— packages, the `s7` user, `/etc/s7/`, the locked root, the package set
audit-pre/audit-post enforce. That's the **system** layer.

The files in this directory are the **user** layer — Quadlet containers,
rootless podman storage config, systemd USER units, desktop entries,
browser sovereign policies, dconf overrides. They live under `~/.config/`,
`~/.local/`, `~/.var/app/`, and the dconf user database. None of those
paths exist until the `s7` user logs in for the first time, so they
cannot be baked into the bootc image directly.

## Layout

```
iac/host-state/
├── README.md                            (this file)
├── install-host-state.sh                (idempotent installer)
├── containers/
│   ├── storage.conf                     → ~/.config/containers/storage.conf
│   └── systemd/
│       ├── s7-kiwix.container           → ~/.config/containers/systemd/
│       ├── s7-jellyfin.container        → ~/.config/containers/systemd/
│       ├── s7-cyberchef.container       → ~/.config/containers/systemd/
│       ├── s7-kolibri.container         → ~/.config/containers/systemd/
│       └── s7-flatnotes.container       → ~/.config/containers/systemd/
├── systemd-user/
│   └── s7-timecapsule-verify.service    → ~/.config/systemd/user/
├── local-bin/
│   └── s7-timecapsule-verify.sh         → ~/.local/bin/
├── applications/
│   ├── s7.desktop                       → ~/.local/share/applications/  (the door)
│   ├── s7-chat.desktop                  → ~/.local/share/applications/  (S7 Chat — opens new window into the chat)
│   ├── vivaldi-stable.desktop           → ~/.local/share/applications/  (S7 Vivaldi — icon fixed to S7 shield)
│   └── io.github.ungoogled_software.ungoogled_chromium.desktop  →  ...  (S7 Browser — icon fixed to WhiteSur SVG)
├── chromium-policies/
│   └── s7-sovereign.json                → ~/.var/app/io.github.ungoogled_software.ungoogled_chromium/config/chromium/policies/managed/
├── vivaldi-policies/
│   └── s7-sovereign.json                → ~/.config/vivaldi/policies/managed/
└── dconf/
    └── 00-s7-budgie-pinned-launchers.txt   → loaded via `dconf load` into Budgie panel state
```

## How it gets installed on a fresh appliance

After the bootc base is installed and the `s7` user logs in for the
first time, the install script runs:

```bash
bash /usr/share/s7/host-state/install-host-state.sh
```

(Or whatever path the bootc image stages it to. The bootc Containerfile
should `COPY iac/host-state/ /usr/share/s7/host-state/` so the files
are present in the system tree. The installer script then copies them
out into `$HOME/...` paths where they actually need to live.)

The installer is **idempotent** — safe to re-run. Existing files are
overwritten with the canonical version from this directory.

## Why this is "right" vs the previous host-state mess

Before tonight, every fix to the host (Plan A, Plan B0, Plan B prereqs,
Plan B service population, the systemd USER units I wrote earlier in
this same session, the desktop entry edits, the chromium policy, the
dconf pinned-launcher fix) was applied **directly to the host** and not
mirrored into the repo. That meant:

- A fresh install would lose all of it
- There was no audit trail of what got changed
- Debugging required reading the host filesystem, not the repo
- "It works on my QUBi" was the only verification

This directory is the fix. Every change to host-state from now on
should land here first, then `install-host-state.sh` applies it. The
repo is the source of truth.

## What is NOT in this directory

- **System packages, /etc/, locked root** — those live in
  `iac/Containerfile.base`
- **The S7 services that run inside the s7-skyqubi pod** — those are
  declared in the pod YAML (which lives somewhere in the deploy tree,
  not here)
- **Secrets** — `~/.env.secrets` and `~/.config/s7/pg-password` are
  per-appliance. They are NOT in the repo. The installer assumes they
  already exist or are seeded by a separate operator step.
- **The TimeCapsule registry contents** — the signed tars themselves
  live at `/s7/timecapsule/registry/` and are populated by the intake
  adapter (`iac/intake/pull-container.sh`). They are NOT in the repo
  either; they are appliance-state, not source.

## Validation after install

```bash
# All Quadlet units active
for u in s7-kiwix s7-jellyfin s7-cyberchef s7-kolibri s7-flatnotes s7-timecapsule-verify; do
  systemctl --user is-active "$u.service"
done
# Expected: 6x "active"

# Desktop entries valid
for f in ~/.local/share/applications/s7.desktop ~/.local/share/applications/s7-chat.desktop; do
  desktop-file-validate "$f" && echo "$f OK"
done

# Browser policies in place
test -f ~/.var/app/io.github.ungoogled_software.ungoogled_chromium/config/chromium/policies/managed/s7-sovereign.json && echo "chromium policy OK"
test -f ~/.config/vivaldi/policies/managed/s7-sovereign.json && echo "vivaldi policy OK"

# dconf pinned launchers
dconf read /com/solus-project/budgie-panel/instance/icon-tasklist/{aa000001-0000-0000-0000-000000000001}/pinned-launchers
# Expected: ['s7.desktop', 's7-chat.desktop']

# additionalimagestores wired
podman info --format '{{range .Store.GraphOptions}}{{println .}}{{end}}' | grep -i additional
# Expected: contains /s7/timecapsule/registry/store
```

## What's deliberately deferred

- **Bake the install-host-state.sh invocation into a first-boot systemd
  oneshot** so it runs automatically on the s7 user's first login.
  Today it runs manually.
- **Bake the host-state directory into the bootc image itself** via
  `COPY iac/host-state/ /usr/share/s7/host-state/` in
  `iac/Containerfile.base`. Today the installer expects you to know
  where the source dir lives. A future Plan adds the COPY line.
- **Bake `~/.env.secrets` and `~/.config/s7/pg-password` seeding** into
  a per-appliance setup script that runs once during initial
  provisioning. Today those are assumed to exist.
