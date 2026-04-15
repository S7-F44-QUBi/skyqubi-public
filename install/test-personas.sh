#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Test Carli + Elias persona endpoints
#
# Sends a "hi" message to each persona via the running persona-chat
# service and reports whether they responded, with latency. This is
# the "is anyone home in the kitchen" check users actually want.
#
# Tests Carli and Elias only — NOT Samuel. Samuel is the one running
# this skill, so calling Samuel from inside Samuel would either be a
# trivial self-test or an infinite loop. Carli + Elias are the two
# personas Samuel can verify externally.
#
# Usage:
#   bash install/test-personas.sh                 # text summary
#   bash install/test-personas.sh --json          # single JSON object
#   bash install/test-personas.sh --samuel        # JSON + ledger row
#   bash install/test-personas.sh --help
#
# Exit codes:
#   0 — all_responding (both Carli and Elias replied non-empty)
#   1 — partial (one of the two responded, the other didn't)
#   2 — all_down (neither responded)
#   3 — service_unreachable (couldn't even connect to persona-chat)
#
# Environment:
#   PERSONA_CHAT_URL    base URL of the persona-chat service
#                       (default: http://127.0.0.1:57080)
#
# Governing rules:
#   feedback_three_rules.md     Rule 1: don't break Samuel's surface
#   project_chat_personas.md    Carli / Elias / Samuel — three voices
# ═══════════════════════════════════════════════════════════════════

set -u
set -o pipefail

JSON_OUT=0
SAMUEL_MODE=0
for arg in "$@"; do
    case "$arg" in
        --json)    JSON_OUT=1 ;;
        --samuel)  SAMUEL_MODE=1; JSON_OUT=1 ;;
        --help|-h)
            sed -n '3,30p' "$0" | sed 's|^# \?||'
            exit 0
            ;;
        *) echo "unknown flag: $arg" >&2; exit 1 ;;
    esac
done

# Colors + FD juggling (in JSON mode, all human output → stderr)
GREEN='' RED='' CYAN='' YELLOW='' BOLD='' RESET=''
if [ -t 1 ]; then
    GREEN=$'\033[0;32m'
    RED=$'\033[0;31m'
    CYAN=$'\033[0;36m'
    YELLOW=$'\033[0;33m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
fi
if [ "$JSON_OUT" -eq 1 ]; then
    exec 3>&1
    exec 1>&2
fi

_out()    { echo -e "$1"; }
ok()      { _out "  ${GREEN}✓${RESET} $1"; }
fail()    { _out "  ${RED}✗${RESET} $1"; }
warn()    { _out "  ${YELLOW}!${RESET} $1"; }
info()    { _out "  ${CYAN}→${RESET} $1"; }
section() { _out ""; _out "${BOLD}${CYAN}── $1${RESET}"; }

PERSONA_CHAT_URL="${PERSONA_CHAT_URL:-http://127.0.0.1:57080}"
RUN_ID="$(date +%s%N)-$$"
TIMEOUT_S=15

_out ""
_out "${BOLD}${CYAN}  S7 SkyQUBi — Test Personas${RESET}"
_out "  Run ID: $RUN_ID"
_out "  URL:    $PERSONA_CHAT_URL"
_out ""

# ── Service reachable? ──────────────────────────────────────────────
section "Service reachability"
if ! curl -sS --max-time 3 -o /dev/null "${PERSONA_CHAT_URL}/health" 2>&1; then
    fail "persona-chat at $PERSONA_CHAT_URL is not responding"
    fail "  (try: curl ${PERSONA_CHAT_URL}/health from a shell)"
    if [ "$JSON_OUT" -eq 1 ]; then
        printf '{"script":"test-personas.sh","run_id":"%s","state":"service_unreachable","exit_code":3,"carli":{"state":"unreachable","latency_ms":0},"elias":{"state":"unreachable","latency_ms":0}}\n' \
            "$RUN_ID" >&3
    fi
    exit 3
fi
ok "persona-chat /health responded"

# ── Per-persona test ────────────────────────────────────────────────
test_persona() {
    # IMPORTANT: this function is called via $(test_persona "x"), which
    # captures stdout. Human-readable status lines must go to stderr
    # (>&2) so they don't pollute the captured pipe-delimited result.
    local persona="$1"
    local sess="test-personas-${RUN_ID}-${persona}"
    local body
    body=$(printf '{"persona":"%s","message":"hi","tier":"L1","user_id":"samuel-selftest","session_id":"%s"}' \
        "$persona" "$sess")

    local t0
    t0=$(date +%s%N)
    local response
    response=$(curl -sS --max-time "$TIMEOUT_S" -X POST \
        -H "Content-Type: application/json" \
        -d "$body" \
        "${PERSONA_CHAT_URL}/persona/chat" 2>&1) || {
        local rc=$?
        local t1
        t1=$(date +%s%N)
        local ms=$(( (t1 - t0) / 1000000 ))
        fail "$persona: curl failed (exit $rc) after ${ms}ms" >&2
        echo "$persona|curl_error|$ms|exit_$rc"
        return
    }
    local t1
    t1=$(date +%s%N)
    local ms=$(( (t1 - t0) / 1000000 ))

    # Extract the response field via python3 (already a hard requirement)
    local reply
    reply=$(echo "$response" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get("response", "") or ""
    print(r[:60])
except Exception:
    pass
' 2>/dev/null)

    if [ -z "$reply" ]; then
        fail "$persona: empty response after ${ms}ms" >&2
        echo "$persona|empty|$ms|"
        return
    fi

    ok "$persona: responded in ${ms}ms — \"${reply}\"" >&2
    echo "$persona|ok|$ms|$reply"
}

section "Carli"
carli_result=$(test_persona "carli")

section "Elias"
elias_result=$(test_persona "elias")

# ── Aggregate verdict ───────────────────────────────────────────────
section "Verdict"

carli_state=$(echo "$carli_result" | cut -d'|' -f2)
carli_ms=$(echo "$carli_result" | cut -d'|' -f3)
elias_state=$(echo "$elias_result" | cut -d'|' -f2)
elias_ms=$(echo "$elias_result" | cut -d'|' -f3)

if [ "$carli_state" = "ok" ] && [ "$elias_state" = "ok" ]; then
    overall_state="all_responding"
    overall_exit=0
    ok "Both personas responded"
elif [ "$carli_state" != "ok" ] && [ "$elias_state" != "ok" ]; then
    overall_state="all_down"
    overall_exit=2
    fail "Both personas failed (Carli: $carli_state, Elias: $elias_state)"
elif [ "$carli_state" = "ok" ]; then
    overall_state="partial"
    overall_exit=1
    warn "Only Carli responded; Elias state: $elias_state"
else
    overall_state="partial"
    overall_exit=1
    warn "Only Elias responded; Carli state: $carli_state"
fi

# ── Ops ledger (samuel mode) ──────────────────────────────────────
if [ "$SAMUEL_MODE" -eq 1 ]; then
    ledger_dir="/s7/.s7-ops-ledger"
    ledger_file="$ledger_dir/test-personas.ndjson"
    mkdir -p "$ledger_dir" 2>/dev/null && chmod 700 "$ledger_dir" 2>/dev/null
    if [ -f "$ledger_file" ] && [ -s "$ledger_file" ]; then
        prev_hash=$(tail -1 "$ledger_file" | sha256sum | awk '{print $1}')
    else
        prev_hash="0000000000000000000000000000000000000000000000000000000000000000"
    fi
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '{"ts":"%s","script":"test-personas.sh","run_id":"%s","state":"%s","carli":"%s","carli_ms":%s,"elias":"%s","elias_ms":%s,"prev_hash":"%s"}\n' \
        "$ts" "$RUN_ID" "$overall_state" "$carli_state" "$carli_ms" "$elias_state" "$elias_ms" "$prev_hash" \
        >> "$ledger_file"
    chmod 600 "$ledger_file" 2>/dev/null || true
fi

# ── JSON emit ───────────────────────────────────────────────────────
if [ "$JSON_OUT" -eq 1 ]; then
    printf '{"script":"test-personas.sh","run_id":"%s","state":"%s","exit_code":%d,"carli":{"state":"%s","latency_ms":%s},"elias":{"state":"%s","latency_ms":%s}}\n' \
        "$RUN_ID" "$overall_state" "$overall_exit" \
        "$carli_state" "$carli_ms" \
        "$elias_state" "$elias_ms" >&3
fi

exit $overall_exit
