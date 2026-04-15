# iac/compliance — S7 Ribbon Measurement Framework

> **What this is:** the chain of compliance scripts that decide whether
> the S7 1st Place Ribbon is HELD or REVOKED. The ribbon gates the
> Cloud of AI chat (Carli / Elias / Samuel with avatars). Cloud is
> open when the ribbon is HELD; closed when any measurement fails.
>
> **Source spec:** `docs/internal/superpowers/specs/2026-04-13-ribbon-gated-cloud-chat-design.md`

## The four measurements

| Script | Standard | Status |
|---|---|---|
| `fips-check.sh` | NIST SP 800-140 — kernel FIPS mode + openssl FIPS provider | **stub** (returns SKIPPED) |
| `cis-check.sh` | CIS Distribution Independent Linux Benchmark v3.x | **stub** (returns SKIPPED) |
| `hipaa-check.sh` | 45 CFR § 164.312 — encryption at rest, audit log retention, access controls, automatic logoff | **stub** (returns SKIPPED) |
| `secure-boot-chain-check.sh` | Internal — TimeCapsule + GPG verify + boot-verify systemd unit + Quadlet image consistency | **real** |

The orchestrator `ribbon-measure.sh` runs all four, reads each one's
JSON verdict, computes `all_green = fips_ok && cis_ok && hipaa_ok && sbc_ok`,
and writes a hash-chained row to `ribbons.measurements` in postgres.

## Why three of four are stubs

Real compliance scripts are substantial work — each one is its own
follow-up plan sized to the standard. Tonight ships the **framework**
(orchestrator, ledger, gate logic) so the architecture can be built
and tested end-to-end. The per-standard scripts get implemented one at
a time, in their own follow-up plans, as the compliance work demands.

The stubs return `verdict: skipped` (NOT `verdict: pass`). A skipped
measurement does NOT count toward the ribbon — the orchestrator treats
SKIPPED as PASS for the gate calculation but flags it in the
`failure_summary` so it's visible. The ribbon CAN be held with stubs
in place, but the failure_summary will say "fips: skipped, cis: skipped,
hipaa: skipped — not yet implemented" so the operator knows.

When a real script replaces a stub, that's a separate commit and the
stub-to-real promotion is itself an audit event.

## The one real script — secure-boot-chain-check.sh

This script wraps existing S7 machinery and verifies the boot chain
end-to-end:

1. **TimeCapsule manifest exists and is well-formed**
   (`/s7/timecapsule/registry/manifest.json` parses, schema validates)
2. **Every signed tar's GPG signature verifies against KEY.fingerprint**
   (the same check `s7-timecapsule-verify.sh` does at boot)
3. **Every tar's sha256 matches its manifest entry**
4. **The boot-verify systemd unit ran successfully on this boot**
   (`systemctl --user is-active s7-timecapsule-verify.service` returned
   `active` or `inactive` with last exit code 0)
5. **Quadlet container images are all in the additionalimagestores**
   (every `localhost/s7/...` reference in `~/.config/containers/systemd/*.container`
   resolves to an image present in `/s7/timecapsule/registry/store/`)

Any failure in any of these → `sbc_ok: false` → ribbon REVOKED.

## How the orchestrator runs

```bash
bash iac/compliance/ribbon-measure.sh
```

Sequence:
1. Run each of the 4 per-standard scripts, capture stdout JSON
2. Compute the verdict (all_green)
3. Read the previous row_hash from postgres (for the hash chain)
4. Compute the new row's row_hash
5. INSERT into `ribbons.measurements`
6. Echo a one-line summary with the new ribbon state

Idempotent: safe to run repeatedly. The systemd USER timer
`s7-ribbon-measure.timer` will run it every 15 minutes (Plan R1
follow-up — not built tonight).

## How the ribbon state is consumed

```sql
SELECT ribbon_state FROM ribbons.current_state;
```

Returns `HELD` or `REVOKED`. The Cloud API (Plan R2) calls this on
every `/api/cloud/status` request and returns the result to the UI.
The UI shows the persona chat when HELD, the closed-cloud page when
REVOKED.

## Manual test

After installing the schema and running the orchestrator once:

```bash
# Apply the schema (one-time)
PGPASSWORD="$(cat /s7/.config/s7/pg-password)" \
  podman exec -i s7-skyqubi-s7-postgres \
  psql -U s7 -d s7_cws < engine/sql/s7-ribbons.sql

# Run the measurement
bash iac/compliance/ribbon-measure.sh

# Query the ledger
PGPASSWORD="$(cat /s7/.config/s7/pg-password)" \
  podman exec -i s7-skyqubi-s7-postgres \
  psql -U s7 -d s7_cws -c 'SELECT * FROM ribbons.current_state;'
# Expected: one row, ribbon_state = HELD or REVOKED, failure_summary
# names which standards were skipped vs failed.

# Verify the chain
PGPASSWORD="$(cat /s7/.config/s7/pg-password)" \
  podman exec -i s7-skyqubi-s7-postgres \
  psql -U s7 -d s7_cws -c 'SELECT * FROM ribbons.verify_chain();'
# Expected: empty result (chain intact)
```
