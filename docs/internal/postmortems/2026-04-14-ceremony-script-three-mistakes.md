---
title: Ceremony Script — Three Chair Mistakes (rm -rf, SSH assumption, token leak)
date: 2026-04-14 evening
severity: HIGH (token leak to conversation history) · MEDIUM (script safety)
reporter: Chair (self-reported after Jamie called out the pattern review)
status: closed — all three fixes landed in `jamie-run-me.sh` + `reset-to-genesis.sh` before any re-run
pairs_with: docs/internal/chef/jamie-love-rca.md (RCA step 2 — believe the tool over the summary line)
---

# Three Chair mistakes in `iac/immutable/jamie-run-me.sh` and its builder

During the first attempted real ceremony on 2026-04-14 evening, Jamie ran `bash iac/immutable/jamie-run-me.sh --real` and the output contained three shipped-by-the-Chair failures that Jamie caught and required fixed before any re-run. Jamie documented the evidence with phone screenshots before asking the Chair to review.

This postmortem names each mistake, explains why it was wrong, names the correct pattern, and records the fix. It stays in `docs/internal/postmortems/` as a permanent lesson so the Chair does not repeat these patterns in any future ceremony tooling.

## Mistake 1 — Unguarded `rm -rf` in a ceremony script

### What shipped

```bash
# jamie-run-me.sh
tmp="/tmp/s7-gold-push-$repo"
run_or_echo rm -rf "$tmp"                      # step 2
run_or_echo rm -rf "$tmp"                      # step 5 cleanup

# reset-to-genesis.sh
rm -rf "$STAGING"                              # top of builder
rm -rf "$STAGING"                              # --clean flag handler
```

Five unguarded `rm -rf` calls across two ceremony scripts. None of them validated the path before deleting.

### Why it was wrong

`set -uo pipefail` catches *unset* variables but does NOT catch variables set to empty strings. A future refactor that typos `tmp` as `trip` slips through `set -u` (because `$tmp` is still set, just empty), and `rm -rf ""` becomes a no-op on most modern `rm` versions — but the safety is implementation-dependent and the habit is wrong.

Worse: a refactor that changes `STAGING` to pull from a config file could introduce an empty value via a parse error, and `rm -rf` would traverse whatever the shell glob-expands next. Ceremony scripts must be deliberate about destructive operations. "It works because `rm` is defensive" is not the covenant discipline. The covenant discipline is "the script is deliberate about destruction."

### The correct pattern

```bash
safe_rm() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo "  🔴 safe_rm: refusing empty path" >&2
    return 3
  fi
  if [[ "$target" != /tmp/s7-gold-* ]]; then
    echo "  🔴 safe_rm: refusing path outside /tmp/s7-gold-* ('$target')" >&2
    return 3
  fi
  if [[ "$target" == *".."* || "$target" == *"*"* ]]; then
    echo "  🔴 safe_rm: refusing path with metacharacters ('$target')" >&2
    return 3
  fi
  rm -rf -- "$target"
}
```

Three guards:
1. **Empty string check** — refuses `rm -rf ""`
2. **Prefix check** — refuses anything outside `/tmp/s7-gold-*`
3. **Metacharacter check** — refuses `..` (path traversal) and `*` (glob expansion)

Plus `rm -rf --` to prevent a leading `-` in the argument being interpreted as a flag.

### Fix landed

All 5 `rm -rf` call sites in both scripts now call `safe_rm`. The `safe_rm` function is defined locally in each script (could factor out, but covenant discipline favors standalone ceremony scripts).

## Mistake 2 — Testing SSH auth without deciding the auth method first

### What shipped

```bash
# jamie-run-me.sh preflight (original)
if ! ssh -T -o BatchMode=yes -o ConnectTimeout=5 git@github.com 2>&1 | grep -qE '...'
then
  echo "  🟡 WARNING: ssh git@github.com did not confirm authentication."
  echo "  Continuing — gh auth may still work via https. If push fails,"
  echo "  we'll know about it and can stop."
fi
```

Three problems bundled:

1. **I tested an auth method I hadn't decided to use.** The push step was `git@github.com:` (SSH URL), but I hadn't verified SSH was the right choice for Jamie's environment. I assumed SSH, tested SSH, and when the test failed I continued anyway.
2. **The failure path "warned and continued."** A preflight check that fails-and-proceeds isn't a preflight — it's a log line. The correct pattern: if the check fails, ABORT with exit 1 and a clear message.
3. **I conflated identity with write-readiness.** `ssh -T` to github.com tests whether your SSH identity is registered — but it doesn't prove any particular repo is reachable or that you have write access. Even a passing `ssh -T` wouldn't guarantee the subsequent push would work.

### Why it was wrong

Ceremony scripts should make ONE decision about auth method at design time and enforce it at preflight. Mixing auth methods — "try SSH first, fall back to HTTPS if it fails" — is exactly the pattern that hides bugs behind soft warnings. The first ceremony's actual failure was "Repository not found" at push time, 200 lines deep in the output, not a preflight abort 3 seconds in.

### The correct pattern

Pick HTTPS at script-writing time because the PAT is already loaded and SSH keys may not be. Preflight asserts the PAT exists and has the right prefix. No SSH check. No fallback. No "continue on warning."

```bash
if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "  🔴 FAIL: GH_TOKEN env var not set."
  exit 1
fi
if [[ "${GH_TOKEN}" != gh[pousr]_* ]]; then
  echo "  🔴 FAIL: GH_TOKEN does not look like a github PAT."
  exit 1
fi
echo "  ✓ GH_TOKEN exported (${#GH_TOKEN} bytes) — credential helper ready"
```

### Fix landed

SSH preflight block removed entirely. Replaced with a PAT-existence + PAT-prefix check. The push step uses HTTPS exclusively.

## Mistake 3 — Token embedded in the push URL, echoed by `run_or_echo`

### What shipped

```bash
# jamie-run-me.sh step 2
run_or_echo git -C "$tmp" remote set-url origin "https://oauth2:${GH_TOKEN}@github.com/$ORG/$repo.git"
```

Plus `run_or_echo` prints `+ $*` to stdout on every real-run step. Result: **the literal PAT appeared 4 times in the terminal output** during the first `--real` attempt — once per repo that reached step 2 before the real auth failure.

Jamie documented the leak with phone screenshots before asking the Chair to review. The token in the screenshots matches the token that was live in `/s7/.config/s7/github-token` at the time of the run — `ghp_*`, ~40 bytes, with scopes `repo`, `admin:org`, `admin:gpg_key`, `admin:enterprise`, `project`, `codespace`, `audit_log`, `copilot`.

### Why it was wrong

There are at least four established patterns for passing a token to `git push`. The Chair chose the **worst one**.

| Pattern | Token lives in | Echoed? |
|---|---|---|
| **URL embedding** `https://oauth2:TOKEN@...` (what shipped) | Remote URL in git config + command-line args | **YES** |
| **HTTP extra-header** `git -c "http.extraHeader=Authorization: bearer $TOKEN" push` | Process command line (visible via `ps`) | Partial |
| **Credential-store file** `git -c credential.helper=store --file=...` | Mode-600 tempfile, deleted after push | No |
| **Stdin credential helper** `git credential approve` fed via stdin | In-memory git credential cache | **No** |

The Chair picked URL embedding because it was the most obvious path. It was also the only path that guaranteed the token would be logged. Every `run_or_echo` call that hit `remote set-url` or `push` printed the full expanded command — `echo "+ $*"` doesn't distinguish between safe args and secrets.

### The correct pattern — stdin credential helper

```bash
# Clean HTTPS URL — no token in the URL, in the config, or in logs.
git -C "$tmp" remote set-url origin "https://github.com/$ORG/$repo.git"

# Feed the token to git's in-memory credential cache via stdin.
{
  printf 'protocol=https\n'
  printf 'host=github.com\n'
  printf 'username=oauth2\n'
  printf 'password=%s\n' "$GH_TOKEN"
  printf '\n'
} | git -C "$tmp" -c 'credential.helper=cache --timeout=60' credential approve >/dev/null 2>&1

# Push — picks up the cached credential automatically.
git -C "$tmp" -c 'credential.helper=cache --timeout=60' push --force origin main

# Revoke immediately.
{
  printf 'protocol=https\n'
  printf 'host=github.com\n'
  printf 'username=oauth2\n'
  printf '\n'
} | git -C "$tmp" -c 'credential.helper=cache --timeout=60' credential reject >/dev/null 2>&1
```

The token is:
- Never in a URL (the remote URL is just `https://github.com/org/repo.git`)
- Never in a command-line arg (stdin only)
- Never in a git config file (cache is in-memory, and `credential.helper=cache` writes to a Unix socket, not disk)
- Never in `run_or_echo`'s `echo "+ $*"` output (the token is on stdin, not in `$*`)

Plus a defense-in-depth filter: `run_or_echo` and the push's own output are piped through `redact_secrets`, a sed filter that replaces any `oauth2:[^@]+@github.com` substring AND any `gh[pousr]_[A-Za-z0-9]{36,}` substring with a literal `REDACTED` marker.

### Fix landed

1. URL is now clean HTTPS
2. Credential cached via stdin before push, revoked after push
3. Push output piped through `redact_secrets` as second witness
4. `GH_TOKEN` existence + prefix check in preflight, no echo of the token itself

### Consequences

- **The leaked PAT must be rotated.** The Chair flagged this in real-time. Jamie documented with phone screenshots and initiated rotation.
- **Future ceremonies use the stdin helper pattern.** This postmortem is the covenant record; the script change is the enforcement.
- **Defense in depth**: even if a future refactor re-introduces a URL-embedded token, the `redact_secrets` sed filter catches it in logs. Not a substitute for the fix — a safety net under the fix.

## Lessons that promote to covenant discipline

1. **Every destructive operation in a ceremony script gets a path guard.** `rm -rf` is the obvious case; `git push --force` is another one that should get a "remote URL matches expected host" guard in a future iteration.

2. **Preflight checks ABORT on failure, they do not warn-and-continue.** If the check isn't worth aborting for, it isn't a preflight — it's a log line. Move it somewhere else.

3. **Pick one auth method at design time. Test ONLY that method. If the method doesn't work, fail loud and early, not deep into the real run.**

4. **Never pass a secret via a command-line argument if `set -x`, `echo "+ $*"`, or any logging function will fire on that command.** The safest pattern is stdin; the next safest is a mode-600 tempfile; URL embedding is never acceptable in a logged script.

5. **A "success" closing line does not mean success.** Jamie Love RCA step 2: *"believe the tool over the summary."* The first attempt's output had `✓ <repo> advanced to v6-genesis` lines for all 5 repos but zero successful pushes — the script's `run_or_echo` was unconditionally printing success regardless of exit code. This postmortem is partially a consequence of that RCA lesson; Jamie caught the `run_or_echo` bug specifically because he knew to believe the tool output over the summary.

6. **When a secret leaks, document the evidence first, then rotate.** Jamie's phone-screenshot discipline is covenant-grade. A text record of the leak (this postmortem + the git history of the commits) is traceable but the phone screenshot is the independent witness that survives even if the text record is later modified.

## Status

- ✅ All three fixes landed in `jamie-run-me.sh` and `reset-to-genesis.sh`
- ✅ `safe_rm` function with three-guard validation
- ✅ `redact_secrets` sed filter catches `oauth2:*@github.com` AND `gh[pousr]_*` patterns
- ✅ Stdin credential helper replaces URL-embedded token
- ✅ SSH preflight block removed
- ⏳ PAT rotation — Jamie's action, documented via phone screenshots
- ⏳ Ceremony re-run — pending fresh token load and repo-existence verification

## Scope this postmortem does NOT cover

- The "4 repositories not found" issue from the first real run. That's a separate RCA about whether the four immutable sibling repos were actually created, what names they have, and how the Chair should have verified repo existence before the ceremony attempted to push. Tracked as a follow-up.
- The `required_signatures` POST-404 issue on `skyqubi-immutable` (the only repo that successfully received its orphan commit on the first attempt). The script counted this as failure because the POST failed, but the commit itself landed. A second follow-up: the script should detect "push succeeded but protection apply failed" as a PARTIAL state, not a full failure.

Both follow-ups are tracked in the session-close handoff doc. Neither is blocked by this postmortem.

---

*Three Chair mistakes. One postmortem. No pattern left unwritten. Love is the architecture — and love tells the truth about its own failures.*
