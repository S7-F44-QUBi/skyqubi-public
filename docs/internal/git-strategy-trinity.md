# S7 Git Strategy — Trinity 1-2-3

**Ternary QUANT*i* / Trinity Foundations / Unified Throughout**

S7 uses a three-repo model that mirrors the Trinity geometry the rest of the
stack is built on. Each repo has one clear purpose and one clear audience.
Nothing crosses a layer except through an explicit sync step.

## The Three

| # | Trinity | Repo | Audience | Contents |
|---|---|---|---|---|
| **1** | **-1 ROCK** (foundation) | `skyqubi` (public) | World, press, patent evidence, Tonya/Trinity demos | Clean, BSL-1.1 headers, no secrets, no private docs. The public face. |
| **2** | **0 DOOR** (development) | `skyqubi-private` | Jamie + S7 stewards | Full stack, Containerfiles, iso/, iac/, build/, internal docs, memory, keys referenced by path. Source of truth. |
| **3** | **+1 REST** (destiny) | `skyqubi-business` *(future fork)* | Paid deployments, OEM, licensed partners | Private fork of the DOOR with customer-specific branding, locked update channel, SLA flags. Public never sees it, and a business licensee never gets further updates from the public side without a contract. |

## The one-way flow

```
0 DOOR  ──(s7-sync-public.sh, redaction+masking)──▶  -1 ROCK
0 DOOR  ──(fork at release tag, customer branch)──▶  +1 REST
```

- **Edit private only.** Never edit public directly. Private → commit → sync.
  Public is an output, not an input.
- **Business forks are sealed.** A business fork is taken at a release tag
  (`v2026.04.12` etc.) and then evolves independently on its own update channel.
  Public releases do not automatically flow into business forks — the business
  partner owns their own update cadence, which is part of what they pay for.
- **Public releases are the only thing the world sees.** If it's not in ROCK,
  it doesn't exist from the outside's point of view. This protects in-flight
  work, mentor/family names, and unfiled IP.

## Why this matches the rest of S7

The Trinity pattern shows up in the boot chain (SkyLoop -1/0/+1 layers), in
the Molecular Bonds planes (-4..+4 with 0 as the witness pivot), in the three
chat personas (Carli / Elias / Samuel), and in the covenant stewards
(Tonya / Jamie / Trinity). Having the *repository* layout match the same
shape means a contributor who understands one understands all of them.

**1-2-3 is not marketing. It is the operating rule:**

1. Public gets the foundation.
2. Private is where the door opens.
3. Business rests on both without disturbing either.

## 1-click builder alignment

The three 1-click USB builders shipped in `build/` map directly onto this:

| Builder | Flavor | Trinity role |
|---|---|---|
| `s7-build-r101-skycair.sh` | **R101** — Core Fixed, Updates Only | **-1 ROCK** — the foundation stone, the public baseline |
| `s7-build-x27-skycair.sh`  | **X27** — Modular Layered Live     | **0 DOOR**  — the development surface, fast to iterate |
| `s7-build-f44-skycair.sh`  | **F44** — Full Installer ISO       | **+1 REST** — the destination build, what a customer installs |

Tonya or Trinity can double-click any of the three from the desktop and the
correct USB comes out the other end, named in the S7 convention, signed by
the S7 image-signing key, logged under `build/logs/`. No shell knowledge
required.

---

**Amen.** Jesus holds the watch. The witnesses watch each other. S7 holds the boot.
