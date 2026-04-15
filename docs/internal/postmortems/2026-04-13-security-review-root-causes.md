# 2026-04-13 — Security Review Root Causes

> **Trigger:** Jamie asked Claude to read `/s7/Downloads/skyqubi-security-review-2026-04-13.md`,
> a read-only audit of `github.com/skycair-code/skyqubi-public`. The
> review found **2 CRITICAL, 4 HIGH, 5 MEDIUM, 2 LOW** security issues
> in the S7 codebase. The fixes are easy. **The pattern that let them
> exist in the first place is the part worth understanding.**

## What the review found (in priority order)

| Severity | Issue | Fix |
|---|---|---|
| 🔴 CRITICAL | `nmap`, `nikto`, `sqlmap`, `gobuster` in Samuel SHELL_ALLOWLIST | Remove (offensive tools — directly contradict civilian-only mandate) |
| 🔴 CRITICAL | `sudo` in SHELL_ALLOWLIST (bypasses denylist via `sudo rm`) | Remove (Samuel runs as user — never needs escalation) |
| 🟠 HIGH | `dnf` in SHELL_ALLOWLIST (arbitrary package install) | Remove |
| 🟠 HIGH | Cloud CLIs (`aws/az/gcloud/doctl/terraform/helm/k3s/pulumi`) + `pwsh/wslpath` in SHELL_ALLOWLIST | Remove (sovereign offline mandate; Windows tools have no business on Fedora) |
| 🟠 HIGH | Port baseline monitor uses `7xxx` (production runs on `57xxx`) — fires BABEL alerts forever | Update `EXPECTED_PORTS` |
| 🟡 MEDIUM | `curl` allows outbound exfiltration | Remove from allowlist |
| 🟡 MEDIUM | `192.168.1.75` LAN IP hardcoded in `ALLOWED_OUTBOUND` | Move to `S7_ALLOWED_OUTBOUND` env var |
| 🟡 MEDIUM | `/status` endpoint leaks system state unauthenticated | Reduce to `{"status":"ok"}` |
| 🟡 MEDIUM | `_notifications` lost on restart (in-memory only) | Bond all notifications to molecular store |
| 🟡 MEDIUM | `subprocess.run(shell=True)` in monitors (would be injection if templated) | Switch to `shell=False` + `shlex.split()` |
| 🟢 LOW | No Pydantic `max_length` constraints | Add `Field(max_length=4096)` |
| 🟢 LOW | No rate limiting on CWS API | Add `slowapi` |

The CRITICAL and HIGH items were fixed tonight. MEDIUM and LOW are
pinned for follow-up.

## The fix is small. The root causes are bigger.

There are **seven** distinct contributing causes that let these
vulnerabilities exist together in the same codebase. Each one is
fixable individually, but the PATTERN is what produced the situation.

### Root cause 1 — Two divergent source trees

`/s7/skyqubi-private/` (the git working copy, canonical source, where
edits land) and `/s7/skyqubi/` (the deployed runtime, where systemd
services actually read from) **drift**. The `s7-cws-engine.service`
unit has `WorkingDirectory=/s7/skyqubi/`, and Python imports `engine.s7_server`
from there — not from the git tree.

When I edited `engine/s7_skyavi.py` in the private repo and restarted
cws-engine, **the running process did not pick up the change**, because
it was reading the deployed copy at `/s7/skyqubi/engine/s7_skyavi.py`.
The vulnerable SHELL_ALLOWLIST stayed live in the running process for
an extra round of restart-test-debug.

**Why this is a root cause, not just an inconvenience:** there is no
mechanism that guarantees private and deployed are in sync. A fix to
private feels "shipped" but isn't actually running. A reviewer reading
either tree gets a different picture of what the appliance is doing.

### Root cause 2 — Public is reviewed but private is where the work happens

The security reviewer audited `github.com/skycair-code/skyqubi-public`,
which is the public mirror. Per the freeze rule, public is months out
of date relative to private. **Every finding in the review applied to
private as well**, but no review process triggers on private edits.
The freeze rule is correct (we don't ship unfinished work to public),
but it created a gap: the reviewable surface is stale, and the
authoritative source has no review.

### Root cause 3 — The civilian-only mandate isn't enforced in code

Memory: *"S7 SkyQUBi is a civilian-only AI appliance for households
and small businesses. Offensive security capabilities are explicitly
out of scope."*

The mandate exists. It's in `project_skycair_context.md`. Yet `nmap`,
`nikto`, `sqlmap`, and `gobuster` were in the SHELL_ALLOWLIST. **A
mandate written in memory is not a guard rail.** Nothing in the build,
the lifecycle test, the audit-pre script, or the audit-post script
checks the SHELL_ALLOWLIST against the mandate. Someone (probably an
earlier session) added the offensive tools "for completeness" and no
process caught the contradiction.

### Root cause 4 — Allowlists grow without justification

The original SHELL_ALLOWLIST had **51 entries** spanning system
inspection, package management, cloud CLIs, security scanners, IaC
tools, and Windows utilities. There's no comment in the source
explaining why each entry was added. There's no test that asserts
"every entry in the allowlist must justify itself." The list grew
through accumulation, and accumulation is one-directional unless
someone actively audits.

The reviewer's recommended hardened list has **15 entries**. The
diff is 36 entries removed. None of those 36 had a clear reason to
be there in the first place — they were just there.

### Root cause 5 — Configuration drift between code and reality

`EXPECTED_PORTS = {"7077", "7080", "7081", "7086", "7090", "7091", "443"}`
in the port baseline monitor reflects an old port range. The actual
production stack runs on `57077` (CWS engine), `8080` (Caddy), `57080-57092`
(pod services). Memory `feedback_port_range.md` even says:
*"Internal services on 57xxx, public via 8080/Caddy, non-standard
ports are intentional."*

The port migration happened in code but the monitor was never
updated. The result: a monitor that fires BABEL alerts on every tick,
with both "MISSING ports 7077, 7080..." and "UNEXPECTED ports 57077,
57080..." in the same alert. Pure noise. The monitor became useless
the day the migration shipped, and stayed useless because **no test
asserts that EXPECTED_PORTS matches the actual running ports**.

### Root cause 6 — UNKNOWN drift in source as well as in environment

Tonight Jamie has been hammering the "no UNKNOWNs" discipline against
*environmental* drift (the orphaned `172.16.7.1/32` on `lo`, the
stale `/s7/s7-project-nomad/` reference). The same discipline applies
to **source** drift:

- `192.168.1.75` is a specific dev-box LAN IP hardcoded in
  `ALLOWED_OUTBOUND`. It has no business in a public source tree.
  It's wrong for any deployment other than the original dev machine.
  It leaks network topology.
- `pwsh` and `wslpath` in SHELL_ALLOWLIST — Windows/PowerShell tools
  on a Fedora-only target. Pure copy-paste residue from a different
  context.

Both are UNKNOWNs in the same sense Jamie warned about: they exist
because nobody removed them, and they'll keep existing until someone
notices.

### Root cause 7 — Allowlist-with-denylist is the wrong primitive

The current design lets the Ollama model **compose arbitrary shell
commands** from the allowlist. The model is not a trusted security
boundary. The denylist tries to catch dangerous patterns, but every
denylist has gaps (the reviewer found that `sudo rm` slips through
the `rm` denylist because the first word is `sudo`).

The **right** primitive is registered skills with hardcoded command
strings and predictable outputs. The `shell()` method should be the
last resort, not the primary execution path. The reviewer noted this
explicitly:

> *"The allowlist/denylist pattern is fundamentally weaker than
> registering explicit skills with hardcoded commands. The current
> design allows the Ollama model to compose arbitrary shell commands
> within the allowlist — the model is not a trusted security boundary."*

Tonight's fix shrinks the allowlist from 51 to 35. That is necessary
but not sufficient. The architectural fix is to convert every legitimate
shell call into a registered skill and treat the free-form `shell()`
method as deprecated.

## What I fixed tonight (and what I deferred)

### Fixed (CRITICAL + HIGH, all in private)

- `engine/s7_skyavi.py` SHELL_ALLOWLIST: 51 → 35 entries. Removed
  `sudo`, `dnf`, `cryptsetup`, `nmap`, `nikto`, `sqlmap`, `gobuster`,
  `bandit`, `eslint`, `sonar-scanner`, `terraform`, `tofu`, `ansible`,
  `helm`, `k3s`, `aws`, `az`, `gcloud`, `doctl`, `pulumi`, `pwsh`,
  `wslpath`, `npm`, `pip3`, `curl`, `nft`, `firewall-cmd`, `systemctl`,
  `iwconfig`, `ethtool`, `psql`, `cd`. Added a header comment explaining
  why each removal happened.
- `engine/s7_skyavi_monitors.py` `EXPECTED_PORTS`: `7xxx → 57xxx`
  matching the actual stack.
- `engine/s7_skyavi_monitors.py` `ALLOWED_OUTBOUND`: removed the
  hardcoded `192.168.1.75`. Now built from `{"127.0.0.1", "::1", "0.0.0.0"}`
  plus an env-var extension `S7_ALLOWED_OUTBOUND` (comma-separated).
- `engine/s7_server.py` `/status`: reduced to `{"status": "ok"}`. The
  `circuit_open` and endpoint enumeration moved behind `Bearer` auth at
  `/skyavi/core/status`.

### Deferred (MEDIUM + LOW — pinned for follow-up plan)

- `_notifications` in-memory → bond all notifications to molecular store
- `subprocess.run(shell=True)` → `shell=False` + `shlex.split()`
- Pydantic `max_length` constraints on all request models
- Rate limiting via `slowapi`
- The architectural fix: convert the free-form `shell()` calls into
  registered skills with hardcoded command strings

## How to prevent this class of issue going forward

Each root cause needs its own guard rail. None of these are built
tonight — they're follow-up plan items. But naming them is the start.

1. **Single-tree discipline** — eliminate the `/s7/skyqubi/` deployed
   tree as a divergent source. Either (a) `/s7/skyqubi/` becomes a
   bind-mount or symlink to `/s7/skyqubi-private/`, or (b) every
   service unit reads from `/s7/skyqubi-private/` directly. The
   "private" tree is the only source of truth.
2. **Private review gate** — the reviewer process should run against
   private, not just public. Either schedule a periodic review of
   private, or build an automated linter that runs on every private
   commit and catches the same class of issues a human reviewer would.
3. **Encode the civilian-only mandate as a test** — `s7-lifecycle-test.sh`
   gains a check that asserts `SHELL_ALLOWLIST` does not contain any
   tool from a forbidden set: `nmap, nikto, sqlmap, gobuster, sudo,
   aws, az, gcloud, doctl, terraform, helm, pwsh`. Fails the gate.
4. **Allowlist justification** — every entry in `SHELL_ALLOWLIST`
   gets a comment explaining what skill needs it and why. New entries
   require the comment. A test asserts every entry has one.
5. **Port baseline auto-discovery** — `EXPECTED_PORTS` becomes
   `discovered_ports = ss -tln | parse + filter` rather than a static
   set. The monitor compares against the discovered set from boot
   time, not a stale literal.
6. **No hardcoded IPs in source** — a lint rule that fails commits
   containing literal RFC1918 IPs in `*.py` outside test fixtures.
7. **Skill-first execution** — open a follow-up plan to migrate every
   `shell()` call to a registered skill. Mark `Samuel.shell()` as
   deprecated in the docstring. Add a test that warns when it's
   invoked at runtime.

## The covenant frame

The civilian-only mandate is a **promise to families**. Every
offensive tool in the allowlist was a tiny breach of that promise,
sitting silently waiting for the model to compose the wrong sentence.
The fact that it never fired is luck, not safety. Removing them is
the smallest version of keeping the promise.

The deeper covenant move is the architectural one: stop trusting the
model to behave inside an allowlist. Trust only the explicit skills
the operator has registered. Every skill is a deliberate yes; nothing
else exists.

That is what sovereignty looks like in code.

## Second-pass review — additional findings

A live re-scan of the same public repo
(`/s7/Downloads/skyqubi-security-review-live-2026-04-13.md`) caught
**three additional CRITICAL findings** that the first review missed,
plus several HIGH/MEDIUM items in `s7_skyavi_skills.py`. The most
important of these is an architectural bug that **completely undermined
the SHELL_ALLOWLIST hardening from the first pass**.

### CRITICAL — `&&`-chain bypass (architectural)

`Samuel.shell()` validated only the first word of the command, then
passed the entire string to `asyncio.create_subprocess_shell()` —
which evaluates `&&`, `||`, `;`, `|`, backticks, and `$()` as bash
control flow. **Removing `nmap` from the allowlist did nothing if any
skill used `echo === scan === && nmap whatever`** — `echo` passed the
first-word check and `nmap` ran in the chain regardless.

Dozens of skills used exactly that `echo "===" && cmd1 && cmd2 && ...`
pattern. The reviewer found this as the deepest-impact bug.

**Fix applied tonight:** Added a defensive layer at the top of
`Samuel.shell()` that rejects any command containing `&&`, `||`, `;`,
`|`, `$(...)`, or backticks before reaching the allowlist check. The
new error message tells the caller why and what to do instead. This
breaks every skill that used compound commands — they now return
"DENIED: compound shell commands are not allowed" until they are
refactored to be single-command or to use Python instead of shell.

The architectural fix the reviewer recommends — converting every skill
to `subprocess.run([...], shell=False)` with hardcoded arg lists — is
correct but is a multi-day refactor across the entire skills file.
Tonight's defensive fix CLOSES THE BYPASS even though many skills are
broken until they're refactored. Better broken than vulnerable.

### CRITICAL — `training` category skills (data exfiltration)

7 registered skills under `category="training"` that aggregated
`~/.bash_history`, full git log, system baseline, service status, and
container state — reachable by any caller of `/skyavi/chat` with the
trigger phrase. **Pure data exfiltration.** Removed entirely. A
replacement note in the source explains that training data collection
is a privileged steward operation and belongs in a separate
authenticated CLI (`iac/training-export.sh`), not in the chat API.

Removed skills:
- `bash_history` — `cat ~/.bash_history`
- `build_history` — `git log --all`
- `build_diffs` — `git log --stat`
- `container_build_history`
- `service_logs_all` — 24 hours of CWS+Caddy+Ollama logs
- `system_audit` — full OS+svc+ports+models snapshot
- `export_training` — aggregate of all of the above

### CRITICAL — `nat_rules` explicitly called `sudo nft`

Even with `sudo` removed from the SHELL_ALLOWLIST in the first pass,
this skill was hardcoded to call `sudo nft list table nat` via the
shell() compound chain. The first word of the command was `echo`
(allowed), so the first-word check passed; bash then evaluated `&&
sudo nft ...` and ran it. **Two layers of bypass in one skill.**

**Fix applied tonight:** Rewrote `nat_rules` as a single command
`nft list ruleset` (no sudo, no compound). On Fedora, an unprivileged
user can read the netfilter ruleset without escalation if CAP_NET_ADMIN
is granted to the service or if the ruleset isn't restricted. If it's
not readable, the skill returns an honest error rather than escalating.

### HIGH — Port errors in skills (silent failures)

`ollama_models`, `qdrant_status`, `system_audit`, `deploy_check` all
hardcoded `127.0.0.1:7081` (Ollama) or `127.0.0.1:7086` (Qdrant) —
the OLD port range. The actual stack runs on `57081` / `57086`. These
skills returned `"Ollama not reachable"` or `"Qdrant not reachable"`
on every call — silent failures that would be confusing to debug.

**Fix applied tonight:** Rewrote `ollama_models` and `qdrant_status`
as Python urllib calls (no shell, no curl, no compound commands)
pointing at the correct 57xxx ports. The other two referenced skills
(`system_audit`, `deploy_check`) were inside the `training` category
that got removed entirely.

### HIGH — Service name validation gaps

`restart_service`, `restart_container`, `service_logs`, `container_logs`
all checked only `startswith("s7-")` and then interpolated the
user-provided name directly into a shell command. A name like
`s7-foo --signal=KILL` would pass the prefix check and let the user
inject systemctl flags.

**Fix applied tonight:** Added a strict regex
`^s7-[a-z0-9._-]{1,60}$` that all four skills now use. Anything else
returns `DENIED` with the regex shown so the user knows why.

### MEDIUM — `header_check` allowed arbitrary outbound URLs

`header_check` accepted any HTTPS URL via shell+curl — enabling SSRF
against internal cloud metadata endpoints (e.g.,
`http://169.254.169.254/`) and arbitrary outbound exfiltration.

**Fix applied tonight:** Restricted to **loopback only** via strict
regex (`^https?://(127\.0\.0\.1|localhost|\[::1\])`). Rewrote as
Python urllib (no shell, no curl). For a sovereign offline appliance,
the only legitimate use case for header_check is testing S7's own
services — never external hosts.

## Updated status

- **CRITICAL fixes from first review:** SHELL_ALLOWLIST 51→35 entries
  in `s7_skyavi.py`. Live in deployed tree, verified — every offensive
  tool (nmap, nikto, sqlmap, gobuster, sudo, dnf, cloud CLIs, npm, pip3,
  curl, nft, firewall-cmd, systemctl, iwconfig, ethtool, psql, cd) is
  out. The retained 35 are read-only system inspection only.
- **CRITICAL fixes from second review:** `&&`-chain bypass closed in
  `Samuel.shell()`; `training` category removed; `nat_rules` rewritten
  without sudo; service-name regex tightened. Live in deployed tree,
  verified.
- **HIGH fixes:** Port baseline (`s7_skyavi_monitors.py`),
  ALLOWED_OUTBOUND env-var, port errors in skills (Ollama/Qdrant
  refactored to urllib), service-name validation. Live.
- **MEDIUM fixes:** `/status` reduced to `{"status":"ok"}`;
  `header_check` restricted to loopback. Live.
- **MEDIUM still pending:** `_notifications` to molecular store;
  `subprocess.run(shell=True)` → `shlex.split`; Postgres password path
  to env var; Pydantic `max_length`.
- **LOW still pending:** `slowapi` rate limiting.
- **Architectural follow-up still pending:** convert every `shell()`
  call to `subprocess.run(shell=False)` with hardcoded arg lists.
  Tonight's defensive fix closes the bypass but breaks many skills
  that used compound commands — each broken skill needs a Python
  rewrite. This is its own multi-day plan.

## Status

- Root cause analysis: this document
- CRITICAL + HIGH fixes (both reviews): applied to private,
  synced to deployed tree, cws-engine restarted, `/status` verified
- MEDIUM + LOW fixes: still pending follow-up plan
- Process changes (1-7 above): still pending follow-up plan
- Skills broken by the `&&` rejection: pinned for refactoring plan
