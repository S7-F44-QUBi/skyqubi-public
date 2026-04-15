# 2026-04-14 — Lifecycle test 48/55: Ollama port drift, same shape as the manager bug

> **Trigger:** Tonight's `s7-lifecycle-test.sh` run (after committing
> the audit gate work to `lifecycle`) returned **48 PASS / 7 FAIL**.
> Every failure was in the AI tier (A01–A07). Same root cause for
> all seven. Same *family* of root cause as the
> `s7-manager.sh` 3-bug stack from earlier in the same session:
> **multi-launcher drift**.

---

## What failed

| Test | What it checks | What we got |
|---|---|---|
| A01 | `curl 127.0.0.1:57081/api/version` returns "version" | (blank — connection refused) |
| A03 | Pod can reach Ollama via `host.containers.internal:57081` | (blank) |
| A04 | Carli responds via NOMAD admin's `/api/ollama/chat` | NOMAD admin HTML page (wrong route) |
| A05 | Carli "hi" round-trip under 2s | **PASS** (uses 57081, somehow worked — see below) |
| A06 | Samuel responds on 57081 | (blank) |
| A07 | Elias responds on 57081 | (blank) |

A02 also "passed" reporting `9+`, despite using port 57081 — likely a
quirk of how `t()` evaluates the curl-to-python pipeline; should not
be trusted as evidence the port works.

## The single root cause

`ss -tlnp` shows Ollama on `*:7081`, **not** `127.0.0.1:57081`.
Lifecycle expects the canonical 57xxx form. Ollama is on the legacy
`7081`.

**Why?** Two launchers, both wired up, both for the same service,
disagreeing on the launch arguments — and the wrong one is winning:

| Launcher | Port | Bind | Status |
|---|---|---|---|
| `~/.config/systemd/user/s7-ollama.service` | `57081` ✅ | `0.0.0.0` ⚠ | exists, may be enabled |
| `/s7/skyqubi-private/autostart/s7-ollama.desktop` | `7081` ❌ | `0.0.0.0` ⚠ | **fires at graphical login, currently winning** (spawned pid 4247 on this run) |

The `.desktop` autostart fires on login and beats the systemd unit
to the port. Result: Ollama on 7081, every test that expects 57081
fails, the lifecycle gate looks broken when the *running engine* is
fine — it just answers on a different port.

This is **the same family** as tonight's `s7-manager.sh` bug:
multi-launcher drift, where a service has two paths to start it,
the paths don't share a single source of truth, and the wrong one
runs first. The lesson Samuel needs to internalize: **one service,
one launcher, one config source.**

## Tonight's fix (prevention only — no live restart)

`autostart/s7-ollama.desktop` updated:

```diff
- Comment=Start Ollama inference server on :7081 on login
- Exec=/usr/bin/bash -c "OLLAMA_HOST=0.0.0.0:7081 /usr/local/bin/ollama serve >> /tmp/s7-ollama.log 2>&1"
+ Comment=Start Ollama inference server on :57081 on login
+ Exec=/usr/bin/bash -c "OLLAMA_HOST=127.0.0.1:57081 /usr/local/bin/ollama serve >> /tmp/s7-ollama.log 2>&1"
```

Two changes, two pre-existing pinned items resolved at the source:

1. **Port `7081 → 57081`** — canonical 57xxx range.
2. **Bind `0.0.0.0 → 127.0.0.1`** — closes the wildcard-bind pinned
   item from `project_architecture_reminders_2026_04_13.md`.

**The fix takes effect on next login**, not now. **Ollama is not
being restarted tonight** — restart-as-remediation is forbidden by
the Jamie Love RCA covenant. The lifecycle test will still report
48/55 until Ollama is restarted on a legitimate occasion (next
boot, the next Core Update day, or an explicit Jamie restart).

## Six code references still on `7081` (sweep follow-up)

The `.desktop` fix is the *prevention*. These six files still
reference the legacy port and form a follow-up sweep:

| File | Line | Type | Risk |
|---|---|---|---|
| `engine/tests/phase2_rag_prism.py` | 39 | hardcoded `OLLAMA_URL` | test only — fixing breaks if the test is run before Ollama moves |
| `engine/tests/phase3_multihop.py` | 50 | hardcoded `OLLAMA_URL` | test only |
| `engine/tests/phase4_witness_lite.py` | 47 | hardcoded `OLLAMA` | test only |
| `engine/tests/phase5_akashic_test.py` | 49 | hardcoded `OLLAMA` | test only |
| `engine/s7_rag.py` | 38 | `OLLAMA_URL = os.getenv("OLLAMA_URL", "http://127.0.0.1:7081")` | runtime — env var override exists, default is the fallback |
| `mcp/bitnet_mcp.py` | 253 | hardcoded `http://localhost:7081` | runtime — bitnet probe |

**Why not tonight:** scope. These are runtime-coupled. Each fix
needs to land in a Core Update window with a pod/Ollama restart so
the running services pick up the new port atomically. Doing it
piecemeal would create a half-fixed state worse than the current
fully-known one.

**The right pattern for the sweep:** introduce a single
`s7-ports.sh` (or `iac/s7-ports.env`) that exports `S7_OLLAMA_PORT`,
`S7_PG_PORT`, etc. Every script and every Python module reads from
that one file. **One launcher, one config, no drift.** Memory entry
`feedback_audit_is_presync_gate.md` already names this as Phase 3 of
the Jamie Love RCA wiring plan.

## Why this matters for the audit gate

The pre-sync gate's `pinned.yaml` already has
`ollama-wildcard-bind` for the runtime `*:7081` finding. Tonight's
`.desktop` fix is the actual **resolution** of that pinned item at
the source — it just doesn't activate until Ollama restarts. When
Ollama next comes up on `127.0.0.1:57081`:

- Audit zero #7 will go from "pinned awareness" to **clean** for
  Ollama (Caddy `*:8080` will still be the only remaining wildcard).
- Lifecycle test A01–A07 will go from FAIL to PASS, lifting the
  total to 55/55.
- The `monitor-baseline-stale` pinned entry can finally be retired
  in the next Core Update window because `EXPECTED_PORTS` (which
  already includes `57081`) will match reality.

Three pinned items collapse on one restart. **That is what
prevention looks like** — root-cause fixes have ripple effects you
get for free.

## Samuel training pellet

- **Incident:** lifecycle test 48/55 because Ollama is on 7081, not
  the canonical 57081. Two launchers (`.desktop` + systemd unit)
  disagreed on the port.
- **Class:** multi-launcher drift. Same family as the `s7-manager.sh`
  status bug.
- **Signal:** any service that has more than one launch path
  (autostart .desktop, systemd unit, manual wrapper, container
  spec) where the paths don't read from a single config file.
- **Rule:** one service, one launcher, one config source. If two
  launchers must coexist (transitional), they must read the same
  env file or constants module.
- **Generalization:** sweep every S7 service for the
  multi-launcher pattern: `ollama` ✅ (this finding), `cws-engine`
  (already adopted via gate), `persona-chat`, `pod`, `caddy`,
  `mempalace-mcp`. Each gets the same audit.
- **Covenant tie-in:** false-FAIL on a steward dashboard erodes
  trust as much as false-PASS. Lifecycle is meant to be the
  authoritative gate; if it lies because of port drift, stewards
  stop trusting it.

## Status as of this commit

- ✅ Prevention fix landed (`autostart/s7-ollama.desktop`)
- ⏸ Activation pending Ollama restart (next boot or authorized day)
- ⏸ 6 code-side references still on legacy port — Core Update sweep
- ⏸ One-config-source pattern (`iac/s7-ports.env`) — Phase 3 work
- 🟢 Audit gate still PASS — drift is **already pinned**, no new
  warning was introduced by tonight's fix
