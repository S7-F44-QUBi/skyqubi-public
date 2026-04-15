#!/bin/bash
###############################################################################
#  S7 SkyQUBi — One-Command Installer
#  ───────────────────────────────────
#  UNIFIED LINUX SkyCAIR by S7 · 123Tech / 2XR, LLC
#
#  Supports: Fedora (dnf) | Debian/Ubuntu (apt) | Arch (pacman)
#  Runtime:  Podman (preferred) | Docker (fallback)
#
#  Usage:
#    git clone https://github.com/skycair-code/SkyCAIR.git
#    cd SkyCAIR
#    sudo ./install/install.sh
#
#  Love is the architecture.
###############################################################################
set -euo pipefail

RESET='\033[0m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'

ok()     { echo -e "  ${GREEN}✓${RESET} $1"; }
info()   { echo -e "  ${YELLOW}→${RESET} $1"; }
err()    { echo -e "  ${RED}✗${RESET} $1"; }
warn()   { echo -e "  ${YELLOW}⚠${RESET} $1"; }
banner() { echo -e "\n${CYAN}═══════════════════════════════════════════════════${RESET}"; echo -e "  ${CYAN}$1${RESET}"; echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}\n"; }

###############################################################################
#  DETECT ENVIRONMENT
###############################################################################
PKG=""
command -v dnf &>/dev/null && PKG="dnf"
command -v apt-get &>/dev/null && [ -z "$PKG" ] && PKG="apt"
command -v pacman &>/dev/null && [ -z "$PKG" ] && PKG="pacman"

RT=""
command -v podman &>/dev/null && RT="podman"
command -v docker &>/dev/null && [ -z "$RT" ] && RT="docker"

REAL_USER="${SUDO_USER:-$(whoami)}"
REAL_UID=$(id -u "$REAL_USER" 2>/dev/null || echo "1000")
REAL_HOME=$(eval echo "~${REAL_USER}")
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_DIR="/opt/s7"
DATA_DIR="${REAL_HOME}/s7-timecapsule-assets"

banner "S7 SkyQUBi Installer"
echo -e "  ${BOLD}UNIFIED LINUX SkyCAIR by S7${RESET}"
echo -e "  AI + Humanity — Built on Trust"
echo ""
echo -e "  OS:        $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)"
echo -e "  Packages:  ${PKG:-none}"
echo -e "  Container: ${RT:-none}"
echo -e "  User:      ${REAL_USER} (${REAL_UID})"
echo ""

[ "$EUID" -ne 0 ] && { err "Run as root: sudo $0"; exit 1; }

###############################################################################
#  1. INSTALL CONTAINER RUNTIME
###############################################################################
banner "1/7 · Container Runtime"

if [ -z "$RT" ]; then
    info "Installing Podman..."
    case "$PKG" in
        dnf)    dnf install -y podman 2>&1 | tail -3 ;;
        apt)    apt-get install -y podman 2>&1 | tail -3 ;;
        pacman) pacman -S --noconfirm podman 2>&1 | tail -3 ;;
        *)      err "Install podman manually"; exit 1 ;;
    esac
    RT="podman"
fi
ok "${RT} $(${RT} --version 2>/dev/null | head -1)"

# Enable podman socket + lingering
if [ "$RT" = "podman" ]; then
    su - "$REAL_USER" -c "systemctl --user enable --now podman.socket" 2>/dev/null || true
    loginctl enable-linger "$REAL_USER" 2>/dev/null || true
    ok "Podman socket + lingering enabled"
fi

###############################################################################
#  2. INSTALL OLLAMA
###############################################################################
banner "2/7 · Ollama"

if command -v ollama &>/dev/null; then
    ok "Ollama already installed: $(ollama --version 2>/dev/null)"
else
    info "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    ok "Ollama installed"
fi

###############################################################################
#  3. INSTALL SYSTEM PACKAGES
###############################################################################
banner "3/7 · System Packages"

#
# Covenant note (B5 of 24hr ship plan, 2026-04-14):
# nodejs + npm are DELIBERATELY ABSENT from this list. S7 runtime
# has no JavaScript build chain — the dashboard UI ships as
# pre-built artifacts committed to dashboard/ (no 'npm install'
# on the target machine). This honors the 'No NPM at runtime'
# covenant rule and closes the gap that three prior external
# reviews flagged as a critical blocker. If a future component
# requires Node.js, it must ship pre-built OR this comment gets
# a signed amendment from Jamie + Tonya.
#
case "$PKG" in
    dnf)
        # Core: runtime, web/db, language; Desktop: polkit agent, wallpaper, terminal, browser.
        # Browser: firefox is the default fallback (vivaldi-stable is out-of-tree for Fedora).
        dnf install -y \
            caddy python3-pip python3-psycopg2 python3-pyyaml git \
            lxpolkit swaybg kitty firefox \
            2>&1 | tail -5
        ;;
    apt)
        apt-get install -y \
            caddy python3-pip python3-psycopg2 python3-yaml git \
            lxpolkit swaybg kitty firefox-esr \
            2>&1 | tail -5
        ;;
    pacman)
        pacman -S --noconfirm \
            caddy python-pip python-psycopg2 python-yaml git \
            lxpolkit swaybg kitty firefox \
            2>&1 | tail -5
        ;;
esac
ok "System packages installed (runtime + desktop tier, no NPM)"

###############################################################################
#  4. INSTALL PYTHON DEPENDENCIES
###############################################################################
banner "4/7 · Python Dependencies"

pip install --no-cache-dir \
    fastapi uvicorn httpx pydantic pydantic-settings \
    psycopg2-binary python-dotenv 2>&1 | tail -3
ok "CWS Engine dependencies installed"

###############################################################################
#  5. INSTALL S7 FILES
###############################################################################
banner "5/7 · S7 Stack"

# Create directories
mkdir -p "${INSTALL_DIR}"/{engine,services}
mkdir -p "${DATA_DIR}"/{postgres,mysql,redis,qdrant,models,mempalace,logs,nomad-storage}

# Copy engine
cp -r "${REPO_DIR}/engine/"* "${INSTALL_DIR}/engine/"
ok "CWS Engine installed"

# Copy pod YAML
cp "${REPO_DIR}/skyqubi-pod.yaml" "${INSTALL_DIR}/skyqubi-pod.yaml"
cp "${REPO_DIR}/start-pod.sh" "${INSTALL_DIR}/start-pod.sh"
chmod +x "${INSTALL_DIR}/start-pod.sh"
ok "Pod manifest installed"

# Copy Caddyfile
cp "${REPO_DIR}/services/Caddyfile" "${INSTALL_DIR}/Caddyfile"
ok "Caddyfile installed"

# Generate secrets if not present
SECRETS_FILE="${REAL_HOME}/.env.secrets"
if [ ! -f "$SECRETS_FILE" ]; then
    info "Generating secrets..."
    DB_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    MYSQL_ROOT=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    MYSQL_USER=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    APP_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    CWS_TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

    cat > "$SECRETS_FILE" <<EOF
# S7 SkyQUBi Secrets — generated $(date -I)
# DO NOT commit this file to git

DB_PASS=${DB_PASS}
MYSQL_ROOT_PASS=${MYSQL_ROOT}
MYSQL_USER_PASS=${MYSQL_USER}
APP_KEY=${APP_KEY}
LOCAL_IP=${LOCAL_IP:-localhost}
S7_APP_KEY=${APP_KEY}
S7_MYSQL_ROOT_PASSWORD=${MYSQL_ROOT}
S7_MYSQL_PASSWORD=${MYSQL_USER}
S7_PG_PASSWORD=${DB_PASS}
CWS_ENGINE_TOKEN=${CWS_TOKEN}
EOF
    chown "${REAL_USER}:${REAL_USER}" "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    ok "Secrets generated: ${SECRETS_FILE}"
else
    ok "Secrets file exists: ${SECRETS_FILE}"
fi

chown -R "${REAL_USER}:${REAL_USER}" "${INSTALL_DIR}" "${DATA_DIR}"

###############################################################################
#  6. INSTALL SYSTEMD SERVICES
###############################################################################
banner "6/7 · Systemd Services"

USER_UNIT_DIR="${REAL_HOME}/.config/systemd/user"
mkdir -p "${USER_UNIT_DIR}"

for svc in s7-cws-engine s7-caddy s7-ollama s7-skyqubi-pod s7-bitnet-mcp s7-dashboard; do
    src="${REPO_DIR}/services/${svc}.service"
    if [ -f "$src" ]; then
        cp "$src" "${USER_UNIT_DIR}/"
        ok "Installed ${svc}.service"
    fi
done

chown -R "${REAL_USER}:${REAL_USER}" "${USER_UNIT_DIR}"

# Reload and enable core services
su - "$REAL_USER" -c "systemctl --user daemon-reload" 2>/dev/null
su - "$REAL_USER" -c "systemctl --user enable s7-skyqubi-pod.service" 2>/dev/null || true
su - "$REAL_USER" -c "systemctl --user enable s7-cws-engine.service" 2>/dev/null || true
su - "$REAL_USER" -c "systemctl --user enable s7-caddy.service" 2>/dev/null || true
su - "$REAL_USER" -c "systemctl --user enable s7-ollama.service" 2>/dev/null || true
ok "Services enabled"

# Copy autostart entries → USER scope (~/.config/autostart/), not system /etc/xdg/autostart
# Per the 2026-04-13 finish-line plan: autostart belongs in user scope so a non-S7
# user on the same box doesn't get S7 services on their login.
if [ -d "${REPO_DIR}/autostart" ]; then
    AUTOSTART_DIR="${REAL_HOME}/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    copied=0
    for desktop_file in "${REPO_DIR}/autostart/"*.desktop; do
        [ -f "$desktop_file" ] || continue
        cp "$desktop_file" "$AUTOSTART_DIR/"
        copied=$((copied + 1))
    done
    chown -R "${REAL_USER}:${REAL_USER}" "${REAL_HOME}/.config"
    if [ "$copied" -gt 0 ]; then
        ok "Desktop autostart entries installed: $copied file(s) in ~/.config/autostart/"
    else
        warn "autostart/ exists but no .desktop files found — skipping"
    fi
fi

# Copy desktop entries → USER scope. Check that the required S7 launcher exists.
# Fail-fast if s7.desktop is missing from the repo — that's a ship regression.
if [ -d "${REPO_DIR}/desktop" ]; then
    APPS_DIR="${REAL_HOME}/.local/share/applications"
    mkdir -p "$APPS_DIR"
    if [ ! -f "${REPO_DIR}/desktop/s7.desktop" ]; then
        err "REQUIRED: ${REPO_DIR}/desktop/s7.desktop is missing"
        err "This is the S7 launcher Tonya/Trinity use. Installer will not continue."
        exit 1
    fi
    copied=0
    for desktop_file in "${REPO_DIR}/desktop/"*.desktop; do
        [ -f "$desktop_file" ] || continue
        cp "$desktop_file" "$APPS_DIR/"
        copied=$((copied + 1))
    done
    chown -R "${REAL_USER}:${REAL_USER}" "$APPS_DIR"
    ok "Desktop entries installed: $copied file(s) in ~/.local/share/applications/"
fi

###############################################################################
#  7. DEPLOY
###############################################################################
banner "7/7 · Deploy SkyQUBi"

# Start the pod
info "Starting SkyQUBi pod..."
su - "$REAL_USER" -c "cd ${INSTALL_DIR} && bash start-pod.sh" 2>&1 | tail -10

# Wait for containers
info "Waiting for containers..."
for i in $(seq 1 30); do
    RUNNING=$(su - "$REAL_USER" -c "${RT} ps --format '{{.Names}}' 2>/dev/null" | grep -c skyqubi || echo 0)
    if [ "$RUNNING" -ge 4 ] 2>/dev/null; then
        ok "${RUNNING} containers running"
        break
    fi
    sleep 2
done

# Start host services
su - "$REAL_USER" -c "systemctl --user start s7-cws-engine.service" 2>/dev/null || true
su - "$REAL_USER" -c "systemctl --user start s7-caddy.service" 2>/dev/null || true

# Pull a starter model
info "Pulling starter AI model..."
su - "$REAL_USER" -c "ollama pull llama3.2:1b" 2>&1 | tail -3 || warn "Model pull failed — run 'ollama pull llama3.2:1b' manually"

###############################################################################
#  OS BRANDING (optional)
###############################################################################
if [ -d "${REPO_DIR}/os" ] && [ -f "${REPO_DIR}/os/os-release" ]; then
    cp "${REPO_DIR}/os/os-release" /etc/os-release
    ok "S7 os-release branding applied"
fi

if [ -d "${REPO_DIR}/branding/plymouth" ]; then
    mkdir -p /usr/share/plymouth/themes/s7
    cp "${REPO_DIR}/branding/plymouth/"* /usr/share/plymouth/themes/s7/ 2>/dev/null
    ok "Plymouth theme installed"
fi

if [ -d "${REPO_DIR}/branding/wallpapers" ]; then
    mkdir -p /usr/share/backgrounds/s7
    cp "${REPO_DIR}/branding/wallpapers/"* /usr/share/backgrounds/s7/ 2>/dev/null
    ok "Wallpapers installed"
fi

###############################################################################
#  DONE
###############################################################################
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
LOCAL_IP="${LOCAL_IP:-localhost}"

banner "S7 SkyQUBi — INSTALLED"

echo -e "  ${CYAN}Command Center:${RESET}  http://${LOCAL_IP}:57080"
echo -e "  ${CYAN}CWS Engine:${RESET}      http://localhost:57077"
echo -e "  ${CYAN}PostgreSQL:${RESET}       localhost:57090"
echo -e "  ${CYAN}Qdrant:${RESET}           localhost:57086"
echo -e "  ${CYAN}Secrets:${RESET}          ${SECRETS_FILE}"
echo -e "  ${CYAN}Data:${RESET}             ${DATA_DIR}"
echo ""
echo -e "  ${YELLOW}Manage:${RESET}"
echo -e "    Start:   systemctl --user start s7-skyqubi-pod"
echo -e "    Stop:    systemctl --user stop s7-skyqubi-pod"
echo -e "    Status:  ${RT} pod ps"
echo -e "    Models:  ollama pull llama3.2:3b"
echo ""

# ── What to do now — walk-the-user-home block ──────────────────────
# Per the 2026-04-13 finish-line plan, Tonya/Trinity/Noah/Jonathan should
# be able to read this end-of-install output and know exactly what to do
# next without a steward in the room.
cat <<'GUIDE'
  ─── What to do now ────────────────────────────────────────────────
    1. Click "S7" on your desktop (or run: firefox http://localhost:57080)
    2. The S7 Command Center opens in your browser.
    3. First visit: set up your local account. Secrets are already
       generated in ~/.env.secrets (mode 600, do not share).
    4. To chat with Carli/Elias/Samuel: go to the Chat tab.
       On first use, you'll be prompted to pick your persona.
    5. To stop S7 (e.g., before shutting down the laptop):
         systemctl --user stop s7-skyqubi-pod
       To restart:
         systemctl --user start s7-skyqubi-pod
    6. If anything looks off, run the pre-flight check:
         bash install/preflight.sh
       It tells you what's wrong and how to fix it.

  ─── If something breaks ───────────────────────────────────────────
    • The pod won't start    → bash install/preflight.sh
    • Chat is slow           → ollama ps (check if the model is warm)
    • "memory error" banner  → disk full; free space or ask a steward
    • "witness offline"      → the covenant witness is still warming up;
                               wait a minute, reload the chat

  ─── Where things live ─────────────────────────────────────────────
    • S7 code:      /opt/s7/engine
    • Your data:    ~/s7-timecapsule-assets
    • Your secrets: ~/.env.secrets  (mode 600, private to you)
    • Updates:      re-run this installer to get the latest S7

GUIDE

echo -e "  ${GREEN}Love is the architecture.${RESET}"
echo ""
