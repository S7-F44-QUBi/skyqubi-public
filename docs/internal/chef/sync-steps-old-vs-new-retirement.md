# Sync Steps — Old vs New (Old Formally Retired)

> **Status (2026-04-14):** The **OLD** step sequence is formally
> **retired in documentation**. The `s7-sync-public.sh` script
> remains **operationally active** until the first immutable
> advance ceremony per the Round 2 council ruling on CHEF Recipe
> #4. This is an intentional transitional state — sync authority
> has not yet been handed off.
>
> **The NEW step sequence is canonical going forward.** Any future
> design work, new script, new recipe, or new training signal
> should reference the NEW steps, not the OLD ones. The OLD
> sequence is kept in this document only as historical reference.
>
> **Rule of the retirement.** If you are reading this document and
> you are about to follow the OLD steps — stop. Either the first
> immutable advance ceremony hasn't happened yet (in which case
> you're the Jamie+Tonya ceremony, not a sync operator) or
> something has gone wrong (in which case this is exactly the
> situation the audit gate and the council pattern exist to
> catch).

---

## The two paths

| | OLD (retired in documentation) | NEW (canonical) |
|---|---|---|
| **Mechanism** | Sync bridge (rsync + commit + push) | Rebuild from immutable (git bundle → orphan branch → force-push) |
| **Source of truth at push time** | Live private tree | Frozen signed bundle |
| **Script** | `s7-sync-public.sh` | `iac/immutable/advance-immutable.sh` + `iac/immutable/rebuild-public.sh` |
| **Freeze mechanism** | Two-factor runtime gate (flag + `core-update-days.txt`) | Ceremonial — the immutable only advances on CORE yearly updates. No runtime gate needed. |
| **Branch protection on public** | Toggled OFF during push window, ON otherwise | Permanently ON. Orphan-branch force-push uses a ceremony-only credential, not the main-branch rule. |
| **Failure mode: test-the-wrapper bypass** | **Real** (caused `a6467b6` tonight) | Impossible — testing `rebuild-public.sh --dry-run` never touches public |
| **Failure mode: silent gate bypass on broken bash** | **Real** (caused `2f3cc9d` tonight, broken `CT` timezone under `set -uo pipefail` without `-e`) | Impossible — there's no runtime freeze check to break. The immutable's existence IS the freeze. |
| **Public history shape** | Linear, accumulating commits | Orphan branch, fresh root per rebuild |
| **What the audit gate verifies** | Zero #10 frozen-tree pin on public/main | Zero #12 byte-match public ↔ rebuild(latest immutable) |
| **Trust model** | Single point of failure (the sync script + the PAT + the toggle) | Four-witness distributed (audit gate + council + Tonya sig + image-signing key) |
| **Retires what** | Nothing — public accumulates history forever | Each rebuild retires prior public history (orphan-branch reset) |

---

## OLD step sequence — RETIRED in documentation 2026-04-14

The procedure that was operational until tonight:

```
OLD — s7-sync-public.sh flow                              [RETIRED]
──────────────────────────────────────────────────────────────────

  1. Edit on lifecycle branch
  2. Commit to lifecycle
  3. Merge lifecycle → private/main (fast-forward)
  4. Push private/main to origin
  5. [Decision] Is today a Core Update day?
       — Required both the --core-update-day flag AND today's date
         in iac/audit/core-update-days.txt (two-factor)
  6. Run: bash s7-sync-public.sh --core-update-day
        a. PRE-FLIGHT 1 — freeze gate (flag + date file)
        b. PRE-FLIGHT 2 — audit gate (zeros 1-12)
        c. Phase 1 rsync (private → public, with excludes)
        d. Phase 2 rsync (docs/public/ → docs/)
        e. git add -A + git commit in /s7/skyqubi-public
        f. curl DELETE required_signatures protection rule
        g. curl DELETE required_pull_request_reviews rule
        h. git push origin main
        i. curl POST required_signatures protection rule
        j. curl PATCH required_pull_request_reviews rule
  7. Verify public surface via curl (Wix, GH Pages, catcher domains)
  8. Wait 30-120s for GH Pages Jekyll rebuild
  9. Update iac/audit/frozen-trees.txt pins
 10. Commit pin updates
 11. Push pin updates to private origin
 12. Re-run audit gate (expect PASS)

THREE FAILURE MODES NAMED BY THE 2026-04-14 INCIDENTS:

 (F1) Test-the-wrapper conflated with test-the-gate
      — running bash s7-sync-public.sh --core-update-day "to test
        the gate" actually executed the sync and pushed to public
        (caused commit a6467b6)

 (F2) Broken bash under set -uo pipefail (no -e)
      — FREEZE_END_EPOCH=$(date -d "2026-07-07 07:00:00 CT") failed
        because "CT" is not a valid GNU date timezone abbreviation;
        the failed command left the variable empty; the empty
        comparison evaluated false; the freeze gate was silently
        bypassed; the audit gate passed; the sync completed and
        pushed the very script that contained the broken gate
        (caused commit 2f3cc9d)

 (F3) Branch protection toggle window
      — between steps 6f/6g and 6i/6j, public main was literally
        unprotected at exactly the moment code crossed the tier
        boundary. Any race condition during that window could push
        unauthorized content.

FULL POSTMORTEM:
  docs/internal/postmortems/2026-04-14-unauthorized-public-commits-incident-row.md
```

**Retirement rationale (summary):** the sync bridge has three
moving parts (script, branch protection toggle, runtime freeze
gate) that can each fail silently. The `set -uo pipefail` without
`-e` pattern in the freeze gate allowed a typo in a timezone
abbreviation to silently disable the covenant's protection. The
toggle window creates a real race surface. The wrapper-vs-gate
test confusion is a training bug in the script's own interface.
**No amount of hardening the old script closes all three failure
modes simultaneously.** The architecture itself is the bug.

---

## NEW step sequence — canonical 2026-04-14 forward

The procedure that replaces the retired one:

```
NEW — Immutable Fork + Rebuild Public flow                [CANONICAL]
──────────────────────────────────────────────────────────────────

PHASE A — Private work (unchanged from old)

  1. Edit on lifecycle branch
  2. Commit to lifecycle
  3. Optional: fast-forward lifecycle → private/main
  4. Push private/main to origin

PHASE B — The CORE yearly update ceremony (Jamie + Tonya + key + council)

  5. Run iac/audit/pre-sync-gate.sh. Must be green. All pinned
     items reviewed and either resolved or carried forward with
     named reason in the council round.

  6. Convene a council round on CHEF Recipe #2 (Bible
     Architecture Multi-Agent Council). Topic: "is this
     private/main state ready to become the next canonical
     immutable?" Two rounds minimum per the Chair code-of-conduct.

  7. Freeze the candidate private/main sha by pinning it in
     iac/audit/frozen-trees.txt. Re-run the audit gate. Still
     green.

  8. Tonya signs. Per-persona sign for any voice or LYNC changes;
     per-system sign for the whole advance. If Tonya does not
     sign, the advance stops and private/main continues moving
     freely.

  9. Produce the bundle:
        git bundle create /s7/immutable/S7-QUBi-IMMUTABLE-v<year>.bundle <candidate-sha>

 10. Sign the bundle with the image-signing key:
        gpg --detach-sign --armor --output <bundle>.sig <bundle>

 11. Append a new entry to iac/immutable/registry.yaml with:
        - version: v<year>
        - advanced: <ISO8601>
        - private_main_sha: <candidate sha>
        - bundle_path, bundle_sha256, signed_by, signature_path
        - public_manifest_sha256
        - tonya_signoff: { artifact_path, signed_at, notes }
        - council_round: <path to Round 1+2 transcript>
        - advanced_by: [jamie, tonya]
        - retires: <prior version or null>
        - frozen_trees_pin_update: { lifecycle, private_main }
        - notes

 12. In the SAME commit as step 11:
        - Remove the public/main line from iac/audit/frozen-trees.txt
          (public is now a function of the immutable, not a tracked branch)
        - Retire the `immutable-registry-empty` entry in pinned.yaml
          (the pin-transition protocol — Round 2 Skeptic catch)

 13. Commit this whole set on lifecycle; fast-forward to private/main
     and push.

PHASE C — The rebuild (deterministic, no human input during run)

 14. Invoke iac/immutable/rebuild-public.sh (no positional arguments —
     the script reads the latest non-retired entry from the registry).

     The script:
        a. Reads the newest non-retired registry entry
        b. Verifies bundle file exists at bundle_path
        c. Verifies sha256sum(bundle) matches bundle_sha256
        d. Verifies image-signing-key signature on the bundle
        e. Verifies Tonya's sign-off artifact exists and verifies
        f. Unpacks bundle into a scratch git repo
        g. Extracts files matching PUBLIC_MANIFEST.txt whitelist
        h. Creates an ORPHAN BRANCH in /s7/skyqubi-public
           (fresh root, no carryover history)
        i. Single commit signed by image-signing key
        j. Force-push orphan branch to origin/main
           (this is the ONLY force-push authorized in the S7
           architecture — permitted because deterministic rebuild
           from the same immutable is a no-op and from a different
           immutable is an explicit ceremony each)

PHASE D — Verification (always, no exceptions)

 15. Run audit zero #12. Must be green. Public/main content must
     byte-match what rebuild-public.sh produces from the latest
     registered immutable. If not, the rebuild failed and the
     advance is rolled back by reverting the registry commit (the
     bundle and signature remain on disk for investigation).

 16. Verify the remote log directly:
        cd /s7/skyqubi-public && git log --oneline -3
     (CRITICAL: read the remote's git log, not the wrapper's stdout.
      This is the hard lesson from the 2026-04-14 incident. The
      rebuild script is still a script; verify reality independently.)

 17. Verify public surface health via curl:
        curl -sI https://skyqubi.com
        curl -sI https://123tech.skyqubi.com
        curl -sI https://skycair-code.github.io/SkyQUBi-public/

 18. Wait 30-120s for GitHub Pages Jekyll rebuild.
     Re-curl https://123tech.skyqubi.com — verify new content serves.

 19. Close the council round with the advance record. The
     council-rounds transcript becomes the permanent witness.

 20. Append to the Living Document.

FOUR-WITNESS GATEKEEPER (no single point of authorization):

  - The audit gate (zeros 1-12) — refuses on any drift
  - The council round (Chair + Skeptic + Witness + Builder) — refuses on any unresolved BLOCK
  - Tonya's signature (covenant veto) — refuses on any LYNC or SAFE regression
  - The image-signing key (cryptographic witness) — refuses forgery

  If any of the four refuses, the advance halts. There is no
  single point of authorization because there is no single point
  of trust.

FAILURE MODE CLOSURE:

 (F1) Test-the-wrapper — CLOSED. rebuild-public.sh --dry-run prints
      what it would do and does NOT touch public. Testing is safe.

 (F2) Silent gate bypass on broken bash — CLOSED. There is no
      runtime freeze gate to break. The immutable's existence IS
      the freeze. An immutable either exists in the registry
      (public is whatever it says) or doesn't (public stays
      whatever the last immutable said). No variable can be
      "silently empty."

 (F3) Branch protection toggle window — CLOSED. Branch protection
      on public/main is PERMANENTLY ON. The orphan-branch force-
      push uses a separate ceremony-only credential that doesn't
      require toggling the main-branch rules.

FULL ARCHITECTURE:
  docs/internal/chef/04-immutable-fork-public-rebuild.md
COUNCIL TRANSCRIPT:
  docs/internal/chef/council-rounds/2026-04-14-immutable-fork-architecture.md
```

---

## The handoff — what the transitional state looks like NOW

**As of 2026-04-14:**

- The OLD steps are **retired in documentation** (you are reading that retirement right now)
- The OLD script (`s7-sync-public.sh`) is **still operational** — it remains the only functioning path to advance public/main until the first immutable ceremony happens
- The NEW steps are **canonical in documentation** but **not yet executable** — `advance-immutable.sh` and `rebuild-public.sh` are stubs that refuse to run
- The first immutable advance ceremony is **deferred** to a future authorized window with Jamie + Tonya + the image-signing key + a full council round
- Until the first ceremony, any legitimate sync (if authorized) uses the OLD path — **but the sync operator must know that the OLD path is already retired in documentation and is only being used because the NEW path isn't operationally ready**

**The physical retirement** — renaming `s7-sync-public.sh` to
`s7-sync-public.sh.retired` — happens **AT THE MOMENT** the first
`rebuild-public.sh` force-push completes successfully. That is
the sync-to-ceremony handoff defined in `iac/immutable/advance-immutable.sh --help`.

## Why the script remains operational until then

The Round 2 council on CHEF Recipe #4 ruled:

> *"Ship the stub. Defer the ceremony. Do not delete
> `s7-sync-public.sh` tonight — it remains the source of truth
> for public/main until the first ceremony yields authority.
> Retiring the old script prematurely creates a multi-month
> sunset half-state where public has no refresh mechanism (the
> Skeptic Round 1 catch)."*

**Retiring the old STEPS is safe** because anyone following them
from this doc forward now sees the retirement banner. **Retiring
the old SCRIPT prematurely is unsafe** because it leaves the
household with no operational sync until the first ceremony.

These are two different retirement actions. **Today: retire the
steps. Future ceremony day: retire the script.**

---

## Cross-reference — a reader's decision tree

**"I want to update public/main today. Which path do I use?"**

```
Is the first immutable advance ceremony complete?
 │
 ├── NO  → Use the OLD path IF AND ONLY IF today is on the
 │         authorized Core Update day list AND all Phase B
 │         council-round preconditions have been met in a
 │         special one-time exception window (Jamie + Tonya
 │         explicit).
 │         The OLD path is retired in documentation. Following
 │         it should be a rare, named, audited event, not a
 │         routine action.
 │
 └── YES → Use the NEW path. Run advance-immutable.sh. The
           registry will refuse to advance without the full
           ceremony. The rebuild is deterministic. The four-
           witness gate fires for you.
```

**"I want to TEST the sync path. Which do I use?"**

```
OLD path: there is no safe test. The only way to exercise
          s7-sync-public.sh is to run it, which pushes. This
          is the bug that caused tonight's incidents. NEVER
          run the wrapper to test the wrapper. Test the
          underlying gate directly via
          ./iac/audit/pre-sync-gate.sh.

NEW path: rebuild-public.sh --dry-run prints the full rebuild
          flow without touching public. Safe to run any time.
          This is one of the architectural reasons the NEW
          path exists.
```

---

## The Samuel training pellet from this retirement

**Retirement has two distinct acts: retire the STEPS in
documentation, and retire the SCRIPT in operation.** They are
not the same act and they do not happen at the same time.

- **Retiring the steps** is a *documentation change* that tells
  future readers "this sequence is historical; the canonical
  path is elsewhere."
- **Retiring the script** is an *operational change* that
  removes the file from the system (or renames it) and breaks
  anyone depending on it.

**In a transition between architectures, the steps can (and
should) be retired first, while the script remains operational.
The script retires only when the new architecture is proven to
serve the household's needs.** Doing the operational retirement
first creates a sunset half-state; doing the documentation
retirement first establishes the canonical direction without
breaking anything.

This is the same pattern as the 2026-04-14 multi-launcher drift
findings: **fix the launchers, not the running service.**
Retirement is a launcher-fix. The running service (the script)
keeps going until its replacement is genuinely ready.

---

## Frame

Love is the architecture. Love retires old patterns honestly —
naming what they were, why they were, what they cost, and when
the retirement becomes operational. Love also keeps the old
pattern running until the new one is proven, because the
household's experience of continuity is not optional.

**The steps are retired. The script continues. The ceremony is
scheduled. The record is honest.** That is the whole
transition, in one sentence.
