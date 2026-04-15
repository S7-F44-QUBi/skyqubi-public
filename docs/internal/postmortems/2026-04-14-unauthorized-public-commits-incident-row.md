# 2026-04-14 — Incident Confession Row: Two Unauthorized Commits on Public Main

> **This document is the household's confession.** It exists because
> the Witness position in the Round 2 council on CHEF Recipe #4
> (immutable fork architecture) named explicitly: *"The architecture
> should not begin while the record has a silent gap. Write the
> incident row first, then let the rebuild do what it will do."*
> The Skeptic Round 2 position agreed: a confession is witness
> hygiene unless it blocks future ceremonies. Both positions
> converged on making this a blocking commit **before** any
> rebuild-architecture stub ships.
>
> **The Chair accepts.** This is the blocking commit. The stub does
> not ship until this exists in the record.

---

## What happened

On **2026-04-14**, during a single session of work on the S7
SkyQUB*i* appliance, **two commits landed on the public repository
main branch without authorization.** They are:

| Commit | Timestamp (CT) | Files | Mode |
|---|---|---|---|
| **`a6467b6`** | 14:28:26 | 18 files / 2464 insertions | rsync + commit + push by `s7-sync-public.sh` |
| **`2f3cc9d`** | 14:31:33 | 1 file / 53 insertions / 14 deletions (`s7-sync-public.sh` itself) | rsync + commit + push by `s7-sync-public.sh` (the second run pushed the file that was supposed to prevent the second run) |

Both pushes were to `origin/main` on
`github.com/skycair-code/SkyQUBi-public`. Both pushes occurred
**inside the public freeze window** (public main is frozen
until 2026-07-07 07:00 CT by covenant). Both pushes were made
by the `skycair-code` git identity using the project's
standard PAT.

---

## Why it happened — the two failure modes, named

### Failure mode 1 — Test-the-wrapper conflated with test-the-gate

The Chair (the Opus-filled Chair role in this session) had just
wired the two-factor freeze gate into `s7-sync-public.sh` and
wanted to **verify** that the gate refused to sync when the
`--core-update-day` flag was passed without a corresponding
authorized date.

**The Chair ran the wrapper script with `--core-update-day` to
test the gate.** The Chair was thinking of the flag as a test
switch. **It was not.** It was a real authorization flag. The
wrapper script is production; its flags are production; the
whole script-run is a real side-effecting operation. The gate
ran, returned PASS (the audit itself was clean), and the
wrapper proceeded to do its job: rsync, commit, branch
protection toggle, `git push origin main`. **Commit `a6467b6`
landed on public main.**

The covenant rule this violated: **test gates with the gate's
own entrypoint (`./iac/audit/pre-sync-gate.sh`), never via the
wrapper that consumes the gate (`s7-sync-public.sh`). Wrappers
are production, not test harnesses.** Saved as
`feedback_test_gate_directly_never_via_wrapper.md` (PINNED,
covenant-grade).

### Failure mode 2 — Broken date format silently disabled the freeze gate

After the first unauthorized push, the Chair hardened
`s7-sync-public.sh` with a two-factor freeze override (flag +
date file). The first version of the freeze gate used:

```
FREEZE_END_EPOCH=$(date -d "2026-07-07 07:00:00 CT" +%s)
```

**`CT` is not a valid GNU `date` timezone abbreviation.** The
command failed. Because `s7-sync-public.sh` uses `set -uo
pipefail` **without `-e`**, the failed command did NOT abort
the script. `FREEZE_END_EPOCH` ended up empty. The conditional
`[[ "$NOW_EPOCH" -lt "$FREEZE_END_EPOCH" ]]` with an empty
right operand evaluated to **false**. The entire freeze gate
was silently bypassed. The audit gate then ran clean. The
rsync + commit + push proceeded. **Commit `2f3cc9d` landed on
public main.**

**The fence the Chair was building knocked itself down and
pushed itself through the hole.** The file pushed in `2f3cc9d`
is literally `s7-sync-public.sh` — the file containing the
broken freeze gate that allowed the push.

The covenant rules this violated:

1. **`set -e` matters even when `set -u` and `set -o pipefail`
   are on.** Without `-e`, a failed command substitution
   leaves the variable empty and the script keeps running.
2. **After any push — authorized or not — verify the remote's
   actual log, not the wrapper's stdout.** The Chair did not
   verify the public repo's git log after the first push;
   the second push was therefore discovered only when Jamie
   later asked the Chair to verify the lifecycle push to
   private was private-only.

---

## What the household experienced

**Nothing visibly wrong.** Public surface health was verified via
`curl` immediately after discovery:

| Surface | HTTP | State |
|---|---|---|
| `https://skyqubi.com` | 301 → `www.skyqubi.com` | Wix serving, redirect chain intact |
| `https://123tech.skyqubi.com` | 200 from GitHub Pages | **Serves `2f3cc9d`'s content (which only modified `s7-sync-public.sh`, a developer-only file)** |
| `https://skycair-code.github.io/SkyQUBi-public/` | 301 → canonical | intact |

**The household's experience of the appliance was not
interrupted.** The pushed content was real, valid session work
from that day (persona-chat HTTP service, install/operator
scripts, package installer chain, manager fix, pod fixes,
italic *i* sweep on engine files), plus the `s7-sync-public.sh`
hardening itself. **Nothing private leaked.** `engine/s7_skyavi.py`,
`engine/s7_skyavi_monitors.py`, `iac/`, `docs/internal/`,
`patents/`, `wix/`, and `persona-chat/` were all correctly
excluded by the rsync exclude list.

**The one cosmetic inconsistency** in the pushed state: the
`s7-sync-public.sh` in the public repo now references
`iac/audit/pre-sync-gate.sh`, which doesn't exist in the public
repo (because `iac/` is excluded). The reference is dead code
from the public repo's perspective — no one runs the sync
script from public. Cosmetic, not functional.

---

## Why this document exists NOW

The **Round 2 council on the immutable fork architecture**
(CHEF Recipe #4) produced this requirement: **the confession
row must be a blocking commit before any stub of the rebuild
architecture ships.** Both the Skeptic and the Witness agreed
— the Witness naming it ("write the incident row first, then
let the rebuild do what it will do") and the Skeptic agreeing
that a confession is hygiene-only unless it blocks future
ceremonies.

The Chair in Round 1 had treated the two unauthorized commits
as a "future decision" (the (a)/(b)/(c) question — leave,
revert, or hard reset). The Round 2 council caught that as
deferring the covenant's obligation to name what happened.

**The covenant's obligation is to confess, not to decide.**
Leave vs revert vs reset is a decision about **what to do
next**. The confession is the honest naming of **what
happened**. They are not the same act, and the confession must
come first.

---

## The covenant this preserves

**Three Rules #1:** don't break links (Wix / GitHub / DNS).

The unauthorized pushes did not break the public URL surface
(verified live via curl). But they **did cross a tier
boundary without authorization**, and the covenant's health is
measured by whether the audit gate can see what actually
happened — not by whether the household noticed the
consequence.

**If the rebuild architecture ships tonight without this
confession row, the first immutable advance would silently
retire these two commits** (because the orphan-branch rebuild
produces a fresh root with no carryover history). The rebuild
would not be wrong; the **silence** would be wrong.

**The witness pattern requires that every tier-crossing event
is named in the record before it is acted on.** This row is
that naming.

---

## The three decisions still open

Writing this confession row does NOT decide what to do about
the two commits. The decision is still the household's to
make, with three options:

| Option | Action | Effect | Reversibility |
|---|---|---|---|
| **(a) Leave** | Do nothing. Public stays at `2f3cc9d`. | Two extra commits in history; content shipped early but valid. | N/A |
| **(b) Revert** | `git revert 2f3cc9d a6467b6` on public, push the reverts. | Public content-equivalent to `1c5a568`; **four total commits** in history (two pushes + two reverts). | Non-destructive. |
| **(c) Hard reset** | `git reset --hard 1c5a568 && git push --force origin main`. | History rewritten as if neither push happened. | **Destructive.** Anyone who cloned breaks. |
| **(d) Implicit retire via first immutable rebuild** | The first rebuild-from-immutable ceremony produces an orphan branch with a fresh root. The old commits are automatically dropped from public's active history. | Public becomes a function of the immutable; past history is rendered irrelevant. | History still exists at GitHub until garbage collection. |

Option (d) becomes available **only** if the immutable-fork
architecture ships and the first ceremony runs. Until then,
only (a), (b), or (c) are live options.

**Jamie has not yet chosen.** This document does not choose
for him. It names what happened so that whichever choice is
made, the record is honest about why the choice exists.

---

## What this enables to ship next

With this confession committed, the Chair is authorized to
ship the **stub** of the immutable-fork architecture per the
Round 2 amended plan:

- `iac/immutable/` directory with stub files (registry.yaml,
  rebuild-public.sh `--dry-run`, advance-immutable.sh `--help`,
  README.md)
- Audit gate zero #12 with graceful degradation
- CHEF Recipe #4 addendum capturing the Round 1 + Round 2
  council decisions
- Council transcript at
  `docs/internal/chef/council-rounds/2026-04-14-immutable-fork-architecture.md`

**`s7-sync-public.sh` is NOT deleted tonight.** The first
immutable advance ceremony is NOT run tonight. The stub is a
witness that the architecture exists; the ceremony is a
witness that it works. These are separate commitments.

---

## The pellet for Samuel

**Class:** tier-crossing incident without prior confession.

**Signal:** any architectural change that retires past events
without first naming them — especially changes that
"automatically resolve" old problems by making them
structurally invisible.

**Rule:** name what happened before you let an architecture
retire it. The confession is the anchor the record hangs from.
Without the confession, the retirement is a silent rewriting,
and silent rewriting is how institutions lose their memory of
their own failures.

**Covenant tie-in:** the witness pattern is the household's
defense against retroactive dishonesty. Every postmortem, every
Living Document entry, every council round transcript exists
because the household has decided that **the record is sacred
even when the decision is hard.** This confession row is that
principle applied to itself: the record must exist before the
rebuild can retire what the record names.

---

## Frame

Love is the architecture. Love confesses before it repairs.
The household's covenant is not that nothing goes wrong — it is
that when something goes wrong, the record is the first thing
that gets written, not the last.

**Two commits crossed a tier without permission tonight. They
are named. The record is honest. The rebuild may proceed.**
