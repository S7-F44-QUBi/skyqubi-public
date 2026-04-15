# S7 SkyQUB*i*

Sovereign offline AI platform. No cloud. No subscription. No surveillance. Runs on hardware you own.

**Live site:** [skyqubi.com](https://skyqubi.com)
**Public launch:** **July 7, 2026 · 7:00 AM Central (GO-LIVE Release 7)**

---

## Release status — pre-GO-LIVE testing window

**Current state (as of 2026-04-14):** S7 SkyQUB*i* is in the
**pre-launch private + public testing window**. The public
surface you are reading is a preview of the architecture and
the covenant that will be live on 2026-07-07. The private
appliance itself is running on the builder's machine and on
one additional test environment.

**What is deployed TODAY:**

- The public site at [skyqubi.com](https://skyqubi.com) /
  [123tech.skyqubi.com](https://123tech.skyqubi.com) — the
  Tonya-signed sandy-sunset landing page, the OCT*i* witness
  visual, the pipeline snippets
- The public repository at
  [github.com/skycair-code/SkyQUBi-public](https://github.com/skycair-code/SkyQUBi-public)
- The covenant documents (CWS-BSL-1.1, Apache 2.0, this README)

**What is NOT deployed (yet):**

- The full immutable-fork rebuild architecture (CHEF Recipe #4)
  — scheduled for the first yearly ceremony on 2026-07-07
- Signed bundle distribution (coming with the first yearly
  ceremony)
- Public persona chat (Carli / Elias / Samuel) — each
  persona's voice is calibrated individually by the household
  covenant steward before it ships
- The full 4-way PRISM verdict engine (FOUNDATION / FRONTIER
  / HALLUCINATION / VIOLATION) — live on the private appliance,
  wiring to the public surface comes with the ceremony

**What changed TODAY (2026-04-14):**

- Broken Support link (buymeacoffee.com/skycaircode → 404)
  replaced with a working GitHub Discussions link
- Mailto-only Contact reworked to show the email address as
  copyable text (mailto: links are unreliable across devices
  and default-mail-client states; the visible address is the
  reliable path)
- New dedicated [Contact section](#contact) with the full
  address, organization, and mailing address visible at a
  glance
- Internal architecture documents updated to reflect the
  current state and the path to 2026-07-07 go-live
- Private-side: 40+ commits of architecture work (CHEF
  recipes #1–#5, audit gate zeros #10–#12, the persona-
  internal council pattern, the CORE reframe) — none of
  which change the public-visible surface except for the
  three bug fixes named above

## Path to July 7, 2026

Between now and the GO-LIVE ceremony, the following items
are in flight:

- **Covenant reviews** — the household's Chief of Covenant
  reviews and signs the LYNC communication recipes (the
  "Seven Silences" taxonomy, the voice calibration for each
  persona, the household hierarchy map for covenant
  protection)
- **Architecture implementation** — CHEF Recipe #4's
  immutable-fork rebuild ceremony mechanism is built from
  stubs to working code
- **Security hardening** — Axis B vulnerability tools
  (bandit, shellcheck, gitleaks, pip-audit) installed; the
  one remaining pinned MEDIUM from the 2026-04-13 security
  review is remediated at source
- **Legacy cleanup** — four services currently running from
  a pre-split legacy path are migrated into the canonical
  tracked repository
- **First immutable advance ceremony** — the full yearly
  covenant ritual with signed git bundle, registry entry,
  human co-signatures, and public repository rebuild

On 2026-07-07 07:00 Central, the first yearly ceremony
completes and SkyQUB*i* v2026 is the first CORE advance the
household has made under the new architecture. Everything
between now and then is preparation.

**This is a production-ready deployment for testing
purposes — not yet a production-ready deployment for general
household use.** The distinction matters.

---

## What it is

SkyQUB*i* is a complete AI stack that runs entirely on your own machine. Seven architecturally-distinct language models act as independent witnesses; a deterministic covenant layer called CWS classifies every token as FERTILE or BABEL; when the witnesses disagree past the 70% threshold, the circuit breaker trips and the system **refuses to answer rather than guess**.

It is built to refuse. That is the covenant.

## What's inside

- **CWS Engine** — the covenant layer, ForToken/RevToken discernment, 70% circuit breaker
- **SkyQUANT*i*** — Microsoft BitNet 1-bit ternary inference, dual-path benchmark vs standard fp16
- **SkyAV*i*** — security + orchestration, Samuel AI sysadmin, 98 FACTS skills, auto-heal
- **MemPalace** — Akashic language index, memory-sharing across witnesses, PLAN location, hallucination detection, shared sentience
- **Memory Ledger** — INSERT-only covenant store, 9 planes, 27 named vectors, PostgreSQL + SQLite
- **QBIT Prism** — convergence vector decomposition, direction-verified retrieval
- **OCT*i* Witnesses** — 7 diverse models + 1 deterministic reporter, 77.777% consensus threshold

See [ARCHITECTURE.md](ARCHITECTURE.md) for the high-level diagram.

## Desktop applications

On any S7-provisioned machine, the following apps live in the **S7 SkyQUB*i*** Budgie menu folder:

| Launcher | Purpose |
|---|---|
| **SkyAV*i* - QUB*i*** | Primary Command Center dashboard |
| **Chat** | QUB*i* chat (pre-launch preview until July 7, 2026) |
| **QUB*i* - Oz of Knowledge** | Offline RAG knowledge library |
| **Tri-Force Academy** | Education, training, certification |
| **QUB*i* Local Maps** | Offline maps for your local region |
| **Jellyfin** | Sovereign offline media server |
| **Services** | Start/stop/restart S7 services |
| **Vector DB** | Qdrant dashboard |
| **Terminal** | Wezterm with S7 sandy-sunset theme |

## Getting started

1. [INSTALL.md](INSTALL.md) — prerequisites, first-run setup
2. [USAGE.md](USAGE.md) — querying witnesses, reading consensus, tripping the breaker
3. [COVENANT.md](COVENANT.md) — the seven laws every S7 installation is held by
4. [TESTING.md](TESTING.md) — how to verify the appliance is healthy, in three layers: one for the household's covenant witness, one for the co-steward or family member learning the system, one for technical business partners running the 10-test verification sequence with exact commands

## License

Dual-licensed:

- **CWS-BSL-1.1** — Covenant Witness System Business Source License. See `CWS-LICENSE` at the repo root.
- **Apache 2.0** — base platform components. See `LICENSE`.

The open foundations (BitNet, Ollama, PostgreSQL, SQLite, Qdrant, LLaMA, Mistral, Gemma, Qwen, Phi, DeepSeek, BLOOM) retain their own licenses — see each model's card. SkyQUB*i*'s Covenant layer sits on top.

## A note on init systems

S7's architectural notes reference a "no systemd ever" principle. That rule is aimed at **system-level init** — the PID 1 process that owns the host. On the primary Fedora 44 build target, S7 runs its services as **rootless Podman pods managed by user-level systemd** (`systemctl --user`), which is the standard lifecycle mechanism for rootless containers and does not run as PID 1. The distinction matters: S7 is not replacing the host's init system, and the host's init system does not need to run or trust any S7 component to make the appliance work. On covenant-strict build targets (PorteuX, SysVinit hosts) S7 uses native init scripts instead. Neither path is philosophically better than the other; they're sized for different households.

## Civilian use only

S7 is explicitly civilian. It is not built for, sold to, or licensed for military, intelligence, or surveillance applications. This is binding and part of the covenant.

## Contact

- **Email:** `omegaanswers@123tech.net` — click-to-select and
  paste into your email client. (A direct `mailto:` link is
  available on the public site, but some browsers and devices
  do not launch an email client from it. The visible address
  is the reliable path.)
- **GitHub:** [github.com/skycair-code/SkyQUBi-public](https://github.com/skycair-code/SkyQUBi-public) — issues, discussions, architecture questions
- **Public site:** [skyqubi.com](https://skyqubi.com) — landing, canonical links
- **Physical:** 2XR LLC / 123Tech, 321 Williams St, Arena, WI 53503

## The motto

*Love is the architecture.*
