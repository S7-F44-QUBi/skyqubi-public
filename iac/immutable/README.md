# S7 Immutable Fork — Rebuild Architecture

> **The one-sentence rule.** *"Sync to private. Rebuild public from
> the private immutable fork."* Public is a view of a frozen,
> signed anchor — not a copy of live private.
>
> **Status (2026-04-14 evening, CORE Update v5):** produceable but
> not shippable. `rebuild-public.sh --dry-run` now produces a real
> signed-ready bundle + manifest + receipt in `/tmp/s7-gold-dry-
> run/` against the current lifecycle tip. Real-run still refuses.
> `advance-immutable.sh` remains a stub pending Tonya witness.
> `registry.yaml` is empty. `s7-sync-public.sh` remains the
> operational source of truth for `skyqubi-public/main` until the
> first ceremony yields authority to this pipeline.
>
> **Target repository** (announced 2026-04-14 evening):
> `https://github.com/skycair-code/skyqubi-immutable` — PUBLIC,
> created but untouched. Four preconditions to first push:
> (1) rebuild-public.sh past refuse-real-runs,
> (2) advance-immutable.sh past stub,
> (3) Tonya witness on the first advance ceremony + sign-off artifact,
> (4) image-signing key unlocked by Chief of Covenant.
> Pinned in `iac/audit/frozen-trees.txt` as `immutable/main PENDING`
> with `frozen-tree-immutable-pending` acknowledgment in pinned.yaml.
>
> **Full architecture:** `docs/internal/chef/04-immutable-fork-public-rebuild.md`

---

## The three files in this directory

| File | Role | Runnable? |
|---|---|---|
| `registry.yaml` | Append-only ledger of all immutable advances. Each entry = one signed bundle, one ceremony, one yearly update. | Read-only data file |
| `rebuild-public.sh` | Deterministic rebuild of public/main from the latest non-retired registry entry. | Stub — `--dry-run` only; real runs refused |
| `advance-immutable.sh` | The CORE yearly ceremony orchestrator. Produces bundle, signs, registers, invokes rebuild. | Stub — `--help` only; real runs refused |

---

## How public becomes a view

```
    lifecycle (daily work)
         ↓
    private/main (staging)
         ↓
    [CORE yearly ceremony — human-led, Jamie + Tonya + council]
         ↓
    S7-QUBi-IMMUTABLE-v<year>.bundle (signed git bundle, byte-immutable)
         ↓
    rebuild-public.sh  (deterministic function of the bundle)
         ↓
    public/main (orphan branch, fresh root per rebuild)
```

**Public has no identity apart from the immutable.** Two rebuilds
from the same immutable produce byte-identical public content.
Rebuilding is idempotent. Advancing the immutable is the only
thing that changes public.

---

## Why this replaces `s7-sync-public.sh`

The legacy sync script has three moving parts — the script, the
branch protection toggle, and the freeze gate — any of which
can fail silently. Two unauthorized public commits on 2026-04-14
proved this:

- **`a6467b6`** — test-the-wrapper conflated with test-the-gate
- **`2f3cc9d`** — broken date format silently bypassed the freeze gate

Confession row: `docs/internal/postmortems/2026-04-14-unauthorized-public-commits-incident-row.md`

The rebuild architecture removes the sync bridge. There is no
`git push` to public from a running script. There is no live-
private dependency at push time. There is no branch protection
toggle. Branch protection stays on permanently. The only way
public can change is through the ceremony, which produces a
new immutable, which triggers a rebuild.

---

## The Round 2 council decisions (2026-04-14)

The first council round on this architecture produced findings
from all three trinity positions. Round 2 re-evaluated the
Chair's merge. The final shipping decision:

**SHIP TONIGHT:**
- This directory (`iac/immutable/`) with the four stub files
- Audit gate zero #12 with graceful degradation
- CHEF Recipe #4 (architecture doc)
- Council round transcript

**DEFER (until future authorized sessions):**
- Deleting `s7-sync-public.sh` — the legacy sync is the source of truth until the first ceremony yields
- The first immutable advance ceremony — human ceremony, Jamie + Tonya + image-signing key
- Verifying GitHub Pages behavior on orphan-branch force-push — must happen on a throwaway repo first
- The six deferred schema items (see `registry.yaml` comments)

**BLOCKING COMMIT (before this directory):**
- The incident confession row for the two 2026-04-14 unauthorized commits — committed first, so the rebuild architecture does not silently retire events the record has not named.

Full transcript: `docs/internal/chef/council-rounds/2026-04-14-immutable-fork-architecture.md`

---

## Six deferred items, named (not lost)

Round 2 of the council surfaced six things that could be silently
missed if the stub shipped without naming them. All six are
named here and in `registry.yaml` schema comments:

### 1. Bundle transport location
**DEFERRED.** Default proposal: `/s7/immutable/S7-QUBi-IMMUTABLE-v<year>.bundle`
(outside the private repo tree; the registry tracks the path, not
the bundle itself). Formally specified in the first ceremony.

### 2. Tonya's sign-off artifact
**DEFERRED.** Default proposal: a plain-text statement at
`<bundle>.tonya.txt` plus a detached GPG signature at
`<bundle>.tonya.sig`. Formally specified in the first ceremony's
council round.

### 3. frozen-trees.txt interaction
**DEFERRED with protocol.** When the first immutable advances,
the `public/main` line in `iac/audit/frozen-trees.txt` must be
**removed in the same commit** as the registry entry that
introduces the first immutable. Public becomes a function of
the immutable and no longer needs its own pin.

### 4. PINNED transition rule
**DEFERRED with protocol.** The `immutable-registry-empty` entry
in `iac/audit/pinned.yaml` must be **retired in the same commit**
as the registry entry that introduces the first immutable.
Whoever creates the first registry entry is also responsible
for removing the registry-empty pin. This is the pin-transition
protocol (Round 2 Skeptic catch).

### 5. Sync-to-ceremony handoff
**DEFERRED with protocol.** `s7-sync-public.sh` remains
operational and authoritative until the first ceremony's
`rebuild-public.sh` force-push completes successfully. At that
moment, the legacy sync yields authority and is renamed to
`s7-sync-public.sh.retired` with a header comment pointing at
CHEF Recipe #4. Deletion is a later-session cleanup.

### 6. The ceremony gatekeeper
**DEFERRED — and intentionally distributed.** The ceremony has
no single script gatekeeper. The authorizing witnesses are, in
order:
- The audit gate (zeros 1-12)
- The council round (Chair + Skeptic + Witness + Builder)
- Tonya's signature (covenant veto)
- The image-signing key (cryptographic witness)

If any of the four refuses, the ceremony halts. **There is no
single point of authorization because there is no single point
of trust.** This is the meta-answer to the "who holds the gate"
question — the gate is held by four distinct witnesses in
conjunction.

---

## What runs tonight

Nothing in this directory runs tonight. This is a stub. The stub
ships to commit the architectural direction, demonstrate the
flow, and add audit zero #12 in graceful-degradation mode so
the fence knows about the immutable layer even before the first
ceremony.

**The audit gate will show:**
- `📌 [A12] Immutable registry — empty (pre-ceremony, acknowledged)`

This is expected. The pin converts BLOCK → PINNED via the
`immutable-registry-empty` entry in `iac/audit/pinned.yaml`.

---

## Frame

Love is the architecture. Love builds the view from the anchor,
not the copy from the live wire. **The public face of the
household must be a function of a signed, frozen, human-
authorized anchor — not a copy of whatever the developer's tree
happened to look like at push time.**

The bridge is the bug. Remove the bridge. Public becomes a view.
