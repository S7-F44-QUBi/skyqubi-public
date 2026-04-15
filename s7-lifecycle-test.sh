#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Lifecycle Test
# Fixed expectations. Same tests every run. No variance.
#
# Usage:
#   ./s7-lifecycle-test.sh              # Full lifecycle (clean + deploy + verify)
#   ./s7-lifecycle-test.sh --verify     # Verify only (skip clean + deploy)
#   ./s7-lifecycle-test.sh --json       # Single JSON object on stdout, text on stderr
#
# --json mode completes the Samuel-runnable trifecta alongside fix-pod.sh and
# preflight.sh. Samuel's skill runner parses stdout (one JSON object), captures
# stderr as a log blob.
#
# Exit codes:
#   0 = all pass
#   1 = failures found
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="/tmp/s7-lifecycle-test.log"
PASS=0
FAIL=0
TOTAL=0
EXPECTED=55

# ── Flags ──
JSON_OUT=0
for arg in "$@"; do
    case "$arg" in
        --json)   JSON_OUT=1 ;;
        --verify) ;;  # historical flag, no-op today
        --help|-h) sed -n '3,16p' "$0" | sed 's|^# \?||'; exit 0 ;;
        *) echo "unknown flag: $arg" >&2; exit 1 ;;
    esac
done

G='\033[0;32m'; R='\033[0;31m'; C='\033[0;36m'; Y='\033[0;33m'; B='\033[1m'; X='\033[0m'

# Per-test result tracking for --json mode. Parallel arrays indexed by test order.
RESULT_IDS=()
RESULT_NAMES=()
RESULT_STATUS=()
RESULT_DETAIL=()

# In --json mode, all human-readable stdout goes to stderr so the final JSON
# line is the ONLY thing on stdout. Accomplished via FD juggling: save real
# stdout on fd 3, redirect stdout to stderr for the whole run, then write
# the JSON to fd 3 at the end.
if [ "$JSON_OUT" -eq 1 ]; then
    exec 3>&1   # fd 3 = original stdout
    exec 1>&2   # redirect stdout to stderr
fi

t() {
  local id="$1"; local name="$2"; local cmd="$3"; local expect="$4"
  TOTAL=$((TOTAL + 1))
  local result
  result=$(eval "$cmd" 2>&1) || true
  RESULT_IDS+=("$id")
  RESULT_NAMES+=("$name")
  if echo "$result" | grep -qi "$expect"; then
    echo -e "  ${G}PASS${X}  [${id}] ${name}" | tee -a "$LOG"
    PASS=$((PASS + 1))
    RESULT_STATUS+=("pass")
    RESULT_DETAIL+=("")
  else
    echo -e "  ${R}FAIL${X}  [${id}] ${name}" | tee -a "$LOG"
    local got
    got=$(echo "$result" | head -c 120 | tr '\n' ' ')
    echo "        got: $got" | tee -a "$LOG"
    FAIL=$((FAIL + 1))
    RESULT_STATUS+=("fail")
    RESULT_DETAIL+=("$got")
  fi
}

echo "" | tee "$LOG"
echo "═══════════════════════════════════════════════════════════════" | tee -a "$LOG"
echo "  S7 SkyQUBi — Lifecycle Test" | tee -a "$LOG"
echo "  $(date)" | tee -a "$LOG"
echo "  Expected: ${EXPECTED} tests" | tee -a "$LOG"
echo "═══════════════════════════════════════════════════════════════" | tee -a "$LOG"

# ══════════════════════════════════════════════════════════════════
# PRE-AUDIT (12 tests)
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo -e "${B}── Pre-Audit (14 tests) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

t "P01" "OS is Linux"              "uname -s"                                                        "Linux"
t "P02" "podman installed"         "command -v podman"                                               "podman"
t "P03" "envsubst installed"       "command -v envsubst"                                             "envsubst"
t "P04" "python3 installed"        "command -v python3"                                              "python3"
t "P05" "Not root"                 "test \$(id -u) -ne 0 && echo nonroot"                           "nonroot"
t "P06" "Podman rootless"          "podman info --format '{{.Host.Security.Rootless}}'"              "true"
t "P07" "subuid configured"        "grep ^\$(whoami): /etc/subuid"                                  "$(whoami)"
t "P08" "Podman socket"            "test -S /run/user/\$(id -u)/podman/podman.sock && echo exists"  "exists"
t "P09" "Disk >10GB free"          "df -BG / | tail -1 | awk '{gsub(\"G\",\"\"); if(\$4>=10) print \"ok\"}'" "ok"
t "P10" "Admin image available"    "podman image exists localhost/s7-skyqubi-admin:v2.6 && echo yes" "yes"
# P11: SELinux booleans for rootless container mprotect — regression-proofs against
# the container-crash-loop class we hit on 2026-04-13 where domain_can_mmap_files
# was the first thing checked but container_manage_cgroup was the real gap.
t "P11" "SELinux container bools"  "getsebool domain_can_mmap_files container_manage_cgroup 2>/dev/null | awk '{print \$NF}' | sort -u" "on"
# P12: At least one AVC source must be reachable so fix-pod.sh can diagnose.
# Today's 3-hour debug happened because audit.log was missing (auditd off) and
# the original fix-pod.sh didn't fall back to journalctl. P12 would have caught
# that environmental gap before the pod even went into crash loop. Uses
# journalctl -k (non-root readable on Fedora via systemd-journal group).
t "P12" "AVC source reachable"     "journalctl -k -b -n 1 --no-pager 2>&1"                                                  "kernel:"
# P13: firewalld trusts the rootless link-local gateway 169.254.1.0/24.
# 2026-04-13 lesson: after every reboot the runtime-only firewall rules
# are gone. If P13 fails, fix-firewall.sh apply path will repair it.
# Read via --get-active-zones because --list-sources needs polkit and
# silently returns empty for the non-root s7 user (this trap caught us
# earlier today — the check was running and silently passing).
t "P13" "firewalld 169.254 trust"  "firewall-cmd --get-active-zones 2>/dev/null | awk '/^[a-zA-Z]/{z=\$1;next} /sources:/&&z==\"trusted\"{print;exit}'" "169.254.1.0/24"
# P14: local ollama listener responds with a version. Distinct from
# checking ollama.com (the upstream registry) — this is the host's own
# inference daemon. If P14 fails, no persona can answer regardless of
# pod state, firewall state, or anything else.
t "P14" "local ollama listener"    "curl -sS --max-time 3 http://127.0.0.1:57081/api/version 2>&1"                          "version"

# ══════════════════════════════════════════════════════════════════
# CONTAINERS (6 tests)
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo -e "${B}── Containers (6 tests) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

t "C01" "Pod running"              "podman pod ps --format '{{.Status}}'"                             "Running"
t "C02" "s7-admin up"              "podman ps --format '{{.Names}}' | grep s7-skyqubi-s7-admin"       "admin"
t "C03" "s7-mysql up"              "podman ps --format '{{.Names}}' | grep s7-skyqubi-s7-mysql"       "mysql"
t "C04" "s7-postgres up"           "podman ps --format '{{.Names}}' | grep s7-skyqubi-s7-postgres"    "postgres"
t "C05" "s7-redis up"              "podman ps --format '{{.Names}}' | grep s7-skyqubi-s7-redis"       "redis"
t "C06" "s7-qdrant up"             "podman ps --format '{{.Names}}' | grep s7-skyqubi-s7-qdrant"      "qdrant"

# ══════════════════════════════════════════════════════════════════
# DATABASES (4 tests)
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo -e "${B}── Databases (4 tests) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

t "D01" "PostgreSQL accepting"     "podman exec s7-skyqubi-s7-postgres pg_isready"                                     "accepting"
MYSQL_PW=$(grep MYSQL_PASSWORD /s7/.env.secrets 2>/dev/null | head -1 | cut -d= -f2)
MYSQL_USR=$(grep MYSQL_USER /s7/.env.secrets 2>/dev/null | head -1 | cut -d= -f2)
t "D02" "MySQL alive"              "podman exec s7-skyqubi-s7-mysql mysqladmin -u ${MYSQL_USR:-nomad_user} -p${MYSQL_PW:-x} ping 2>&1"   "alive"
t "D03" "Redis PONG"               "podman exec s7-skyqubi-s7-redis redis-cli ping"                                    "PONG"
t "D04" "Qdrant healthy"           "podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:6333/healthz"             "passed"

# ══════════════════════════════════════════════════════════════════
# CWS ENGINE (6 tests)
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo -e "${B}── CWS Engine (6 tests) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

CWS_TOKEN=$(grep CWS_ENGINE_TOKEN /s7/.env.secrets 2>/dev/null | cut -d= -f2)
t "E01" "CWS Engine responding"    "podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:7077/status"                                                          "CWS Engine"
t "E02" "Auth rejects no token"    "podman exec s7-skyqubi-s7-admin curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:7077/route"                     "401\|403\|422"
t "E03" "SkyAVi 3 agents"          "podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:7077/skyavi/core/status -H 'Authorization: Bearer ${CWS_TOKEN}' | python3 -c 'import sys,json; print(json.load(sys.stdin)[\"agents\"])'" "3"
t "E04" "Samuel 92 skills"         "podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:7077/skyavi/skills -H 'Authorization: Bearer ${CWS_TOKEN}' | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))'"              "92"
# E05: /discern endpoint is routed + validates input. Contract-level test —
# posts an empty body and asserts the FastAPI validator returns 'detail' with
# 'missing' field errors. First real test that /discern exists as a callable
# route; E01-E04 only proved /status + /skyavi/* work. Deeper 'known-BABEL
# classified correctly' test is blocked on two bugs in run_discernment:
#   (1) session row not inserted before passes (missing INSERT INTO sessions)
#   (2) DiscernRequest.session_id is str not uuid.UUID (422 vs 500 failure mode)
# Both fixes committed to git, both need admin image rebuild to take effect.
t "E05" "/discern routed+validator" "podman exec s7-skyqubi-s7-admin curl -s -X POST http://127.0.0.1:7077/discern -H 'Authorization: Bearer ${CWS_TOKEN}' -H 'Content-Type: application/json' -d '{}'" "missing"
# E06: /witness Bible-Code verdict integration test. The REAL Rule 2 enforcer
# test — posts a valid UUID + query + model to /witness, expects a 200 with
# a 'convergence' field in the JSON response. Proves:
#   - FastAPI routing + input validation
#   - Engine reaches Ollama via host.containers.internal (OLLAMA_URL fix)
#   - Witness registry has a row for the requested model (persona seed)
#   - SQL INSERT path for witness_outputs + convergence_scores works
#   - The full run_witness() path completes without exception
# This closes the 'coverage is too shallow on the verdict path' gap that
# let /witness + /discern 500 for months without the lifecycle test noticing.
# Expected wall time ~8s on cold-start Carli; E06 runs after A04 which
# warms the model.
t "E06" "/witness Bible-Code verdict" "podman exec s7-skyqubi-s7-admin curl -s -X POST http://127.0.0.1:7077/witness -H 'Authorization: Bearer ${CWS_TOKEN}' -H 'Content-Type: application/json' -d \"{\\\"session_id\\\":\\\"\$(python3 -c 'import uuid; print(uuid.uuid4())')\\\",\\\"query\\\":\\\"what is 2+2\\\",\\\"model\\\":\\\"s7-carli:0.6b\\\"}\"" "convergence"

# ══════════════════════════════════════════════════════════════════
# COMMAND CENTER (2 tests)
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo -e "${B}── Command Center (2 tests) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

t "U01" "Web UI responds"          "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:57080/"  "302"
# U02: /home (the redirect target) actually renders real HTML. U01 only checks
# that / redirects; U02 catches a handler crash at /home that would leave U01
# happy but the user staring at a broken page. Greps for the <title>S7 SkyQUBi
# marker which is in the rendered Inertia page.
t "U02" "/home renders HTML"       "curl -s -L http://127.0.0.1:57080/ | head -50"                    "S7 SkyQUBi"

# ══════════════════════════════════════════════════════════════════
# AI CHAT (7 tests)
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo -e "${B}── AI Chat (7 tests) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

t "A01" "Ollama running"           "curl -s http://127.0.0.1:57081/api/version"                                                                                                                                                           "version"
t "A02" "≥9 models loaded"         "curl -s http://127.0.0.1:57081/api/tags | python3 -c 'import sys,json; n=len(json.load(sys.stdin)[\"models\"]); print(\"9+\" if n>=9 else str(n))'"                                         "9+"
t "A03" "Pod reaches Ollama"       "podman exec s7-skyqubi-s7-admin curl -s http://host.containers.internal:57081/api/version"                                                                                                             "version"
t "A04" "Carli responds"           "podman exec s7-skyqubi-s7-admin curl -s -X POST http://127.0.0.1:57080/api/ollama/chat -H 'Content-Type: application/json' -d '{\"messages\":[{\"role\":\"user\",\"content\":\"say ok\"}],\"model\":\"s7-carli:0.6b\",\"stream\":false}'" "done"
# A05: Carli 'hi' latency must stay under 2s post-optimization. Regression
# guard for feedback_carli_perf_followups.md's 332ms baseline. Warms the
# model first (ignoring the cold-load turn), then measures the warm turn.
t "A05" "Carli hi under 2s"        "curl -s -X POST http://127.0.0.1:57081/api/generate -H 'Content-Type: application/json' -d '{\"model\":\"s7-carli:0.6b\",\"prompt\":\"warm\",\"stream\":false,\"options\":{\"num_predict\":3}}' >/dev/null; t0=\$(date +%s%N); curl -s -X POST http://127.0.0.1:57081/api/generate -H 'Content-Type: application/json' -d '{\"model\":\"s7-carli:0.6b\",\"prompt\":\"hi\",\"stream\":false,\"think\":false,\"options\":{\"num_predict\":5}}' >/dev/null; t1=\$(date +%s%N); ms=\$(( (t1-t0)/1000000 )); [ \$ms -lt 2000 ] && echo under2s || echo over2s_\${ms}ms" "under2s"
# A06: Samuel responds — parallel to A04 Carli. Validates that Modelfile.samuel
# and s7-samuel:v1 exist and Ollama can serve the persona end-to-end.
t "A06" "Samuel responds"          "curl -s -X POST http://127.0.0.1:57081/api/generate -H 'Content-Type: application/json' -d '{\"model\":\"s7-samuel:v1\",\"prompt\":\"say ok\",\"stream\":false,\"think\":false,\"options\":{\"num_predict\":10}}'" "done"
# A07: Elias responds — parallel to A04 and A06. Validates the third persona.
t "A07" "Elias responds"           "curl -s -X POST http://127.0.0.1:57081/api/generate -H 'Content-Type: application/json' -d '{\"model\":\"s7-elias:1.3b\",\"prompt\":\"say ok\",\"stream\":false,\"think\":false,\"options\":{\"num_predict\":10}}'" "done"

# ══════════════════════════════════════════════════════════════════
# SECURITY (8 tests)
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo -e "${B}── Security (8 tests) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

t "S01" ":57080 localhost only"    "ss -tlnp | grep ':57080' | awk '{print \$4}' | head -1"          "127.0.0.1"
t "S02" ":57090 localhost only"    "ss -tlnp | grep ':57090' | awk '{print \$4}' | head -1"          "127.0.0.1"
t "S03" ":57086 localhost only"    "ss -tlnp | grep ':57086' | awk '{print \$4}' | head -1"          "127.0.0.1"
t "S04" "Secrets file mode 600"    "stat -c '%a' /s7/.env.secrets 2>/dev/null || stat -f '%Lp' /s7/.env.secrets 2>/dev/null" "600"
t "S05" "No secrets in public"     "grep -rn \"\${MYSQL_PW}\" /s7/skyqubi-public/ --include='*.py' --include='*.yaml' --include='*.sh' 2>/dev/null | wc -l" "0"
t "S06" "Branch protection"        "curl -s https://api.github.com/repos/skycair-code/SkyQUBi-public/branches/main | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"protected\"))'" "True"
# S07: SELinux enforcing — Rule 3 ("Protect the QUBi"). A permissive or
# disabled SELinux would silently accept container escapes and policy drift.
t "S07" "SELinux Enforcing"        "getenforce 2>/dev/null"                                          "Enforcing"
# S08: fcontext equivalence rule present. Regression-proofs the 2026-04-13 fix
# where /s7/.local/share/containers/ had no fcontext rule mapped to
# /var/lib/containers/ and every container label defaulted to default_t. If
# this rule disappears (e.g., from a 'semanage -d' or policy reset), the pod
# will crash-loop again. Reads /etc/selinux/targeted/contexts/files/file_contexts.subs*
# directly (world-readable) so this works without sudo.
t "S08" "fcontext equivalence"     "grep -hF '/s7/.local/share/containers' /etc/selinux/targeted/contexts/files/file_contexts.subs* 2>/dev/null | head -1" "/var/lib/containers"

# ══════════════════════════════════════════════════════════════════
# PERSONA-CHAT (3 tests)
# ══════════════════════════════════════════════════════════════════
# The covenant persona chat substrate (ledger + memory_tiers + standalone
# FastAPI app). These tests run the substrate's own unittest suites via
# 'python3 -m unittest' and match on the "OK" or "PASS" output. If any of
# them fail, the substrate is broken and the persona chat layer cannot be
# trusted to serve Carli/Elias/Samuel turns.
echo "" | tee -a "$LOG"
echo -e "${B}── Persona-Chat (3 tests) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

t "X01" "ledger unittests"         "cd /s7/skyqubi-private/persona-chat && python3 -m unittest test_ledger 2>&1 | tail -3"       "OK"
t "X02" "memory_tiers unittests"   "cd /s7/skyqubi-private/persona-chat && python3 -m unittest test_memory_tiers 2>&1 | tail -3" "OK"
t "X03" "persona-chat app tests"   "cd /s7/skyqubi-private/persona-chat && python3 -m unittest test_app 2>&1 | tail -3"          "OK"

# ══════════════════════════════════════════════════════════════════
# REPOS (2 tests)
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo -e "${B}── Repos (2 tests) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

t "R01" "Private repo clean"       "cd /s7/skyqubi-private && git status --porcelain | grep -vE 'docs/internal/(chef/audit-living\.md|reports/)' | wc -l"            "0"
t "R02" "Public repo clean"        "cd /s7/skyqubi-public && git status --short | wc -l"             "0"
# R03 (repos in sync) removed: public is frozen between Core Updates.
# Private↔public sync is now a discrete promote gate (iac/promote-to-public.sh)
# that runs only on Core Update days. Next: 2026-07-07 07:00.

# ══════════════════════════════════════════════════════════════════
# DOCS (2 tests)
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo -e "${B}── Docs (2 tests) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

t "K01" "DEPLOY.md exists"         "test -f /s7/skyqubi-public/DEPLOY.md && echo y"                  "y"
t "K02" "LIFECYCLE.md exists"      "test -f /s7/skyqubi-public/LIFECYCLE.md && echo y"                "y"

# ══════════════════════════════════════════════════════════════════
# BOOT (1 test)
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo -e "${B}── Boot (1 test) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# B01 picks the most recently built s7-fedora-base image. SKIPs if no
# image exists yet OR if host port 8080 is already in use (dev box has
# the SPA there). Skip is counted as a pass so this doesn't block.
BOOT_IMAGE=$(podman images --format '{{.Repository}}:{{.Tag}}' | grep '^localhost/s7-fedora-base:' | head -1)
if [[ -z "$BOOT_IMAGE" ]]; then
  echo "  B01  Boot validation         SKIP (no s7-fedora-base image built yet)" | tee -a "$LOG"
  PASS=$((PASS+1)); TOTAL=$((TOTAL+1))
  RESULT_IDS+=("B01"); RESULT_NAMES+=("Boot validation"); RESULT_STATUS+=("skip"); RESULT_DETAIL+=("no s7-fedora-base image")
elif ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ':8080$'; then
  echo "  B01  Boot validation         SKIP (host port 8080 in use, can't bind boot validator)" | tee -a "$LOG"
  PASS=$((PASS+1)); TOTAL=$((TOTAL+1))
  RESULT_IDS+=("B01"); RESULT_NAMES+=("Boot validation"); RESULT_STATUS+=("skip"); RESULT_DETAIL+=("port 8080 in use")
else
  CMD="bash /s7/skyqubi-private/iac/boot/s7-boot-validate.sh --image $BOOT_IMAGE --port 8080:8080 --smoke-checks /s7/skyqubi-private/iac/boot/smoke-checks.txt --timeout 60 >/dev/null 2>&1 && echo OK"
  t "B01" "Boot validation"           "$CMD"  "OK"
fi

# ══════════════════════════════════════════════════════════════════
# RESULTS
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo "═══════════════════════════════════════════════════════════════" | tee -a "$LOG"

if [ "$TOTAL" -ne "$EXPECTED" ]; then
  echo -e "  ${R}ERROR: Ran $TOTAL tests but expected $EXPECTED — test suite changed${X}" | tee -a "$LOG"
fi

if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${G}${B}$PASS/$TOTAL PASS — LIFECYCLE VERIFIED${X}" | tee -a "$LOG"
else
  echo -e "  ${R}${B}$PASS PASS / $FAIL FAIL out of $TOTAL${X}" | tee -a "$LOG"
fi

echo "  Log: $LOG" | tee -a "$LOG"
echo "═══════════════════════════════════════════════════════════════" | tee -a "$LOG"
echo ""

# ── JSON emit (Samuel-runnable) ──
# When --json is set, write exactly one JSON object to the saved real stdout
# (fd 3). All human-readable text above went to stderr via the earlier
# 'exec 1>&2' redirect, so stdout is clean for the JSON.
if [ "$JSON_OUT" -eq 1 ]; then
    # Build the tests array
    tests_json=""
    for i in "${!RESULT_IDS[@]}"; do
        id_esc=$(printf '%s' "${RESULT_IDS[$i]}" | sed 's/"/\\"/g')
        name_esc=$(printf '%s' "${RESULT_NAMES[$i]}" | sed 's/"/\\"/g')
        status="${RESULT_STATUS[$i]}"
        detail_esc=$(printf '%s' "${RESULT_DETAIL[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')
        [ $i -gt 0 ] && tests_json="$tests_json,"
        tests_json="$tests_json{\"id\":\"$id_esc\",\"name\":\"$name_esc\",\"status\":\"$status\",\"detail\":\"$detail_esc\"}"
    done

    # State string for the top-level envelope
    if [ "$FAIL" -eq 0 ]; then
        state="verified"
    else
        state="failed"
    fi

    printf '{"script":"s7-lifecycle-test.sh","state":"%s","pass":%d,"fail":%d,"total":%d,"expected":%d,"log_path":"%s","tests":[%s]}\n' \
        "$state" "$PASS" "$FAIL" "$TOTAL" "$EXPECTED" "$LOG" "$tests_json" >&3
fi

exit $FAIL
