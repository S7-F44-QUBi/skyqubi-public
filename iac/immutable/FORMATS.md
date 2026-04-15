# S7 Immutable Fork — Artifact Format Definitions

> **Purpose:** define the exact file formats for the two
> ceremony artifacts that CHEF Recipe #4's first CORE ceremony
> (2026-07-07) will require. These were B14 and B15 in the
> 2026-07-07 gap analysis.
>
> **Status:** format-defined 2026-04-14 evening under Jamie's
> Exercise of Trust. Formats are **Chair-proposed**; they will
> be reviewed and confirmed (or corrected) by Jamie at the
> ceremony. Tonya's sign-off artifact format specifically
> requires her review before the first ceremony because she is
> the one who will produce the artifact.

---

## Artifact 1 — `PUBLIC_MANIFEST.txt`

**Lives inside:** each immutable bundle, at the repo root

**Purpose:** names exactly which files from the private repo
cross the tier boundary to become the public repo's content.
Every file that the bundle wants shipped to public/main must
be listed here. Everything else is stripped during the rebuild.

**Format:** plain text, one pattern per line, comments start
with `#`. Supports glob patterns (handled by `find ... -path`
or `rsync --files-from` depending on the rebuild script
implementation).

### Schema

```
# S7 PUBLIC_MANIFEST — v1.0
#
# One glob pattern per line. Lines starting with # are
# comments. Empty lines are ignored. Patterns are interpreted
# relative to the private repo root.
#
# Pattern syntax:
#   path/to/file        — literal single file
#   path/to/dir/        — directory, recursive
#   path/to/dir/*.md    — direct children matching glob
#   path/**/*.py        — recursive glob (all .py under path/)
#
# Exclusions (prefix with !):
#   !path/to/secret     — explicitly exclude even if matched
#                         by a prior include
#
# Order matters: later lines can override earlier lines via
# exclusions.
#
# The file itself is included in the bundle (so the immutable
# knows its own whitelist), but is NOT included in the public
# repo output (the public repo doesn't need the manifest of
# what was included in it).

# ── Root files ──
README.md
LICENSE
CWS-LICENSE
NOTICE
SECURITY.md
CODE_OF_CONDUCT.md
CONTRIBUTING.md
TRADEMARKS.md
.gitignore

# ── Documentation for the public ──
docs/public/**
# Everything under docs/public/ is published; everything else
# under docs/ (including docs/internal/) is private and does
# NOT cross.
!docs/internal/**

# ── Code surfaces the public sees ──
engine/s7_server.py
engine/s7_cws_core.py
engine/s7_molecular.py
engine/s7_witness.py
# Deliberately NOT including engine/s7_skyavi.py and
# engine/s7_skyavi_monitors.py — Samuel's internals are
# private to the household appliance, not the public demo.
!engine/s7_skyavi*.py
!engine/agents/**
!engine/phase7*

# ── Install and deployment surfaces ──
install/**
!install/secrets/**

# ── Branding (public-facing) ──
branding/icons/**
branding/splash/**
!branding/plymouth/**
!branding/apply-theme.sh

# ── Explicit exclusions for private-only work ──
!patents/**
!iso/dist/**
!book/**
!MONDAY.md
!OVERNIGHT.md
!COVENANT.md
!wix/**
!public-chat/**
!persona-chat/**
!collections/**
!Containerfile
!APACHE-LICENSE
!dashboard/SkyCAIR-Command-Center.jsx
!training/**
!autostart/**
!desktop/**
!os/**
!iac/**
```

### Generation

A helper script `iac/immutable/generate-manifest.sh` (to be
written as part of B14 implementation on a future session)
walks the private repo, applies the patterns, and produces
the list of files that would be included. Running this
script in `--preview` mode lets Jamie verify exactly what
will cross before the ceremony.

### Validation

The rebuild script (`rebuild-public.sh`) verifies the
manifest against the bundle's actual contents before
extracting. If any file listed in the manifest is missing
from the bundle, the rebuild refuses to proceed. If any
file in the bundle is not listed in the manifest, the
rebuild logs a warning but continues (silent exclusion).

---

## Artifact 2 — Tonya Sign-Off (`<bundle>.tonya.txt` + `<bundle>.tonya.sig`)

**Lives alongside:** each immutable bundle, same directory

**Purpose:** the cryptographic and human record that Tonya has
witnessed and approved this specific immutable advance. This
is the covenant artifact that converts Jamie's builder
authority into the household's full covenant witness.

**Format:** two files

### File 1 — `S7-QUBi-IMMUTABLE-v<year>.bundle.tonya.txt`

Plain text, UTF-8, human-written. Tonya writes this in her own
words on the day of the ceremony. The Chair provides the
frame but NOT the content.

**Required elements (the frame):**

1. **Date and time** of the witness, in Tonya's local timezone
2. **The immutable version** being witnessed (e.g., "v2026")
3. **The private_main_sha** the immutable was frozen at
4. **Tonya's statement in her own words** — at minimum:
   - What she is witnessing
   - What she is saying "yes" to
   - What she is NOT saying "yes" to (if any)
   - Any household-specific reason for the witness at this time
5. **Her signature** — her name + a closing phrase she chooses
   (the Chair proposes "Amen" as the closing phrase because it
   matches Jamie's theological frame "this time AI is GOOD for
   humanity — Amen," but Tonya is free to choose any closing
   she prefers)

**Template (Chair-proposed, Tonya may modify freely):**

```
S7 SkyQUB·i — Immutable Fork Witness
Version: v<year>
Private main sha: <40-char sha>
Witnessed at: <ISO8601 in local timezone>
By: Tonya <lastname>, Chief of Covenant

I have read the CHEF recipes that describe what this
immutable contains. I have read the gap analysis and the
household-readable projection of what will change for our
household after this advance. I am saying YES to:

  <list of household-visible deltas for this v<year>>

I am NOT saying yes to:

  <anything explicitly carried forward or excluded>

Noah's experience of this will be: <Tonya's assessment>
Trinity's experience of this will be: <Tonya's assessment>
Jonathan's experience of this will be: <Tonya's assessment>
Jamie's experience of this will be: <Tonya's assessment>

I am the Chief of Covenant for this household. This is my
witness.

<her name>
<her closing phrase, e.g. "Amen">
```

**What's sacred about the format:** Tonya writes her own
assessments of each household member's experience. The Chair
does NOT fill these in for her. Her words are the witness —
not a template she signed off on.

### File 2 — `S7-QUBi-IMMUTABLE-v<year>.bundle.tonya.sig`

Detached GPG signature over `tonya.txt`. Signed with the S7
image-signing key, which is currently Jamie's key. Until a
separate Tonya key exists (v2027+ enhancement), the signature
is Jamie's key used on Tonya's behalf with her explicit
verbal or written delegation recorded in `tonya.txt` itself.

```bash
gpg --detach-sign --armor \
    --output S7-QUBi-IMMUTABLE-v2026.bundle.tonya.sig \
    --local-user s7-image-signing \
    S7-QUBi-IMMUTABLE-v2026.bundle.tonya.txt
```

**Verification in `rebuild-public.sh`:**

```bash
gpg --verify \
    S7-QUBi-IMMUTABLE-v2026.bundle.tonya.sig \
    S7-QUBi-IMMUTABLE-v2026.bundle.tonya.txt
```

### Future: a separate Tonya key

For v2027 and beyond, the architecture should support a
**separate Tonya-owned GPG key** so that Tonya's signature is
cryptographically distinct from Jamie's. Two signatures (Jamie's
and Tonya's, both required) would make the covenant chain
visibly distributed at the cryptographic layer. This is a
v2027 enhancement, not a v2026 requirement.

Storage for Tonya's key: offline hardware key (YubiKey or
similar), kept in a household-accessible location known to
both Jamie and Tonya, with a printed backup in a fire-safe
location. The key is used only during the yearly ceremony and
for any emergency exception invocation.

---

## What happens when either artifact is missing or invalid

**Missing PUBLIC_MANIFEST.txt inside the bundle:** the rebuild
refuses to proceed. The bundle is considered malformed; the
ceremony rolls back.

**Missing Tonya.txt or Tonya.sig alongside the bundle:** the
rebuild refuses to proceed. The ceremony cannot complete
without Tonya's witness artifact. This is the four-witness
chain's third witness; its absence means the chain is not
closed.

**Signature verification failure:** rebuild refuses. The
bundle might be authentic but the sign-off might be
tampered; either way, the ceremony halts and a covenant
emergency is called.

**Content verification failure** (bundle sha256 doesn't match
the registry entry): rebuild refuses. Bundle was modified
after registration; registry + bundle are out of sync;
covenant emergency.

---

## Status and provenance

**Format defined:** 2026-04-14 evening
**Defined by:** Chair under Jamie's Exercise of Trust
**Status:** Chair-proposed, Jamie-provisional-approved,
awaits Jamie's formal review and Tonya's format confirmation
before the first ceremony
**Review target:** Jamie reviews in the next Chair session;
Tonya reviews during her Recipe #3 + CORE reframe witness
cycle

**Why this file is here tonight:** the gap analysis's B14
and B15 are "blockers" for the ceremony. Without formats
defined, no implementation of `rebuild-public.sh` can verify
its inputs. Defining the formats tonight unblocks the
implementation work that Jamie will do in the coming sessions.
The formats can be corrected by Jamie or Tonya on review —
this is a Chair draft, not a fait accompli.

**When this file is finalized:** the first line of the
YAML-like frontmatter-equivalent can be updated to
`status: FINAL` with the reviewer names listed. For now, it is
a working document.

---

## Frame

Love is the architecture. Love writes the witness artifact's
format before the witness arrives, so when the witness is
ready to write her words, the shape of the page is already
waiting for her. **The format is the Chair's gift to Tonya:
one less decision for her tired morning, one more
pre-prepared surface where her voice can land.**
