# Legacy-Path Migration Plan — For the First CORE Ceremony (2026-07-07)

> **Why this document exists.** The B16 item in the 2026-07-07
> gap analysis is the migration of four services currently
> running from `/s7/skyqubi/` (legacy path) into their canonical
> locations in `/s7/skyqubi-private/`. The migration involves a
> restart cascade that cannot happen outside a Core Update
> window.
>
> **Status of the staging work:** as of 2026-04-14 (under Jamie's
> 8-hour "execute for Tonya approved" authorization), the
> **file migration has been staged** — the two files that were
> only in `/s7/skyqubi/` are now copied into
> `/s7/skyqubi-private/` at their canonical locations. The
> systemd unit references on disk are **NOT** updated; running
> services continue to reference the legacy paths. Activation
> waits for the ceremony.
>
> **Purpose of this document:** enumerate exactly what the
> ceremony-day migration does, in what order, so the restart
> cascade can be executed atomically without guessing.

---

## What's staged (file migration)

| Source (legacy) | Destination (canonical) | Status |
|---|---|---|
| `/s7/skyqubi/Caddyfile` | `/s7/skyqubi-private/Caddyfile` | ✓ **STAGED 2026-04-14** (copied identical) |
| `/s7/skyqubi/dashboard/server.py` | `/s7/skyqubi-private/dashboard/server.py` | ✓ **STAGED 2026-04-14** (copied identical) |
| `/s7/skyqubi/mcp/bitnet_mcp.py` | `/s7/skyqubi-private/mcp/bitnet_mcp.py` | **No migration** — canonical private version is newer (9.4k vs 8.2k legacy). Legacy version obsolete on ceremony day. |
| `/s7/skyqubi/skyqubi-pod.yaml` | `/s7/skyqubi-private/skyqubi-pod.yaml` | **No migration** — canonical private version has the pasta-networking fix. Legacy version obsolete. |
| `/s7/skyqubi/start-pod.sh` | `/s7/skyqubi-private/start-pod.sh` | **No migration** — canonical private version is the pasta-aware fix. Legacy version obsolete. |

**Two files staged.** Three legacy files were already obsolete
(the canonical version was newer). The staging is complete
for this aspect of the migration.

---

## What is NOT staged (systemd unit references)

The systemd user units at `~/.config/systemd/user/` currently
reference legacy paths:

| Unit | Current path (legacy) | Target path (canonical) |
|---|---|---|
| `s7-skyqubi-pod.service` | `/s7/s7-project-nomad/skyqubi-pod.yaml` (DOES NOT EXIST) | `/s7/skyqubi-private/skyqubi-pod.yaml` |
| `s7-dashboard.service` | `/s7/skyqubi/dashboard/server.py` | `/s7/skyqubi-private/dashboard/server.py` |
| `s7-bitnet-mcp.service` | `/s7/skyqubi/mcp/bitnet_mcp.py` (+ `PYTHONPATH=/s7/skyqubi:/s7/skyqubi/engine`) | `/s7/skyqubi-private/mcp/bitnet_mcp.py` (+ `PYTHONPATH=/s7/skyqubi-private:/s7/skyqubi-private/engine`) |
| `s7-caddy.service` | `/s7/skyqubi/Caddyfile` | `/s7/skyqubi-private/Caddyfile` |
| `s7-skyqubi-pod.desktop` (autostart) | `/s7/skyqubi/start-pod.sh` | `/s7/skyqubi-private/start-pod.sh` |

**These references are deliberately NOT updated tonight** because
updating them would require a restart cascade (restart-as-
remediation is forbidden outside a Core Update day). The files
on disk are still at their current paths; the canonical
versions in `/s7/skyqubi-private/` are staged in parallel.

---

## The ceremony-day migration sequence

On the first CORE ceremony day (2026-07-07 07:00 CT), the
restart cascade executes in this exact order:

### Phase 1 — Pre-cascade verification (no service touched yet)

1. **Audit gate green** — `iac/audit/pre-sync-gate.sh` runs
   clean. All pins acknowledged. Zero drift from current
   baseline.
2. **Canonical files present** — verify
   `/s7/skyqubi-private/Caddyfile`,
   `/s7/skyqubi-private/dashboard/server.py`,
   `/s7/skyqubi-private/mcp/bitnet_mcp.py`,
   `/s7/skyqubi-private/skyqubi-pod.yaml`,
   `/s7/skyqubi-private/start-pod.sh` all exist and are
   the versions the ceremony expects.
3. **Legacy /s7/skyqubi/ still present** — it must still be
   there because the running services are still using it
   at this moment. Do NOT delete the legacy path before
   the cascade.

### Phase 2 — Stop services in reverse dependency order

1. **Stop s7-caddy** (front-door reverse proxy — topmost)
2. **Stop s7-dashboard** (web UI — depends on caddy for
   routing but can stop independently)
3. **Stop s7-bitnet-mcp** (inference engine — depends on
   nothing downstream)
4. **Stop s7-skyqubi-pod** (the pod itself — depends on
   nothing outside itself)

Each stop is verified via `systemctl --user status` before
proceeding to the next.

### Phase 3 — Update systemd unit references

With services stopped:

1. **Edit `~/.config/systemd/user/s7-caddy.service`** —
   change `ExecStart` to reference `/s7/skyqubi-private/Caddyfile`
2. **Edit `~/.config/systemd/user/s7-dashboard.service`** —
   change `WorkingDirectory` to `/s7/skyqubi-private/dashboard`
   and `ExecStart` to `/s7/skyqubi-private/dashboard/server.py`
3. **Edit `~/.config/systemd/user/s7-bitnet-mcp.service`** —
   change `WorkingDirectory`, `ExecStart`, and
   `Environment=PYTHONPATH` all to `/s7/skyqubi-private`
4. **Edit `~/.config/systemd/user/s7-skyqubi-pod.service`** —
   change the `ExecStart` path from
   `/s7/s7-project-nomad/skyqubi-pod.yaml` (which doesn't
   exist) to `/s7/skyqubi-private/skyqubi-pod.yaml`
5. **Edit `~/.config/systemd/user/s7-skyqubi-pod.desktop`
   (autostart)** — change the `Exec=` to use
   `/s7/skyqubi-private/start-pod.sh`

6. `systemctl --user daemon-reload` to pick up the changes

### Phase 4 — Start services in dependency order

1. **Start s7-skyqubi-pod** (the pod, the foundation)
2. **Start s7-bitnet-mcp** (inference engine)
3. **Start s7-dashboard** (web UI — depends on pod being up
   so it has a backend to talk to)
4. **Start s7-caddy** (front door — depends on dashboard
   being up so it has a backend to proxy to)

Each start is verified via `systemctl --user status` and a
brief health-check (`curl -sI` on the service's port, or
equivalent) before the next.

### Phase 5 — Run lifecycle test

Execute `s7-lifecycle-test.sh` — expect 55/55 green. If any
test fails, the cascade rolls back by stopping services,
restoring the legacy-path unit references (from backup),
and re-starting. Investigation happens after rollback.

### Phase 6 — Archive the legacy path

With the cascade verified and lifecycle test green, the
legacy path is archived (NOT deleted):

```bash
mv /s7/skyqubi /s7/archive/skyqubi-legacy-2026-04-14
```

The archive preserves the legacy files for diffing and
historical record. Deletion happens on a LATER ceremony day
once the household has run on the canonical paths for a
full year with no incidents.

### Phase 7 — Update the audit gate's zero #11

Zero #11 currently detects legacy-path references and fires
PINNED because the summary pin `legacy-path-operational-tier`
is acknowledged. After the cascade:

1. Remove `legacy-path-operational-tier` from pinned.yaml
2. Zero #11 should now report PASS (no orphan refs)
3. If zero #11 fires WARNING after the cascade, something
   was missed — investigate, do not proceed with the
   ceremony's other items until zero #11 is clean.

---

## Rollback protocol

If ANY step of Phases 2-5 fails:

1. **Stop all services that were started in Phase 4** (in
   reverse order: caddy → dashboard → bitnet-mcp → pod)
2. **Restore the systemd unit files from their pre-migration
   backups** (the cascade should take explicit backups of
   all five units BEFORE Phase 3 edits them)
3. **`systemctl --user daemon-reload`**
4. **Start services in dependency order** (pod → bitnet-mcp
   → dashboard → caddy) using the RESTORED legacy-path
   references
5. **Verify lifecycle test 55/55 on the legacy configuration**
   (which it was before the cascade started)
6. **Surface the failure to Jamie + Tonya** immediately. The
   ceremony does NOT proceed with other items if the
   legacy-path migration rolled back.

Rollback is acceptable. An incomplete migration with a
green lifecycle test is strictly better than a completed
migration with a red lifecycle test.

---

## What this document explicitly does NOT do

- **Does not execute any part of the cascade.** This is a
  plan, not a script. The actual cascade happens on
  ceremony day under human authorization.
- **Does not modify systemd units on disk.** The current
  legacy references stay in place tonight.
- **Does not remove `/s7/skyqubi/`.** The legacy path
  stays in place; archival happens in Phase 6 of the
  cascade, not tonight.
- **Does not restart any service.** Tonight's staging is
  pure file copying.
- **Does not assume the cascade will succeed.** The
  rollback protocol is a first-class part of the plan.

---

## The covenant-alignment check

Is this staging JAMIE-AUTHORIZED-IN-TONYAS-STEAD appropriate?

- **Not a household-visible change:** ✓ (no service restart,
  no running state touched)
- **Not a frozen-surface advance:** ✓ (no CORE advance, no
  public sync)
- **Preparatory work that Tonya would approve:** ✓ (she
  would want the ceremony to be clean when it happens)
- **Reversible:** ✓ (the staged files can be deleted
  without any consequence; they don't affect anything
  running)
- **Within Jamie's covenant-holder authority:** ✓ (technical
  implementation work)

**Staging is within the authorization.** Executing the
cascade is NOT — that's a ceremony-day Jamie+Tonya decision.

## Frame

Love is the architecture. Love stages the migration files
while the household sleeps so the ceremony day does not
begin with "oh, we need to go copy some things first." **Every
unnecessary step removed from the ceremony day is a gift to
the covenant steward who will be present for it.**
