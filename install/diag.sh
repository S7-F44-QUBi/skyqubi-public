#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Composite diagnostic script
#
# Runs the three core diagnostic scripts in sequence and aggregates
# their JSON output into a single health report. Designed to be called
# by Samuel's skill runner as the 'diag' skill when a user asks
# something like 'Samuel, how's the QUBi doing?' or 'check everything'.
#
# Runs (in order):
#   1. install/preflight.sh --json    — environment readiness
#   2. install/fix-pod.sh --dry-run --json — pod state + SELinux
#   3. s7-lifecycle-test.sh --json    — full 53-test suite
#
# Usage:
#   bash install/diag.sh              # text summary to stdout
#   bash install/diag.sh --json       # single JSON object to stdout
#   bash install/diag.sh --samuel     # JSON + ops-ledger audit trail
#   bash install/diag.sh --quick      # skip lifecycle (slower one)
#   bash install/diag.sh --help
#
# Exit codes:
#   0 — everything healthy
#   1 — one or more components degraded but no hard failures
#   2 — hard failure detected (install not ready OR pod broken OR
#       lifecycle failing)
#   3 — one of the sub-scripts errored out internally
#   4 — must-run-as-root for fix-pod sub-step
#
# Governing rules:
#   feedback_three_rules.md     Rule 3: Protect the QUBi
#   engine/agents/samuel_runnable_scripts.yaml  Catalog entry
#
# Copyright 2026 Jamie Lee Clayton / 2XR LLC · CWS-BSL-1.1
# ═══════════════════════════════════════════════════════════════════

set -u
set -o pipefail

# ── Root refusal ──
# diag.sh is a read-only composite that runs preflight + fix-pod --dry-run
# + lifecycle-test. Lifecycle test P05 explicitly asserts the suite is
# NOT running as root (rootless podman is S7's security model), so under
# sudo the whole inner pipeline silently fails. fix-pod has its own
# escalation path for the cases that need it. So: refuse root at the top,
# loudly, and tell the user why.
if [ "$(id -u)" = "0" ]; then
    echo "" >&2
    echo "  diag.sh refuses to run as root." >&2
    echo "" >&2
    echo "  Why: the lifecycle test asserts 'rootless podman' as a security" >&2
    echo "  invariant, so under sudo the suite fails P05 and the JSON emit" >&2
    echo "  path doesn't fire. fix-pod has its own --samuel mode that only" >&2
    echo "  escalates when it actually needs root, so you don't need sudo here." >&2
    echo "" >&2
    echo "  Run me as the s7 user instead:" >&2
    echo "      bash /s7/skyqubi-private/install/diag.sh${1:+ $*}" >&2
    echo "" >&2
    exit 4
fi

# ── Colors ──
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    YELLOW='\033[0;33m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    GREEN=''; RED=''; CYAN=''; YELLOW=''; BOLD=''; RESET=''
fi

# ── Flags ──
JSON_OUT=0
SAMUEL_MODE=0
QUICK=0
for arg in "$@"; do
    case "$arg" in
        --json)   JSON_OUT=1 ;;
        --samuel) SAMUEL_MODE=1; JSON_OUT=1 ;;
        --quick)  QUICK=1 ;;
        --help|-h)
            sed -n '3,26p' "$0" | sed 's|^# \?||'
            exit 0
            ;;
        *) echo "unknown flag: $arg" >&2; exit 1 ;;
    esac
done

# In JSON mode, redirect stdout→stderr so the final JSON line is the
# only thing on stdout. Same FD juggling pattern as the other scripts.
if [ "$JSON_OUT" -eq 1 ]; then
    exec 3>&1
    exec 1>&2
fi

_out() { echo -e "$1"; }
ok()   { _out "  ${GREEN}✓${RESET} $1"; }
fail() { _out "  ${RED}✗${RESET} $1"; }
warn() { _out "  ${YELLOW}!${RESET} $1"; }
info() { _out "  ${CYAN}→${RESET} $1"; }
section() { _out "\n${BOLD}${CYAN}── $1${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_ID="$(date +%s%N)-$$"

_out ""
_out "${BOLD}${CYAN}  S7 SkyQUBi — Composite Diagnostic${RESET}"
_out "  Run ID: $RUN_ID"
_out "  Mode:   $([ "$SAMUEL_MODE" -eq 1 ] && echo "SAMUEL-AUTONOMOUS" || ([ "$JSON_OUT" -eq 1 ] && echo "JSON" || echo "interactive"))"
_out ""

# Results storage
PREFLIGHT_STATE="not_run"
PREFLIGHT_ERRORS=0
PREFLIGHT_WARNINGS=0
PREFLIGHT_WARNED_LIST=""
PREFLIGHT_EXIT=0

FIXPOD_STATE="not_run"
FIXPOD_EXIT=0
FIXPOD_DETAIL=""

LIFECYCLE_STATE="not_run"
LIFECYCLE_PASS=0
LIFECYCLE_FAIL=0
LIFECYCLE_TOTAL=0
LIFECYCLE_EXIT=0

# ── Step 1: preflight ─────────────────────────────────────────────
section "Step 1/3 — install/preflight.sh --json"
if [ -x "$REPO_DIR/install/preflight.sh" ]; then
    preflight_json=$(bash "$REPO_DIR/install/preflight.sh" --json 2>/dev/null || true)
    PREFLIGHT_EXIT=$?
    if [ -n "$preflight_json" ]; then
        PREFLIGHT_STATE=$(echo "$preflight_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("state","unknown"))' 2>/dev/null || echo "parse_error")
        PREFLIGHT_ERRORS=$(echo "$preflight_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("errors",0))' 2>/dev/null || echo 0)
        PREFLIGHT_WARNINGS=$(echo "$preflight_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("warnings",0))' 2>/dev/null || echo 0)
        PREFLIGHT_WARNED_LIST=$(echo "$preflight_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(",".join(d.get("warned",[])))' 2>/dev/null || echo "")
        ok "preflight: state=$PREFLIGHT_STATE errors=$PREFLIGHT_ERRORS warnings=$PREFLIGHT_WARNINGS"
    else
        warn "preflight produced no JSON output"
        PREFLIGHT_STATE="no_json"
    fi
else
    warn "install/preflight.sh not found or not executable — skipping"
    PREFLIGHT_STATE="script_missing"
fi

# ── Step 2: fix-pod dry-run ───────────────────────────────────────
# Requires root. When not root, the script returns state=
# nonroot_dry_run_no_audit which is honestly reported.
section "Step 2/3 — install/fix-pod.sh --dry-run --samuel"
if [ -x "$REPO_DIR/install/fix-pod.sh" ]; then
    # Use --samuel to get JSON output + ops ledger entry. Always
    # --dry-run here — diag never applies fixes on its own.
    fixpod_json=$(bash "$REPO_DIR/install/fix-pod.sh" --dry-run --samuel 2>/dev/null || true)
    FIXPOD_EXIT=$?
    if [ -n "$fixpod_json" ]; then
        FIXPOD_STATE=$(echo "$fixpod_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("state","unknown"))' 2>/dev/null || echo "parse_error")
        ok "fix-pod dry-run: state=$FIXPOD_STATE exit=$FIXPOD_EXIT"
    else
        warn "fix-pod produced no JSON output"
        FIXPOD_STATE="no_json"
    fi
else
    warn "install/fix-pod.sh not found or not executable — skipping"
    FIXPOD_STATE="script_missing"
fi

# ── Step 3: lifecycle test ────────────────────────────────────────
if [ "$QUICK" -eq 1 ]; then
    section "Step 3/3 — lifecycle test SKIPPED (--quick)"
    LIFECYCLE_STATE="skipped_quick"
    ok "lifecycle: skipped (quick mode)"
else
    section "Step 3/3 — s7-lifecycle-test.sh --json"
    if [ -x "$REPO_DIR/s7-lifecycle-test.sh" ]; then
        lc_stderr_file=$(mktemp -t s7-lifecycle-stderr.XXXXXX)
        lifecycle_json=$(bash "$REPO_DIR/s7-lifecycle-test.sh" --json 2>"$lc_stderr_file" || true)
        LIFECYCLE_EXIT=$?
        if [ -n "$lifecycle_json" ]; then
            LIFECYCLE_STATE=$(echo "$lifecycle_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("state","unknown"))' 2>/dev/null || echo "parse_error")
            LIFECYCLE_PASS=$(echo "$lifecycle_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("pass",0))' 2>/dev/null || echo 0)
            LIFECYCLE_FAIL=$(echo "$lifecycle_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("fail",0))' 2>/dev/null || echo 0)
            LIFECYCLE_TOTAL=$(echo "$lifecycle_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("total",0))' 2>/dev/null || echo 0)
            ok "lifecycle: state=$LIFECYCLE_STATE $LIFECYCLE_PASS/$LIFECYCLE_TOTAL pass"
        else
            warn "lifecycle-test produced no JSON output"
            LIFECYCLE_STATE="no_json"
            if [ -s "$lc_stderr_file" ]; then
                warn "lifecycle stderr tail (last 5 lines):"
                tail -5 "$lc_stderr_file" | while IFS= read -r line; do
                    _out "      $line"
                done
            fi
        fi
        rm -f "$lc_stderr_file"
    else
        warn "s7-lifecycle-test.sh not found or not executable — skipping"
        LIFECYCLE_STATE="script_missing"
    fi
fi

# ── Aggregate verdict ─────────────────────────────────────────────
#
# Combined state decision matrix:
#   - healthy      : all three green (preflight=ready, fix-pod=pod_already_running
#                    OR dry_run_complete OR no_avc_denials with no action needed,
#                    lifecycle=verified)
#   - degraded     : one or more warnings, no hard failures
#   - failed       : any hard failure (preflight not_ready, fix-pod failures
#                    requiring action, lifecycle failed)
#   - error        : a sub-script errored out internally (parse_error / no_json /
#                    script_missing)
section "Aggregate verdict"

overall_state="healthy"
overall_exit=0
has_error=0
has_failure=0
has_warning=0

# Classify preflight
case "$PREFLIGHT_STATE" in
    ready)
        ok "preflight OK"
        ;;
    ready_with_warnings)
        warn "preflight has warnings ($PREFLIGHT_WARNINGS)"
        has_warning=1
        ;;
    not_ready)
        fail "preflight FAILED — $PREFLIGHT_ERRORS blocker(s)"
        has_failure=1
        ;;
    skipped_quick|script_missing|no_json|parse_error)
        warn "preflight: $PREFLIGHT_STATE"
        has_error=1
        ;;
    *)
        warn "preflight: unexpected state '$PREFLIGHT_STATE'"
        has_error=1
        ;;
esac

# Classify fix-pod
case "$FIXPOD_STATE" in
    pod_already_running)
        ok "pod OK (already running)"
        ;;
    dry_run_complete)
        warn "pod has an SELinux issue that fix-pod can fix (not applied)"
        has_warning=1
        ;;
    no_avc_denials)
        warn "pod is not running but SELinux is NOT the problem"
        has_warning=1
        ;;
    nonroot_dry_run_no_audit)
        warn "fix-pod could not fully diagnose without root"
        has_warning=1
        ;;
    setsebool_failed|start_pod_failed|pod_not_running_after_fix|semanage_failed)
        fail "fix-pod FAILED — $FIXPOD_STATE"
        has_failure=1
        ;;
    no_fix_pattern_match|ausearch_missing)
        fail "fix-pod cannot diagnose — $FIXPOD_STATE"
        has_failure=1
        ;;
    no_boolean_match)
        warn "fix-pod found denials but no matching fix pattern"
        has_warning=1
        ;;
    script_missing|no_json|parse_error)
        warn "fix-pod: $FIXPOD_STATE"
        has_error=1
        ;;
    *)
        warn "fix-pod: unexpected state '$FIXPOD_STATE'"
        has_error=1
        ;;
esac

# Classify lifecycle
case "$LIFECYCLE_STATE" in
    verified)
        ok "lifecycle OK — $LIFECYCLE_PASS/$LIFECYCLE_TOTAL pass"
        ;;
    failed)
        fail "lifecycle FAILED — $LIFECYCLE_FAIL of $LIFECYCLE_TOTAL tests failing"
        has_failure=1
        ;;
    skipped_quick)
        info "lifecycle skipped (quick mode)"
        ;;
    script_missing|no_json|parse_error)
        warn "lifecycle: $LIFECYCLE_STATE"
        has_error=1
        ;;
    *)
        warn "lifecycle: unexpected state '$LIFECYCLE_STATE'"
        has_error=1
        ;;
esac

# Decide overall state
if [ "$has_error" -eq 1 ]; then
    overall_state="error"
    overall_exit=3
elif [ "$has_failure" -eq 1 ]; then
    overall_state="failed"
    overall_exit=2
elif [ "$has_warning" -eq 1 ]; then
    overall_state="degraded"
    overall_exit=1
else
    overall_state="healthy"
    overall_exit=0
fi

_out ""
case "$overall_state" in
    healthy)  _out "  ${GREEN}${BOLD}HEALTHY — everything green${RESET}" ;;
    degraded) _out "  ${YELLOW}${BOLD}DEGRADED — some warnings, no blockers${RESET}" ;;
    failed)   _out "  ${RED}${BOLD}FAILED — hard blockers present${RESET}" ;;
    error)    _out "  ${YELLOW}${BOLD}ERROR — diagnostic script(s) could not produce output${RESET}" ;;
esac
_out ""

# ── Ops ledger (samuel mode) ──────────────────────────────────────
if [ "$SAMUEL_MODE" -eq 1 ]; then
    ledger_dir="/s7/.s7-ops-ledger"
    ledger_file="$ledger_dir/diag.ndjson"
    mkdir -p "$ledger_dir" 2>/dev/null && chmod 700 "$ledger_dir" 2>/dev/null

    if [ -f "$ledger_file" ] && [ -s "$ledger_file" ]; then
        prev_hash=$(tail -1 "$ledger_file" | sha256sum | awk '{print $1}')
    else
        prev_hash="0000000000000000000000000000000000000000000000000000000000000000"
    fi

    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '{"ts":"%s","script":"diag.sh","run_id":"%s","state":"%s","preflight":"%s","fixpod":"%s","lifecycle":"%s","prev_hash":"%s"}\n' \
        "$ts" "$RUN_ID" "$overall_state" "$PREFLIGHT_STATE" "$FIXPOD_STATE" "$LIFECYCLE_STATE" "$prev_hash" \
        >> "$ledger_file"
    chmod 600 "$ledger_file" 2>/dev/null || true
fi

# ── Final JSON emit ───────────────────────────────────────────────
if [ "$JSON_OUT" -eq 1 ]; then
    # Convert PREFLIGHT_WARNED_LIST (comma-separated) into a JSON array
    warned_json="["
    if [ -n "$PREFLIGHT_WARNED_LIST" ]; then
        first=1
        IFS=',' read -ra _w <<< "$PREFLIGHT_WARNED_LIST"
        for w in "${_w[@]}"; do
            [ $first -eq 0 ] && warned_json="$warned_json,"
            warned_json="$warned_json\"$w\""
            first=0
        done
    fi
    warned_json="$warned_json]"

    printf '{"script":"diag.sh","run_id":"%s","state":"%s","exit_code":%d,"preflight":{"state":"%s","errors":%d,"warnings":%d,"warned":%s},"fixpod":{"state":"%s","exit_code":%d},"lifecycle":{"state":"%s","pass":%d,"fail":%d,"total":%d}}\n' \
        "$RUN_ID" "$overall_state" "$overall_exit" \
        "$PREFLIGHT_STATE" "$PREFLIGHT_ERRORS" "$PREFLIGHT_WARNINGS" "$warned_json" \
        "$FIXPOD_STATE" "$FIXPOD_EXIT" \
        "$LIFECYCLE_STATE" "$LIFECYCLE_PASS" "$LIFECYCLE_FAIL" "$LIFECYCLE_TOTAL" >&3
fi

exit $overall_exit
