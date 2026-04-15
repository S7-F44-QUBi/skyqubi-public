#!/usr/bin/env bash
# iac/compliance/hipaa-check.sh
#
# STUB. Real implementation is its own follow-up plan.
# Returns SKIPPED so the orchestrator can run end-to-end without a
# real HIPAA measurement in place yet.
#
# When implemented, this should check the HIPAA technical safeguards
# under 45 CFR § 164.312 that the appliance can verify on its own:
#   - Encryption at rest (LUKS root partition + TimeCapsule signed images)
#   - Audit log retention (audit.file_change_history present and
#     hash-chain intact, retention policy in effect)
#   - Access controls (root locked, /etc/s7 mode 0750, nologin shell)
#   - Automatic logoff (session idle policy enforced)
#   - Unique user identification (UID 1000 for s7, no shared accounts)
#   - Person or entity authentication (per-user credentials, no shared
#     keys, GPG-signed commits)

set -uo pipefail
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat <<EOF
{"standard":"hipaa","verdict":"skipped","checks_run":0,"failures":[],"reason":"stub — real HIPAA technical safeguards check not yet implemented","ts":"$NOW"}
EOF
exit 2
