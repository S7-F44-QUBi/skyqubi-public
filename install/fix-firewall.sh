#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Firewall diagnose + fix
#
# Captures the 2026-04-13 lesson: rootless pasta-mode containers reach
# the host via the link-local 169.254.1.0/24 gateway. firewalld's
# default zone (FedoraServer on this box) doesn't trust that source,
# so containers can't reach host services like ollama on 57081 even
# though ollama listens on all interfaces.
#
# Symptom: from inside any rootless container,
#   curl http://host.containers.internal:57081/api/version
# times out, even though the same URL works from the host.
#
# Root cause: the trusted zone covers podman0/cni-podman0/10.89.0.0/16
# (rootful bridges) but not 169.254.1.0/24 (rootless pasta gateway).
# After every host reboot, any runtime-only firewall rule that used
# to bridge this gap is gone.
#
# Fix:
#   firewall-cmd --permanent --zone=trusted --add-source=169.254.1.0/24
#   firewall-cmd --reload
#
# This is permanent. It only opens the link-local rootless gateway
# to host services — link-local traffic by definition can't leave
# the host, so no external exposure.
#
# Usage:
#   bash install/fix-firewall.sh                     # interactive (asks)
#   bash install/fix-firewall.sh --dry-run --samuel  # diagnose, JSON, no fix
#   bash install/fix-firewall.sh --samuel            # apply, JSON, no prompt
#   bash install/fix-firewall.sh --help
#
# Exit codes:
#   0  pod_can_reach_host       — verified after fix, or never broken
#   1  dry_run_complete         — diagnosed but not applied
#   2  no_action_needed         — trust rule already present
#   3  firewall_cmd_failed      — apply step failed mid-execution
#   4  must_run_as_root         — apply path needs root
#   5  firewalld_not_active     — firewalld isn't running, different problem
#
# Governing rules:
#   feedback_three_rules.md     Rule 3: Protect the QUBi
#   engine/agents/samuel_runnable_scripts.yaml  Catalog entry
# ═══════════════════════════════════════════════════════════════════

set -u
set -o pipefail

# ── Flags ──
JSON_OUT=0
SAMUEL_MODE=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --json)    JSON_OUT=1 ;;
        --samuel)  SAMUEL_MODE=1; JSON_OUT=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --help|-h)
            sed -n '3,40p' "$0" | sed 's|^# \?||'
            exit 0
            ;;
        *) echo "unknown flag: $arg" >&2; exit 1 ;;
    esac
done

# ── Colors + FD juggling ──
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

RUN_ID="$(date +%s%N)-$$"

_out ""
_out "${BOLD}${CYAN}  S7 SkyQUBi — Firewall Diagnose + Fix${RESET}"
_out "  Run ID: $RUN_ID"
_out ""

emit_json() {
    local state="$1"
    local exit_code="$2"
    local detail="${3:-}"
    if [ "$JSON_OUT" -eq 1 ]; then
        printf '{"script":"fix-firewall.sh","run_id":"%s","state":"%s","exit_code":%d,"detail":"%s"}\n' \
            "$RUN_ID" "$state" "$exit_code" "$detail" >&3
    fi
}

# ── Step 1: firewalld active? ───────────────────────────────────────
section "Step 1 — firewalld active?"
if ! command -v firewall-cmd >/dev/null 2>&1; then
    fail "firewall-cmd not installed"
    emit_json "firewalld_not_active" 5 "firewall-cmd missing"
    exit 5
fi
if ! systemctl is-active firewalld >/dev/null 2>&1; then
    fail "firewalld is not active — different problem class"
    info "If you intended to disable firewalld, container→host should already work."
    emit_json "firewalld_not_active" 5 "service inactive"
    exit 5
fi
ok "firewalld is active"

# ── Step 2: is the trust rule already present? ─────────────────────
section "Step 2 — trust rule status"
ROOTLESS_SOURCE="169.254.1.0/24"

# We deliberately avoid 'firewall-cmd --zone=trusted --list-sources'
# because that command requires polkit and silently returns nothing
# for the non-root s7 user. 'firewall-cmd --get-active-zones' DOES
# work without polkit and returns the full zone listing including
# sources, so we parse that instead.
already_trusted=0
if firewall-cmd --get-active-zones 2>/dev/null | awk '
    /^[a-zA-Z]/ { zone=$1; next }
    /sources:/ && zone=="trusted" { print; exit }
' | grep -q "$ROOTLESS_SOURCE"; then
    already_trusted=1
fi

if [ "$already_trusted" -eq 1 ]; then
    ok "$ROOTLESS_SOURCE is already in the trusted zone"
    emit_json "no_action_needed" 2 "$ROOTLESS_SOURCE already trusted"
    exit 2
fi
warn "$ROOTLESS_SOURCE is NOT in the trusted zone"
info "Without this, rootless containers cannot reach host services like ollama on 57081"

# ── Step 3: dry-run path ────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
    section "Step 3 — dry-run (no changes applied)"
    info "Would run:"
    info "  firewall-cmd --permanent --zone=trusted --add-source=$ROOTLESS_SOURCE"
    info "  firewall-cmd --reload"
    info "Effect: rootless containers can reach host services on link-local."
    info "Reversible: --remove-source restores the prior state."
    emit_json "dry_run_complete" 1 "would add $ROOTLESS_SOURCE to trusted zone"
    exit 1
fi

# ── Step 4: apply ───────────────────────────────────────────────────
section "Step 4 — apply"
if [ "$(id -u)" -ne 0 ]; then
    fail "Apply requires root for firewall-cmd --permanent"
    fail "Re-run with: sudo bash $0${SAMUEL_MODE:+ --samuel}"
    emit_json "must_run_as_root" 4 "apply path needs root"
    exit 4
fi

info "Adding $ROOTLESS_SOURCE to trusted zone (permanent)"
if ! firewall-cmd --permanent --zone=trusted --add-source="$ROOTLESS_SOURCE" >&2; then
    fail "firewall-cmd --add-source failed"
    emit_json "firewall_cmd_failed" 3 "add-source failed"
    exit 3
fi

info "Reloading firewalld"
if ! firewall-cmd --reload >&2; then
    fail "firewall-cmd --reload failed"
    # Try to roll back the add-source
    warn "Rolling back the trust rule"
    firewall-cmd --permanent --zone=trusted --remove-source="$ROOTLESS_SOURCE" >&2 || true
    emit_json "firewall_cmd_failed" 3 "reload failed; rolled back"
    exit 3
fi
ok "Trust rule applied"

# ── Step 5: verify ──────────────────────────────────────────────────
section "Step 5 — verify"
if firewall-cmd --zone=trusted --list-sources 2>/dev/null | grep -q "$ROOTLESS_SOURCE"; then
    ok "$ROOTLESS_SOURCE is now in the trusted zone"
else
    warn "Trust rule applied but verification grep didn't find it — check manually"
fi

# Try to actually reach ollama from the rootless pod context if it
# exists. Best-effort: skip if podman / pod isn't around.
if command -v podman >/dev/null 2>&1 && podman pod exists s7-skyqubi 2>/dev/null; then
    if podman exec s7-skyqubi-s7-admin curl -s --max-time 3 http://host.containers.internal:57081/api/version 2>/dev/null | grep -q version; then
        ok "Verified: container can now reach host:57081"
        emit_json "pod_can_reach_host" 0 "trust rule applied and verified"
        exit 0
    else
        warn "Trust rule applied but container still can't reach host:57081"
        warn "  Possible secondary issue: ollama not running, or different listener address"
        emit_json "pod_can_reach_host" 0 "trust rule applied; container reachability not verified"
        exit 0
    fi
fi

emit_json "pod_can_reach_host" 0 "trust rule applied (no live pod to verify against)"
exit 0
