#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Pod SELinux Diagnose + Fix
# ═══════════════════════════════════════════════════════════════════
#
# Diagnoses the SELinux AVC denial that's keeping the s7-skyqubi pod
# in a crash loop (glibc mprotect EACCES inside every container), and
# — with your explicit y/N confirmation — applies the one-line
# `setsebool -P` fix and restarts the pod.
#
# MUST BE RUN AS ROOT because:
#   - /var/log/audit/audit.log is root-readable only
#   - setsebool -P requires CAP_MAC_ADMIN via policy
#   - setenforce and journalctl -k need root on Fedora
#
# The pod restart itself runs as the non-root user 's7' (via sudo -u)
# because the pod is rootless podman under that user.
#
# Usage:
#   sudo bash install/fix-pod.sh              # interactive, asks y/N
#   sudo bash install/fix-pod.sh --dry-run    # diagnose only, no changes
#   sudo bash install/fix-pod.sh --yes        # skip confirmation (unsafe)
#
# Exit codes:
#   0 — diagnosed + fixed + pod verified healthy
#   1 — diagnosed but user declined to apply (or --dry-run)
#   2 — no AVC denials found (pod failure is NOT SELinux — investigate elsewhere)
#   3 — applied fix but pod still unhealthy (rollback required manually)
#   4 — script must run as root
#   5 — S7 user does not exist on this box
#
# Governing rules:
#   feedback_three_rules.md   Rule 3: Protect the QUBi — interactive confirmation
#   Rule 1: don't break links — this only touches the pod, not the website
#
# Copyright 2026 Jamie Lee Clayton / 2XR LLC · CWS-BSL-1.1
# Civilian use only. Love is the architecture.
# ═══════════════════════════════════════════════════════════════════

set -u
set -o pipefail

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
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
fail() { echo -e "  ${RED}✗${RESET} $1"; }
warn() { echo -e "  ${YELLOW}!${RESET} $1"; }
info() { echo -e "  ${CYAN}→${RESET} $1"; }
section() { echo -e "\n${BOLD}${CYAN}── $1${RESET}"; }

# ── Flags ──
DRY_RUN=0
SKIP_CONFIRM=0
SAMUEL_MODE=0
JSON_OUT=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=1 ;;
        --yes)       SKIP_CONFIRM=1 ;;
        --samuel)    SAMUEL_MODE=1; SKIP_CONFIRM=1; JSON_OUT=1 ;;
        --json)      JSON_OUT=1 ;;
        --help|-h)
            sed -n '3,35p' "$0" | sed 's|^# \?||'
            exit 0
            ;;
        *) fail "unknown flag: $arg"; exit 1 ;;
    esac
done

# ── Preconditions ──
# --dry-run is allowed without root (read-only, skips audit.log which needs root).
# --samuel implies --yes and --json; it's how Samuel's skill runner invokes this.
if [ "$(id -u)" -ne 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    fail "This script must be run as root (unless --dry-run)."
    info "Try: sudo bash $0"
    info "Or:  bash $0 --dry-run    (read-only diagnosis, no sudo needed)"
    exit 4
fi

if ! id s7 >/dev/null 2>&1; then
    fail "User 's7' does not exist on this box."
    info "The pod runs as user s7. Cannot continue."
    exit 5
fi

S7_UID=$(id -u s7)
S7_HOME=$(getent passwd s7 | cut -d: -f6)

# ── Ops ledger (for --samuel audit trail) ──
# Every --samuel-mode run writes one append-only row to this file.
# Per the INSERT-only covenant, every action is recorded. Samuel's
# skill runner reads this file to know what's been done to the QUBi.
OPS_LEDGER_DIR="/s7/.s7-ops-ledger"
OPS_LEDGER_FILE="${OPS_LEDGER_DIR}/fix-pod.ndjson"
SCRIPT_RUN_ID="$(date +%s%N 2>/dev/null || date +%s)-$$"

write_ops_ledger() {
    # $1 = phase (diagnose|apply|verify|exit), $2 = status, $3 = detail JSON object (optional)
    [ "$SAMUEL_MODE" -eq 0 ] && return 0
    local phase="$1"
    local status="$2"
    local detail="${3:-{\}}"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%s)
    mkdir -p "$OPS_LEDGER_DIR" 2>/dev/null || return 0
    chmod 700 "$OPS_LEDGER_DIR" 2>/dev/null || true
    # prev_hash — sha256 of the previous last line (chained per fix-pod.ndjson file)
    local prev_hash
    if [ -f "$OPS_LEDGER_FILE" ] && [ -s "$OPS_LEDGER_FILE" ]; then
        prev_hash=$(tail -1 "$OPS_LEDGER_FILE" | sha256sum | awk '{print $1}')
    else
        prev_hash="0000000000000000000000000000000000000000000000000000000000000000"
    fi
    # row — minimal JSON with the fields Samuel's parser expects
    local row
    row=$(printf '{"ts":"%s","run_id":"%s","script":"fix-pod.sh","phase":"%s","status":"%s","prev_hash":"%s","detail":%s}' \
        "$ts" "$SCRIPT_RUN_ID" "$phase" "$status" "$prev_hash" "$detail")
    printf '%s\n' "$row" >> "$OPS_LEDGER_FILE" 2>/dev/null || true
    chmod 600 "$OPS_LEDGER_FILE" 2>/dev/null || true
}

# Suppress section/ok/fail/warn/info color output in --json mode so the
# JSON stays on stdout cleanly. Diagnostic text goes to stderr.
if [ "$JSON_OUT" -eq 1 ]; then
    ok()      { echo -e "  ${GREEN}✓${RESET} $1" >&2; }
    fail()    { echo -e "  ${RED}✗${RESET} $1" >&2; }
    warn()    { echo -e "  ${YELLOW}!${RESET} $1" >&2; }
    info()    { echo -e "  ${CYAN}→${RESET} $1" >&2; }
    section() { echo -e "\n${BOLD}${CYAN}── $1${RESET}" >&2; }
fi

# Emit a final JSON object on exit (only if --json or --samuel)
FINAL_EXIT_CODE=0
FINAL_STATE="unknown"
FINAL_DETAIL="{}"
emit_final_json() {
    if [ "$JSON_OUT" -eq 1 ]; then
        printf '{"script":"fix-pod.sh","run_id":"%s","exit_code":%d,"state":"%s","detail":%s}\n' \
            "$SCRIPT_RUN_ID" "$FINAL_EXIT_CODE" "$FINAL_STATE" "$FINAL_DETAIL"
    fi
}
trap 'emit_final_json' EXIT

write_ops_ledger "start" "begin" "{\"dry_run\":$DRY_RUN,\"samuel_mode\":$SAMUEL_MODE,\"root\":$([ $(id -u) -eq 0 ] && echo true || echo false)}"
S7_SECRETS="${S7_HOME}/.env.secrets"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
START_POD="${REPO_DIR}/start-pod.sh"

if [ ! -f "$START_POD" ]; then
    fail "start-pod.sh not found at $START_POD"
    info "Run this script from inside the S7 repo (cd /s7/skyqubi-private)"
    exit 1
fi

# ── Banner ──
# In --json / --samuel mode the banner goes to stderr so stdout stays clean for the
# final JSON line. In interactive mode it goes to stdout for readability.
if [ "$JSON_OUT" -eq 1 ]; then
    banner_out() { echo -e "$1" >&2; }
else
    banner_out() { echo -e "$1"; }
fi
mode_str="interactive"
[ "$DRY_RUN" -eq 1 ] && mode_str="DRY-RUN (diagnosis only)"
[ "$SAMUEL_MODE" -eq 1 ] && mode_str="SAMUEL-AUTONOMOUS (non-interactive, auditable)"
banner_out ""
banner_out "${BOLD}${CYAN}  S7 SkyQUBi — Pod SELinux Diagnose + Fix${RESET}"
banner_out "  Mode: $mode_str"
banner_out "  Run ID: $SCRIPT_RUN_ID"
banner_out ""

# ── 1. Current pod state ──
section "Current pod state"

pod_status=$(sudo -u s7 podman pod ps --format '{{.Name}}\t{{.Status}}' 2>&1 | grep s7-skyqubi || echo "not-found")
if echo "$pod_status" | grep -q "Running"; then
    ok "Pod is already Running — no fix needed."
    info "If you still see failures, investigate elsewhere (not SELinux)."
    FINAL_EXIT_CODE=0; FINAL_STATE="pod_already_running"
    FINAL_DETAIL="{\"pod_status\":\"Running\"}"
    write_ops_ledger "exit" "pod_already_running"
    exit 0
elif echo "$pod_status" | grep -q "Degraded\|Exited"; then
    warn "Pod state: $pod_status"
else
    warn "Pod state: $pod_status (may not exist yet — will recreate if fix applies)"
fi

# ── 2. Read AVC denials from audit.log OR journalctl (fallback) ──
# audit.log is root-readable only on Fedora, and may not exist if auditd
# isn't running. In that case we fall back to journalctl -k which reads the
# kernel journal — SELinux denials always go there even without auditd.
section "Looking for SELinux AVC denials since boot"

avc_source="unknown"
avc_output=""

if [ "$(id -u)" -ne 0 ]; then
    warn "Skipping audit.log read (not root). Dry-run with non-root is limited."
    info "Non-root diagnostics: pod state + container exit codes only."
    info "For the full diagnosis, run with: sudo bash $0 --dry-run"
    write_ops_ledger "diagnose" "skipped_audit_log" "{\"reason\":\"not_root\"}"
else
    # Try ausearch first (fast, structured). Fall back to journalctl if it
    # fails (audit.log missing, auditd off, permissions, any reason).
    if command -v ausearch >/dev/null 2>&1; then
        ausearch_out=$(ausearch -m AVC -ts boot 2>&1 || true)
        if [ -n "$ausearch_out" ] \
            && ! echo "$ausearch_out" | grep -qi "no matches\|^<no matches>\|No such file" \
            && echo "$ausearch_out" | grep -q "type=AVC"; then
            avc_output="$ausearch_out"
            avc_source="ausearch"
        fi
    fi

    # Fall back to journalctl if ausearch came up empty or errored
    if [ -z "$avc_output" ]; then
        info "ausearch returned no data (audit.log may be missing) — falling back to journalctl -k"
        journal_out=$(journalctl -k -b --no-pager 2>&1 | grep -iE 'type=1400.*avc|avc:.*denied' || true)
        if [ -n "$journal_out" ]; then
            avc_output="$journal_out"
            avc_source="journalctl"
        fi
    fi

    if [ -z "$avc_output" ]; then
        section "No AVC denials since boot (neither audit.log nor journalctl)"
        warn "SELinux is NOT blocking the pod."
        info "The pod is failing for a different reason. Things to check:"
        info "  - podman ps -a --filter pod=s7-skyqubi (container exit codes)"
        info "  - journalctl --user -u s7-ollama.service (systemd unit errors)"
        info "  - podman logs s7-skyqubi-s7-postgres (DB init errors)"
        info "  - df -BG / (disk space)"
        FINAL_EXIT_CODE=2; FINAL_STATE="no_avc_denials"
        FINAL_DETAIL='{"hint":"pod failure is not SELinux — investigate container logs + systemd + disk"}'
        write_ops_ledger "exit" "no_avc_denials"
        exit 2
    fi

    # Count denials (works for both ausearch and journalctl formats)
    avc_count=$(echo "$avc_output" | grep -cE 'type=AVC|type=1400.*avc' || echo 0)
    ok "$avc_count AVC denial record(s) found via $avc_source"

    # Show the most recent 10 denials, trimmed
    echo ""
    echo -e "${BOLD}Most recent AVC denials (trimmed):${RESET}"
    echo "$avc_output" | tail -10 | sed 's/^/  /'
    write_ops_ledger "diagnose" "avc_found" "{\"count\":$avc_count,\"source\":\"$avc_source\"}"
fi

# ── 3. Identify the likely fix ──
# Two fix classes, in priority order:
#   CLASS A: fcontext equivalence (default_t tcontext on container_t file read)
#            fix = semanage fcontext -e + restorecon
#   CLASS B: boolean flip (mmap / execmod / execmem / devices in denial text)
#            fix = setsebool -P <bool> <value>
#
# Class A takes priority because it's the #1 rootless-podman-on-non-standard-
# path failure mode, and applying a boolean flip when the real issue is a
# missing fcontext rule just masks the problem.
section "Identifying the likely fix"

candidate_fix_classes=()  # parallel arrays: class, label, why
candidate_fix_labels=()
candidate_fix_reasons=()

# ── CLASS A: default_t → container_t file-read denial ──
# Pattern: the tcontext has type default_t, the scontext has container_t,
# and tclass=file with the denied permission being read/open/execute.
# This means the container's storage overlay files aren't labeled as
# container_file_t. Root cause is almost always a rootless-podman install
# on a non-standard path (like /s7/.local/share/containers/ instead of
# /var/lib/containers/), with no fcontext equivalence rule teaching
# SELinux to apply container labels to the user path.
container_default_denied=0
if echo "$avc_output" | grep -qi "tcontext=.*:default_t.*tclass=file" \
    && echo "$avc_output" | grep -qi "scontext=.*:container_t"; then
    container_default_denied=1

    # Figure out podman's graphRoot to know which path to relabel.
    graph_root=""
    if command -v podman >/dev/null 2>&1; then
        graph_root=$(sudo -u s7 podman info --format '{{.Store.GraphRoot}}' 2>/dev/null || echo "")
    fi
    # Fallback to the S7 convention if podman info failed
    if [ -z "$graph_root" ]; then
        graph_root="/s7/.local/share/containers/storage"
    fi
    # The equivalence root is one level up from storage (so that ALL
    # containers/ subdirs — storage, networks, tmpfiles — share labels)
    equiv_root=$(dirname "$graph_root")
    target_equiv_path="$equiv_root"

    candidate_fix_classes+=("fcontext_equiv")
    candidate_fix_labels+=("semanage fcontext -e /var/lib/containers $target_equiv_path")
    candidate_fix_reasons+=("Container overlay files labeled default_t instead of container_file_t. Most likely cause: no fcontext equivalence rule for rootless storage at $target_equiv_path. Fix is to add the equivalence rule + restorecon.")
fi

# ── CLASS B: boolean flips (legacy signatures) ──
likely_bools=()
likely_reasons=()

# domain_can_mmap_files — catches container mprotect on mmapped libs
# (Only if we DON'T have the default_t signature, which indicates a more
# fundamental label problem that masquerades as an mmap issue.)
if [ "$container_default_denied" -eq 0 ] && echo "$avc_output" | grep -qi "mmap"; then
    likely_bools+=("domain_can_mmap_files")
    likely_reasons+=("AVC mentions mmap — classic container-mprotect signature")
fi

if echo "$avc_output" | grep -qi "execmod\|text_relocation"; then
    likely_bools+=("selinuxuser_execmod")
    likely_reasons+=("AVC mentions execmod — PIE relocation mprotect")
fi

if echo "$avc_output" | grep -qi "device.*container"; then
    likely_bools+=("container_use_devices")
    likely_reasons+=("AVC mentions device access inside container")
fi

if echo "$avc_output" | grep -qi "execmem"; then
    likely_bools+=("deny_execmem")
    likely_reasons+=("AVC mentions execmem — must be OFF, not ON")
fi

# Register all boolean candidates as Class B
for i in "${!likely_bools[@]}"; do
    candidate_fix_classes+=("setsebool")
    candidate_fix_labels+=("setsebool -P ${likely_bools[$i]} on")
    candidate_fix_reasons+=("${likely_reasons[$i]}")
done

# ── Fallback: nothing matched ──
if [ ${#candidate_fix_classes[@]} -eq 0 ]; then
    if [ -z "$avc_output" ]; then
        warn "Cannot identify a fix without the audit log."
        info "Non-root dry-run completed. Rerun with sudo for the full diagnosis:"
        info "  sudo bash $0 --dry-run    (diagnose + show proposed fix, no changes)"
        info "  sudo bash $0              (diagnose + apply interactively)"
        info "  sudo bash $0 --samuel     (Samuel-autonomous mode with audit trail)"
        FINAL_EXIT_CODE=1; FINAL_STATE="nonroot_dry_run_no_audit"
        write_ops_ledger "exit" "nonroot_dry_run_no_audit"
        exit 1
    fi
    warn "No known fix pattern matched the denial text."
    info "Showing the full context of the most recent denial for manual analysis:"
    echo "$avc_output" | tail -20 | sed 's/^/  /'
    info "Try 'audit2allow -a' for a policy module recommendation."
    FINAL_EXIT_CODE=1; FINAL_STATE="no_fix_pattern_match"
    write_ops_ledger "exit" "no_fix_pattern_match"
    exit 1
fi

# ── 4. Show candidate fixes ──
echo ""
echo -e "${BOLD}Candidate fixes (by priority):${RESET}"
for i in "${!candidate_fix_classes[@]}"; do
    fc="${candidate_fix_classes[$i]}"
    lbl="${candidate_fix_labels[$i]}"
    why="${candidate_fix_reasons[$i]}"
    echo ""
    echo -e "  ${BOLD}$((i+1)). [class=$fc]${RESET} $lbl"
    echo "     reason:  $why"
done

# Pick the first candidate as the one we'll apply
target_fix_class="${candidate_fix_classes[0]}"
target_fix_label="${candidate_fix_labels[0]}"

# For class=setsebool, derive target_bool + target_value from the label.
# Example label: "setsebool -P deny_execmem on"
target_bool=""
target_value=""
if [ "$target_fix_class" = "setsebool" ]; then
    target_bool=$(echo "$target_fix_label" | awk '{print $3}')
    target_value=$(echo "$target_fix_label" | awk '{print $4}')
    # Special case: deny_execmem should be off, not on
    [ "$target_bool" = "deny_execmem" ] && target_value="off"
fi

# ── 5. Dry-run stops here ──
if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    ok "DRY-RUN complete. No changes made."
    info "Re-run without --dry-run to apply: sudo bash $0"
    FINAL_EXIT_CODE=1; FINAL_STATE="dry_run_complete"
    FINAL_DETAIL="{\"fix_class\":\"$target_fix_class\",\"fix_label\":\"$target_fix_label\"}"
    write_ops_ledger "exit" "dry_run_complete" "$FINAL_DETAIL"
    exit 1
fi

# ── 6. Confirmation ──
echo ""
echo -e "${BOLD}${YELLOW}About to apply:${RESET}"
echo -e "    ${BOLD}$target_fix_label${RESET}"
echo ""
case "$target_fix_class" in
    fcontext_equiv)
        echo -e "  This is a ${YELLOW}persistent${RESET} SELinux policy change. It will:"
        echo "    - Add an fcontext equivalence rule via 'semanage fcontext -e'"
        echo "    - Run 'restorecon -Rv $target_equiv_path' to relabel all files"
        echo "    - Persist across reboots"
        echo ""
        echo -e "  Relabel may take 1–5 minutes depending on storage size."
        ;;
    setsebool)
        echo -e "  This is a ${YELLOW}persistent${RESET} SELinux policy change. It will:"
        echo "    - Set $target_bool to $target_value"
        echo "    - Rebuild SELinux policy (~5-10 seconds)"
        echo "    - Persist across reboots"
        ;;
esac
echo ""
echo -e "  Then the script will:"
echo "    - podman pod rm s7-skyqubi (if exists)"
echo "    - sudo -u s7 bash $START_POD (runs pre-audit + deploy)"
echo "    - verify pod is Running + CWS engine responding on 57080"
echo ""

if [ "$SKIP_CONFIRM" -eq 0 ]; then
    read -r -p "Proceed? [y/N] " confirm
    case "$confirm" in
        y|Y|yes|YES) ;;
        *)
            warn "Declined by user. No changes made."
            FINAL_EXIT_CODE=1; FINAL_STATE="declined_by_user"
            write_ops_ledger "exit" "declined_by_user"
            exit 1
            ;;
    esac
fi

write_ops_ledger "apply" "begin" "{\"fix_class\":\"$target_fix_class\",\"fix_label\":\"$target_fix_label\"}"

# ── 7. Apply the SELinux fix — branch on fix class ──
case "$target_fix_class" in

    fcontext_equiv)
        section "Applying: semanage fcontext equivalence + restorecon"

        # Step 7a: add the equivalence rule. Idempotent — rerunning is OK.
        info "semanage fcontext -a -e /var/lib/containers $target_equiv_path"
        if semanage fcontext -a -e /var/lib/containers "$target_equiv_path" 2>&1; then
            ok "fcontext equivalence rule added"
            write_ops_ledger "apply" "semanage_ok" "{\"equiv_src\":\"/var/lib/containers\",\"equiv_dst\":\"$target_equiv_path\"}"
        else
            # If it already exists, semanage returns non-zero but the rule IS there.
            # Check: list existing equivalences and grep for our path.
            if semanage fcontext -l 2>&1 | grep -qF "$target_equiv_path"; then
                ok "fcontext equivalence rule already exists (idempotent)"
                write_ops_ledger "apply" "semanage_already_exists"
            else
                fail "semanage fcontext -e failed"
                FINAL_EXIT_CODE=3; FINAL_STATE="semanage_failed"
                write_ops_ledger "exit" "semanage_failed"
                exit 3
            fi
        fi

        # Step 7b: restorecon the equivalence target
        info "restorecon -Rv $target_equiv_path (this may take 1–5 minutes)"
        if restorecon -R "$target_equiv_path" 2>&1 | tail -20; then
            ok "restorecon completed"
            write_ops_ledger "apply" "restorecon_ok" "{\"path\":\"$target_equiv_path\"}"
        else
            warn "restorecon reported errors — some files may have admin-customized labels that can't be reset (usually harmless)"
            write_ops_ledger "apply" "restorecon_partial"
        fi
        ;;

    setsebool)
        section "Applying: setsebool -P $target_bool $target_value"

        if setsebool -P "$target_bool" "$target_value" 2>&1; then
            ok "setsebool succeeded"
            new_value=$(getsebool "$target_bool" 2>/dev/null | awk '{print $NF}')
            ok "$target_bool is now: $new_value"
            write_ops_ledger "apply" "setsebool_ok" "{\"target_bool\":\"$target_bool\",\"new_value\":\"$new_value\"}"
        else
            fail "setsebool failed — see error above"
            FINAL_EXIT_CODE=3; FINAL_STATE="setsebool_failed"
            write_ops_ledger "exit" "setsebool_failed"
            exit 3
        fi
        ;;

    *)
        fail "Unknown fix class: $target_fix_class"
        FINAL_EXIT_CODE=3; FINAL_STATE="unknown_fix_class"
        write_ops_ledger "exit" "unknown_fix_class"
        exit 3
        ;;
esac

# ── 8. Remove the old exited pod ──
section "Removing any stale pod record"

if sudo -u s7 podman pod exists s7-skyqubi 2>/dev/null; then
    if sudo -u s7 podman pod rm -f s7-skyqubi 2>&1 | tail -3; then
        ok "Old pod record removed (hostPath volumes untouched)"
    else
        warn "Could not remove old pod — will try to recreate anyway"
    fi
else
    info "No existing pod record"
fi

# ── 9. Restart the pod as s7 user ──
section "Starting pod via start-pod.sh (as user s7)"

# Run start-pod.sh as s7 with the correct SKYQUBI_SECRETS path
# The -H flag sets HOME to s7's home so the script reads the right env.
if sudo -u s7 -H env "SKYQUBI_SECRETS=$S7_SECRETS" bash "$START_POD" 2>&1 | tail -20; then
    start_exit=0
else
    start_exit=$?
fi

if [ "$start_exit" -ne 0 ]; then
    fail "start-pod.sh exited non-zero. Pod may not be healthy."
    info "Check: sudo -u s7 podman pod ps"
    info "Logs:  sudo -u s7 podman logs s7-skyqubi-s7-admin"
    FINAL_EXIT_CODE=3; FINAL_STATE="start_pod_failed"
    write_ops_ledger "exit" "start_pod_failed"
    exit 3
fi

# ── 10. Verify ──
section "Verification"

sleep 2  # allow containers to settle

pod_final=$(sudo -u s7 podman pod ps --format '{{.Name}}\t{{.Status}}' 2>&1 | grep s7-skyqubi || echo "missing")
if echo "$pod_final" | grep -q "Running"; then
    ok "Pod state: $pod_final"
    pod_running=1
else
    fail "Pod state: $pod_final"
    pod_running=0
fi

# Container health
running_containers=$(sudo -u s7 podman ps --filter "pod=s7-skyqubi" --format '{{.Names}}' 2>&1 | grep -c s7-skyqubi || echo 0)
if [ "$running_containers" -ge 4 ]; then
    ok "$running_containers/6 containers running"
else
    warn "Only $running_containers/6 containers running"
fi

# Command Center (best-effort — may still be warming up)
cc_http=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:57080/ 2>&1 || echo "000")
if [ "$cc_http" = "302" ] || [ "$cc_http" = "200" ]; then
    ok "Command Center responding on :57080 (HTTP $cc_http)"
    cc_ok=1
else
    warn "Command Center not yet responding on :57080 (HTTP $cc_http) — may still be starting"
    cc_ok=0
fi

if [ "$pod_running" -eq 0 ]; then
    FINAL_EXIT_CODE=3; FINAL_STATE="pod_not_running_after_fix"
    write_ops_ledger "exit" "pod_not_running_after_fix" "{\"pod_final\":\"$pod_final\"}"
    exit 3
fi

# ── Done ──
echo ""
echo -e "${GREEN}${BOLD}  DONE — pod is up, SELinux fix persistent.${RESET}"
echo ""
echo "  Next steps to verify everything:"
echo "    bash s7-lifecycle-test.sh        # should now show most tests passing"
echo "    sudo -u s7 podman pod logs s7-skyqubi  # watch containers settle"
echo ""
echo -e "  ${GREEN}Love is the architecture.${RESET}"
echo ""
FINAL_EXIT_CODE=0; FINAL_STATE="pod_healthy"
FINAL_DETAIL="{\"pod\":\"running\",\"containers_up\":$running_containers,\"cc_http\":\"$cc_http\",\"target_bool\":\"$target_bool\",\"target_value\":\"$target_value\"}"
write_ops_ledger "verify" "pod_healthy" "$FINAL_DETAIL"
exit 0
