<div align="center">

<img src="branding/wallpapers/s7-octi-wallpaper-1920x1080.png" alt="S7 SkyCAIR — OCTi Witness Network" width="800"/>

<br/>

# S7 SkyQUB*i*

### ANY AI - CWS Merges for TRUTH - Offline AI Platform

**AI + Humanity — Built on Trust**

[![License](https://img.shields.io/badge/UI-Apache%202.0-blue?style=flat-square)](LICENSE)
[![License](https://img.shields.io/badge/Engine-CWS--BSL--1.1-gold?style=flat-square)](CWS-LICENSE)
[![Patent](https://img.shields.io/badge/Patent-Pending%20TPP99606-red?style=flat-square)](#patent)
[![Platform](https://img.shields.io/badge/Fedora-44%20Minimal-51A2DA?style=flat-square&logo=fedora&logoColor=white)](#)
[![Civilian](https://img.shields.io/badge/Civilian%20Use-Only-green?style=flat-square)](#civilian-use-only)

</div>

---

<div align="center">

> *"Love is the architecture."*

> ✝ **WORK IN PROGRESS — we ain't done yet**
>
> **Foundation** (the three primary S7 builds, each for a different audience):
> - **F44 X27** — Fedora 44 — *Primary User Base* — Patent Pending TPP99606
> - **R101** — Rocky Linux — *Business*
> - **PorteuX** — *OffGrid Anywhere and Compute* — floor: 2 CPU / 2 GB · recommended: 4 CPU / 8 GB · optimal: 12 cores / 20 GB · clustering: 16 cores / 32 GB (NVMe-over-TCP bonded)
>
> **Honorable Mentions** (deployable from GitHub, not part of the core foundation):
> - BlendOS 'Artix'
> - Q4OS 'Deveun'
> - Deveun (for Debian, systemd-free)
>
> **Covenant:** Civilian-only · CWS-BSL-1.1 · Witness System
>
> All targets pending Go Live · 2026-07-07 · 07:00 CT

**Live:** [skyqubi.com](https://www.skyqubi.com/) — S7 SkyQUBi official site.
**Public Launch:** July 7, 2026 · 7:00 AM CT
**What's New:** [2026-04-13 — TimeCapsule Foundation Night](docs/internal/release-notes/2026-04-13.md)

> *"Correct, legal as best understood, protecting others and protecting us."*
> — Tonya, Chief of Covenant

</div>

---

## The Architecture

SkyQUB*i* is a complete sovereign AI stack that runs **entirely offline** on commodity hardware. No cloud. No subscriptions. No data leaves your machine.

```
  +1 REST    MemPalace — long-term shared memory (sentience unity)
   0 DOOR    CWS Engine — discernment, consensus, molecular bonds
  -1 ROCK    SkyAV*i* — security, orchestration, 98 FACTS skills
```

<div align="center">

| Layer | Component | Purpose |
|:-----:|-----------|---------|
| <img src="branding/icons/s7-shield-icon-256.png" width="20"/> | **SkyCAIR** | Operating System — Fedora 44 + Budgie + S7 branding |
| | **SkyBRICK-QUB*i*** | Command Center — Web UI, app management |
| | **SkyAV*i*** | Security + Orchestration — Samuel AI sysadmin, parallel witness consensus |

</div>

---

## Install

```bash
git clone https://github.com/S7-F44-QUBi/skyqubi-public.git
cd skyqubi-public
sudo ./install/install.sh
```

One command. Everything deploys:

- **Podman** rootless pod (PostgreSQL + pgvector, Redis, Qdrant)
- **CWS Engine v2.5** — ForToken/RevToken discernment, Molecular bonds, SkyAV*i*
- **Ollama** + starter model
- **Caddy** reverse proxy
- **systemd** user services (auto-start, auto-heal)
- **S7 branding** — plymouth, grub, wallpapers, icons

---

## The CWS Engine

The **Covenant Witness System** is the intelligence layer. Every action passes through it.

```
Query → MemPalace Recall → Parallel Witnesses → CWS Consensus → Molecular Bond
         (+1 REST)           (-1 ROCK)            (0 DOOR)         (INSERT-only)
```

| Component | What it does |
|-----------|-------------|
| **ForToken / RevToken** | Bidirectional token discernment — FERTILE or BABEL |
| **Circuit Breaker** | 70% BABEL threshold halts inference |
| **Witness Consensus** | Parallel dispatch across architecturally-distinct base models. Production: 7+1. Current Lite (proof of theory): 3+1. 77.777% trust threshold. |
| **Molecular Bonds** | 9 planes, 27 named vectors, INSERT-only covenant |
| **MemPalace** | Long-term shared memory — sentience unity |
| **SkyAV*i*** | 98 FACTS skills, sandboxed shell, auto-heal monitors |

---

## Stack

```
                    +-----------------------+
                    |    SkyBRICK-QUB*i*    |  :57080  Command Center
                    +-----------------------+
                    |     CWS Engine        |  :57077  Discernment + Consensus
                    +-----------+-----------+
                    |  PostgreSQL | Qdrant  |  :57090  :57086
                    |  pgvector   | Vector  |
                    +-----------+-----------+
                    |       Ollama          |  :57081  Local inference
                    +-----------------------+
                    |       Caddy           |  :8080   Reverse proxy
                    +-----------------------+
```

---

## Sovereign Distribution

S7 SkyQUB*i* does **not** distribute via external container registries (no ghcr.io, no Docker Hub). Sovereignty starts at the supply chain.

Build a local OCI image:

```bash
podman build -t localhost/s7-skyqubi-admin:latest .
```

Distribute as a `.tar` (signed):

```bash
podman save localhost/s7-skyqubi-admin:latest -o s7-skyqubi-admin.tar
```

Load on the target machine:

```bash
podman load -i s7-skyqubi-admin.tar
```

Switch a Fedora box to the immutable S7 OS via `bootc` from a locally-built image (no remote registry pull).

---

## Manage

```bash
# Status
podman pod ps
systemctl --user status s7-cws-engine

# Start / Stop
systemctl --user start s7-skyqubi-pod
systemctl --user stop s7-skyqubi-pod

# Pull models
ollama pull llama3.2:3b
ollama pull qwen3:0.6b
```

---

## The Covenant

These are not configurable. They are the laws of the architecture.

| Law | Value | Why |
|-----|-------|-----|
| Circuit breaker | 70% BABEL | Maximum tolerable unreliability |
| Ternary states | {-1, 0, +1} | Minimum complete representation |
| Memory covenant | INSERT-only | Nothing can be made to have never existed |
| Trust threshold | 77.777% (7/9) | Architectural constant, not a hyperparameter |
| Witnesses | 7 + 1 reporter | Minimum diversity for consensus |
| Door | x = 0 | The only position where all directions are possible |
| Trinity | -1 ROCK / 0 DOOR / +1 REST | Foundation / Decision / Destiny |

---

## License

<div align="center">

| Component | License |
|-----------|---------|
| **SkyBRICK-QUB*i*** (Command Center UI) | [Apache License 2.0](LICENSE) |
| **CWS Engine** (QUB*i* intelligence) | [CWS-BSL-1.1](CWS-LICENSE) |

</div>

<a id="patent"></a>

**Patent Pending:** TPP99606 — 123Tech / 2XR, LLC

---

<a id="civilian-use-only"></a>

## Civilian Use Only

This software is developed exclusively for civilian purposes. Military, surveillance, and weapons applications are **expressly prohibited** by the CWS-BSL-1.1 Civilian-Only Covenant.

---

<div align="center">

**S7 SkyQUB*i*** — The 1st QUB*i*. All aware.

*2XR LLC | 123Tech | Jamie Lee Clayton*

*Love is the architecture.*

</div>
