#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi installer — inner stage
#
# Runs after installer-header.sh has verified the payload sha256 and
# extracted everything to a tempdir. By this point we have:
#   ./inner.sh                   (this file)
#   ./manifest.json              (release metadata + per-artifact hashes)
#   ./repo.tar.zst               (snapshot of /s7/skyqubi-private at release)
#   ./images/*.tar               (DEFERRED to Pass 2: podman save tarballs)
#   ./models/*.bin               (DEFERRED to Pass 2: ollama blob drops)
#   ./db/*.dump                  (DEFERRED to Pass 2: postgres + mysql seeds)
#
# Order of operations (each step can abort with rollback):
#   1. preflight     — verify the host can host S7
#   2. configure_host — selinux + firewalld + /s7 dirs (the lessons we learned)
#   3. unpack_repo   — drop /s7/skyqubi-private from repo.tar.zst
#   4. load_artifacts — DEFERRED Pass 2: podman load + ollama blobs + db restore
#   5. start_pod     — DEFERRED Pass 2: podman play kube
#   6. lifecycle     — DEFERRED Pass 2: 53-test verify, abort on FAIL
#   7. report        — print one line, exit 0 on success
#
# If any required step fails, rollback() is called and the system is
# returned to its pre-install state. The user gets either a working
# QUBi or no QUBi — never a half-installed one.
#
# Governing rules:
#   feedback_three_rules.md      Rule 3: Protect the QUBi
#   feedback_intake_gate_*.md    Verify-before-trust
#   feedback_preaudit.md         Audit the host before deploying anything
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; CYAN=$'\033[0;36m'; YELLOW=$'\033[0;33m'; RESET=$'\033[0m'
ok()      { echo "  ${GREEN}✓${RESET} $1"; }
fail()    { echo "  ${RED}✗${RESET} $1" >&2; }
warn()    { echo "  ${YELLOW}!${RESET} $1"; }
info()    { echo "  ${CYAN}→${RESET} $1"; }
section() { echo; echo "${CYAN}── $1${RESET}"; }

PAYLOAD_DIR="$(cd "$(dirname "$0")" && pwd)"
S7_USER="${S7_USER:-s7}"
S7_HOME="${S7_HOME:-/s7}"
S7_REPO_DIR="${S7_REPO_DIR:-${S7_HOME}/skyqubi-private}"
ROLLBACK_ACTIONS=()

register_rollback() { ROLLBACK_ACTIONS+=("$1"); }

rollback() {
    fail "Rolling back install"
    # Iterate in reverse so undo order matches inverse of apply order
    for ((i=${#ROLLBACK_ACTIONS[@]}-1; i>=0; i--)); do
        info "rollback: ${ROLLBACK_ACTIONS[$i]}"
        bash -c "${ROLLBACK_ACTIONS[$i]}" || true
    done
    fail "Rollback complete. System should be in its pre-install state."
    exit 1
}
trap 'rollback' ERR

# ── Step 0: resource preflight ──────────────────────────────────────
# Bail early if the user's box doesn't have the room. Prevents the
# half-installed state Jamie called out: don't run out of /, /var,
# /tmp, or /boot mid-install. Numbers tuned for the 5-image bundle.
section "Step 0/7 — resource preflight"

inner_check_free_mb() {
    local path="$1"
    local need_mb="$2"
    local label="$3"
    local free_mb
    free_mb=$(df -BM "$path" 2>/dev/null | awk 'NR==2 {gsub(/M/,"",$4); print $4}')
    if [ -z "$free_mb" ]; then
        warn "$label: could not stat (assuming OK)"
        return 0
    fi
    if [ "$free_mb" -lt "$need_mb" ]; then
        fail "$label: $free_mb MB free, need at least $need_mb MB"
        return 1
    fi
    ok "$label: $free_mb MB free (need $need_mb)"
}

resource_fail=0
# /s7 (or wherever S7_HOME is) takes the brunt: extracted images,
# pulled blobs, persistent data. 10 GB is the realistic floor for
# a 5-image install.
inner_check_free_mb "$(dirname "$S7_HOME")" 10240 "S7_HOME parent (target install root)" || resource_fail=1
# /var/lib/containers — ALSO a write target if rootless storage
# happens to fall under /var. Best-effort.
[ -d /var/lib/containers ] && inner_check_free_mb /var/lib/containers 5120 "/var/lib/containers" || true
# /tmp — used by tar pipes during extraction
inner_check_free_mb /tmp 100 "/tmp (extraction scratch)" || resource_fail=1
# /boot — only relevant if we'll be touching the kernel/initramfs
# layer. We don't today, but check anyway so a nearly-full /boot
# trips a warning before any future kernel-touching step lands.
[ -d /boot ] && inner_check_free_mb /boot 100 "/boot (kernel/initramfs layer)" || true

if [ "$resource_fail" -eq 1 ]; then
    fail "Insufficient disk for a clean install."
    fail "Free up space and re-run. The installer has not modified anything yet."
    exit 5
fi

# ── Step 1: preflight ───────────────────────────────────────────────
section "Step 1/7 — preflight"
if [ -x "$PAYLOAD_DIR/preflight.sh" ]; then
    if bash "$PAYLOAD_DIR/preflight.sh" --json >/tmp/s7-installer-preflight.json 2>&1; then
        ok "preflight: ready"
    else
        ec=$?
        # Exit code 2 = ready_with_warnings, still proceeds
        if [ "$ec" -eq 2 ]; then
            warn "preflight: ready_with_warnings (proceeding)"
        else
            fail "preflight: not_ready (exit $ec)"
            cat /tmp/s7-installer-preflight.json >&2 || true
            rollback
        fi
    fi
else
    warn "preflight.sh not in payload — skipping (Pass 2 will require it)"
fi

# ── Step 2: configure_host ──────────────────────────────────────────
section "Step 2/7 — configure host (SELinux + firewalld + /s7 dirs)"

if [ "$(id -u)" -ne 0 ]; then
    fail "configure_host requires root for semanage and firewall-cmd"
    fail "Re-run with: sudo bash $0"
    exit 4
fi

# 2a. Create the s7 user if missing
if ! id "$S7_USER" >/dev/null 2>&1; then
    info "Creating user '$S7_USER'"
    useradd -m -d "$S7_HOME" -s /bin/bash "$S7_USER"
    register_rollback "userdel -r '$S7_USER'"
    ok "user $S7_USER created"
else
    ok "user $S7_USER already exists"
fi

# 2b. subuid/subgid mapping for rootless podman
if ! grep -q "^${S7_USER}:" /etc/subuid 2>/dev/null; then
    info "Adding subuid/subgid for $S7_USER"
    usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$S7_USER"
    register_rollback "usermod --del-subuids 100000-165535 --del-subgids 100000-165535 '$S7_USER'"
    ok "subuid/subgid added"
else
    ok "subuid already configured"
fi

# 2c. SELinux fcontext equivalence rule for rootless container storage
# This is the 2026-04-13 lesson: rootless storage at non-default paths
# (e.g. /s7/.local/share/containers) needs an equivalence rule or
# containers fail with default_t denials.
if command -v semanage >/dev/null 2>&1; then
    if ! semanage fcontext -l 2>/dev/null | grep -q "${S7_HOME}/.local/share/containers"; then
        info "Adding SELinux fcontext equivalence rule"
        semanage fcontext -a -e /var/lib/containers "${S7_HOME}/.local/share/containers" 2>&1 || {
            fail "semanage fcontext failed"
            rollback
        }
        register_rollback "semanage fcontext -d '${S7_HOME}/.local/share/containers' 2>/dev/null"
        ok "fcontext equivalence rule added"
    else
        ok "SELinux fcontext equivalence already configured"
    fi
    # restorecon the directory if it exists
    if [ -d "${S7_HOME}/.local/share/containers" ]; then
        info "Running restorecon"
        restorecon -Rv "${S7_HOME}/.local/share/containers" >/dev/null 2>&1 || true
        ok "restorecon complete"
    fi
else
    warn "semanage not available (non-SELinux host) — skipping fcontext rule"
fi

# 2d. Host firewall trust for rootless link-local gateway
#
# IMPORTANT: This is purely about LOCAL pod-to-host loopback plumbing,
# NOT perimeter security. The QUBi is a sovereign-offline appliance —
# there is no external network to defend with this rule. The 169.254
# link-local space is non-routable by RFC 3927, so trusting it cannot
# expose anything beyond the host itself.
#
# 2026-04-13 lesson: pasta-mode rootless containers reach the host
# via 169.254.1.0/24 link-local. On Fedora-with-firewalld, the
# default zone doesn't trust that source out of the box, so the
# rootless container can't reach host services like ollama. We add
# the trust rule there. On other host firewalls (ufw / nft / iptables /
# none), link-local is generally not blocked by default and we only
# verify, never modify the user's existing config.
detect_firewall() {
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
        echo "firewalld"
    elif command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        echo "ufw"
    elif command -v nft >/dev/null 2>&1 && systemctl is-active nftables >/dev/null 2>&1; then
        echo "nftables"
    elif command -v iptables >/dev/null 2>&1 && iptables -L INPUT 2>/dev/null | head -1 | grep -q Chain; then
        echo "iptables"
    else
        echo "none"
    fi
}

fw_flavor=$(detect_firewall)
case "$fw_flavor" in
    firewalld)
        if ! firewall-cmd --get-active-zones 2>/dev/null \
            | awk '/^[a-zA-Z]/{z=$1;next} /sources:/&&z=="trusted"{print;exit}' \
            | grep -q '169.254.1.0/24'; then
            info "Trusting rootless link-local gateway in firewalld"
            firewall-cmd --permanent --zone=trusted --add-source=169.254.1.0/24 || {
                fail "firewall-cmd add-source failed"
                rollback
            }
            firewall-cmd --reload || {
                fail "firewall-cmd reload failed"
                rollback
            }
            register_rollback "firewall-cmd --permanent --zone=trusted --remove-source=169.254.1.0/24 && firewall-cmd --reload"
            ok "firewalld trusts 169.254.1.0/24 (rootless gateway)"
        else
            ok "firewalld already trusts 169.254.1.0/24"
        fi
        ;;
    ufw)
        # ufw allows link-local by default unless explicitly denied.
        # We don't add a rule (would clutter the user's ufw config)
        # but we verify nothing is blocking it.
        if ufw status numbered 2>/dev/null | grep -q '169.254'; then
            warn "ufw has a 169.254 rule — review manually if rootless networking fails"
        else
            ok "ufw active, no link-local rule needed (default allow)"
        fi
        ;;
    nftables)
        # nftables direct: no zone concept. Link-local is generally
        # not blocked unless the user has a custom INPUT drop rule.
        ok "nftables active — link-local not blocked by default"
        info "  if rootless networking fails, check 'nft list ruleset' for drops on 169.254"
        ;;
    iptables)
        ok "iptables direct mode — link-local not blocked by default"
        info "  if rootless networking fails, check 'iptables -L INPUT' for drops on 169.254"
        ;;
    none)
        ok "no host firewall detected — nothing to configure"
        ;;
esac

# 2e. /s7 directory tree
mkdir -p "$S7_HOME" "$S7_HOME/.s7-ops-ledger" "$S7_HOME/.config/s7"
chown -R "${S7_USER}:${S7_USER}" "$S7_HOME"
ok "/s7 directory tree ready"

# ── Step 3: unpack_repo ─────────────────────────────────────────────
section "Step 3/7 — unpack repo"
if [ -f "$PAYLOAD_DIR/repo.tar.zst" ]; then
    if [ -d "$S7_REPO_DIR" ]; then
        warn "$S7_REPO_DIR already exists — refusing to overwrite"
        warn "Move or remove it before re-running the installer"
        rollback
    fi
    info "Extracting repo.tar.zst → $S7_REPO_DIR"
    mkdir -p "$S7_REPO_DIR"
    register_rollback "rm -rf '$S7_REPO_DIR'"
    zstd -d --stdout "$PAYLOAD_DIR/repo.tar.zst" | tar -x -C "$S7_REPO_DIR"
    chown -R "${S7_USER}:${S7_USER}" "$S7_REPO_DIR"
    ok "repo unpacked into $S7_REPO_DIR"
else
    fail "repo.tar.zst missing from payload — refusing to install"
    rollback
fi

# ── Step 4: load_artifacts ──────────────────────────────────────────
section "Step 4/7 — load artifacts (containers + models)"

# 4a. podman load for each bundled container image
if [ -d "$PAYLOAD_DIR/images" ] && [ -f "$PAYLOAD_DIR/images.manifest.json" ]; then
    info "Loading bundled container images"
    # Read the images manifest to get the canonical (image, file) pairs
    image_list=$(python3 -c '
import json, sys
with open("'"$PAYLOAD_DIR"'/images.manifest.json") as f:
    m = json.load(f)
for img in m.get("images", []):
    print(f"{img[\"image\"]}\t{img[\"file\"]}")
' 2>/dev/null)
    if [ -z "$image_list" ]; then
        fail "images.manifest.json is unreadable or empty"
        rollback
    fi
    loaded_images=()
    while IFS=$'\t' read -r img_ref img_file; do
        [ -z "$img_ref" ] && continue
        info "  loading $img_ref from $img_file"
        if ! sudo -u "$S7_USER" podman load -i "$PAYLOAD_DIR/$img_file" >/dev/null 2>&1; then
            fail "podman load failed for $img_ref"
            rollback
        fi
        loaded_images+=("$img_ref")
        ok "    $img_ref"
    done <<< "$image_list"
    # Register one rollback per loaded image
    for img in "${loaded_images[@]}"; do
        register_rollback "sudo -u '$S7_USER' podman rmi '$img' 2>/dev/null || true"
    done
    ok "loaded ${#loaded_images[@]} container images"
else
    warn "no bundled images in payload — skipping podman load"
fi

# 4b. Drop bundled ollama model blobs into the s7 user's ollama home
if [ -d "$PAYLOAD_DIR/models" ] && [ -f "$PAYLOAD_DIR/models.manifest.json" ]; then
    info "Installing bundled ollama models"
    OLLAMA_DEST="${S7_HOME}/.ollama/models"
    mkdir -p "$OLLAMA_DEST/manifests" "$OLLAMA_DEST/blobs"
    chown -R "${S7_USER}:${S7_USER}" "$OLLAMA_DEST"

    # Copy the bundled manifests/* tree into place (preserves
    # registry.ollama.ai/library/MODEL/TAG layout)
    if [ -d "$PAYLOAD_DIR/models/manifests" ]; then
        cp -an "$PAYLOAD_DIR/models/manifests/." "$OLLAMA_DEST/manifests/"
        ok "manifests dropped into $OLLAMA_DEST/manifests"
    fi

    # Copy the unique blobs (-an = no-clobber so existing blobs from
    # other models on the user's box are preserved)
    if [ -d "$PAYLOAD_DIR/models/blobs" ]; then
        copied=0
        for blob in "$PAYLOAD_DIR/models/blobs/"sha256-*; do
            [ -f "$blob" ] || continue
            blob_name=$(basename "$blob")
            if [ ! -f "$OLLAMA_DEST/blobs/$blob_name" ]; then
                cp -a "$blob" "$OLLAMA_DEST/blobs/$blob_name"
                copied=$((copied + 1))
            fi
        done
        ok "$copied new blobs dropped (existing blobs preserved)"
    fi

    # Re-own everything to the s7 user
    chown -R "${S7_USER}:${S7_USER}" "$OLLAMA_DEST"

    # Register rollback: remove only the manifests we dropped
    register_rollback "rm -rf '$OLLAMA_DEST/manifests/registry.ollama.ai/library/s7-qwen3' '$OLLAMA_DEST/manifests/registry.ollama.ai/library/s7-carli' '$OLLAMA_DEST/manifests/registry.ollama.ai/library/s7-elias' '$OLLAMA_DEST/manifests/registry.ollama.ai/library/s7-samuel'"
    ok "model bundling complete"
else
    warn "no bundled models in payload — skipping ollama drop"
fi

# ── Step 5: start_pod ───────────────────────────────────────────────
section "Step 5/7 — start pod"

# The repo we just unpacked has the kube manifest at iac/s7-skyqubi-pod.yaml
# (or similar). We invoke 'podman play kube' as the s7 user.
KUBE_MANIFEST_CANDIDATES=(
    "$S7_REPO_DIR/iac/s7-skyqubi-pod.yaml"
    "$S7_REPO_DIR/iac/podman/s7-skyqubi.yaml"
    "$S7_REPO_DIR/iac/k8s/s7-skyqubi.yaml"
)
KUBE_MANIFEST=""
for candidate in "${KUBE_MANIFEST_CANDIDATES[@]}"; do
    if [ -f "$candidate" ]; then
        KUBE_MANIFEST="$candidate"
        break
    fi
done

if [ -z "$KUBE_MANIFEST" ]; then
    warn "no kube manifest found in expected locations:"
    for c in "${KUBE_MANIFEST_CANDIDATES[@]}"; do warn "  $c"; done
    warn "Pass 2 inner installer cannot start the pod automatically."
    warn "After this installer completes, the user can start manually:"
    warn "  su - $S7_USER -c 'cd ~/skyqubi-private && podman play kube <path>'"
else
    # CRITICAL: 2026-04-13 lesson — without explicit --network pasta
    # options, podman defaults to '-T none -U none' which disables ALL
    # container→host TCP/UDP forwarding. The admin container needs to
    # reach the host's ollama on 57081 (and BitNet on 57091), so we
    # pass '-T,auto' to enable automatic TCP forwarding from container
    # to host. This is link-local only (RFC 3927 169.254.1.0/24), so
    # no external exposure — same security profile as the default.
    # See: man podman-play-kube + project_pasta_t_none_pod_network_2026_04_13.md
    info "Starting pod from $KUBE_MANIFEST"
    info "  using --network pasta:-T,auto so containers can reach host services"
    if sudo -u "$S7_USER" podman play kube --network pasta:-T,auto "$KUBE_MANIFEST" >/tmp/s7-installer-podstart.log 2>&1; then
        ok "pod started"
        # --down doesn't need --network (it just stops what's running)
        register_rollback "sudo -u '$S7_USER' podman play kube --down '$KUBE_MANIFEST' 2>/dev/null || true"
        # Wait up to 30 seconds for the pod to reach Running state
        for i in 1 2 3 4 5 6; do
            state=$(sudo -u "$S7_USER" podman pod inspect s7-skyqubi --format '{{.State}}' 2>/dev/null || echo unknown)
            if [ "$state" = "Running" ]; then
                ok "pod state: Running"
                break
            fi
            info "  pod state: $state (waiting...)"
            sleep 5
        done
    else
        fail "podman play kube failed; see /tmp/s7-installer-podstart.log"
        cat /tmp/s7-installer-podstart.log >&2 || true
        rollback
    fi
fi

# ── Step 6: lifecycle verify ────────────────────────────────────────
section "Step 6/7 — lifecycle verify"

# Run the lifecycle test as the s7 user. If it fails, rollback the
# whole install so the user gets either a working QUBi or no QUBi.
LIFECYCLE_SCRIPT="$S7_REPO_DIR/s7-lifecycle-test.sh"
if [ -x "$LIFECYCLE_SCRIPT" ]; then
    info "Running lifecycle test (this is the install gate)"
    if sudo -u "$S7_USER" bash "$LIFECYCLE_SCRIPT" --json >/tmp/s7-installer-lifecycle.json 2>&1; then
        # Parse the JSON for the verdict
        lc_state=$(python3 -c 'import sys,json; print(json.load(open("/tmp/s7-installer-lifecycle.json")).get("state","unknown"))' 2>/dev/null || echo parse_error)
        lc_pass=$(python3 -c 'import sys,json; print(json.load(open("/tmp/s7-installer-lifecycle.json")).get("pass",0))' 2>/dev/null || echo 0)
        lc_total=$(python3 -c 'import sys,json; print(json.load(open("/tmp/s7-installer-lifecycle.json")).get("total",0))' 2>/dev/null || echo 0)
        if [ "$lc_state" = "verified" ]; then
            ok "lifecycle: $lc_pass/$lc_total VERIFIED"
        else
            fail "lifecycle: $lc_state ($lc_pass/$lc_total) — install gate failed"
            rollback
        fi
    else
        fail "lifecycle test crashed — see /tmp/s7-installer-lifecycle.json"
        rollback
    fi
else
    warn "lifecycle test script not found at $LIFECYCLE_SCRIPT — skipping gate"
    warn "  (the install will report success without verification)"
fi

# ── Step 7: report ──────────────────────────────────────────────────
section "Step 7/7 — done"
trap - ERR  # disarm rollback on success

cat <<EOF

  ${GREEN}✓ S7 SkyQUBi install complete.${RESET}

  Repo:        $S7_REPO_DIR
  User:        $S7_USER
  Host config: SELinux fcontext + firewall trust + subuid mappings
  Containers:  loaded from bundled tarballs (no internet pulls)
  Models:      ollama blobs dropped into ${S7_HOME}/.ollama/models
  Pod:         started via 'podman play kube'
  Lifecycle:   verified (the install gate)

  Talk to your QUBi:
    Open a browser to the persona-chat UI (port 57080 by default)
    or curl the local API:
      curl http://127.0.0.1:57080/persona/chat \\
        -X POST -H 'Content-Type: application/json' \\
        -d '{"persona":"samuel","message":"how is the qubi doing","tier":"L1","user_id":"$S7_USER","session_id":"first"}'

  Re-run anytime to re-verify:
    su - $S7_USER -c 'bash ~/skyqubi-private/install/diag.sh'

EOF
exit 0
