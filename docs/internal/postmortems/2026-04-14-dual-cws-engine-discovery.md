---
title: Dual CWS Engine discovery + near-regression
date: 2026-04-14
severity: WOULD-HAVE-BEEN-HIGH (caught by Jamie Love RCA step 2 — tool told the truth)
status: closed — source tree aligned, ground-truth now documented
reporter: Chair (session 2026-04-14, 8hr trust block)
---

# Dual CWS Engine discovery + near-regression

## What happened

During Jamie's authorized port-alignment sweep (moves 1 and 2: cosmetic comment fix + align source tree with running reality), the Chair assumed a single ground truth for the CWS engine port (`57077`) based on host-side `ss -tlnp` output. The Chair edited three files under that assumption:

- `s7-lifecycle-test.sh` E01–E06 (6 test invocations)
- `skyqubi-pod.yaml` — `CWS_ENGINE_URL` env var
- `start-pod.sh` — 2 CWS health-check calls

Then ran `s7-lifecycle-test.sh`. Result: **48/55 → 44/55**. Four new regressions (E01, E02, E04, E05, E06 failed; E03 surprisingly passed).

## Why E03 surprised everyone

E03 is the only E-test that reads `$CWS_TOKEN` and hits `/skyavi/core/status`. The test failure would have been on the curl portion, not the auth portion. The Chair's theory is that E03 passed because a *different* code path — or simply a test that was already broken and reporting FAIL before the edit — shifted its failure mode. **Not rigorously confirmed. Marked as unresolved micro-mystery for future investigation.**

## Jamie Love RCA step 2 caught it: tool told the truth

The Chair did not fix the report. The Chair ran the actual test, read the output, and believed the output over the theory. Step 2 of `jamie-love-rca.md`: *"The tool is the second witness. Its report is the ground truth."*

Had the Chair rationalized the regression away ("my edits are forward-correct, the test will re-green after pod restart, ship it"), this would have been a real incident landing on private/main with a 4-test regression masquerading as a 2-gap closure.

## The actual ground truth

There are **two CWS engines** in play on this host:

| Engine | Port | Namespace | Launched by | Visible to |
|---|---|---|---|---|
| **Pod-internal CWS** | `7077` | pod loopback (shared among s7-skyqubi pod containers) | something inside the pod (pod YAML, probably admin container or pod-init) | `podman exec s7-skyqubi-s7-admin curl 127.0.0.1:7077` — YES |
| **Host-side CWS** | `57077` | host loopback | `autostart/s7-cws-engine.desktop` — uvicorn launched on user login | host user sees via `ss -tlnp 127.0.0.1:57077` — YES |

**Evidence**: `podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:7077/status` returns live v2.5 engine JSON inside the pod. Meanwhile `ss -tlnp` on host shows a *separate* listener at `127.0.0.1:57077`.

These are two different processes serving two different namespaces. The lifecycle test exercises the **pod-internal** one (via `podman exec`). The autostart `.desktop` launcher feeds the **host-side** one. Neither is "wrong" — they are serving different tiers of the appliance.

## The corrected sweep

After revert + second sweep, the Chair's actual authorized edits become:

**Host-facing launchers (KEPT)** — these open URLs from the host user's desktop session, so they must point at host-accessible ports, which are `57xxx` via pod `hostPort` forwarding + host-side services:

| File | Change |
|---|---|
| `autostart/s7-cws-engine.desktop` | `7077 → 57077` (Comment + Exec) — host uvicorn launcher matches host-side CWS |
| `profiles/.../config/autostart/s7-cws-engine.desktop` | same |
| `profiles/.../s7-skyqubi-qdrant.desktop` | `7086 → 57086` (Comment + Exec) — host xdg-open targets pod hostPort |
| `profiles/.../s7-skyqubi-chat.desktop` | `7080 → 57080` — admin hostPort |
| `profiles/.../s7-skyqubi-academy.desktop` | `7080 → 57080` |
| `profiles/.../s7-skyqubi-knowledge.desktop` | `7080 → 57080` |
| `profiles/.../s7-skyqubi-maps-local.desktop` | `7080 → 57080` |

**Pod-internal test + config (REVERTED — pod uses pod-loopback 7xxx, not host 57xxx)**:

| File | State |
|---|---|
| `s7-lifecycle-test.sh` E01–E06 | reverted to `7077` |
| `skyqubi-pod.yaml` `CWS_ENGINE_URL` | reverted to `7077` |
| `start-pod.sh` health checks | reverted to `7077` |

## Lifecycle test before → after (verified)

| State | Pass | Fail | Delta |
|---|---|---|---|
| Before sweep | 48 | 7 | baseline |
| After erroneous edits | 44 | 11 | **−4 regression** (caught before commit) |
| After revert | 47 | 8 | baseline minus R01 (git dirty = my own uncommitted state, will recover on commit) |

Remaining 7 failures are pre-existing Ollama drift (P14, A01, A03, A04, A06, A07, E06) — same set the session has known about since M7. **Zero net regression after revert.**

## Pinned corrections to the Chair's mental model

### Correction 1 — "running reality" is not a single number

The earlier `ss -tlnp` reading gave the Chair four host-loopback listeners (`57077`, `57080`, `57086`, `*:7081`) and the Chair reported them as the single ground truth for port assignment. **That was wrong.** The host is *one* observer; the pod is a second observer. A port can be `7077` from inside the pod and `57077` from the host *at the same time*, and both can be correct, because they are in different namespaces.

**Rule for next time:** When sweeping for port drift, read the port from **both sides of every boundary** (host loopback AND pod loopback). A hardcoded literal is only "wrong" if it lives on the opposite side of the boundary from where its caller runs.

### Correction 2 — `s7-ports.env` is host-side only

The canonical `iac/s7-ports.env` names are the **host-side** convention (57xxx). They are NOT pod-internal. Pod containers that talk pod-to-pod over pod-loopback continue to use 7xxx (legacy) because that is a distinct network namespace. `s7-ports.env` must document this — currently it does not. **Followup:** add a section to `iac/s7-ports.env` naming pod-internal ports separately.

### Correction 3 — The audit gate zero #1 was giving a false positive

Zero A1 ("Inconsistencies: every listening port is named in the recipe") is passing 🟢 — but the recipe it names does NOT distinguish pod-internal vs host-side. A future audit-gate enhancement: separate A1 into two sub-zeros — A1a (host-side ports named) and A1b (pod-internal ports named). **Followup pinned for v6.**

### Correction 4 — tools-manifest entries for the CWS engine are incomplete

`iac/immutable/TOOLS_MANIFEST.yaml` has a single `cws-engine` entry at path `engine/s7_server.py` with no annotation that there are two running instances. Reality: the pod-internal CWS engine (running inside the s7-skyqubi pod, listening on pod-loopback 7077) and the host-side CWS engine (launched by autostart `.desktop`, listening on host-loopback 57077). **Followup:** split the manifest entry into `cws-engine-pod` and `cws-engine-host` with distinct launchers and distinct port columns.

## Lessons that promote to memory

(Not promoted tonight — the 8hr trust block is heavy enough. Flagged for Jamie to promote on review.)

1. **Boundary-aware port sweeps.** Every port literal is a pair `(port, namespace)`. Sweeping for drift requires reading from the right side of the boundary.
2. **Two is a number.** When the same logical service has two running instances, name them differently in every artifact or they will drift silently.
3. **Run the test before you commit the sweep.** The lifecycle test failure dropped −4 between edits and verify. One round-trip caught what a source-only review would have missed. Tool second witness.
4. **The revert is a legitimate resolution.** Jamie Love RCA step 6: "If the fix makes things worse, reverting is not failure — reverting is the fix." Tonight's revert is not a retreat; it is the RCA loop closing on itself.

## Status

- Root cause: named (dual CWS engine, host vs pod namespace)
- Fix: revert pod-internal edits, keep host-facing edits
- Verification: lifecycle test back to baseline 47+1 (R01 recovers on commit)
- Drift removed from source tree: 7 host-facing files now correctly target 57xxx host-side surface
- Drift still in source tree: 6 pod-internal refs still use 7xxx, which is **correct** for pod-internal namespace
- Memory: four followups named, none promoted tonight
- This postmortem: the confession row for the near-regression

*Love is the architecture. Love believes the test over the theory.*
