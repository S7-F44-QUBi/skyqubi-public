#!/usr/bin/env bash
# iac/audit/local-health-report.sh
#
# Generates the S7 Local Health Report — one JSON source of truth,
# one markdown snapshot for git history, and the persona-chat
# /health route reads the latest JSON to render the HTML surface.
#
# Data sources:
#   - iac/audit/pre-sync-gate.sh    (Axis A/B/C findings)
#   - s7-lifecycle-test.sh          (E/A/P/R/S/K/B test results)
#   - podman pod inspect            (pod + container state)
#   - ss -tlnp                      (host-side port listeners)
#   - curl :57077/status            (CWS engine responsiveness)
#   - curl :57077/skyavi/core/status (Samuel agent count)
#
# Every finding carries: id, severity, title, root_cause, impact,
# next_step. Per Jamie's exact words: "output report chart metrix
# performance root of issue suggest impact".
#
# Usage:
#   ./local-health-report.sh              # emit JSON + markdown
#   ./local-health-report.sh --json-only  # JSON only
#   ./local-health-report.sh --quiet      # skip console output
#   ./local-health-report.sh --help       # print this header

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORTS_DIR="$REPO_ROOT/docs/internal/reports"
mkdir -p "$REPORTS_DIR"

TS_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TS_FILE="$(date -u +%Y%m%d-%H%M%S)"
JSON_OUT="$REPORTS_DIR/local-health-${TS_FILE}.json"
MD_OUT="$REPORTS_DIR/local-health-${TS_FILE}.md"
LATEST_JSON="$REPORTS_DIR/local-health-latest.json"
LATEST_MD="$REPORTS_DIR/local-health-latest.md"

JSON_ONLY=false
QUIET=false
for arg in "$@"; do
  case "$arg" in
    --json-only) JSON_ONLY=true ;;
    --quiet) QUIET=true ;;
    --help|-h) sed -n '2,22p' "$0" | sed 's|^# \?||'; exit 0 ;;
  esac
done

# ── Collector: findings array builder ──────────────────────────
FINDINGS=()
OVERALL="green"

add_finding() {
  local severity="$1" title="$2" root_cause="$3" impact="$4" next_step="$5" id="${6:-}"
  [[ -z "$id" ]] && id="finding-$(date -u +%s%N | tail -c 6)"
  FINDINGS+=("$(jq -nc \
    --arg id "$id" \
    --arg severity "$severity" \
    --arg title "$title" \
    --arg root_cause "$root_cause" \
    --arg impact "$impact" \
    --arg next_step "$next_step" \
    '{id:$id,severity:$severity,title:$title,root_cause:$root_cause,impact:$impact,next_step:$next_step}')")
  if [[ "$severity" == "red" ]]; then
    OVERALL="red"
  elif [[ "$severity" == "yellow" && "$OVERALL" == "green" ]]; then
    OVERALL="yellow"
  fi
}

# ── Source 1: audit gate ────────────────────────────────────────
collect_audit_gate() {
  local gate_output gate_pass gate_pinned gate_warn gate_block
  gate_output=$(bash "$SCRIPT_DIR/pre-sync-gate.sh" 2>&1 || true)
  gate_pass=$(echo "$gate_output" | grep -oP 'pass:\s*\K\d+' | head -1 || echo 0)
  gate_pinned=$(echo "$gate_output" | grep -oP 'pinned:\s*\K\d+' | head -1 || echo 0)
  gate_warn=$(echo "$gate_output" | grep -oP 'warn:\s*\K\d+' | head -1 || echo 0)
  gate_block=$(echo "$gate_output" | grep -oP 'block:\s*\K\d+' | head -1 || echo 0)

  AUDIT_GATE_JSON=$(jq -nc \
    --argjson pass "${gate_pass:-0}" \
    --argjson pinned "${gate_pinned:-0}" \
    --argjson warn "${gate_warn:-0}" \
    --argjson block "${gate_block:-0}" \
    '{pass:$pass,pinned:$pinned,warn:$warn,block:$block}')

  if [[ "${gate_block:-0}" -gt 0 ]]; then
    add_finding "red" "Audit gate BLOCK" \
      "pre-sync-gate.sh returned $gate_block blocking findings" \
      "blocks-deploy" \
      "run bash iac/audit/pre-sync-gate.sh and read the findings list" \
      "audit-gate-block"
  elif [[ "${gate_warn:-0}" -gt 0 ]]; then
    add_finding "yellow" "Audit gate warnings" \
      "pre-sync-gate.sh returned $gate_warn warnings" \
      "household-visible" \
      "review warnings, promote to pinned.yaml if accepted, or resolve" \
      "audit-gate-warn"
  fi
}

# ── Source 2: lifecycle test ────────────────────────────────────
collect_lifecycle() {
  local lc_output lc_pass lc_fail lc_total
  if [[ -x "$REPO_ROOT/s7-lifecycle-test.sh" ]]; then
    lc_output=$(bash "$REPO_ROOT/s7-lifecycle-test.sh" 2>&1 || true)
    lc_pass=$(echo "$lc_output" | grep -oP '\K\d+(?= PASS)' | tail -1 || echo 0)
    lc_fail=$(echo "$lc_output" | grep -oP '\K\d+(?= FAIL)' | tail -1 || echo 0)
    lc_total=$(echo "$lc_output" | grep -oP 'out of \K\d+' | tail -1 || echo 55)
  else
    lc_pass=0; lc_fail=0; lc_total=55
    add_finding "yellow" "Lifecycle test not runnable" \
      "s7-lifecycle-test.sh not executable" \
      "cosmetic" \
      "chmod +x s7-lifecycle-test.sh" \
      "lifecycle-not-runnable"
  fi

  LIFECYCLE_JSON=$(jq -nc \
    --argjson pass "${lc_pass:-0}" \
    --argjson fail "${lc_fail:-0}" \
    --argjson total "${lc_total:-55}" \
    '{pass:$pass,fail:$fail,total:$total}')

  if [[ "${lc_fail:-0}" -gt 5 ]]; then
    add_finding "yellow" "Lifecycle test: ${lc_fail:-0} failures" \
      "known drift: Ollama on legacy 7081 not 57081 until autostart relogin" \
      "blocks-deploy if sustained; cosmetic in-session" \
      "systemctl --user restart s7-ollama OR log out and back in" \
      "lifecycle-ollama-drift"
  elif [[ "${lc_fail:-0}" -gt 0 ]]; then
    add_finding "yellow" "Lifecycle test: ${lc_fail:-0} minor failures" \
      "verify per-test findings in lifecycle log" \
      "household-visible" \
      "cat /tmp/s7-lifecycle-test.log" \
      "lifecycle-minor"
  fi
}

# ── Source 3: pod state ─────────────────────────────────────────
collect_pod() {
  local pod_running=false pod_status="unknown" pod_containers="[]"
  if command -v podman >/dev/null 2>&1; then
    if podman pod exists s7-skyqubi 2>/dev/null; then
      pod_status=$(podman pod inspect s7-skyqubi --format '{{.State}}' 2>/dev/null || echo "unknown")
      [[ "$pod_status" == "Running" ]] && pod_running=true
      pod_containers=$(podman pod inspect s7-skyqubi --format '{{json .Containers}}' 2>/dev/null | jq -c '[.[] | {name, state}] // []' 2>/dev/null || echo "[]")
    fi
  fi

  POD_JSON=$(jq -nc \
    --argjson running "$pod_running" \
    --arg status "$pod_status" \
    --argjson containers "$pod_containers" \
    '{running:$running,status:$status,containers:$containers}')

  if [[ "$pod_running" != "true" ]]; then
    add_finding "red" "Pod not running" \
      "podman pod inspect s7-skyqubi reports state=$pod_status" \
      "blocks-deploy" \
      "run bash start-pod.sh OR s7-manager.sh pod start" \
      "pod-not-running"
  fi
}

# ── Source 4: port listeners + performance ─────────────────────
collect_performance() {
  local cws_latency_ms ollama_port_actual samuel_skills
  cws_latency_ms=$( { time curl -s -o /dev/null http://127.0.0.1:57077/status 2>/dev/null; } 2>&1 | grep real | awk '{print $2}' | sed 's/[ms]//g' || echo "null")

  # Ollama port check — running reality
  ollama_port_actual=$(ss -tlnp 2>/dev/null | awk '/:(7081|57081) /{print $4}' | head -1 || echo "not-running")

  # Samuel skill count via CWS engine
  samuel_skills=$(curl -s -m 2 http://127.0.0.1:57077/skyavi/skills 2>/dev/null | jq 'length // 0' 2>/dev/null || echo 0)

  PERF_JSON=$(jq -nc \
    --arg cws_latency "$cws_latency_ms" \
    --arg ollama_port "$ollama_port_actual" \
    --argjson samuel_skills "${samuel_skills:-0}" \
    '{cws_latency: $cws_latency, ollama_port_running: $ollama_port, samuel_skills: $samuel_skills}')

  if [[ "$ollama_port_actual" == *"7081"* && "$ollama_port_actual" != *"57081"* ]]; then
    add_finding "yellow" "Ollama on legacy 7081 (not 57081)" \
      "autostart .desktop was source-fixed but running process predates restart — user has not re-logged-in" \
      "cosmetic at household level; breaks 7 lifecycle tests" \
      "log out and back in (safest) OR systemctl --user restart s7-ollama" \
      "ollama-legacy-port"
  fi
}

# ── Source 5: frozen trees ──────────────────────────────────────
collect_frozen() {
  local frozen_file="$SCRIPT_DIR/frozen-trees.txt"
  local pending_count=0
  if [[ -f "$frozen_file" ]]; then
    pending_count=$(grep -c 'PENDING' "$frozen_file" 2>/dev/null || echo 0)
  fi
  FROZEN_JSON=$(jq -nc --argjson pending "$pending_count" '{pending:$pending}')
}

# ── Run all collectors ──────────────────────────────────────────
if ! $QUIET; then
  echo "Collecting local health data..." >&2
fi

# initialize empty so unused sources don't break the final assembly
AUDIT_GATE_JSON='{}'
LIFECYCLE_JSON='{}'
POD_JSON='{}'
PERF_JSON='{}'
FROZEN_JSON='{}'

collect_audit_gate 2>/dev/null || add_finding "yellow" "audit gate collector failed" "collector script error" "cosmetic" "check iac/audit/local-health-report.sh" "collector-audit-fail"
collect_lifecycle 2>/dev/null || add_finding "yellow" "lifecycle collector failed" "collector script error" "cosmetic" "check iac/audit/local-health-report.sh" "collector-lifecycle-fail"
collect_pod 2>/dev/null || add_finding "yellow" "pod collector failed" "collector script error" "cosmetic" "check iac/audit/local-health-report.sh" "collector-pod-fail"
collect_performance 2>/dev/null || add_finding "yellow" "performance collector failed" "collector script error" "cosmetic" "check iac/audit/local-health-report.sh" "collector-perf-fail"
collect_frozen 2>/dev/null || true

# ── Assemble JSON ───────────────────────────────────────────────
findings_json=$(printf '%s\n' "${FINDINGS[@]}" | jq -s '.' 2>/dev/null || echo '[]')

jq -n \
  --arg generated_at "$TS_ISO" \
  --arg core_update "v6-genesis" \
  --arg overall "$OVERALL" \
  --argjson lifecycle "$LIFECYCLE_JSON" \
  --argjson audit_gate "$AUDIT_GATE_JSON" \
  --argjson pod "$POD_JSON" \
  --argjson performance "$PERF_JSON" \
  --argjson frozen "$FROZEN_JSON" \
  --argjson findings "$findings_json" \
  '{
    schema: "s7-local-health/v1",
    generated_at: $generated_at,
    core_update: $core_update,
    overall_status: $overall,
    lifecycle: $lifecycle,
    audit_gate: $audit_gate,
    pod: $pod,
    performance: $performance,
    frozen_trees: $frozen,
    findings: $findings
  }' > "$JSON_OUT"

# Symlink latest
ln -sf "$(basename "$JSON_OUT")" "$LATEST_JSON"

# ── Markdown renderer ───────────────────────────────────────────
if ! $JSON_ONLY; then
  {
    echo "# S7 Local Health Report"
    echo
    echo "| Field | Value |"
    echo "|---|---|"
    echo "| Generated | $TS_ISO |"
    echo "| CORE Update | v6-genesis |"
    case "$OVERALL" in
      green)  echo "| Overall | 🟢 GREEN — all gates passing |" ;;
      yellow) echo "| Overall | 🟡 YELLOW — household-acknowledged drift |" ;;
      red)    echo "| Overall | 🔴 RED — attention needed |" ;;
    esac
    echo
    echo "## Lifecycle test"
    echo
    echo '```'
    echo "$LIFECYCLE_JSON" | jq -r '. | "pass: \(.pass)  fail: \(.fail)  total: \(.total)"'
    echo '```'
    echo
    echo "## Audit gate"
    echo
    echo '```'
    echo "$AUDIT_GATE_JSON" | jq -r '. | "pass: \(.pass)  pinned: \(.pinned)  warn: \(.warn)  block: \(.block)"'
    echo '```'
    echo
    echo "## Pod state"
    echo
    echo '```'
    echo "$POD_JSON" | jq .
    echo '```'
    echo
    echo "## Performance"
    echo
    echo '```'
    echo "$PERF_JSON" | jq .
    echo '```'
    echo
    echo "## Findings"
    echo
    if [[ ${#FINDINGS[@]} -eq 0 ]]; then
      echo "*No findings.*"
    else
      echo "| Severity | Title | Root cause | Impact | Next step |"
      echo "|---|---|---|---|---|"
      printf '%s\n' "${FINDINGS[@]}" | jq -r '. | "| \(.severity) | \(.title) | \(.root_cause) | \(.impact) | \(.next_step) |"'
    fi
    echo
    echo "---"
    echo
    echo "*Source of truth: [\`$(basename "$JSON_OUT")\`]($(basename "$JSON_OUT"))*"
    echo
    echo "*Rendered by \`iac/audit/local-health-report.sh\` • persona-chat \`/health\` route reads the JSON.*"
  } > "$MD_OUT"
  ln -sf "$(basename "$MD_OUT")" "$LATEST_MD"
fi

if ! $QUIET; then
  case "$OVERALL" in
    green)  echo "  🟢 LOCAL HEALTH: GREEN" ;;
    yellow) echo "  🟡 LOCAL HEALTH: YELLOW" ;;
    red)    echo "  🔴 LOCAL HEALTH: RED" ;;
  esac
  echo "  JSON: $JSON_OUT"
  [[ ! "$JSON_ONLY" == "true" ]] && echo "  MD:   $MD_OUT"
  echo "  Findings: ${#FINDINGS[@]}"
fi

exit 0
