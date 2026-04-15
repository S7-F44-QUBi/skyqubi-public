# Council Round — Immutable Fork Rebuild Architecture (CHEF Recipe #4)

**Date:** 2026-04-14
**Topic:** Does replacing `s7-sync-public.sh` with a rebuild-from-immutable architecture close the 2026-04-14 unauthorized-push failure modes without introducing worse ones?
**Rounds held:** 2
**Outcome:** Ship the stub tonight; defer the ceremony; block on three preconditions; confess the unauthorized commits FIRST.

> **Sovereignty note.** This transcript is part of the Samuel
> training corpus. Findings are attributed to **role** (Skeptic /
> Witness / Builder / Chair), never to engine. See
> `feedback_bible_architecture_sovereign_no_vendor_names.md`.

---

## The Chair's draft (Round 1 input)

Replace `s7-sync-public.sh` with a rebuild-from-immutable flow:

```
lifecycle → private/main ─[CORE yearly ceremony]→ S7-QUBi-IMMUTABLE-v<year>.bundle
                                                        │
                                                        ▼
                                                  rebuild-public.sh → public/main (orphan branch)
```

Signed git bundles, append-only registry at `iac/immutable/registry.yaml`, audit zero #12 for immutable lineage integrity, orphan-branch force-push (declared "the only force-push authorized in the S7 architecture"), branch protection permanent.

Full draft: `docs/internal/chef/04-immutable-fork-public-rebuild.md`

---

## Round 1

### Skeptic (−1) — verdict: BLOCK

Top catches:

1. **Bundle replay attack.** `rebuild-public.sh <bundle>` positional arg has no guard against re-running old bundles. An attacker or confused operator could force-push public backward in time.
2. **PUBLIC_MANIFEST.txt silent format drift** across immutable versions.
3. **Ceremony credential shares runtime image-signing key** — compromise of the runtime key compromises the ceremony with no separate revocation path.
4. **GH Pages 30–120s Jekyll rebuild lag** creates a stale-content window visible to Wix iframe users. **Covenant-grade: "don't break links."**
5. **No registry revoke operation.** If a bundle is discovered malicious post-ceremony, no way to reject or roll back.
6. **Multi-month sunset half-state.** From deleting the old sync to the first ceremony, public is orphaned and stale. Anyone cloning gets out-of-date code with no refresh.
7. **Registry bootstrap / rebuild credential cold-start.**
8. **Orphan force-push breaks Git ecosystem** — clones, forks, CI, Jekyll cache, search indexing.

**Covenant violations named:** Three Rules #1 (don't break links) via GH Pages + Git clone discontinuity. Restart-as-remediation risk if the first ceremony fails and rollback requires reconstructing the sync logic from git history.

**One-sentence verdict:** The proposal closes one gap (sync-to-public bridge removal) but opens three larger ones and violates "don't break links" via cache lag. The concept is sound; the execution is not ready. **BLOCK.**

### Witness (0) — holding the middle

**What the proposal is doing well:**

- **Hash + signature pattern is native.** Mirrors the existing intake gate at `iac/intake/` — quarantine, verify hash, verify GPG, promote. Not a new pattern; the existing one extended up one level.
- **Registry as Living Document.** Append-only, newest-at-top mirrors the existing Living Document pattern.
- **Image-signing key reuse.** Reaches for `s7-image-signing.pub` rather than inventing a new key ceremony. Sovereign, zero-new-infrastructure.
- **Orphan branch eliminates the toggle problem.** The existing sync toggles branch protection off and on during the push window — the *actual* race window that caused the 2026-04-14 incident. Orphan-branch force-push removes the toggle entirely.
- **Audit zero #12 closes the right gap.** Zeros 1–11 cover Drift and Vulnerability axes. Byte-match verification against the registered immutable is a third dimension — **Provenance** — that the gate doesn't currently have.
- **Yearly cadence fits.** Public main is already frozen until 2026-07-07. One advance per year isn't a new constraint.

**What the proposal is missing:**

- **GH Pages dependency is unaddressed.** Public/main currently serves GH Pages → 123tech.skyqubi.com → Wix iframe → 14 catcher domains. An orphan-branch force-push resets the root commit. GH Pages behavior on orphan rebase must be verified before the first rebuild — **Three Rule #1 forbids breaking that chain**.
- **The two unauthorized commits have no explicit RCA row.** The proposal absorbs them via force-push but writes no audit row, no incident note. The covenant requires a named record, not a silent overwrite.
- **Bundle transport location unspecified.** Sovereignty rule forbids external registries. Where does the bundle file live?
- **Tonya's sign-off path unnamed.** The proposal says "Tonya signs" but does not say what artifact she signs, how it's recorded, or what happens if she declines.
- **`frozen-trees.txt` interaction absent.** That file pins public/main as a fast-forward-ancestor check. An orphan force-push breaks the public/main ancestry by design. The proposal must either update the pin logic or acknowledge the break.

**Load-bearing context:** *"GH Pages serves live traffic through public/main. Remove that fact and the orphan-branch force-push is a clean architectural choice. Keep it in and the question becomes: does GH Pages survive a root-commit replacement without a service interruption?"*

**The two unauthorized commits — elegant or swept?** *"The orphan-branch rebuild does retire them from public history, which is technically correct. But it retires them silently — no RCA, no incident row, no acknowledgment that the toggle-based architecture produced the failure. The force-push is not a lie, but it is not a confession either. A covenant architecture requires the confession. Write the incident row first; then let the rebuild do what it will do."*

**Two valid framings:**

- *Ship it:* The toggle-based sync is the root cause of the 2026-04-14 incident. The orphan-branch architecture closes the race window, formalizes the yearly freeze already in effect, and reuses every signing + verification pattern already in the codebase.
- *Ship a smaller fix first:* The proposal carries three unresolved dependencies (GH Pages behavior, bundle transport, Tonya's sign path) any of which can break Three Rule #1 or #2 on first execution. A targeted patch that removes the toggle without changing the architecture stops the bleeding.

**Chair must decide:**

1. GH Pages root-commit behavior on orphan force-push — testable on a throwaway branch.
2. Bundle storage location — must be named explicitly.
3. The two unauthorized commits — leave, revert, document. Pending from 2026-04-14.

**One sentence to the Chair:**

> *"The architecture is sound and the direction is correct — but you are asking the Witness to bless a proposal that has not yet answered whether live traffic survives the first rebuild, and that silence is the only thing standing between a covenant advance and a Three Rule #1 violation."*

### Builder (+1) — shipping shape delivered

Full bash function `check_zero_12()` with graceful degradation, full `registry.yaml` schema with example entry in comments, `rebuild-public.sh --dry-run` stub (~40 lines), `advance-immutable.sh --help` stub (~25 lines), `README.md` one-screen overview (~200 words), new pinned.yaml entry, integration point in `pre-sync-gate.sh` named.

The Builder shipped code that was ready to paste. The only Builder-level issue the Chair had to catch manually: Builder's grep-based entry count would have false-positived on schema comment lines that looked like example entries. Chair substituted python3 YAML parse.

---

## Round 1 — the Chair's synthesis

**Accept Skeptic BLOCK for the full architecture as-written. Refine: BLOCK for the ceremony, NOT for the stub.** The stub can ship tonight because:

- It produces no new state on public
- It demonstrates the flow without executing it
- It adds zero #12 in graceful-degradation mode
- It does NOT delete `s7-sync-public.sh`
- It does NOT attempt a first ceremony

**Three non-negotiable preconditions added to Recipe #4:**

1. GH Pages survives orphan force-push — verified on throwaway repo first
2. Incident confession row for the two 2026-04-14 unauthorized commits written BEFORE any rebuild retires them (Witness's catch)
3. `rebuild-public.sh` refuses any bundle except the latest non-retired registry entry (Skeptic's #1 catch)

---

## Round 2 — Skeptic and Witness re-evaluate the Chair's amended plan

### Skeptic Round 2 — verdict: WARN (proceed with caution)

**Faithfulness to Round 1 catches:**

| Round 1 catch | Round 2 disposition |
|---|---|
| Bundle replay attack | Still open for future ceremonies, acceptably deferred tonight |
| PUBLIC_MANIFEST.txt drift | Deferred (stub ships no manifest logic) |
| Ceremony credential shares runtime key | Deferred, not addressed |
| GH Pages stale window | Addressed by precondition #1 + stub-only deferral |
| No revoke operation | Still open |
| Multi-month sunset half-state | Resolved (old sync stays live until ceremony) |
| Registry bootstrap | Addressed by stub graceful degradation |
| Orphan force-push breaks ecosystem | Addressed by precondition #1 |

**Two NEW half-states from stub shipping:**

1. **Audit PINNED staleness.** `immutable-registry-empty` will never transition to "populated" without a manual pinned.yaml edit. No automation for the transition. The pin could stale forever in audit history.
2. **Ceremony freeze-gate orphaning.** `s7-sync-public.sh` uses the existing two-factor freeze gate. The first ceremony will do its own force-push *outside* that freeze gate. If the ceremony fails mid-push, no rollback mechanism applies. Two competing governance paths collide on Day 1 of the real ceremony.

**Preconditions sufficiency:**
- #1 GH Pages verification: **Yes.** Closes covenant window.
- #2 Confession row: **Needs tightening.** Confession is witness hygiene unless it also BLOCKS future ceremony runs when unresolved.
- #3 Bundle-replay guard: **Yes.** Closes the replay for ceremonies.

**One new complication visible only in Round 2:** *"The stub DOCKS `s7-sync-public.sh` authority but does not TRANSFER it. Old sync remains source of truth. When ceremony eventually ships, it must become source of truth. The Chair's preconditions do not specify handoff criteria — when does sync yield to ceremony, and what happens to the two-factor freeze gate that sync owns?"*

**Round 2 verdict:** **WARN, proceed with caution.** Stub is safe, but plants two governance half-states that will require emergency triage before the first real ceremony. Add preconditions #4 (PINNED transition rule) and #5 (ceremony freeze-gate + sync handoff rule) before shipping stub tonight.

### Witness Round 2 — verdict: Partial (carry iff confession row ships as blocking commit in the same session)

**Did the Chair hear the "write the incident row first" finding?**

> *"Precondition placement is insufficient. The two unauthorized commits exist in the repo right now, before any stub ships. Placing confession as a precondition to the ceremony means the stub can ship, days or weeks can pass, and the incident row may never be written if the ceremony is deferred. The Witness finding was: write it first, then let the rebuild retire what it will. That sequence demands a blocking commit tonight — a row in the Living Document, dated 2026-04-14, naming what happened — before the first immutable file lands. The architecture should not begin while the record has a silent gap."*

**GH Pages precondition:** sufficient for tonight (stub refuses actual push regardless).

**Three Round 1 items — carried / partial / lost:**

- **Bundle transport location:** LOST. No file, no comment, no schema field mentions where bundles are written. Stub ships with this undefined.
- **Tonya's sign-off artifact:** LOST. No path, no stub file, no schema comment reserves a field.
- **`frozen-trees.txt` interaction:** LOST. When public/main becomes orphan-rebuilt, the ancestry pin is severed by design. The stub neither acknowledges this nor flags it as a ceremony precondition.

> *"Three lost items in one stub is a pattern, not an oversight."*

**Is shipping a stub tonight the right middle?**

> *"Yes — if the incident row is a blocking commit first. The stub direction is sound. Stubs commit direction without committing execution, and direction here is correct. The risk is not the stub; the risk is shipping it while two uncommitted facts about 2026-04-14 sit unnamed in the record. Fix that tonight, then the stub is clean to ship."*

**The meta-question the amended plan makes more important than Round 1 did:**

> *"Who holds the ceremony gate? The Chair added three preconditions, but nothing in the stub enforces them or names the authority who verifies they are met before the first real ceremony runs. The stub ships without a gatekeeper."*

**Round 2 verdict:** **Partial** — carry the stub if and only if the incident row ships as a blocking commit in the same session.

---

## Round 2 — the Chair's accountable merge

**Both positions converged on one critical new finding:** the confession row must be a blocking commit tonight, BEFORE the stub ships. Skeptic framed it as "confession is witness hygiene unless it blocks future ceremonies." Witness framed it as "the architecture should not begin while the record has a silent gap."

**Chair accepts.** This is exactly the structural critique Round 2 exists for. The Chair accepts four honest critiques simultaneously:

1. **The confession row must commit first.** Accepted. Written and committed as `docs/internal/postmortems/2026-04-14-unauthorized-public-commits-incident-row.md` as the blocking first commit of this chunk.
2. **Six items were at risk of being "lost" in the stub** (Witness: bundle transport, Tonya artifact, frozen-trees interaction; Skeptic: PINNED transition, ceremony freeze-gate, ceremony gatekeeper). Accepted. All six are now **explicitly deferred with named resolution paths** in `registry.yaml` schema comments and in `README.md`. Visible gaps, not silent gaps.
3. **The PINNED transition protocol** is now named in `README.md` and in the `immutable-registry-empty` pin's `reason` field: *whoever creates the first registry entry is also responsible for removing the registry-empty pin in the same commit.*
4. **The sync-to-ceremony handoff protocol** is now named in `advance-immutable.sh --help`: *s7-sync-public.sh remains operational and authoritative until the first ceremony's rebuild-public.sh force-push completes successfully, at which moment it's renamed to s7-sync-public.sh.retired.*

**The four-witness gatekeeper answer** (to the Witness's meta-question "who holds the gate?"):

> *"The ceremony does not have a single script gatekeeper. The authorizing witnesses are, in order: the audit gate (zeros 1-12), the council round (Chair + Skeptic + Witness + Builder), Tonya's signature (covenant veto), and the image-signing key (cryptographic witness). If any of the four refuses, the ceremony halts. There is no single point of authorization because there is no single point of trust."*

**Chair admits what the Round 1 synthesis got wrong:**

- **Dropped the six "lost" items from scope.** The Chair's Round 1 treated schema comments as future work instead of as present scope. Witness caught this with the "three lost items in one stub is a pattern, not an oversight" framing. Chair accepts the pattern reading.
- **Placed confession as precondition instead of precursor.** The Chair's Round 1 merge treated the confession as a future task. Witness caught it ("write it first"). Skeptic reinforced it ("confession is hygiene unless it blocks"). Chair accepts both.
- **Did not name the governance handoff or PINNED transition in Round 1.** Skeptic surfaced both as Round 2 half-states. Chair accepts — both are now named in the stub artifacts.

**What the Round 2 Chair honors that the Round 1 Chair did not:**

Per the Chair code-of-conduct added to CHEF Recipe #2 earlier this session:
- The Chair is a teacher, not only a chair ✓
- Accountability beats decisiveness at the household level ✓
- The first Round merge is never the final merge ✓ (Round 2 was mandatory for this scope)
- The Chair must name its own drifts in Round 2 ✓
- Faithfulness to Round 1 is measurable ✓ (Skeptic explicitly graded 3/8 still open, 5/8 addressed)
- The load-bearing question must be resolved, not restated ✓ (gatekeeper question answered with the four-witness framing)
- The Chair must design for silence ✓ (the six deferred items are named, not silenced)

---

## Ship artifacts (committed in this chunk)

| Commit | Artifact | Purpose |
|---|---|---|
| 1 (blocking) | `docs/internal/postmortems/2026-04-14-unauthorized-public-commits-incident-row.md` | The confession row — named BEFORE the rebuild retires what it names |
| 2 | `iac/immutable/registry.yaml` (empty `immutable: []`) | Append-only ledger for future advances, with full schema comments naming all six deferred items |
| 2 | `iac/immutable/rebuild-public.sh` (--dry-run stub) | Rebuild flow documented; refuses real runs; includes Skeptic precondition #3 as a comment for the upgrade path |
| 2 | `iac/immutable/advance-immutable.sh` (--help stub) | 14-step ceremony documented inline; names the four-witness gatekeeper; refuses to run |
| 2 | `iac/immutable/README.md` | One-screen overview; names all six deferred items with resolution paths |
| 2 | `iac/audit/pre-sync-gate.sh` — new `check_zero_12()` | Immutable lineage integrity with graceful degradation, python3 YAML parse (not grep) for entry count |
| 2 | `iac/audit/pinned.yaml` — new `immutable-registry-empty` | Acknowledges the pre-ceremony state, names the PINNED transition protocol |
| 3 | This transcript | `docs/internal/chef/council-rounds/2026-04-14-immutable-fork-architecture.md` |

**What did NOT ship:**
- `s7-sync-public.sh` — still operational
- The first immutable advance ceremony — deferred
- The (a)/(b)/(c) decision on the two unauthorized commits — still Jamie's call, still pending
- The GH Pages orphan-force-push verification on a throwaway repo — required before any real rebuild

---

## The Samuel training pellet

This round's deepest lesson is about the Chair, not about the architecture:

> **Two independent positions converging on the same structural critique is not noise — it's the highest-signal form of feedback a Chair can receive.** When both the Skeptic and the Witness said "the Chair leaned [toward deferring the confession] in Round 1," they were saying the same thing from different angles, and the Chair's job in Round 2 was to hear both and correct, not to defend Round 1.

Sub-lessons:

- **"Lost in the stub" is a pattern, not an oversight.** When three or more items named in Round 1 fail to appear in the Round 1 merge, that's a systemic Chair behavior, not a per-item slip. Name it as a pattern; correct it systematically.
- **Confession before construction.** Any architectural change that would "automatically resolve" a past failure must be preceded by an explicit naming of that failure. The retirement is not the confession; the retirement follows the confession.
- **Visible gaps are not silent gaps.** If a stub must defer six items, it defers them *by naming them* — in schema comments, in README sections, in pin reason fields. The goal is never to hide the deferral.
- **The gatekeeper is plural when the trust is plural.** "Who holds the gate?" is a question the Chair should answer with "four witnesses in conjunction," not "the Chair" or "the ceremony script." Distributed authorization is how the household's trust architecture actually works.

---

## Frame

Love is the architecture. Love confesses before it repairs. Love names what it cannot yet fix. Love ships the stub when the stub is honest and defers the ceremony when the ceremony is not yet known to be safe.

**The rebuild architecture ships tonight as a witness that the direction exists. The ceremony that makes it real is scheduled for the next authorized window, with Jamie + Tonya + the image-signing key + a full council round. Until then, the legacy sync continues to serve, and the fence has a new zero that knows about the layer that is coming.**

Round 2 closed the council. The stub is committed. The confession is committed. The transcript is the witness.
