#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Pre-flight checker
# ═══════════════════════════════════════════════════════════════════
#
# This script runs the same diagnostics as start-pod.sh's Phase 1
# pre-audit BUT without requiring .env.secrets to exist. It's safe
# to run on a fresh F44 box before committing to `sudo install.sh`.
#
# Exit codes:
#   0 — ready to install
#   1 — hard blockers (install will fail)
#   2 — warnings only (install may proceed but some features degraded)
#
# Usage:
#   bash install/preflight.sh           # full check
#   bash install/preflight.sh --quick   # only the hardware/packages pass
#   bash install/preflight.sh --json    # machine-readable output
#
# Per the 2026-04-13 finish-line plan, Phase A audit finding F7:
# the existing start-pod.sh pre-audit is the strongest diagnostic in
# the repo but requires .env.secrets. This script unlocks it for the
# fresh-box case.
#
# Copyright 2026 Jamie Lee Clayton / 2XR LLC · CWS-BSL-1.1
# Civilian use only. Love is the architecture.
# ═══════════════════════════════════════════════════════════════════

set -u
set -o pipefail

# ── Colors ──────────────────────────────────────────────────────────
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

_out_target() {
    # In --json mode, all human-readable diagnostics go to stderr so stdout
    # stays clean for the final JSON object.
    if [ "${JSON:-0}" -eq 1 ]; then
        echo -e "$1" >&2
    else
        echo -e "$1"
    fi
}
ok()      { _out_target "  ${GREEN}✓${RESET} $1"; }
fail()    { _out_target "  ${RED}✗${RESET} $1"; }
warn()    { _out_target "  ${YELLOW}!${RESET} $1"; }
info()    { _out_target "  ${CYAN}→${RESET} $1"; }
section() { _out_target "\n${BOLD}${CYAN}── $1${RESET}"; }

# ── Flags ───────────────────────────────────────────────────────────
QUICK=0
JSON=0
for arg in "$@"; do
    case "$arg" in
        --quick) QUICK=1 ;;
        --json)  JSON=1 ;;
        --help|-h)
            sed -n '3,28p' "$0" | sed 's|^# \?||'
            exit 0
            ;;
        *) fail "unknown flag: $arg"; exit 1 ;;
    esac
done

# ── Result tracking ─────────────────────────────────────────────────
errors=0
warnings=0
declare -a failed_checks=()
declare -a warned_checks=()

record_fail() {
    errors=$((errors + 1))
    failed_checks+=("$1")
}

record_warn() {
    warnings=$((warnings + 1))
    warned_checks+=("$1")
}

# ── Banner ──────────────────────────────────────────────────────────
_out_target ""
_out_target "${BOLD}${CYAN}  S7 SkyQUBi — Pre-flight Check${RESET}"
_out_target "  Target: Fedora 44 (or compatible)"
_out_target ""

# ── 1. Operating system ─────────────────────────────────────────────
section "Operating System"

if [ -f /etc/os-release ]; then
    os_id=$(. /etc/os-release && echo "${ID:-unknown}")
    os_version=$(. /etc/os-release && echo "${VERSION_ID:-unknown}")
    pretty=$(. /etc/os-release && echo "${PRETTY_NAME:-unknown}")
    # 's7' is the native S7 SkyCAIR platform identifier (built from
    # Fedora 44 but identifies as its own distribution). It's not a
    # warning — it's the most-supported case.
    if [ "$os_id" = "s7" ]; then
        ok "OS: $pretty (native S7 platform)"
    elif [ "$os_id" = "fedora" ] && [ "$os_version" = "44" ]; then
        ok "OS: $pretty (primary target)"
    elif [ "$os_id" = "fedora" ]; then
        warn "OS: $pretty (Fedora but not 44 — may need tweaks)"
        record_warn "os_version_not_44"
    else
        warn "OS: $pretty (not Fedora — S7 install will try multi-distro paths)"
        record_warn "os_not_fedora"
    fi
else
    fail "Cannot detect OS (no /etc/os-release)"
    record_fail "no_os_release"
fi

# Kernel version
uname_r=$(uname -r 2>/dev/null || echo "unknown")
ok "Kernel: $uname_r"

# ── 2. Hardware baseline ────────────────────────────────────────────
section "Hardware"

cpu_count=$(nproc 2>/dev/null || echo 0)
if [ "$cpu_count" -ge 4 ]; then
    ok "CPUs: $cpu_count (≥4 recommended for warm-set + witnesses)"
elif [ "$cpu_count" -ge 2 ]; then
    warn "CPUs: $cpu_count (minimum 2, but witnesses will contend)"
    record_warn "low_cpu"
else
    fail "CPUs: $cpu_count (need at least 2)"
    record_fail "insufficient_cpu"
fi

mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
mem_gb=$(( mem_kb / 1024 / 1024 ))
if [ "$mem_gb" -ge 8 ]; then
    ok "RAM: ${mem_gb}G (sufficient for warm chat + witnesses)"
elif [ "$mem_gb" -ge 6 ]; then
    warn "RAM: ${mem_gb}G (tight — consider smaller warm set)"
    record_warn "low_ram"
else
    fail "RAM: ${mem_gb}G (need at least 6G for the full stack)"
    record_fail "insufficient_ram"
fi

# Disk — / must have ≥10G free
free_g=$(df -BG / 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}')
if [ "${free_g:-0}" -ge 10 ]; then
    ok "Disk: ${free_g}G free on / (minimum 10G)"
else
    fail "Disk: ${free_g:-?}G free on / (need at least 10G)"
    record_fail "insufficient_disk"
fi

# /var/tmp — 512M+ for image builds
tmp_m=$(df -BM /var/tmp 2>/dev/null | awk 'NR==2 {gsub("M",""); print $4}')
if [ "${tmp_m:-0}" -ge 512 ]; then
    ok "/var/tmp: ${tmp_m}M free"
else
    warn "/var/tmp: ${tmp_m:-?}M free (image builds may fail)"
    record_warn "low_vartmp"
fi

if [ "$QUICK" -eq 1 ]; then
    section "Quick mode — skipping package + rootless checks"
    _out_target ""
    # Jump to the Summary block rather than exiting directly, so --json
    # still emits its final JSON object and both exit paths are consistent.
    goto_summary=1
fi

if [ "${goto_summary:-0}" -ne 1 ]; then

# ── 3. Required packages ────────────────────────────────────────────
section "Packages (will be installed by install.sh if missing)"

REQUIRED_CMDS="curl git python3"
for cmd in $REQUIRED_CMDS; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ver=$("$cmd" --version 2>&1 | head -1)
        ok "$cmd ($ver)"
    else
        fail "$cmd not found — required for git clone + install.sh"
        record_fail "missing_$cmd"
    fi
done

OPTIONAL_CMDS="podman ollama caddy kitty firefox"
for cmd in $OPTIONAL_CMDS; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd present"
    else
        info "$cmd missing (install.sh will install)"
    fi
done

# envsubst for pod YAML templating — hard requirement
if command -v envsubst >/dev/null 2>&1; then
    ok "envsubst (gettext) present"
else
    fail "envsubst missing — install: sudo dnf install gettext"
    record_fail "missing_envsubst"
fi

# Python version
if command -v python3 >/dev/null 2>&1; then
    pyver=$(python3 -c 'import sys; print("{}.{}".format(sys.version_info[0], sys.version_info[1]))')
    pymajor=$(echo "$pyver" | cut -d. -f1)
    pyminor=$(echo "$pyver" | cut -d. -f2)
    if [ "$pymajor" -eq 3 ] && [ "$pyminor" -ge 9 ]; then
        ok "Python $pyver (>= 3.9 required)"
    else
        fail "Python $pyver is too old — need >= 3.9"
        record_fail "python_too_old"
    fi
fi

# ── 4. Rootless podman (only if podman is present) ──────────────────
section "Rootless Podman"

if command -v podman >/dev/null 2>&1; then
    if podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -q "true"; then
        ok "Podman rootless mode"
    else
        warn "Podman not in rootless mode (will try to self-configure)"
        record_warn "podman_not_rootless"
    fi

    me=$(whoami)
    subuid=$(grep "^${me}:" /etc/subuid 2>/dev/null | head -1)
    if [ -n "$subuid" ]; then
        ok "subuid mapping: $subuid"
    else
        warn "No subuid mapping for $me"
        warn "  fix: sudo usermod --add-subuids 100000-165535 $me"
        record_warn "no_subuid"
    fi

    sock="/run/user/$(id -u)/podman/podman.sock"
    if [ -S "$sock" ]; then
        ok "Podman socket at $sock"
    else
        info "Podman socket not active (install.sh will start it)"
    fi
else
    info "Podman not installed yet — install.sh will install it"
fi

# ── 5. SELinux ──────────────────────────────────────────────────────
section "SELinux"

if command -v getenforce >/dev/null 2>&1; then
    mode=$(getenforce 2>/dev/null)
    if [ "$mode" = "Enforcing" ]; then
        ok "SELinux: Enforcing"

        # Check the specific boolean S7 containers need
        if command -v getsebool >/dev/null 2>&1; then
            mmap=$(getsebool domain_can_mmap_files 2>/dev/null | awk '{print $NF}')
            if [ "$mmap" = "on" ]; then
                ok "domain_can_mmap_files = on"
            else
                fail "domain_can_mmap_files = off — containers will crash"
                warn "  fix: sudo setsebool -P domain_can_mmap_files on"
                record_fail "selinux_mmap_off"
            fi

            cgroup=$(getsebool container_manage_cgroup 2>/dev/null | awk '{print $NF}')
            if [ "$cgroup" = "on" ]; then
                ok "container_manage_cgroup = on"
            else
                warn "container_manage_cgroup = off"
                record_warn "selinux_cgroup_off"
            fi
        fi

        # fcontext equivalence rule check (added 2026-04-13 — the 3-hour-
        # debug root cause). When rootless podman runs out of a non-standard
        # storage path (like /s7/.local/share/containers), SELinux's shipped
        # fcontext rules only match /var/lib/containers. Without an
        # equivalence rule, restorecon labels everything as default_t and
        # the container_t domain can't read its own overlay files. This
        # check is read-only (reads the file_contexts.subs file directly,
        # no sudo) and warns if the equivalence is missing.
        subs_file="/etc/selinux/targeted/contexts/files/file_contexts.subs"
        if [ -f "$subs_file" ]; then
            # Check for any rootless-path equivalence rule pointing at
            # /var/lib/containers. The exact left-hand path depends on
            # the install location.
            equiv_rules=$(grep -E '/var/lib/containers' "$subs_file" 2>/dev/null \
                                    "${subs_file}.local" 2>/dev/null | head -5)
            if [ -n "$equiv_rules" ]; then
                ok "fcontext equivalence rule present (rootless storage labeled correctly)"
                # Extract the LHS (user-path) for informational display
                user_paths=$(echo "$equiv_rules" | awk '{print $1}' | sort -u | head -3)
                for p in $user_paths; do
                    info "  $p → /var/lib/containers"
                done
            else
                warn "No fcontext equivalence rule for rootless container storage"
                warn "  If S7 storage is not under /var/lib/containers, containers may fail"
                warn "  fix: sudo semanage fcontext -a -e /var/lib/containers <your-storage-path>"
                warn "       sudo restorecon -Rv <your-storage-path>"
                record_warn "selinux_no_fcontext_equiv"
            fi
        else
            info "file_contexts.subs not found (non-targeted SELinux policy?)"
        fi

        # Audit source check — either ausearch on audit.log OR
        # journalctl -k. fix-pod.sh needs at least one of these to
        # diagnose AVC denials when the pod crashes.
        if [ -f /var/log/audit/audit.log ]; then
            ok "audit.log present (ausearch diagnostics available)"
        elif journalctl -k -b -n 1 --no-pager 2>/dev/null | grep -q .; then
            ok "journalctl -k readable (AVC fallback diagnostics available)"
        else
            warn "No AVC diagnostic source reachable (neither audit.log nor journalctl)"
            warn "  If the pod crashes, SELinux root-cause analysis will be blind"
            warn "  fix: sudo systemctl enable --now auditd"
            record_warn "no_avc_source"
        fi

    elif [ "$mode" = "Permissive" ]; then
        warn "SELinux: Permissive (functional but not hardened)"
        record_warn "selinux_permissive"
    else
        ok "SELinux: $mode"
    fi
else
    info "SELinux tools not installed (non-Fedora?)"
fi

# ── 6. Ports ────────────────────────────────────────────────────────
section "Port availability"

S7_PORTS="57077 57080 57086 57088 57089 57090 57091"
# A port held by a process running as the current user (the s7 user
# on a real box) is "ours" by definition — rootlessport from the
# s7-skyqubi pod and Python S7 services both qualify. Only flag a
# port if some OTHER user holds it, which would be a real conflict.
my_uid="$(id -u)"

port_listener_uid() {
    local port="$1"
    local pid
    pid=$(ss -tlnpH 2>/dev/null \
        | awk -v p=":${port}$" '$4 ~ p {print; exit}' \
        | grep -oP 'pid=\K[0-9]+' | head -1)
    [ -z "$pid" ] && { echo ""; return; }
    awk '/^Uid:/ {print $2; exit}' "/proc/$pid/status" 2>/dev/null
}

for port in $S7_PORTS; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        listener_uid=$(port_listener_uid "$port")
        if [ -n "$listener_uid" ] && [ "$listener_uid" = "$my_uid" ]; then
            ok "port :$port held by S7 (uid $my_uid — pod or service)"
        else
            warn "port :$port already in use (foreign uid: ${listener_uid:-unknown})"
            record_warn "port_in_use_$port"
        fi
    else
        ok "port :$port available"
    fi
done

# ── 6b. Firewalld trust for rootless link-local gateway ────────────
# 2026-04-13 lesson: rootless pasta-mode containers reach the host
# via 169.254.1.0/24. firewalld's default zone doesn't trust that
# source out of the box, so containers can't reach host services
# like ollama on 57081. After every host reboot, runtime-only rules
# are gone — preflight should catch this so the user sees the drift
# at the diagnostic layer, not after a lifecycle test fails downstream.
section "Firewall (rootless gateway trust)"

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
    # Use --get-active-zones because --zone=trusted --list-sources
    # needs polkit and silently returns nothing for the non-root s7
    # user. Same polkit trap fix-firewall.sh already learned today.
    if firewall-cmd --get-active-zones 2>/dev/null \
        | awk '/^[a-zA-Z]/{z=$1;next} /sources:/&&z=="trusted"{print;exit}' \
        | grep -q '169.254.1.0/24'; then
        ok "firewalld trusts 169.254.1.0/24 (rootless gateway → host services)"
    else
        warn "firewalld does NOT trust 169.254.1.0/24"
        warn "  rootless containers cannot reach host services like ollama on 57081"
        warn "  fix: sudo /s7/skyqubi-private/install/fix-firewall.sh"
        record_warn "firewall_rootless_trust_missing"
    fi
else
    info "firewalld not active — no trust rule needed"
fi

# ── 6c. Local Ollama listener ──────────────────────────────────────
# Distinct from ollama.com (the upstream registry) — this is the host
# ollama process serving inference on :57081. If this is down or
# wedged, no persona will respond, regardless of firewall state.
# 2026-04-13 lesson: A03/A04/E06 lifecycle failures had two prongs —
# (1) firewall trust drift, AND (2) we never checked if the local
# ollama listener was alive. Now we check both at the diagnostic layer.
section "Local Ollama listener"

if curl -sS --max-time 3 http://127.0.0.1:57081/api/version 2>/dev/null | grep -q '"version"'; then
    ollama_ver=$(curl -sS --max-time 3 http://127.0.0.1:57081/api/version 2>/dev/null \
        | python3 -c 'import sys,json; print(json.load(sys.stdin).get("version","?"))' 2>/dev/null || echo "?")
    ok "local ollama listener responding (v$ollama_ver)"

    # 2026-04-13 architecture reminder: check the bind address.
    # On a sovereign civilian appliance, ollama should bind to 127.0.0.1
    # (loopback) so it's not exposed to the WiFi LAN. Rootless containers
    # reach it via the link-local gateway path (169.254.1.0/24), which
    # works regardless of bind address. A 0.0.0.0 bind is a real
    # exposure on a box that has wifi up.
    ollama_bind=$(ss -tlnp 2>/dev/null | awk '/:57081 / {print $4; exit}')
    case "$ollama_bind" in
        127.0.0.1:57081|::1:57081)
            ok "ollama bind is loopback-only ($ollama_bind)"
            ;;
        \*:57081|0.0.0.0:57081)
            warn "ollama is bound to ALL interfaces ($ollama_bind)"
            warn "  this exposes inference to the LAN/WiFi; civilian household devices can hit it"
            warn "  fix: 'OLLAMA_HOST=127.0.0.1:57081 ollama serve' (loopback only)"
            warn "  rootless containers still reach it via 169.254.1.0/24 — broad bind is not needed"
            record_warn "ollama_bind_too_broad"
            ;;
        "")
            : # already warned by the not-responding branch
            ;;
        *)
            info "ollama bind is $ollama_bind (review whether this is intended)"
            ;;
    esac
else
    warn "local ollama listener at 127.0.0.1:57081 is NOT responding"
    warn "  no persona will be able to answer until ollama is back"
    warn "  fix: sudo systemctl restart ollama  (or check 'systemctl status ollama')"
    record_warn "ollama_local_unreachable"
fi

# ── 7. Network reachability (for the git pull and model downloads) ─
section "Network"

if curl -sSL --max-time 5 -o /dev/null -w '%{http_code}' https://github.com 2>/dev/null | grep -q '^[23]'; then
    ok "GitHub reachable"
else
    warn "GitHub not reachable — pull from git may fail"
    record_warn "github_unreachable"
fi

if curl -sSL --max-time 5 -o /dev/null -w '%{http_code}' https://ollama.com 2>/dev/null | grep -q '^[23]'; then
    ok "ollama.com reachable (upstream registry)"
else
    warn "ollama.com not reachable — model pulls may fail"
    record_warn "ollama_registry_unreachable"
fi

# ── 8. Repo presence (for the install phase) ───────────────────────
section "Repo"

if [ -d .git ] && [ -f install/install.sh ]; then
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    ok "Inside S7 repo clone (branch: $branch)"
else
    info "Not inside a repo — pull with:"
    info "  git clone https://github.com/skycair-code/SkyQUBi-public.git"
    info "  cd SkyQUBi-public"
    info "  bash install/preflight.sh    # re-run from inside"
fi

fi  # end of 'if goto_summary != 1' block (full check section)

# ── Summary ─────────────────────────────────────────────────────────
_out_target ""
_out_target "${BOLD}${CYAN}── Summary${RESET}"
_out_target ""

# Determine exit code and state string. These are used both for JSON
# output and for the human-readable summary.
if [ "$errors" -eq 0 ] && [ "$warnings" -eq 0 ]; then
    exit_code=0
    state="ready"
elif [ "$errors" -eq 0 ]; then
    exit_code=2
    state="ready_with_warnings"
else
    exit_code=1
    state="not_ready"
fi

if [ "$JSON" -eq 1 ]; then
    # Minimal JSON report on stdout. Human-readable text already went
    # to stderr via _out_target. One JSON object, one line, parseable
    # by Samuel's skill runner.
    printf '{"script":"preflight.sh","state":"%s","exit_code":%d,"errors":%d,"warnings":%d,"failed":[' \
        "$state" "$exit_code" "$errors" "$warnings"
    first=1
    for c in "${failed_checks[@]+"${failed_checks[@]}"}"; do
        [ $first -eq 0 ] && printf ','
        printf '"%s"' "$c"
        first=0
    done
    printf '],"warned":['
    first=1
    for c in "${warned_checks[@]+"${warned_checks[@]}"}"; do
        [ $first -eq 0 ] && printf ','
        printf '"%s"' "$c"
        first=0
    done
    printf ']}\n'
    exit $exit_code
fi

# Human-readable summary (non-JSON path)
case "$state" in
    ready)
        echo -e "  ${GREEN}${BOLD}READY — you can run: sudo bash install/install.sh${RESET}"
        echo ""
        ;;
    ready_with_warnings)
        echo -e "  ${YELLOW}${BOLD}READY with $warnings warning(s) — install.sh will proceed but some features degraded${RESET}"
        echo ""
        for c in "${warned_checks[@]}"; do echo "    ! $c"; done
        echo ""
        ;;
    not_ready)
        echo -e "  ${RED}${BOLD}NOT READY — $errors error(s), $warnings warning(s)${RESET}"
        echo "  Fix the errors above, then re-run this script."
        echo ""
        for c in "${failed_checks[@]}"; do echo "    ✗ $c"; done
        for c in "${warned_checks[@]}"; do echo "    ! $c"; done
        echo ""
        ;;
esac
exit $exit_code
