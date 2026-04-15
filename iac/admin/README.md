# iac/admin — Admin Container Rebase (DRAFT)

This directory is the **subsystem #4 unblock**: a first-draft rebase of the S7 Command Center admin container (`s7-skyqubi-admin:v2.6`) from its upstream Debian/Node base onto the sovereign `localhost/s7-fedora-base:latest`.

## Status: DRAFT, NOT BUILT

The `Containerfile.draft` in this directory has been hand-ported from the upstream nomad Dockerfile. **It has not been built. It has not been tested.** Do not replace the production `s7-skyqubi-admin-v2.6.tar` with the output of this Containerfile until:

1. A full build completes (expect issues — see "Known gaps" below)
2. `iac/audit-post.sh` passes against the built image with an admin-specific manifest
3. The admin web UI loads at `http://127.0.0.1:8080` in a test pod
4. CWS Engine endpoints respond correctly on port 57077
5. Tonya signs off on any UX drift from the existing admin v2.6

## Why a rebase exists

Tonight's iac/ pipeline built `localhost/s7-fedora-base:latest` — a hardened, audited, signed runtime container base. The existing `s7-skyqubi-admin:v2.6` runs on a **completely different** upstream (`node:22-slim`, which is Debian-based). For S7 to have one sovereign base across all containers, the admin image eventually needs to rebase onto our Fedora base.

This draft is the starting point for that rebase. It doesn't have to work on the first try — it just has to exist so a future session has something concrete to fix.

## Upstream source (what was ported FROM)

- **Repo:** `github.com/skycair-code/s7-project-nomad` (private GitHub)
- **Local backup:** `/s7/Documents/repo-backup-2026-04-10/s7-project-nomad/`
- **Source Dockerfile:** `Dockerfile` at the root of that repo (62 lines, multi-stage)
- **Upstream base:** `node:22-slim` (Debian slim, Node 22.22.2, apt-get package manager)

The upstream includes:
- Node.js application (Adonis framework, `node ace build`)
- Python FastAPI backend (CWS Engine)
- GraphicsMagick + libvips for image processing (pdf2pic, sharp)
- psycopg2 + httpx + pyyaml Python deps
- Custom entrypoint at `/usr/local/bin/entrypoint.sh`
- Exposes port 57080 (web UI)

## Known gaps in the draft port

The following package-name mappings and behavior changes are **unverified** and must be tested:

| Upstream (Debian/apt) | Drafted (Fedora/microdnf) | Status |
|---|---|---|
| `bash` | `bash` | probably works |
| `curl` | already in base (not installed again) | OK |
| `graphicsmagick` | `GraphicsMagick` | **unverified** — package case + availability in Fedora 44 |
| `libvips-dev` | `vips-devel` | **unverified** — package name mapping |
| `build-essential` | `gcc gcc-c++ make` | manual decomposition, unverified |
| `python3-pip` | already in base | OK |
| `apt-get install` | `microdnf install` | syntax fixed, dependency resolution may differ |
| `pip install --break-system-packages` | same flag exists in Fedora's pip | **verify** — Fedora's pip may need alternate flag |

**Other unknowns:**

- **Node 22.22.2 exact version**: Fedora 44's default `nodejs` package is Node 24.x; the upstream builds against 22.22.2. Node 24 may introduce breaking changes in the Adonis build. If so, use NodeSource RPM or `nvm` in the build stage to pin to 22.
- **`admin/` subdirectory**: the Containerfile references `COPY admin/package.json`, `COPY admin/ ./`, `COPY admin/engine/`, `COPY admin/docs` — all assume the build context is the **s7-project-nomad repo root**, not `iac/admin/`. The build must be run with the context set to the nomad source, not this directory.
- **`install/entrypoint.sh`**: references the nomad `install/` directory. Build context must include it.
- **`README.md` + `package.json`**: referenced at the repo root during COPY. Build context must include these.
- **Default user**: upstream runs as root (no `USER` directive); the draft drops to uid 1000 (the `s7` user from our base) but this may cause write-permission failures inside `/app` at startup. Revert to root only if testing confirms it's needed.
- **Port 8080 exposure**: upstream exposes 57080 only; the current running admin container exposes BOTH 57080 and 8080 per `podman image inspect`. The draft matches the running state (both exposed).

## How to build this (when ready, not tonight)

The build MUST run with the nomad source as the context, not this directory. Expected invocation:

```bash
# from wherever nomad source lives
cd /s7/Documents/repo-backup-2026-04-10/s7-project-nomad
podman build \
  -f /s7/skyqubi-private/iac/admin/Containerfile.draft \
  -t localhost/s7-skyqubi-admin:v2.7-draft \
  --build-arg VERSION=v2.7-draft \
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --build-arg VCS_REF="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)" \
  .
```

**Expect the first build to fail on package name resolution.** Iterate on `Containerfile.draft` until microdnf resolves all packages and `node ace build` completes.

## What to do instead of building this tonight

**Nothing.** The iac/ pipeline for `s7-fedora-base` is production-ready and tested. The existing `s7-skyqubi-admin-v2.6.tar` is already signed (will be, once re-signed with the new key) and loaded into podman. The pod runs. The site serves. There's no urgency to rebase the admin container tonight.

**Do this when:**

1. A future session has dedicated build + test time (~2 hours)
2. Jamie is ready to rebuild and test in a non-production context
3. The existing nomad source (from the repo backup) is available on the build machine

## The goal of this directory, restated

**To exist.** When a future Claude session is told "rebase the admin container onto s7-fedora-base," the session finds this draft + this README, knows exactly what's been tried, what's known to be broken, and where to start. That's the knowledge capture.

## Related

- `iac/Containerfile.base` — the base this will eventually use
- `iac/manifest.yaml` — the base package set
- `iac/build-s7-base.sh` — the pipeline that builds the base
- `docs/internal/superpowers/specs/2026-04-12-iac-context-and-next-steps.md` — earlier spec that flagged subsystem #4 as blocked; this draft unblocks it at the "starting point exists" level
- `/s7/Documents/repo-backup-2026-04-10/s7-project-nomad/Dockerfile` — the upstream being ported from
