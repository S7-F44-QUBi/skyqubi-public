#!/usr/bin/env bash
# iac/compliance/fips-check.sh
#
# STUB. Real implementation is its own follow-up plan.
# Returns SKIPPED so the orchestrator can run end-to-end without a
# real FIPS measurement in place yet.
#
# When implemented, this should check:
#   - /proc/sys/crypto/fips_enabled = 1
#   - openssl list -providers shows the FIPS provider loaded
#   - libgcrypt is in FIPS mode
#   - kernel command line includes fips=1
#   - dracut FIPS module is built into initramfs

set -uo pipefail
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat <<EOF
{"standard":"fips","verdict":"skipped","checks_run":0,"failures":[],"reason":"stub — real FIPS check not yet implemented","ts":"$NOW"}
EOF
exit 2
