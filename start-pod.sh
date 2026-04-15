#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Sovereign AI Platform Deployer
# Pre-audit → Deploy → Configure → Verify
# Usage: ./start-pod.sh [--down] [--check]
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="${SKYQUBI_SECRETS:-${SCRIPT_DIR}/.env.secrets}"
POD_TEMPLATE="${SCRIPT_DIR}/skyqubi-pod.yaml"
POD_RENDERED="/tmp/s7-skyqubi-pod-rendered.yaml"
MIN_DISK_GB=10
MIN_TMP_MB=512

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; RESET='\033[0m'; BOLD='\033[1m'
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
fail() { echo -e "  ${RED}✗${RESET} $1"; }
warn() { echo -e "  ${YELLOW}!${RESET} $1"; }
info() { echo -e "  ${CYAN}→${RESET} $1"; }

# ══════════════════════════════════════════════════════════════════
# PHASE 1: PRE-DEPLOYMENT AUDIT
# ══════════════════════════════════════════════════════════════════
pre_audit() {
  local errors=0
  local warnings=0

  echo ""
  echo -e "${BOLD}  ── Pre-Deployment Audit ──${RESET}"
  echo ""

  # ── OS ──
  echo -e "${CYAN}  OS${RESET}"
  if [ -f /etc/os-release ]; then
    local os_id=$(. /etc/os-release && echo "${ID_LIKE:-$ID}")
    local os_name=$(. /etc/os-release && echo "${PRETTY_NAME}")
    if echo "$os_id" | grep -qi "fedora\|rhel\|centos\|s7"; then
      ok "OS: $os_name"
    else
      warn "OS: $os_name (not Fedora-based — may need adjustments)"
      ((warnings++))
    fi
  else
    fail "Cannot detect OS"
    ((errors++))
  fi

  # ── Packages ──
  echo -e "${CYAN}  Packages${RESET}"
  # Detect package manager for install hints
  local PM="sudo dnf install"
  command -v apt-get &>/dev/null && PM="sudo apt-get install -y"
  command -v pacman &>/dev/null && PM="sudo pacman -S"

  for pkg in podman curl git; do
    if command -v "$pkg" &>/dev/null; then
      ok "$pkg"
    else
      fail "$pkg not found — install: $PM $pkg"
      ((errors++))
    fi
  done

  if command -v envsubst &>/dev/null; then
    ok "envsubst"
  else
    fail "envsubst not found — install: $PM gettext"
    ((errors++))
  fi

  if command -v python3 &>/dev/null; then
    ok "python3 $(python3 --version 2>&1 | awk '{print $2}')"
  else
    fail "python3 not found — install: $PM python3"
    ((errors++))
  fi

  # ── User ──
  echo -e "${CYAN}  User${RESET}"
  if [ "$(id -u)" -eq 0 ]; then
    fail "Running as root — SkyQUBi requires a non-root user"
    ((errors++))
  else
    ok "User: $(whoami) (UID $(id -u))"
  fi

  # ── Podman rootless ──
  echo -e "${CYAN}  Podman${RESET}"
  if podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -q "true"; then
    ok "Podman rootless mode"
  else
    fail "Podman not in rootless mode"
    ((errors++))
  fi

  local subuid=$(grep "^$(whoami):" /etc/subuid 2>/dev/null | head -1)
  if [ -n "$subuid" ]; then
    ok "subuid: $subuid"
  else
    fail "No subuid mapping for $(whoami)"
    echo "    Fix: sudo usermod --add-subuids 100000-165535 $(whoami)"
    ((errors++))
  fi

  local sock="${PODMAN_SOCK:-/run/user/$(id -u)/podman/podman.sock}"
  if [ -S "$sock" ]; then
    ok "Podman socket: $sock"
  else
    warn "Podman socket not found — starting..."
    systemctl --user start podman.socket 2>/dev/null || true
    if [ -S "$sock" ]; then
      ok "Podman socket started"
    else
      fail "Cannot start Podman socket"
      ((errors++))
    fi
  fi

  # ── SELinux ──
  echo -e "${CYAN}  SELinux${RESET}"
  local selinux=$(getenforce 2>/dev/null || echo "Disabled")
  if [ "$selinux" = "Enforcing" ]; then
    local mmap=$(getsebool domain_can_mmap_files 2>/dev/null | awk '{print $NF}')
    if [ "$mmap" = "on" ]; then
      ok "SELinux: Enforcing (domain_can_mmap_files=on)"
    else
      fail "SELinux: Enforcing but domain_can_mmap_files=off — containers will crash"
      echo "    Fix: sudo setsebool -P domain_can_mmap_files on"
      ((errors++))
    fi
  elif [ "$selinux" = "Permissive" ]; then
    warn "SELinux: Permissive (functional but not hardened)"
    ((warnings++))
  else
    ok "SELinux: $selinux"
  fi

  # ── Disk ──
  echo -e "${CYAN}  Disk${RESET}"
  local free_gb=$(df -BG / | tail -1 | awk '{gsub("G",""); print $4}')
  if [ "$free_gb" -ge "$MIN_DISK_GB" ]; then
    ok "Disk: ${free_gb}G free (minimum ${MIN_DISK_GB}G)"
  else
    fail "Disk: ${free_gb}G free — need at least ${MIN_DISK_GB}G"
    ((errors++))
  fi

  local tmp_mb=$(df -BM /var/tmp | tail -1 | awk '{gsub("M",""); print $4}')
  if [ "$tmp_mb" -ge "$MIN_TMP_MB" ]; then
    ok "/var/tmp: ${tmp_mb}M free"
  else
    warn "/var/tmp: ${tmp_mb}M free — image builds may fail"
    echo "    Fix: sudo mount -o remount,size=3G /var/tmp"
    ((warnings++))
  fi

  # ── Secrets ──
  echo -e "${CYAN}  Secrets${RESET}"
  if [ -f "$SECRETS_FILE" ]; then
    local perms=$(stat -c '%a' "$SECRETS_FILE" 2>/dev/null || stat -f '%Lp' "$SECRETS_FILE" 2>/dev/null)
    if [ "$perms" = "600" ]; then
      ok ".env.secrets (mode $perms)"
    else
      warn ".env.secrets permissions: $perms (should be 600)"
      echo "    Fix: chmod 600 $SECRETS_FILE"
      ((warnings++))
    fi

    if grep -q "CHANGE_ME" "$SECRETS_FILE" 2>/dev/null; then
      fail ".env.secrets contains CHANGE_ME placeholders — edit before deploying"
      echo "    Generate: python3 -c \"import secrets; print(secrets.token_urlsafe(32))\""
      ((errors++))
    else
      ok "No placeholder values in secrets"
    fi
  else
    fail ".env.secrets not found"
    echo "    Setup: cp ${SCRIPT_DIR}/.env.example ${SECRETS_FILE}"
    echo "    Then edit and replace all CHANGE_ME values"
    ((errors++))
  fi

  # ── Admin Image ──
  echo -e "${CYAN}  Image${RESET}"
  if podman image exists localhost/s7-skyqubi-admin:v2.6 2>/dev/null; then
    ok "Admin image: localhost/s7-skyqubi-admin:v2.6"
  elif [ -f "${SCRIPT_DIR}/s7-skyqubi-admin-v2.6.tar" ]; then
    ok "Admin image tar found (will load on deploy)"
    # Verify signature if present. ssh-keygen -Y verify needs an
    # allowed_signers file (principal pubkey), NOT a raw .pub file,
    # so we build one on the fly from s7-image-signing.pub.
    if [ -f "${SCRIPT_DIR}/s7-skyqubi-admin-v2.6.tar.sig" ]; then
      if command -v ssh-keygen &>/dev/null && [ -f "${SCRIPT_DIR}/s7-image-signing.pub" ]; then
        _allowed=$(mktemp)
        printf 's7-skyqubi %s\n' "$(cat "${SCRIPT_DIR}/s7-image-signing.pub")" > "$_allowed"
        if ssh-keygen -Y verify -f "$_allowed" -I s7-skyqubi -n file -s "${SCRIPT_DIR}/s7-skyqubi-admin-v2.6.tar.sig" < "${SCRIPT_DIR}/s7-skyqubi-admin-v2.6.tar" 2>/dev/null; then
          ok "Image signature verified"
        else
          fail "Image signature INVALID — image may be tampered"
          ((errors++))
        fi
        rm -f "$_allowed"
      else
        warn "Signature file present but no public key to verify"
        ((warnings++))
      fi
    fi
  else
    fail "Admin image not found"
    echo "    Place s7-skyqubi-admin-v2.6.tar in ${SCRIPT_DIR}/"
    ((errors++))
  fi

  # ── SQL Init ──
  echo -e "${CYAN}  SQL${RESET}"
  local sql_count=$(ls "${SCRIPT_DIR}/engine/sql/"*.sql 2>/dev/null | wc -l)
  if [ "$sql_count" -ge 1 ]; then
    ok "SQL init scripts: $sql_count files"
  else
    fail "No SQL init scripts in engine/sql/"
    ((errors++))
  fi

  # ── Pod YAML ──
  echo -e "${CYAN}  Config${RESET}"
  if [ -f "$POD_TEMPLATE" ]; then
    ok "skyqubi-pod.yaml"
  else
    fail "skyqubi-pod.yaml not found"
    ((errors++))
  fi

  # ── Port conflicts ──
  echo -e "${CYAN}  Ports${RESET}"
  local conflicts=0
  for port in 57080 57086 57090; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
      # Check if it's our own pod
      if podman pod exists s7-skyqubi 2>/dev/null; then
        ok ":$port (existing S7 pod)"
      else
        fail ":$port already in use by another service"
        ((conflicts++))
      fi
    else
      ok ":$port available"
    fi
  done
  if [ "$conflicts" -gt 0 ]; then
    ((errors++))
  fi

  # ── Results ──
  echo ""
  if [ "$errors" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}PRE-AUDIT FAILED: $errors error(s), $warnings warning(s)${RESET}"
    echo "  Fix the errors above and run again."
    echo ""
    return 1
  elif [ "$warnings" -gt 0 ]; then
    echo -e "  ${YELLOW}${BOLD}PRE-AUDIT PASSED with $warnings warning(s)${RESET}"
    echo ""
    return 0
  else
    echo -e "  ${GREEN}${BOLD}PRE-AUDIT PASSED — system ready${RESET}"
    echo ""
    return 0
  fi
}

# ══════════════════════════════════════════════════════════════════
# PHASE 2: LOAD CONFIG + IMAGE
# ══════════════════════════════════════════════════════════════════
load_config() {
  set -a
  source "$SECRETS_FILE"
  set +a

  export SKYQUBI_STORAGE="${SKYQUBI_STORAGE:-${HOME}/.skyqubi/data}"
  export SKYQUBI_SQL="${SKYQUBI_SQL:-${SCRIPT_DIR}/engine/sql}"
  export PODMAN_SOCK="${PODMAN_SOCK:-/run/user/$(id -u)/podman/podman.sock}"

  mkdir -p "${SKYQUBI_STORAGE}"/{admin,mysql,postgres,redis,qdrant}
}

ensure_image() {
  if podman image exists localhost/s7-skyqubi-admin:v2.6 2>/dev/null; then
    return
  fi
  local tar="${SCRIPT_DIR}/s7-skyqubi-admin-v2.6.tar"
  if [ -f "$tar" ]; then
    info "Loading admin image..."
    podman load -i "$tar"
    ok "Admin image loaded"
  fi
}

# ══════════════════════════════════════════════════════════════════
# PHASE 3: DEPLOY
# ══════════════════════════════════════════════════════════════════
deploy() {
  info "Rendering pod YAML..."
  envsubst < "$POD_TEMPLATE" > "$POD_RENDERED"

  # CRITICAL: --network pasta:-T,auto is REQUIRED. Without it, podman
  # defaults to '-T none' and the admin container cannot reach
  # host:57081 (ollama) — silently breaks Carli/Elias/Samuel and the
  # /witness endpoint. See:
  #   project_pasta_t_none_pod_network_2026_04_13.md
  #   man podman-play-kube
  info "Deploying pod (--network pasta:-T,auto for container→host TCP)..."
  podman play kube --network pasta:-T,auto "$POD_RENDERED"
  rm -f "$POD_RENDERED"
}

# ══════════════════════════════════════════════════════════════════
# PHASE 4: POST-DEPLOY CONFIGURATION
# ══════════════════════════════════════════════════════════════════
post_deploy() {
  info "Waiting for services..."

  for i in $(seq 1 30); do
    podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:7077/status 2>/dev/null | grep -q "CWS" && break
    sleep 1
  done

  for i in $(seq 1 30); do
    podman exec s7-skyqubi-s7-mysql mysqladmin -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" ping 2>/dev/null | grep -q "alive" && break
    sleep 1
  done

  info "Configuring Ollama connection..."
  podman exec s7-skyqubi-s7-mysql mysql -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" -e "
    INSERT INTO kv_store (\`key\`, value, created_at, updated_at)
    VALUES ('ai.remoteOllamaUrl', 'http://host.containers.internal:57081', NOW(), NOW())
    ON DUPLICATE KEY UPDATE value='http://host.containers.internal:57081';

    INSERT INTO kv_store (\`key\`, value, created_at, updated_at)
    VALUES ('ai.assistantCustomName', 'SkyQUBi', NOW(), NOW())
    ON DUPLICATE KEY UPDATE value='SkyQUBi';
  " 2>/dev/null

  info "Fixing service configs..."
  podman exec s7-skyqubi-s7-mysql mysql -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" -e "
    UPDATE services SET container_config = REPLACE(container_config, '/opt/project-nomad/storage', '${SKYQUBI_STORAGE}/admin')
    WHERE container_config LIKE '%/opt/project-nomad/%';

    UPDATE services SET container_config = REPLACE(container_config, '{\"HostPort\":', '{\"HostIp\": \"127.0.0.1\", \"HostPort\":')
    WHERE container_config NOT LIKE '%HostIp%' AND container_config LIKE '%HostPort%';

    UPDATE services SET installed=0, installation_status='not_installed'
    WHERE installed=1 AND service_name IN ('s7_kiwix_server','s7_flatnotes','s7_cyberchef','s7_kolibri');

    UPDATE services SET installed=1, installation_status='idle'
    WHERE service_name IN ('s7_qdrant','s7_ollama');

    UPDATE services SET installed=1, installation_status='idle', container_image='built-in'
    WHERE service_name='s7_skyavi';
  " 2>/dev/null

  ok "Configuration complete"
}

# ══════════════════════════════════════════════════════════════════
# PHASE 5: VERIFY
# ══════════════════════════════════════════════════════════════════
verify() {
  local pass=0 total=0
  check() {
    ((total++))
    if eval "$1" 2>/dev/null | grep -qi "$2"; then
      ok "$3"; ((pass++))
    else
      fail "$3"
    fi
  }

  echo ""
  echo -e "${BOLD}  ── Verification ──${RESET}"
  echo ""
  check "podman pod ps --format '{{.Status}}'" "Running" "Pod running"
  check "podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:7077/status" "CWS Engine" "CWS Engine v2.5"
  check "podman exec s7-skyqubi-s7-postgres pg_isready" "accepting" "PostgreSQL"
  check "podman exec s7-skyqubi-s7-mysql mysqladmin -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ping 2>&1" "alive" "MySQL"
  check "podman exec s7-skyqubi-s7-redis redis-cli ping" "PONG" "Redis"
  check "podman exec s7-skyqubi-s7-admin curl -s http://127.0.0.1:6333/healthz" "passed" "Qdrant"
  check "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:57080/" "302" "Command Center"

  echo ""
  if [ "$pass" -eq "$total" ]; then
    echo -e "  ${GREEN}${BOLD}DEPLOY SUCCESS: ${pass}/${total} verified${RESET}"
  else
    echo -e "  ${RED}${BOLD}DEPLOY PARTIAL: ${pass}/${total} verified${RESET}"
  fi
  echo ""
  echo "  Command Center: http://127.0.0.1:57080"
  echo "  AI Chat:        http://127.0.0.1:57080/chat  (requires Ollama)"
  echo ""
  echo "  Love is the architecture."
  echo ""
}

# ══════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════
echo ""
echo "  S7 SkyQUBi — Sovereign AI Platform"
echo ""

case "${1:-}" in
  --down)
    load_config
    info "Stopping S7 SkyQUBi pod..."
    envsubst < "$POD_TEMPLATE" > "$POD_RENDERED"
    podman play kube --down "$POD_RENDERED" || true
    rm -f "$POD_RENDERED"
    ok "Pod stopped"
    ;;
  --check)
    load_config 2>/dev/null || true
    pre_audit
    ;;
  *)
    pre_audit || exit 1
    load_config
    ensure_image
    deploy
    post_deploy
    verify
    ;;
esac
