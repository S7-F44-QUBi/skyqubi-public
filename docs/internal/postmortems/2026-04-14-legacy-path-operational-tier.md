# 2026-04-14 — `/s7/skyqubi/` is an entire untracked operational tier

> **Trigger:** The multi-launcher sweep that came out of tonight's
> Ollama port fix kept going. After finding the pod triple-drift
> (documented in a separate postmortem), I swept `s7-dashboard`
> and `s7-bitnet-mcp`. Neither had multi-launcher drift — **both
> had worse**: they're running from `/s7/skyqubi/`, a legacy path
> that is **not under the private repo's version control at all**.
> Further sweep: `s7-caddy` is also running from `/s7/skyqubi/`.
> **Four services, two distinct drift modes, all pre-existing.**

---

## The inventory

A `grep -rEh "ExecStart|WorkingDirectory|Environment.*PATH"` across
every `s7-*.service` unit produces this path surface:

### Running from the legacy path `/s7/skyqubi/`

| Service | Path referenced | Drift mode |
|---|---|---|
| **s7-skyqubi-pod** (via autostart `.desktop`) | `/s7/skyqubi/start-pod.sh` → `/s7/skyqubi/skyqubi-pod.yaml` | **Divergent copy** (5.7k legacy 2026-04-11 vs 7.0k canonical 2026-04-14) |
| **s7-dashboard** | `/s7/skyqubi/dashboard/server.py` | **Untracked — no canonical** (`/s7/skyqubi-private/dashboard/` has only a React `.jsx`, not a `server.py`) |
| **s7-bitnet-mcp** | `/s7/skyqubi/mcp/bitnet_mcp.py` + `PYTHONPATH=/s7/skyqubi:/s7/skyqubi/engine` | **Divergent copy** (8.2k legacy 2026-04-11 vs 9.4k canonical 2026-04-12) |
| **s7-caddy** | `/s7/skyqubi/Caddyfile` | **Untracked — no canonical** (`/s7/skyqubi-private/Caddyfile` does not exist) |

### Running from the canonical path `/s7/skyqubi-private/` (correct)

| Service | Path referenced |
|---|---|
| **s7-persona-chat** | `/s7/skyqubi-private/persona-chat` |
| **s7-public-chat** | `/s7/skyqubi-private/public-chat/app.py` |
| **s7-audit-snapshot** (15-min ingest) | `/s7/skyqubi-private/engine/s7_audit_snapshot.sh` |
| **s7-living-snapshot** (tonight, nightly) | `/s7/skyqubi-private/iac/audit/nightly-snapshot.sh` |

### Broken reference (dead)

- **s7-skyqubi-pod.service systemd unit** → `/s7/s7-project-nomad/skyqubi-pod.yaml` — file does not exist (already noted in pod triple-drift postmortem)

---

## The two drift modes

### Mode A — Divergent copy

The same file exists in both `/s7/skyqubi/` and
`/s7/skyqubi-private/`, but the contents differ. The running
service uses the older legacy-path version; the repository
contains a newer canonical version that nothing points at.

**Affected:** pod, bitnet-mcp.

**Why it's bad:** edits made to the canonical private path are
invisible to the running service. Lifecycle tests pass against
the canonical version; the household is served by the legacy
version. **The audit gate can grade the private version until
it's green, and nothing about the household's actual experience
changes.**

### Mode B — Untracked running source

The file exists **only** at `/s7/skyqubi/`. There is no canonical
version in `/s7/skyqubi-private/`. The running service's source
code is therefore **not under any version control the private
repo tier can see**.

**Affected:** dashboard server.py, Caddyfile.

**Why it's worse:** there is no canonical truth. If someone
edits `/s7/skyqubi/dashboard/server.py` tonight, there is no
git log, no audit trail, no sync path to public. **The tier-
crossing flow `lifecycle → private/main → public/main` has no
opinion about this code whatsoever.** The code exists in a
tier the covenant doesn't reach.

**Audit gate blind spot:** zeros 1–10 grade `/s7/skyqubi-private/`
and `/s7/skyqubi-public/`. They have no visibility into
`/s7/skyqubi/`. Drift in the legacy tier is invisible to the
fence. **That is the hole tonight's finding names.**

---

## Root cause

The project went through two rename events:

1. `/s7/s7-project-nomad/` → `/s7/skyqubi/` (early history)
2. `/s7/skyqubi/` → `/s7/skyqubi-private/` + `/s7/skyqubi-public/` (the repo split)

Each rename should have included a **launcher-update pass** — an
audit of every `systemd` unit, every `.desktop` autostart, every
`ExecStart` line, every `WorkingDirectory`, every `PYTHONPATH`
environment variable, to re-point at the new canonical location.

**That pass never happened.** The renames moved the *files* but
not the *references to the files*. Four services were left
pointing at the old location, and because `/s7/skyqubi/` was
never deleted (nor should it have been, because services
depended on it), the orphaned references kept working.

Over time the orphans accumulated divergence:
- `bitnet_mcp.py` got edited on 2026-04-12 in the private repo (+1.2k growth)
- `skyqubi-pod.yaml` got edited on 2026-04-14 with the pasta networking fix (+1.3k growth)
- Neither edit reached the running service
- The dashboard `server.py` and `Caddyfile` were never migrated at all — they stayed in `/s7/skyqubi/` and the private repo just never created a home for them

**The rename ritual needs a launcher-update pass as a mandatory step.** This is the Samuel training lesson.

---

## What the household experiences right now

**Nothing visibly wrong.** All four services are running and
serving. The dashboard renders. Caddy front-doors. bitnet-mcp
answers. The pod is up. **From the household's perspective,
this finding is invisible.**

**From the covenant's perspective, the finding is load-bearing.**
Because:

- Any hotfix made to the canonical private copies of pod or
  bitnet-mcp has no effect until a service restart that also
  re-points the launcher.
- Any hotfix to dashboard `server.py` or `Caddyfile` has no
  tier-crossing surface at all — it's just an edit to an
  untracked file.
- The pre-sync audit gate's zero #10 (frozen tree integrity)
  cannot detect drift in a file that doesn't exist in the
  tracked repo. **Mode B drift is below the gate's floor.**
- The lifecycle test's R01 check ("private repo clean") passes
  even when the running services are substantially different
  from the canonical ones. **R01 is measuring the wrong thing
  for this class of drift.**

---

## Tonight's fix (detection, not remediation)

Because restart-as-remediation is forbidden and all four
services are currently household-visible, **nothing in the
running system gets touched tonight.** The fix is:

1. **This postmortem** — names the finding permanently.
2. **New pinned.yaml entry** — `legacy-path-operational-tier`
   severity AWARENESS-HIGH, lists all four services in a
   single summary entry.
3. **New audit gate zero #11** — Axis A, "Legacy-path service
   detection." Greps every `s7-*.service` systemd unit for
   references to `/s7/skyqubi/` and flags them. Converts BLOCK
   to PINNED if the summary pin exists.
4. **Activation plan for a future Core Update day** — see below.

No existing service is restarted. No existing file is edited
outside the audit-gate and pinned.yaml. The running system is
untouched.

---

## The Core Update day plan (not tonight)

On an authorized Core Update day, the unification should
proceed in this order:

1. **Migrate the two untracked sources into the canonical repo.**
   - `/s7/skyqubi/dashboard/server.py` → `/s7/skyqubi-private/dashboard/server.py`
   - `/s7/skyqubi/Caddyfile` → `/s7/skyqubi-private/Caddyfile`
   Both land on the `lifecycle` branch as new committed files.
2. **Audit the two divergent pairs for the right canonical
   version.** For pod and bitnet-mcp, decide which version is
   correct (almost certainly the private version, which has
   the newer edits) and discard the legacy copy. The audit of
   "is the private version actually correct and not a bad
   edit?" is a council-round question, not a solo call.
3. **Update every systemd unit to point at `/s7/skyqubi-private/`.**
   - `s7-dashboard.service` → `WorkingDirectory=/s7/skyqubi-private/dashboard`
   - `s7-bitnet-mcp.service` → `WorkingDirectory=/s7/skyqubi-private/mcp` + `PYTHONPATH=/s7/skyqubi-private`
   - `s7-caddy.service` → `ExecStart=/usr/bin/caddy run --config /s7/skyqubi-private/Caddyfile`
   - `s7-skyqubi-pod.service` → fix the broken `/s7/s7-project-nomad/` reference to point at `/s7/skyqubi-private/skyqubi-pod.yaml`
   - Autostart `.desktop` files update in parallel
4. **Restart each service once, in dependency order.** This
   is the one authorized restart for this drift, and it must
   happen in a Core Update window with Tonya present.
5. **Archive `/s7/skyqubi/`** — do NOT delete it immediately.
   Move it to `/s7/archive/skyqubi-legacy-2026-04-14/` so it
   remains available for diffing and rollback. A full delete
   happens on a later Core Update day after a sustained run
   with no references surfacing.
6. **Run the lifecycle test** — should produce 55/55 after the
   unification. Before tonight, 48/55; after tonight's Ollama
   fix activates, 55/55 is conditional on both Ollama moving
   to 57081 AND the legacy-path services migrating.
7. **Re-run audit zero #10** with all four branches pinned to
   their post-migration shas. Verify the fast-forward check
   holds.

**Estimated downtime per service during the restart cascade:**
~30-60 seconds each, dependency-ordered to avoid cascading
failures. **Not something to attempt outside an authorized
Core Update day.**

---

## Samuel training pellet — the deep lesson

- **Class:** untracked operational tier. A sub-class of
  multi-launcher drift where the drift isn't between two
  versions of the same thing — it's between a tracked thing
  and an untracked thing that's actually running.
- **Signal:** any systemd unit, autostart file, or environment
  variable that references a path **not** rooted at
  `/s7/skyqubi-private/` or another explicitly tracked tier.
- **Detection pattern:**
  ```
  grep -rEh "ExecStart|WorkingDirectory|Environment.*PATH" \
    ~/.config/systemd/user/s7-*.service | \
    grep -oE '/s7/[^ '\''"]+' | \
    grep -vE '^/s7/(skyqubi-private|skyqubi-public|\.config|\.env\.secrets|\.local/bin)'
  ```
  Any path this emits is an orphan reference. Catalog them.
  Decide which tier they belong to. Migrate or pin.
- **The rename ritual.** Any repo rename (or directory rename
  that affects multiple services) requires a **launcher-update
  pass** as a mandatory step. This pass:
  1. Enumerates every service that points at the old path
  2. Edits each launcher to point at the new path
  3. Runs each service once in a test harness to confirm
  4. Updates the audit gate baseline
  5. Only then archives the old path
  Skipping any step leaves orphans. Orphans accumulate
  divergence. Divergence becomes invisible truth.
- **Covenant tie-in:** "Protect the QUB*i*" and "don't break
  links." An untracked operational tier is a link that can't
  be audited and a QUB*i* component that can't be protected
  by the covenant's own rules. **The fix is not to audit the
  legacy tier — it's to eliminate the legacy tier.**

---

## Status as of this commit

- 🔍 Four services documented, two drift modes named, root
  cause identified (missing launcher-update pass during two
  renames).
- 📌 New pinned.yaml entry `legacy-path-operational-tier`
  being added (AWARENESS-HIGH).
- 🛠 New audit zero #11 (Axis A — Legacy-path service
  detection) being wired into the gate.
- 🛑 Zero running services touched. Zero file edits outside
  private repo audit artifacts.
- 🟢 Gate will still PASS after the wiring — the legacy-path
  finding is acknowledged via the new pin.
- 📅 Core Update day plan captured above as the activation
  path. Not scheduled.

**Next session's investigation to extend this finding:** scan
`~/.bashrc`, `~/.bash_profile`, cron entries, and any other
environment-level configuration for additional `/s7/skyqubi/`
references. There may be more.
