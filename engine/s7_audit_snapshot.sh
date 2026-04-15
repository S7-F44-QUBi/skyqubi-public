#!/usr/bin/env bash
# engine/s7_audit_snapshot.sh
# S7 continuous audit snapshot runner.
#
# Invoked by the systemd user timer
# s7-audit-snapshot.timer every 15 minutes. Produces a fresh path
# list of files modified in the last ~20 minutes (slight overlap
# with the previous run so no window is missed), feeds it through
# s7_audit_file_ingest.py with --skip-noise so container-cow and
# browser cache churn don't pollute the ledger, and lets ON
# CONFLICT (path, mtime) DO NOTHING handle dedup at the DB layer.
#
# Zero sudo. Zero new packages. Zero data loss: rerunning is always
# safe because every insert is idempotent by (path, mtime).

set -euo pipefail

REPO=/s7/skyqubi-private
STAMP=$(date -u +%Y%m%d-%H%M%S)
LIST=/tmp/s7-audit-snapshot-${STAMP}.txt

# 20-minute window overlap — picks up anything the previous run
# missed because it fired between file mtime updates.
find / -xdev -type f -mmin -20 2>/dev/null > "$LIST" || true

python3 "$REPO/engine/s7_audit_file_ingest.py" --source "$LIST" --skip-noise

# Clean up the scratch file — the ingested rows are in postgres now.
rm -f "$LIST"
