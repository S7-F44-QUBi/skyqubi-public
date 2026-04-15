#!/usr/bin/env bash
# iac/audit/nightly-snapshot.sh
#
# Insert-only by design — copies the current Living Audit Document to
# a dated history file each night so QUBi remembers live drift across
# time. Nothing is ever rewritten. Nothing is ever deleted. If a
# finding is resolved, the next snapshot records that it was resolved
# — it doesn't erase the original.
#
# This is the witness pattern: today's truth survives even if
# tomorrow's process fails. The household's memory is the household's.
#
# Usage:
#   ./nightly-snapshot.sh           # snapshot using today's date
#   ./nightly-snapshot.sh --force   # overwrite today's snapshot if exists
#                                     (default: refuse — append-only)
#
# Exit codes:
#   0 — snapshot written (or already existed and --force not given)
#   1 — Living Document missing
#   2 — would overwrite existing snapshot, refused

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIVING_DOC="$REPO_DIR/docs/internal/chef/audit-living.md"
HISTORY_DIR="$REPO_DIR/docs/internal/chef/audit-living"
TODAY=$(TZ='America/Chicago' date +%Y-%m-%d)
SNAPSHOT="$HISTORY_DIR/${TODAY}.md"

FORCE=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
  esac
done

mkdir -p "$HISTORY_DIR"

if [[ ! -f "$LIVING_DOC" ]]; then
  echo "  ✗ Living Document not found at $LIVING_DOC"
  echo "    Run iac/audit/pre-sync-gate.sh first to create it."
  exit 1
fi

if [[ -f "$SNAPSHOT" && "$FORCE" != "true" ]]; then
  echo "  ⚠ Snapshot for $TODAY already exists at:"
  echo "    $SNAPSHOT"
  echo ""
  echo "  Nothing was overwritten. The witness trail is intact."
  echo "  (Pass --force to deliberately overwrite — not recommended.)"
  exit 0
fi

cp -p "$LIVING_DOC" "$SNAPSHOT"
echo "  🟢 Snapshot written: docs/internal/chef/audit-living/${TODAY}.md"
echo "    ($(wc -l < "$SNAPSHOT") lines, $(stat -c %s "$SNAPSHOT") bytes)"
