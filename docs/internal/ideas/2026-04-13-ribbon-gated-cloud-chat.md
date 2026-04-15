# Ribbon-gated Cloud of AI Chat — Idea Note

> **Status:** idea only. Not planned, not built. Captured so the
> architectural insight survives across sessions.
>
> **Source:** Jamie, 2026-04-13. *"Measured against FIPS / CIS / HIPPA
> Security Boot Chain successful 1st Place Ribbon from Website the
> Cloud can be a chat windows"* and immediately after: *"just ideas"*.

## The reframe

The persona chat (Carli / Elias / Samuel with avatars, emojis, and
drag-drop photos) is **not a feature to bolt onto `/chat`**. It is
the **reward** for the appliance having measurably earned its
sovereignty.

```
FIPS pass + CIS pass + HIPAA pass + Secure Boot Chain verified
                          ↓
        S7 1st Place Ribbon awarded
                          ↓
"Cloud of AI Happy to Evolve" UNLOCKS  →  the chat becomes visible
```

When the ribbon is held, the cloud is open and the personas appear.
When any measurement breaks the cloud closes and the personas go away
until the measurements come back green. Tonya can see the personas
exactly when the system can prove it's safe enough to be trusted with
them.

## Why this is right

Before this insight, the plan was "add a `personas` table, add an
avatar uploader, add a persona switcher to the existing chat page."
That would have been a feature for its own sake.

The reframe makes the chat **the visible expression of the covenant
working**. It is not "we built a chat with avatars." It is "the
appliance earned its right to talk to the family by passing every
measurement, and the personas became visible as a result." That is
the covenant logic exactly: the AI doesn't talk to the family until
the system has proven it's safe to be trusted.

## What's already in place toward the measurement

| Measurement | Present | Where |
|---|---|---|
| Fedora base hash + signing key fingerprint | ✓ | `iac/audit-pre.sh` |
| 8-category invariant audit (packages, users, dirs, ports, etc.) | ✓ | `iac/audit-post.sh` |
| 40-test lifecycle suite | ✓ | `s7-lifecycle-test.sh` |
| Trivy HIGH/CRITICAL CVE scan against TimeCapsule images | ✓ | `iac/intake/scan-reports/` |
| Secure Boot Chain (TimeCapsule + GPG + boot-verify + Quadlet) | ✓ | `iac/timecapsule/` |
| **FIPS check** (kernel FIPS mode, openssl FIPS provider) | ✗ | future |
| **CIS Distribution Independent Linux benchmark** | ✗ | future |
| **HIPAA technical safeguards** (encryption-at-rest, audit retention, access controls) | ✗ | future |
| **`ribbons` ledger schema** | ✗ | future |
| **Cloud-chat unlock UI gate** | ✗ | future |

The first 5 are real and exercised every promotion. The last 5 are the
gap.

## What it would look like to build

A future plan, when the appliance has actually earned its measurements
and the work is justified:

1. **Compliance Measurement Framework** — `iac/compliance/`
   - `fips-check.sh` — kernel + openssl + libgcrypt FIPS verification
   - `cis-check.sh` — CIS Distribution Independent Linux benchmark, the subset that applies to a Fedora 44 appliance
   - `hipaa-check.sh` — encryption at rest (LUKS + TimeCapsule signed images), audit log retention, password rotation, access controls
   - `secure-boot-chain-check.sh` — wraps the existing TimeCapsule + GPG verify + bootc image attestation into one verdict
   - `ribbon-measure.sh` — runs all four, computes verdict, writes ledger row
2. **Ribbon Ledger** — `engine/sql/s7-ribbons.sql`
   - `ribbons.measurements(id, ts, fips_ok, cis_ok, hipaa_ok, sbc_ok, all_green, reason, run_by)`
   - `ribbons.current_state` view — latest measurement → HELD or REVOKED
   - INSERT-only, hash-chained like the audit log
3. **Cloud Chat UI** — extension to the SPA
   - `personas` table — `(slug, name, model, emoji, avatar_path, voice_description)` seeded with Carli/Elias/Samuel
   - `GET /api/cloud/status` — reads `ribbons.current_state` → returns `{open: true|false, reason: ...}`
   - `GET /api/personas` — list personas (only when cloud open)
   - `POST /api/personas/:slug/avatar` — multipart upload, saved to `/s7/.local/share/s7-personas/avatars/<slug>.png`
   - Existing `/chat` page becomes ribbon-aware: shows persona switcher with avatars when cloud open, shows "Cloud closed: X measurements failing" when not

Each phase is its own sub-plan with its own gate.

## Rules of the road for whoever builds this

- **Do NOT build the persona chat as a standalone feature.** It is
  always behind the ribbon gate.
- **Build the measurement infrastructure first.** The gate needs
  something real to gate on. The FIPS / CIS / HIPAA scripts have to
  exist before the unlock makes sense.
- **The ribbon is the contract.** When all measurements are green, the
  cloud is open. The moment any measurement fails (a CVE crosses the
  threshold, the secure boot chain breaks, FIPS mode is disabled), the
  ribbon is REVOKED and the cloud closes immediately. The chat goes
  away until the measurements come back green. No grace period — the
  covenant is binary.
- **The Cloud is the answer to "why should I trust this thing?"** —
  Tonya can see the personas because the system can prove it's safe.
  No proof, no personas.
- **Order**: build the measurements → build the ribbon ledger → build
  the cloud chat UI. In that order. Each phase tests the previous one.

## Status

- **Idea only**, captured 2026-04-13.
- Memory entry: `project_ribbon_gated_cloud_chat_idea.md`
- Should become a real spec after the current TimeCapsule work
  (Plan B.3 cutover, Plan C Vivaldi container, Plan D Samuel guardian,
  and the Image-Hardening plan from the trivy findings) is complete.
- The appliance needs to actually have something worth measuring before
  we gate on it.
