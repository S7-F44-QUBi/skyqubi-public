# S7 SkyQUB*i* — Lifecycle Guide

> End-user guide for deploy, operate, troubleshoot, and maintain.

## Deploy

```bash
git clone https://github.com/skycair-code/SkyQUBi-public.git
cd SkyQUBi-public
cp .env.example .env.secrets     # Edit: change ALL "CHANGE_ME" values
./start-pod.sh                    # Deploys the full stack
```

**First deploy:** The script auto-creates storage directories at `~/.skyqubi/data/`. All databases initialize fresh with your passwords.

**Image required:** Place `s7-skyqubi-admin-v2.6.tar` in the repo directory. The script auto-loads it on first run.

## Operate

### Start / Stop
```bash
./start-pod.sh          # Start
./start-pod.sh --down   # Stop
./s7-manager.sh         # Interactive menu
```

### Access
| Service | URL |
|---|---|
| Command Center | http://127.0.0.1:57080 |
| AI Chat | http://127.0.0.1:57080/chat |
| Install Apps | http://127.0.0.1:57080 → Install Apps |

### Install Ollama (AI Chat)
```bash
curl -fsSL https://ollama.com/install.sh | sh
OLLAMA_HOST=0.0.0.0:57081 ollama serve &
ollama pull qwen3:0.6b
```

The Command Center auto-detects Ollama. Chat works immediately after pulling a model.

### Install Apps
From the Command Center UI, click **Install Apps**. Available:
- Information Library (Kiwix) — offline Wikipedia
- Education Platform (Kolibri) — learning courses
- Notes (FlatNotes) — note-taking
- Data Tools (CyberChef) — data analysis

## Troubleshoot

### Common Issues

**"AI Assistant service not installed"**
Ollama runs on the host, not in a container. Start it:
```bash
OLLAMA_HOST=0.0.0.0:57081 ollama serve &
```
The `0.0.0.0` binding is required so the pod can reach it.

**App install shows "network not found"**
Restart the admin container to reload the network config:
```bash
podman restart s7-skyqubi-s7-admin
```
Then retry the install from the UI.

**"Access denied" / database errors after changing passwords**
If you change `.env.secrets` passwords after first deploy, the databases still have the old passwords. Either:
1. Keep the same passwords, or
2. Delete the data directories and redeploy fresh:
```bash
./start-pod.sh --down
rm -rf ~/.skyqubi/data/mysql ~/.skyqubi/data/postgres
./start-pod.sh
```
**Warning:** This deletes all database data. Back up first.

**SELinux "cannot apply additional memory protection"**
```bash
sudo setsebool -P domain_can_mmap_files on
```
Then restart the pod.

**Port conflict**
If another service uses ports 57080/57086/57090, stop it or change the ports in `skyqubi-pod.yaml`.

### Health Check
```bash
# Full lifecycle test (40 tests covering pod, DBs, CWS Engine, AI chat, security, repos, docs)
./s7-lifecycle-test.sh

# Quick status
podman pod ps
podman ps --pod

# Detailed check
podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:7077/status
podman exec s7-skyqubi-s7-postgres pg_isready
podman exec s7-skyqubi-s7-redis redis-cli ping
```

The lifecycle test is the canonical "is everything healthy" check. It exits 0 only if all 40 tests pass. Run it after deploy, after upgrades, and before announcing changes are live.

### Logs
```bash
# Admin container (CWS Engine + Command Center)
podman logs s7-skyqubi-s7-admin

# Specific database
podman logs s7-skyqubi-s7-postgres
podman logs s7-skyqubi-s7-mysql
```

## Maintain

### Update
```bash
cd SkyQUBi-public
git pull
./start-pod.sh --down
./start-pod.sh
```

### Backup
```bash
# Database data
cp -r ~/.skyqubi/data ~/skyqubi-backup-$(date +%Y%m%d)
```

### Password Rotation
1. Stop the pod: `./start-pod.sh --down`
2. Back up data: `cp -r ~/.skyqubi/data ~/skyqubi-backup`
3. Delete DB dirs: `rm -rf ~/.skyqubi/data/mysql ~/.skyqubi/data/postgres`
4. Update `.env.secrets` with new passwords
5. Redeploy: `./start-pod.sh`

### Storage Locations
```
~/.skyqubi/data/
├── admin/      — uploads, logs, ZIM files
├── mysql/      — admin database (DO NOT DELETE without backup)
├── postgres/   — CWS engine database (DO NOT DELETE without backup)
├── redis/      — session cache (safe to delete)
└── qdrant/     — vector embeddings (rebuilt on next use)
```

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                    s7-skyqubi pod                     │
│                                                      │
│  ┌─────────────┐  ┌──────────┐  ┌───────────────┐   │
│  │  s7-admin   │  │ s7-mysql  │  │  s7-postgres  │   │
│  │ Command     │  │ Admin DB  │  │  CWS Engine   │   │
│  │ Center      │  │          │  │  Database      │   │
│  │ + CWS Engine│  └──────────┘  └───────────────┘   │
│  │ + SkyAVi    │                                     │
│  │ + Samuel    │  ┌──────────┐  ┌───────────────┐   │
│  └─────────────┘  │ s7-redis │  │   s7-qdrant   │   │
│                    │ Cache    │  │   Vectors     │   │
│                    └──────────┘  └───────────────┘   │
└──────────────────────────────────────────────────────┘
        │                              │
   :57080 (UI)                    :57090 (PG)
   localhost only                 localhost only

┌─────────────────┐     ┌──────────────────────────────┐
│  Ollama (host)  │     │    App Containers (optional)  │
│  :57081         │     │  Kiwix :8090  CyberChef :8100 │
│  8 AI models    │     │  Notes :8200  Kolibri :8300   │
└─────────────────┘     └──────────────────────────────┘
   all localhost only           all localhost only
```

## Known Single Points of Failure

| SPOF | Impact | Mitigation |
|---|---|---|
| MySQL password mismatch | All app installs fail, chat fails | Never change passwords without wiping DB dirs |
| Ollama not running | Chat returns error | Start Ollama before using chat |
| SELinux enforcing | All containers crash | Run `setsebool` command above |
| Admin container restart | Network fix reloads (v2.6 has it baked in) | Use v2.6+ image |
| `/var/tmp` < 1GB | Image builds fail | `sudo mount -o remount,size=3G /var/tmp` |

## Security

- All ports bound to 127.0.0.1 — nothing exposed to your network
- CWS API requires Bearer token
- Containers run rootless — no root privileges
- Civilian use only — baked into the license

---

*S7 SkyQUB*i* — AI + Humanity. Built on Trust.*
*"Love is the architecture."*
