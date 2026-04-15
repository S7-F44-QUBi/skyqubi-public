# Patent Additions Memo — 2026-04-13

> **Status:** ⚠ **CORRECTED 2026-04-13 (later in the same session).**
> The original draft below proposed three "candidate new claims" that
> are **already covered by existing patent claims**. The author (Claude)
> had scanned the patent for the keyword "TimeCapsule," found no hits,
> and incorrectly assumed gaps existed. A subsequent end-to-end read of
> the 34 existing claims revealed the candidates were embodiments of
> existing claims, not new inventions. **No new claims should be added
> based on this memo.** See the "What this memo got wrong" section at
> the bottom for the specific corrections.
>
> Patents are legally consequential — claims should be drafted only with
> Jamie's explicit go-ahead AND a proper end-to-end read of the existing
> claims first.

## Summary

Tonight's TimeCapsule + intake + scan + network work introduced several
architectural patterns that may warrant new patent claims. None of them
are *purely* novel in isolation (signed image archives exist; vulnerability
scanners exist; bridge networks exist), but the **specific combinations
unique to S7 SkyQUB*i*** may be patent-eligible. Decision is Jamie's.

## Candidate additions

### Candidate Claim N — TimeCapsule registry as the +1 layer of Trinity Mount

The TimeCapsule registry is the persistent disk layer (+1) of the S7
Trinity Mount architecture, where:

- **-1 (skycair)** is the volatile tmpfs witness state
- **0 (qubi)** is the service runtime tmpfs
- **+1 (timecapsule)** is the signed-tar persistent audit + image layer

The novel combination is using +1 simultaneously as:
1. A **read-only podman additional image store** (`additionalimagestores`)
   that podman runtime consumes at zero copy
2. A **GPG-signed delivery format** where each tar carries a detached
   signature against a single appliance signing key
3. A **boot-verified mount** where a systemd oneshot walks the manifest
   before podman starts and refuses to load tampered images
4. A **decoupled update channel** where adding a new signed tar to the
   directory is the entire upgrade mechanism for an in-cube service —
   zero rebuild of the bootc base image required

This mapping (Trinity Mount layer assignment + dual use as image store +
signed delivery + boot verification + decoupled update) does not appear
in the existing claims and could be Claim 11+.

### Candidate Claim N+1 — Scan-before-seal gate

The intake gate's pre-promotion vulnerability scan stage is novel in
combination with:

1. The signing step that would otherwise seal the artifact with the S7
   brand
2. The refusal to promote into TimeCapsule on detection of HIGH/CRITICAL
   findings above an operator-defined threshold
3. The scan reports being committed to an audit trail in the same repo
   as the intake gate config (creating a tamper-evident record of which
   bits were scanned, when, against which CVE database version, and what
   the operator decision was)

The combination encodes a discipline not generally found in existing
container supply-chain frameworks (which typically scan AFTER signing,
or sign without scanning). The S7 mechanism makes it impossible to
silently sign vulnerable bits.

### Candidate Claim N+2 — qubi network as cube isolation boundary

The `qubi` podman network at 172.16.7.32/27 (or the brand-canonical .0/27
on appliances without the orphan lo conflict) is the network-layer
expression of the cube/desktop separation rule. The novel aspect is
**static IP assignment by S7 architectural role**:

- The SPA at 172.16.7.42 (the door)
- Witness services at 172.16.7.43–47
- Standalone services at 172.16.7.52–53
- Vivaldi (the human window) at 172.16.7.62

The network has `--internal` capability that, when enabled, makes the
entire cube unreachable from the internet at the kernel layer, while
the desktop layer (Wayland session, .desktop files, the wrapper script)
remains entirely outside it. The novel combination is **using a podman
network's CIDR as the cube boundary, with the desktop layer outside it**.

### Candidate Claim N+3 — Samuel as warm-loop guardian (deferred — Plan D)

This claim cannot be drafted yet because the implementation is in Plan D.
Note for future revision: the qubi_service_guardian skill's three-tier
remediation ladder (restart / reload-from-tar / escalate-with-audit)
is the warm-loop counterpart to the cold-start wrapper, and the handoff
discipline (cold-start owns startup, Samuel owns liveness, neither
overlaps) is itself an architectural pattern.

## What does NOT need a new claim

These pieces are tonight's *work* but are implementation, not new
inventions, on top of existing patent claims:

- The Python manifest module (atomic JSON updater) — engineering
- The boot verify script — engineering
- The systemd unit installation pattern — engineering
- The lifecycle/main two-tier release model — operational discipline,
  not patentable
- The cube/desktop rule itself — architectural discipline derived from
  Linus's kernel/desktop separation; that's prior art

## Operator decision needed

Jamie:

1. **Are any of Candidate Claims N / N+1 / N+2 worth adding to the
   provisional patent before the next filing?** If yes, I'll draft the
   actual claim language for your review.
2. **Should the TimeCapsule architecture be cross-referenced from the
   existing claims** (e.g., as a dependent claim on the system claim
   that already mentions the appliance) **even if no new independent
   claim is added?**
3. **Timing.** The provisional was filed at TPP99606. Adding new claims
   means either (a) filing a continuation or (b) bundling them into the
   non-provisional conversion. Which path?

I am not making these calls. They go through you and the patent attorney.

---

## What this memo got wrong (correction added 2026-04-13 later same session)

After Jamie pushed back ("better review whats in the paton"), the
author actually read the existing 34 claims end-to-end. The original
memo claimed only ~9-10 claims existed and proposed three "candidate
new claims." All three are **already covered**:

### Original Candidate 1: "TimeCapsule registry as +1 layer of Trinity Mount"

**Already covered by Claim 25:**

> The architecture of Claim 23, wherein the physical storage hierarchy
> maps to a Trinity structure:
> - Volatile fast layer (tmpfs): active inference and OS state
> - Volatile medium layer (tmpfs): current session working memory
> - Persistent layer (HDD/NVMe): INSERT-only permanent audit storage
> corresponding to the ternary poles {-1, 0, +1} of the convergence
> geometry.

The TimeCapsule registry IS the persistent +1 layer described in
Claim 25. It's an embodiment, not a new invention. The implementation
choices (GPG-signed tar + manifest.json + podman additionalimagestores)
are engineering details under the umbrella of Claim 25's "INSERT-only
permanent audit storage."

### Original Candidate 2: "Scan-before-seal gate"

**Already covered by Claim 31** (and the spirit of Claim 12's
INSERT-only covenant):

> The system of Claim 1, wherein the INSERT-only covenant applies to
> all memory tables including discernment results, consensus outputs,
> retrieval hops, and reasoning chains, providing a complete temporal
> audit trail of all inference activity.

The trivy scan integration into the intake gate is consistent with
this discipline — refusing to insert tampered or vulnerable bits into
the audit-trail-protected store is the same covenant applied at the
container-image layer instead of the memory-table layer. It's not a
new claim; it's an extension of the existing INSERT-only discipline
to a new tier of state.

### Original Candidate 3: "qubi network as cube isolation boundary"

**Already covered by Claim 27:**

> The platform of Claim 26, wherein the offline mandate is an
> architectural constraint, not a configuration option — the system
> is designed from first principles to require no external services
> for any of its core functions.

The `qubi` podman network at 172.16.7.32/27 is the network-layer
expression of Claim 27's offline-mandate-as-architectural-constraint.
The static IP allocation per S7 service role is engineering; the
isolation principle itself is patented in Claim 27.

## What I missed in the original memo

Sections of the existing patent I failed to mention because I didn't
read them:

- **Section 4.9.4 Trinity Mount Mapping** — the patent already
  documents the Trinity structure tonight's work is built on
- **Section 4.10 The QUBi Platform** — the patent already defines
  the complete sovereign offline AI platform as a patented embodiment
- **Section 4.10.2 Offline-First Mandate** — the patent already
  documents the architectural constraint
- **Section 4.10.3 Civilian-Only Mandate** — the patent already
  carries the civilian-only covenant
- **Claim 26** — the complete platform (the QUBi appliance) is
  Claim 26, not a new thing
- **Claim 28** — civilian-only constraint
- **Claim 29** — self-contained appliance for household use
- **Claim 30** — the open-source command center + CWS engine
  combination, which is exactly the public/private architecture
  tonight's work has been operating within
- **Claim 33** — MemPalace as navigable spatial memory interface
- **Claim 34** — the integration method of BitNet + MemPalace + CWS

The patent has **34 claims**, not "9+" as the original memo's first
sentence implied. Every component of S7-X27/R101/PorteuX tonight's
work has either implemented or extended is covered.

## What the operator might still consider — narrowly

The HONEST possible patent additions, after the corrected read, are
much narrower than the original memo proposed. None are urgent. None
should be filed without a proper patent attorney review:

1. **The slipstream + recall store + content-hash build cache pattern**
   (`iso/porteux/slipstream.sh` recall store) — this is a deduplicating
   build artifact cache that's somewhat novel in its content-addressed
   hash format. Maybe a method claim about reproducible-by-content
   builds, but probably already prior art (ostree, Nix, Bazel all do
   variants of this).

2. **The two-stage measurement → ribbon → cloud-unlock gate**
   (the ribbon-gated Cloud chat design from earlier tonight) — this
   IS a novel coupling of compliance measurement to AI capability
   unlock. The pattern "the system can prove it's safe → the AI
   appears" might be patentable as a method claim. But it's unbuilt
   today; filing on an unbuilt method is poor practice. Wait until
   it ships.

3. **Nothing else.** Tonight's other work — security hardening,
   restart fix, desktop branding, FastFetch, container migration,
   trivy integration — is all engineering execution under the
   existing claim umbrella.

## Status of this memo

- **Original draft:** wrong, kept above for honesty about the mistake
- **Correction:** this section
- **Net effect on the patent:** zero. No new claims should be added
  on the basis of this memo. The patent is more comprehensive than
  the original draft represented.
- **Lesson for the next patent review:** read the claims before
  writing the additions memo. Keyword grep is not a substitute for
  reading.
