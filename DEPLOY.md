# S7 SkyQUB*i* — Deployment Guide

> *"Love is the architecture."*
> Civilian Use Only — CWS-BSL-1.1

## Requirements

- **Linux** — Fedora 44+, RHEL 9+, Debian 12+, Ubuntu 22.04+, or Arch
- **Podman 5.x+** (rootless)
- **envsubst** (from gettext)
- **Python 3**
- **4GB+ RAM** (8GB recommended)
- **10GB+ free disk**

## Quick Start

```bash
# 1. Clone
git clone https://github.com/skycair-code/SkyQUBi-public.git
cd SkyQUBi-public

# 2. Get the admin image
# Download s7-skyqubi-admin-v2.6.tar from the releases page
# Place it in this directory

# 3. Configure secrets
cp .env.example .env.secrets
chmod 600 .env.secrets
# Edit .env.secrets — change ALL "CHANGE_ME" values
# Generate passwords: python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# 4. Pre-audit (checks your system before deploying)
./start-pod.sh --check

# 5. Deploy
./start-pod.sh

# 6. Open Command Center
xdg-open http://127.0.0.1:57080
```

## Pre-Deployment Audit

The deploy script runs a full system audit before deploying. It checks:

| Check | What it validates |
|---|---|
| OS | Linux distribution detected |
| Packages | podman, envsubst, python3, curl, git installed |
| User | Not running as root |
| Podman | Rootless mode, subuid/subgid, socket active |
| SELinux | Status + required booleans |
| Disk | Minimum 10GB free |
| /var/tmp | Minimum 512MB (for image operations) |
| Secrets | .env.secrets exists, permissions 600, no CHANGE_ME values |
| Image | Admin image tar or loaded image present |
| SQL | Init scripts present |
| Config | Pod YAML present |
| Ports | No conflicts on 57080/57086/57090 |

Run `./start-pod.sh --check` to audit without deploying.

If any check fails, the script tells you exactly how to fix it.

## What Gets Deployed

### Full port map

The appliance uses two distinct port namespaces: **host-side** (everything you can `curl` from your local browser at `127.0.0.1:57xxx`) and **pod-internal** (ports that exist only inside the pod's network namespace and are not reachable from the host).

**Host-side ports — these are what your browser and scripts see:**

| Service | Port | Bind | Notes |
|---|---|---|---|
| s7-admin (Command Center) | `127.0.0.1:57080` | loopback | Main UI. Open in Vivaldi. |
| s7-qdrant (Vector memory) | `127.0.0.1:57086` | loopback | Qdrant dashboard at `/dashboard`. |
| s7-postgres (CWS DB) | `127.0.0.1:57090` | loopback | pgvector. Requires PGPASSWORD. |
| Ollama (host process) | `*:57081` | wildcard | See "Ollama wildcard" below. |
| CWS engine (host-side) | `127.0.0.1:57077` | loopback | Host-side copy of the engine — separate from the pod-internal one. |
| persona-chat | `127.0.0.1:57082` | loopback | Carli / Elias / Samuel. Also serves `/health` and `/digest`. |

**Pod-internal ports — these exist only inside the pod namespace:**

| Service | Port | Notes |
|---|---|---|
| s7-mysql | `pod:3306` | Admin UI database. Not reachable from host. |
| s7-redis | `pod:6379` | Session cache. Not reachable from host. |
| CWS engine (pod-internal) | `pod:7077` | Pod-internal copy of the engine — separate from the host-side one on 57077. |

### Why there are two CWS engines

S7 runs **two copies of the CWS engine**. This is intentional:

- The **pod-internal** copy on `pod:7077` serves requests from inside the pod (the admin UI container reaches it as `127.0.0.1:7077` because they share the pod's network namespace).
- The **host-side** copy on `127.0.0.1:57077` serves requests from host-side tools and from the persona-chat service, which runs as a host systemd user service and cannot see the pod's loopback.

Neither is a mirror of the other. They are two independent running processes with the same code. A request hits exactly one of them based on where it originates. This split is documented in `docs/internal/postmortems/2026-04-14-dual-cws-engine-discovery.md` — the first time the audit gate caught drift between the two.

### Ollama wildcard

Ollama binds to `*:57081` (wildcard, not loopback) because the pod reaches Ollama via `host.containers.internal:57081` under the pasta network path — and `host.containers.internal` only resolves to a non-loopback host IP. This is an intentional tradeoff acknowledged in `iac/audit/pinned.yaml` as `ollama-wildcard-bind`. Everything else binds to `127.0.0.1` only.

All other ports bind to **127.0.0.1 only** — nothing else is exposed to your network. The wildcard Ollama bind is protected by the host firewall.

## Post-Deploy

The script automatically:
- Waits for all services to boot
- Configures Ollama connection (if running on host)
- Fixes service storage paths for your system
- Binds all app ports to localhost
- Marks built-in services (SkyAV*i*, Qdrant, Ollama)
- Verifies 7 core services and reports status

## AI Chat (Ollama)

Optional — install Ollama for AI chat. **The `curl | sh` path below is the upstream-documented install method. For a more sovereign install, download the Ollama binary from its GitHub release, verify its sha256 against a pinned manifest, and run it directly. S7's Pillar 1 airgap roadmap tracks this as a vendored-binary swap for the bootc image.**

```bash
# Upstream-documented install (internet required at install time):
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama under the S7 systemd user unit (preferred) which
# pins OLLAMA_HOST=0.0.0.0:57081 + OLLAMA_KEEP_ALIVE=24h + CPU
# pinning + pre-warm of s7-carli:0.6b:
systemctl --user enable --now s7-ollama.service

# OR start it by hand:
OLLAMA_HOST=0.0.0.0:57081 ollama serve &
ollama pull qwen3:0.6b
```

The `0.0.0.0` binding is required so the pod can reach Ollama on the host via `host.containers.internal:57081`. This is the pinned `ollama-wildcard-bind` entry in the audit gate.

## Image Signing (Optional)

If the image tar has a `.sig` file and a `s7-image-signing.pub` key is present, the deploy script verifies the signature before loading. Unsigned or tampered images are rejected.

## Stop / Restart

```bash
./start-pod.sh --down    # Stop
./start-pod.sh           # Start (re-runs pre-audit)
./s7-manager.sh          # Interactive menu
```

## Security

- All ports: 127.0.0.1 only
- CWS API: Bearer token required
- Containers: rootless, no privilege escalation
- Secrets: 600 permissions, never committed to git
- Image: signature verification (when signed)
- License: Civilian use only

## Platform Support

| Distro | Package Manager | Install Command |
|---|---|---|
| Fedora/RHEL | dnf | `sudo dnf install podman gettext python3 curl git` |
| Debian/Ubuntu | apt | `sudo apt-get install podman gettext-base python3 curl git` |
| Arch | pacman | `sudo pacman -S podman gettext python curl git` |

---

*S7 SkyQUB*i* — AI + Humanity. Built on Trust.*
*Patent Pending: TPP99606 — 123Tech / 2XR, LLC*
