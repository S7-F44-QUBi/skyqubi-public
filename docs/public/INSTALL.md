# Install S7 SkyQUB*i*

> **Release status (as of 2026-04-14):** S7 SkyQUB*i* is in the
> **pre-launch testing window**. Full public launch is
> **July 7, 2026 · 7:00 AM Central (GO-LIVE Release 7)**. The
> install instructions below are stable for the current testing
> deployment; the full production deployment with the immutable-
> fork rebuild architecture lands with the GO-LIVE ceremony. See
> [README.md](README.md) for the full release status and path
> to 2026-07-07.

S7 runs as a set of containers inside a single Podman pod on your own Linux machine. No cloud dependency. No external telemetry. Everything you install here stays on your hardware.

## Prerequisites

- **Linux** (Fedora 40+ recommended; any systemd-based distro with `podman` available works)
- **Podman** 4.x or newer — `sudo dnf install podman` or equivalent
- **~30 GB free disk** for models + database
- **~16 GB RAM minimum** (32 GB recommended for the full 7-witness set)
- **A GPU is optional** — the 3+1 lite witness set runs on CPU-only hardware; the 7+1 full set benefits from any modern GPU
- **Outbound internet access for initial model download only** — the system can run fully offline afterward

## First install

Clone the public repository:

```bash
git clone https://github.com/skycair-code/SkyQUBi-public.git
cd SkyQUBi-public
```

Start the pod:

```bash
./start-pod.sh
```

This brings up:

- PostgreSQL (port 57080, bound to `127.0.0.1` only)
- Qdrant vector database (port 57090)
- Ollama model host (port 57086)
- The SkyQUB*i* engine container that connects them

The `start-pod.sh` script is idempotent — running it twice is safe. See `skyqubi-pod.yaml` for the full pod definition.

## Downloading the witnesses

First run will pull the three lite-witness models (~6 GB total):

- `qwen2.5:3b`
- `deepseek-coder:1.3b`
- `qwen3:0.6b`

Plus the embedding model `all-minilm:latest` (~23 MB).

For the full 7+1 witness set, see the advanced install section in `DEPLOY.md` (larger download, ~60 GB).

## Verifying the install

After the pod is up, run the lifecycle test:

```bash
./s7-lifecycle-test.sh
```

You should see **40/40 PASS**. If anything fails, check:

- Pod status: `podman pod ps`
- Container health: `podman ps --all`
- Ollama reachable: `curl http://127.0.0.1:57086/api/tags`
- Logs: `podman logs s7-skyqubi-engine`

## Ports you should know

All S7 services bind to `127.0.0.1` by default — nothing is exposed to your LAN without explicit configuration.

| Port  | Service            |
|-------|--------------------|
| 57080 | PostgreSQL         |
| 57086 | Ollama             |
| 57088 | Public chat API    |
| 57090 | Qdrant             |

If you want to reach the system from another machine on your network, configure a reverse proxy (Caddy, nginx, Traefik) — do **not** rebind the services themselves. Exposing a database or an inference engine directly to a network is an invitation to trouble.

## Uninstall

```bash
podman pod stop s7-skyqubi
podman pod rm s7-skyqubi
```

That removes everything. The downloaded models live under `~/.ollama/` and can be deleted separately if you want to reclaim disk.

## Getting help

- Open an issue on [GitHub](https://github.com/skycair-code/SkyQUBi-public/issues)
- Email [omegaanswers@123tech.net](mailto:omegaanswers@123tech.net)

Keep in mind: the install is currently in "Core in Development" status before the **July 7, 2026** public launch. Expect rough edges until that date. File issues freely.
