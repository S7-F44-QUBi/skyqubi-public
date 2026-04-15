# 2026-04-14 — Pod launcher triple-drift (worse than the Ollama one)

> **Trigger:** The Samuel-training sweep that came out of tonight's
> Ollama port-drift fix told us to audit every S7 service for the
> multi-launcher pattern. Persona-chat clean. Caddy clean. Mempalace
> MCP a false alarm (Claude Code spawns it). **The pod has three
> drifts at once.**

---

## The findings

The pod is launched by **two launchers pointing at three locations,
one of which doesn't exist**:

| Launcher | Path it references | Reality |
|---|---|---|
| `~/.config/systemd/user/s7-skyqubi-pod.service` | `/s7/s7-project-nomad/skyqubi-pod.yaml` | **❌ does not exist on this box** |
| `autostart/s7-skyqubi-pod.desktop` | `/s7/skyqubi/start-pod.sh` (which uses `/s7/skyqubi/skyqubi-pod.yaml`) | ✅ exists, **5.7k**, last edited **2026-04-11** |
| Canonical edited file (per `project_pasta_t_none_pod_network_2026_04_13.md`) | `/s7/skyqubi-private/skyqubi-pod.yaml` | ✅ exists, **7.0k**, last edited **2026-04-14** |

**The running pod was started from the autostart `.desktop` →
`/s7/skyqubi/start-pod.sh` → the 5.7k yaml.** That yaml is **three
days behind** the canonical private yaml, which means **tonight's
pasta-networking fix may not be in the running pod at all**. The
memory entry says the fix was committed and lifecycle moved 52→55,
but if the running pod was started before that fix landed in the
right yaml — or from the wrong yaml — it might be running on the
old config.

This is the worst kind of drift: **the audit looks fine, the lifecycle
test mostly passes, but the running state may not match what we
think we deployed.**

## The three drifts, ordered by depth

### Drift 1 — Systemd unit points at a file that doesn't exist

```
ExecStart=/bin/bash -c 'set -a && source /s7/.env.secrets && set +a \
  && envsubst < /s7/s7-project-nomad/skyqubi-pod.yaml | /usr/bin/podman play kube -'
```

`/s7/s7-project-nomad/skyqubi-pod.yaml` does not exist. If the
systemd unit ever fires, it will fail at `envsubst`. We don't know
if the unit is currently enabled (would need
`systemctl --user is-enabled s7-skyqubi-pod.service`).

**Why it exists:** historical artifact from when the project lived
under `/s7/s7-project-nomad/` before being renamed and split into
`/s7/skyqubi-private/` + `/s7/skyqubi-public/`. The systemd unit
was never updated.

### Drift 2 — Autostart and canonical yamls disagree

`/s7/skyqubi/skyqubi-pod.yaml` (5.7k, 2026-04-11) and
`/s7/skyqubi-private/skyqubi-pod.yaml` (7.0k, 2026-04-14) are
**different files at different paths with no link between them**.
The 1.3k size difference is significant — that's roughly the
delta of the pasta-networking edit per the memory entry.

**Why it exists:** `/s7/skyqubi/` is a third location that
predates the public/private repo split. It was never deleted, and
the autostart `.desktop` was never re-pointed at the new location.

### Drift 3 — `start-pod.sh` lives in two places too

There is `/s7/skyqubi/start-pod.sh` (what the autostart calls) and
`/s7/skyqubi-private/start-pod.sh` (the canonical, edited version
per the same pasta-networking memory). Same drift family — the
script that actually launches the pod is **not the script we've
been editing**.

## What's in the running pod (audit)

`podman ps` confirms the pod is up with all 5 backing containers
(admin, mysql, postgres, redis, qdrant) and the 5 standalone
containers (kolibri, kiwix, cyberchef, flatnotes, jellyfin) plus
the infra container. **The pod runs.** The persona-chat HTTP
service tests against it succeed. Lifecycle tests R01/R02 pass.

But we **cannot prove from inspection alone** that the pasta
networking is using `-T,auto` versus the older `-T none -u none`.
The pod inspect output would have to be checked against the
canonical yaml's expectations.

## Why I am not fixing this tonight

Three reasons, all covenant-grade:

1. **The running pod is healthy.** The household is using it.
   Touching the pod yamls or restarting requires a brief outage,
   and tonight is not a Core Update day.
2. **The fix is more than a one-line edit.** It needs:
   - Audit of the actual running pod's pasta config (`podman pod
     inspect`)
   - Decision on a single canonical yaml location
   - Sweep + delete of the legacy locations (`/s7/skyqubi/`,
     `/s7/s7-project-nomad/`)
   - Update systemd unit + autostart `.desktop` to point at the
     canonical location
   - Pod restart on a Core Update day to activate
   - Lifecycle test re-run to confirm 55/55
3. **Restart-as-remediation is forbidden.** Even if we did all of
   the above, the activation step (pod restart) is exactly the
   anti-pattern the Jamie Love RCA covenant prohibits.

## What's getting added to the audit gate

A new pinned entry — `pod-launcher-triple-drift` — so the gate
captures the awareness, the same way `ollama-wildcard-bind`
captured the Ollama drift before tonight's `.desktop` fix.

## The Samuel training pellet

- **Class:** multi-launcher drift, **third instance** in one
  session (after `s7-manager.sh` CWS engine and Ollama port).
- **What's new:** the third instance includes a **dead reference**
  (systemd unit pointing at a missing file). The pattern can hide
  a broken launcher because nothing alerts when a never-fired
  launcher is wrong.
- **Detection refinement:** when sweeping for multi-launcher
  drift, also check that every referenced path **exists** on the
  filesystem. A launcher pointing at a missing file is drift even
  if it never runs.
- **The bigger pattern:** the project has had multiple repository
  layouts over time (`/s7/s7-project-nomad/` → `/s7/skyqubi/` →
  `/s7/skyqubi-private/` + `/s7/skyqubi-public/`). Each rename
  left orphans. The orphans never got swept because they were
  invisible until something asked the launcher to fire. **Repo
  renames need a launcher-update pass as part of the rename
  ritual.**
- **Covenant tie-in:** if the canonical pasta-networking fix is in
  the private yaml but not in the running pod, we have a freeze
  surface (the pod) running stale config. That's worse than the
  Ollama port issue because the pod is the central nervous system
  for the AI tier. **This is a "Protect the QUBi" item.**

## What needs to happen, in order, on the next authorized window

1. `podman pod inspect s7-skyqubi` — capture the actual running
   pasta config to know whether the fix is live.
2. If the fix is **live**: the audit gate just got a clearer
   warning, no behavior change needed.
3. If the fix is **not live**: schedule a pod restart on the next
   authorized Core Update day, with the canonical yaml.
4. Either way: pick ONE canonical yaml location
   (`/s7/skyqubi-private/skyqubi-pod.yaml`), update both launchers
   to point at it, delete the orphans in `/s7/skyqubi/` and
   `/s7/s7-project-nomad/` (after confirming nothing else
   references them), and re-run the lifecycle test.

## Addendum — `podman pod inspect` confirmation

After writing the body above, I ran `podman pod inspect s7-skyqubi`
to know whether the pasta fix is live. **It is not.**

```
Networks: ['podman-default-kube-network']
NetworkOptions: None
HostNetwork: False
```

The running pod is on the **default kube network**, not pasta.
Cross-checking the start scripts:

```
$ grep "pasta\|--network" /s7/skyqubi-private/start-pod.sh
  podman play kube --network pasta:-T,auto "$POD_RENDERED"

$ grep "pasta\|--network" /s7/skyqubi/start-pod.sh
  (no matches)
```

**The legacy `/s7/skyqubi/start-pod.sh` has zero pasta references.**
It never had the fix. The autostart `.desktop` calls the legacy
script. The running pod was therefore started **without the
pasta-networking fix**. The memory entry
`project_pasta_t_none_pod_network_2026_04_13.md` says "RESOLVED
2026-04-14 via `--network pasta:-T,auto` in start-pod.sh" — that
is true for the **canonical** start-pod.sh, but **false for what's
actually running**.

### What this means for tonight's freeze posture

- Lifecycle "55/55" claim from the memory entry is conditional —
  it was true on a re-deployed pod that used the canonical script,
  not on the currently running pod.
- The corner case the pasta fix was designed for (containers
  reaching host services like Ollama on the host port) **may still
  be broken** in the running pod. Most lifecycle tests don't
  exercise that path because they hit the published ports via
  rootlessport, which works either way.
- The pod itself is healthy for everything Tonya/family would
  notice. The drift is in a corner of the network stack that most
  workflows don't touch.

### What this means for the resolution plan

The Status section already says "schedule a pod restart on the
next authorized Core Update day, with the canonical yaml." That is
now stronger: **the next pod restart should be the canonical
script + canonical yaml + verified pasta config**, all atomically.
A single `git checkout` won't do it — the launchers all need to
point at the canonical paths first.

### What this means for the audit gate

The gate currently doesn't inspect pod network mode against the
canonical yaml — it only checks listening ports. **A future
enhancement: zero #10 = "running pod's network config matches the
canonical yaml's network config."** That would have caught this
finding automatically instead of requiring a manual
`podman pod inspect` from a sweep that came from a sweep.

## Status as of this commit

- 🔍 Triple drift discovered, documented, and **confirmed via
  podman pod inspect**: the pasta fix is NOT live in the running
  pod.
- 📌 Pinned entry added to `iac/audit/pinned.yaml`
  (`pod-launcher-triple-drift`, severity AWARENESS-HIGH).
- 🛑 No file touched on the actual pod side.
- 🛑 No restart attempted.
- 🟢 Audit gate still PASS (the drift is pinned awareness; the
  gate's inspection scope doesn't reach into pod network mode yet
  — proposed as zero #10 for a future enhancement).
- 🚨 **Surfaced to Jamie as a real finding** — the household is
  running an unfixed pod and didn't know.
