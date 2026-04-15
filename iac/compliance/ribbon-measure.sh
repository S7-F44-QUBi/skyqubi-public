#!/usr/bin/env bash
# iac/compliance/ribbon-measure.sh
#
# Orchestrator. Runs the 4 per-standard checks, computes a verdict,
# writes a hash-chained row to ribbons.measurements in postgres, and
# echoes a one-line summary.
#
# The ribbon is HELD when all_green = (fips_ok AND cis_ok AND hipaa_ok
# AND sbc_ok). A SKIPPED standard counts as PASS for the gate
# calculation, but the failure_summary records that it was skipped so
# the operator knows the gate is conditional on stubs.
#
# Usage:
#   bash iac/compliance/ribbon-measure.sh
#   bash iac/compliance/ribbon-measure.sh --dry-run    # don't write to DB
#
# Environment:
#   S7_PG_PASSWORD_FILE  — defaults to /s7/.config/s7/pg-password
#   S7_PG_HOST           — defaults to 127.0.0.1
#   S7_PG_PORT           — defaults to 57090
#   S7_PG_DB             — defaults to s7_cws
#   S7_PG_USER           — defaults to s7

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

PG_PASSWORD_FILE="${S7_PG_PASSWORD_FILE:-/s7/.config/s7/pg-password}"
PG_HOST="${S7_PG_HOST:-127.0.0.1}"
PG_PORT="${S7_PG_PORT:-57090}"
PG_DB="${S7_PG_DB:-s7_cws}"
PG_USER="${S7_PG_USER:-s7}"

# ── Run each per-standard check ──
echo "═══════════════════════════════════════════════════"
echo "  S7 ribbon measurement"
echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "═══════════════════════════════════════════════════"

run_check() {
  local script="$1"
  local label="$2"
  echo
  echo "[$label] running $script"
  local out
  out=$(bash "$SCRIPT_DIR/$script" 2>&1)
  local rc=$?
  echo "$out" | tail -5
  echo "$out" | tail -1   # the JSON line is always last
}

FIPS_JSON=$(bash "$SCRIPT_DIR/fips-check.sh" 2>/dev/null | tail -1)
CIS_JSON=$(bash "$SCRIPT_DIR/cis-check.sh" 2>/dev/null | tail -1)
HIPAA_JSON=$(bash "$SCRIPT_DIR/hipaa-check.sh" 2>/dev/null | tail -1)
SBC_JSON=$(bash "$SCRIPT_DIR/secure-boot-chain-check.sh" 2>/dev/null | tail -1)

# ── Parse the verdicts ──
parse_verdict() {
  echo "$1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("verdict","unknown"))'
}

FIPS_V=$(parse_verdict "$FIPS_JSON")
CIS_V=$(parse_verdict "$CIS_JSON")
HIPAA_V=$(parse_verdict "$HIPAA_JSON")
SBC_V=$(parse_verdict "$SBC_JSON")

# Gate logic: pass OR skipped both count as "ok" for the gate. A SKIPPED
# standard is recorded in failure_summary so the operator knows the
# ribbon is being held conditionally on stubs.
ok_for_gate() {
  case "$1" in
    pass|skipped) echo true ;;
    *) echo false ;;
  esac
}

FIPS_OK=$(ok_for_gate "$FIPS_V")
CIS_OK=$(ok_for_gate "$CIS_V")
HIPAA_OK=$(ok_for_gate "$HIPAA_V")
SBC_OK=$(ok_for_gate "$SBC_V")

ALL_GREEN=false
if [[ "$FIPS_OK" == "true" && "$CIS_OK" == "true" && "$HIPAA_OK" == "true" && "$SBC_OK" == "true" ]]; then
  ALL_GREEN=true
fi

# ── Compose failure_summary ──
SUMMARY_PARTS=()
[[ "$FIPS_V" != "pass" ]] && SUMMARY_PARTS+=("fips:$FIPS_V")
[[ "$CIS_V" != "pass" ]] && SUMMARY_PARTS+=("cis:$CIS_V")
[[ "$HIPAA_V" != "pass" ]] && SUMMARY_PARTS+=("hipaa:$HIPAA_V")
[[ "$SBC_V" != "pass" ]] && SUMMARY_PARTS+=("sbc:$SBC_V")
SUMMARY=$(IFS=, ; echo "${SUMMARY_PARTS[*]:-all-pass}")

echo
echo "─── verdict ───"
echo "  fips:  $FIPS_V"
echo "  cis:   $CIS_V"
echo "  hipaa: $HIPAA_V"
echo "  sbc:   $SBC_V"
echo "  all_green: $ALL_GREEN"
echo "  summary:  $SUMMARY"

if $DRY_RUN; then
  echo
  echo "[dry-run] not writing to database"
  exit 0
fi

# ── Write to ribbons.measurements (hash-chained) ──
if [[ ! -f "$PG_PASSWORD_FILE" ]]; then
  echo "FAIL: pg password file missing at $PG_PASSWORD_FILE" >&2
  exit 2
fi
PG_PW=$(cat "$PG_PASSWORD_FILE")

# Pull the previous row_hash (NULL on first run)
PREV_HASH=$(podman exec -e PGPASSWORD="$PG_PW" s7-skyqubi-s7-postgres \
  psql -U "$PG_USER" -d "$PG_DB" -tAc \
  "SELECT row_hash FROM ribbons.measurements ORDER BY id DESC LIMIT 1;" 2>/dev/null || echo "")
PREV_HASH=$(echo "$PREV_HASH" | tr -d '[:space:]')

# Insert the new row using the SQL helper to compute row_hash. The
# trick: we INSERT with a placeholder row_hash, then UPDATE the row
# with the computed hash referencing the same row's data — but that's
# racy under concurrent inserts. Cleaner: compute the row_hash in SQL
# with COMMIT-time visibility via a CTE.
INSERT_SQL=$(cat <<EOF
WITH params AS (
  SELECT
    now()::TIMESTAMPTZ                AS ts,
    ${FIPS_OK}::BOOLEAN               AS fips_ok,
    ${CIS_OK}::BOOLEAN                AS cis_ok,
    ${HIPAA_OK}::BOOLEAN              AS hipaa_ok,
    ${SBC_OK}::BOOLEAN                AS sbc_ok,
    \$\$${SUMMARY}\$\$::TEXT          AS failure_summary,
    'ribbon-measure.sh'::TEXT         AS measured_by,
    NULLIF(\$\$${PREV_HASH}\$\$,'')::TEXT AS prev_row_hash
)
INSERT INTO ribbons.measurements
  (ts, fips_ok, cis_ok, hipaa_ok, sbc_ok, failure_summary, measured_by, prev_row_hash, row_hash)
SELECT
  ts, fips_ok, cis_ok, hipaa_ok, sbc_ok, failure_summary, measured_by, prev_row_hash,
  ribbons.compute_row_hash(ts, fips_ok, cis_ok, hipaa_ok, sbc_ok, failure_summary, measured_by, prev_row_hash)
FROM params
RETURNING id, all_green, row_hash;
EOF
)

RESULT=$(podman exec -i -e PGPASSWORD="$PG_PW" s7-skyqubi-s7-postgres \
  psql -U "$PG_USER" -d "$PG_DB" -tA <<<"$INSERT_SQL" 2>&1)

if echo "$RESULT" | grep -qE '^[0-9]+\|'; then
  echo
  echo "─── ledger row written ───"
  echo "  $RESULT"
  if [[ "$ALL_GREEN" == "true" ]]; then
    echo
    echo "  ribbon: HELD"
  else
    echo
    echo "  ribbon: REVOKED"
  fi
  exit 0
else
  echo "FAIL: insert failed:" >&2
  echo "$RESULT" >&2
  exit 2
fi
