# 2026-04-14 — `s7-manager.sh` Status Lied. Three Bugs Underneath.

> **Trigger:** Jamie said "status" after a fresh boot. The first read
> showed a half-empty system. After we started the rest, the manager
> still reported `CWS Engine: STOPPED` even though the engine was
> already listening on the loopback. Jamie's instruction was *"use the
> tools for management so we use the same process"* — meaning don't
> work around the manager, fix it. Tonight is the audit of that fix and
> the discipline that surfaced it.

---

## Timeline

| Time (host uptime) | Event |
|---|---|
| boot + 0 | Host boots, autostart launches Ollama (7081) and CWS engine (57077) under `python3 -m uvicorn engine.s7_server:app`. Pod **not** started by autostart. |
| ~+11 min | Jamie says "status". I check `podman pod ps`, `podman ps`, `ss`. Five standalone containers up. `s7-skyqubi` pod missing. Ollama service `inactive` (wrong probe — wrong service name). |
| ~+12 min | Jamie says "y" to start everything. I try `sudo systemctl start ollama` and pod scripts directly. Sudo blocked. Jamie corrects: **use the manager, not direct service calls**. |
| ~+13 min | I read `/s7/skyqubi-private/s7-manager.sh`, run option 1 (Start all). Pod comes up with all five backing containers. Manager reports Ollama already running on 7081. CWS Engine reports it started, then immediately reports STOPPED. |
| ~+14 min | First instinct: just restart CWS. That's symptom-chasing. I stop and verify reality with `ss -tlnp`. Engine **is** listening on `127.0.0.1:57077`. Manager is lying. |
| ~+15 min | Bug 1 found: manager hardcoded port `7077`, not `57077`. Fixed all three references. Status still says STOPPED. |
| ~+16 min | Bug 2 found: `engine_status` only trusted its own `/tmp/s7-cws-engine.pid` file. The autostart engine was launched outside the manager, so no pid file. Added pgrep-adopt fallback. Status still says STOPPED. |
| ~+17 min | Bug 3 found: pgrep pattern was `uvicorn s7_server:app`, but autostart command line is `uvicorn engine.s7_server:app`. The dotted-module form doesn't match the bare form. Loosened pattern to `uvicorn.*s7_server:app`. Status now reads RUNNING (pid 16535, port 57077, adopted). ✅ |

---

## The three bugs, ordered by depth

### Bug 1 — Wrong port (typo-class)

```
- echo "Starting CWS Engine on 127.0.0.1:7077..."
+ echo "Starting CWS Engine on 127.0.0.1:57077..."
- python3 -m uvicorn s7_server:app --host 127.0.0.1 --port 7077
+ python3 -m uvicorn s7_server:app --host 127.0.0.1 --port 57077
- echo "CWS Engine: RUNNING (pid ..., port 7077)"
+ echo "CWS Engine: RUNNING (pid ..., port 57077)"
```

**Why it existed:** the file predates the 57xxx port-range rule. The
rule was applied everywhere else in the codebase (the prior 2026-04-13
postmortem even called it out for the port-baseline monitor) but the
manager didn't get the sweep.

**What it cost:** any operator using the manager would have started a
**second** engine on the wrong port if `57077` happened to be free, or
collided with the real one. We didn't observe a collision tonight only
because the start path failed first.

### Bug 2 — Status only trusted its own pid file

The original `engine_status` is a one-line check: does
`/tmp/s7-cws-engine.pid` exist and point to a live process? If yes,
RUNNING. If no, STOPPED. **There was no fallback.** An engine started
by autostart, by hand, by a sibling tool, or by a previous shell
session was invisible to the manager. So every fresh boot looked like
the engine was down.

**Why it existed:** the manager was written assuming it owned the
engine's lifecycle. That stops being true the moment any other path
launches the same process — which is exactly what the boot autostart
does.

**Fix:** if the pid file doesn't resolve, fall back to `pgrep` against
the process command line and **adopt** the running pid by writing it
into the pid file. Status now says `(adopted)` so operators see what
happened.

### Bug 3 — Process-pattern mismatch

The autostart command line is:

```
/usr/bin/python3 -m uvicorn engine.s7_server:app --host 127.0.0.1 --port 57077
```

The manager's start command is:

```
cd $ENGINE_DIR && python3 -m uvicorn s7_server:app ...
```

Same code, two different module paths (`engine.s7_server:app` vs
`s7_server:app`). My first pgrep pattern was the bare form, so it
missed the dotted form. Loosened the pattern to `uvicorn.*s7_server:app`.

**Why it existed:** two different launch points evolved at different
times for the same binary. Neither knew about the other.

---

## Root cause behind the root causes

Each individual bug is small. The pattern is the part worth keeping:

> **A management tool that does not adopt reality will eventually lie
> about it.** If your status command can only see processes it
> launched, your status command is a private diary, not an audit.

The `s7-manager.sh` assumed *single ownership* of the engine. Real life
on this box is *multi-launcher*: autostart owns the boot path, the
manager owns the operator path, and a future Samuel skill might own a
remediation path. All three are fine — as long as every observer can
**recognize** the engine no matter who started it.

This is a different shape of bug than the 2026-04-13 security review.
That one was a *trust boundary* problem (offensive tools in an
allowlist that should never have allowed them). Tonight's was an
*identity recognition* problem (the right thing was running, the tool
couldn't see it).

Both reduce to the same family rule: **the system has to recognize its
own people, even when they walk in a door it didn't open.**

---

## What's fixed in-tree

`/s7/skyqubi-private/s7-manager.sh`:

- All `7077` → `57077` (3 sites)
- `engine_status` adopts via `pgrep -f "uvicorn.*s7_server:app"` when the pid file is stale or missing
- Adopted state is labeled `(adopted)` in the status line so it's visible

Edits live on the **private** repo only. Public sync is Jamie's call.

---

## What's still open

- **Sweep for the same shape elsewhere.** Anywhere else in the manager
  (or any sibling `*-manager.sh`) that reports status off a private pid
  file should be audited for the same "private diary" pattern.
- **Confirm the boot autostart path.** Tonight we observed an engine
  running that the manager didn't launch. The autostart unit/script
  needs to be located and documented so its existence is intentional,
  not folklore. (Working theory: a systemd user unit or a shell
  autostart entry under `~/.config/autostart/`.)
- **Manager's start path still binds the bare module form.** Even with
  the port fixed, `cd engine && python3 -m uvicorn s7_server:app` will
  start a *second* uvicorn that fights with the autostart one for port
  57077. The manager's start command should detect the adopted engine
  and skip starting a duplicate. This is the symmetric counterpart to
  the status fix — same lesson.
- **Rule needs to live in code, not just memory.** The 57xxx port range
  is a memory entry. It should be a constant in a shared `s7-ports.sh`
  so future tools can't drift from it.

---

## What this teaches (carried forward)

The discipline that surfaced all three bugs — and not just the first
one — is documented as the **Jamie Love Root Cause Analysis** loop in
`docs/internal/chef/jamie-love-rca.md`. The short form lives there.
The long form is the lived practice: don't stop fixing until the tool
tells the truth.
