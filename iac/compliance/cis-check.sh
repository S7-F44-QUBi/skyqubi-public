#!/usr/bin/env bash
# iac/compliance/cis-check.sh
#
# STUB. Real implementation is its own follow-up plan.
# Returns SKIPPED so the orchestrator can run end-to-end without a
# real CIS measurement in place yet.
#
# When implemented, this should check the subset of CIS Distribution
# Independent Linux Benchmark v3.x that applies to a Fedora 44
# appliance:
#   - Filesystem hardening (separate /tmp, nodev/nosuid mounts)
#   - Service hardening (only required services running)
#   - Network parameter hardening (sysctl)
#   - Logging and auditing (rsyslog, audit.rules)
#   - Access control (sudo configuration, SSH if present)
#   - Password policy (PAM, /etc/login.defs, faillock)

set -uo pipefail
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat <<EOF
{"standard":"cis","verdict":"skipped","checks_run":0,"failures":[],"reason":"stub — real CIS benchmark check not yet implemented","ts":"$NOW"}
EOF
exit 2
