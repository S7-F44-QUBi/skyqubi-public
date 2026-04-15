# FOSS Repos with Toggle — Idea Note

> **Status:** idea only. Not planned, not built. Captured 2026-04-13.
>
> **Source:** Jamie, *"we should have OS FOSS REPOS and software so
> users can add when enable the toggle"* — said immediately after
> asking to uninstall Steam, which had been pre-installed.

## The reframe

S7 ships with a **minimal core** only. Everything else lives in a
**curated FOSS catalog** the user opts into via a toggle in the SPA.
Software that the user didn't ask for has no business being on a
household appliance, even if it's benign.

## What got removed tonight (the first concrete step)

- **Steam flatpak** (`com.valvesoftware.Steam`) — uninstalled. It had
  been renamed to "S7 Games" in the menu but the household never asked
  for it.

## What stays as core

Minimum viable QUB*i*:
- bootc Fedora base + audited packages
- podman + S7 services pod (postgres / mysql / redis / qdrant / nomad)
- Vivaldi (S7 door)
- kitty (S7 Terminal)
- S7 cube engine + skills
- Carli / Elias / Samuel via Ollama
- Audit + verify scripts (compliance, TimeCapsule, lifecycle test)

## What goes into the catalog (toggle-driven)

| Slug | Category | Why catalog (not core) |
|---|---|---|
| jellyfin | Media | Family choice — not every household wants media server |
| kiwix | Library | Education choice |
| kolibri | Education | Same |
| cyberchef | Tools | Power-user data tools |
| flatnotes | Notes | Writing tool, opinionated |
| libreoffice | Office | Many alternatives, large footprint |
| (future) | … | … |

## The toggle UI

The SPA shows the catalog as a grid of cards. Each card has:
- Friendly name + icon + 1-line description
- Toggle (OFF by default)
- Status (idle / installing / running / failed)
- Install size
- Last CVE scan verdict
- "Open" button when running

Toggling ON triggers the install pipeline (intake gate → TimeCapsule
→ Quadlet unit → start). Toggling OFF triggers the inverse: stop the
container, remove the Quadlet, leave volumes intact (with an option
to wipe them too).

## The pieces that already exist

- `services` table with `installed` + `installation_status` columns
- Intake gate (`iac/intake/`)
- TimeCapsule registry (`/s7/timecapsule/registry/`)
- Quadlet `.container` files (`~/.config/containers/systemd/`)
- Trivy CVE scan reports (`iac/intake/scan-reports/`)

## What's missing

- A **`catalog` table** distinct from `services` — services = always-on
  core; catalog = opt-in
- A **toggle UI** in the SPA that flips `installed` and triggers the
  install/uninstall pipeline
- An **uninstall flow** that's the clean inverse of install
- A **default visibility split** so the SPA shows core vs catalog
  apps differently
- A **catalog manifest** in the repo (e.g. `iac/catalog/manifest.yaml`)
  declaring which slugs exist, their pinned upstream digests, their
  TimeCapsule image hash, their CVE scan status

## What this rules out (going forward)

- **No pre-installing apps beyond the minimal core.** Future sessions
  must not add software without going through the catalog model.
- **No "kitchen sink" defaults.** The `/usr/share/applications/` and
  `/s7/.local/share/applications/` directories should be audited to
  remove entries that came from Fedora Workstation defaults but are
  not in the minimal core.
- **No silent updates.** A catalog app being toggled ON means the user
  consented to that VERSION. A new upstream version requires re-toggling
  or an explicit "accept update" click.

## Pinned follow-up: steam-devices udev rules (separate from Steam)

Even though Steam itself is removed, the **udev rules from `steam-devices`**
should still be installed system-wide. They cover Steam Controller,
Valve Index, generic Xbox/PS gamepads, etc. — useful for any household
that plugs in a controller, regardless of whether they use Steam.
This is hardware compatibility, not gaming.

```bash
sudo dnf install -y steam-devices
```

Triple per the (would-be) categorization framework: this is
`[BROKEN, USER_FIX, INFRA]` — Steam was telling Tonya about the
missing rules. Pin as a sudo follow-up.

## Status

- **Idea only**, no spec, no plan, no build
- Memory: `project_foss_repos_with_toggle.md`
- First concrete step: Steam removed tonight
- Becomes a real spec after image-hardening defines the minimal core
