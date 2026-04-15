#!/bin/bash
###############################################################################
#  S7 SkyCAIR — First Boot Setup
#  Runs once on first login after OCI image install (bootc)
#  Creates user secrets and starts services
###############################################################################
set -euo pipefail

SECRETS_FILE="$HOME/.env.secrets"
MARKER="$HOME/.s7-first-boot-done"

[ -f "$MARKER" ] && exit 0

echo "S7 SkyCAIR — First boot setup..."

# Generate secrets if not present
if [ ! -f "$SECRETS_FILE" ]; then
    DB_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    MYSQL_ROOT=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    MYSQL_USER=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    APP_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    CWS_TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

    cat > "$SECRETS_FILE" <<EOF
# S7 SkyQUBi Secrets — generated $(date -I)
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
    chmod 600 "$SECRETS_FILE"
fi

# Create data directories
mkdir -p "$HOME/s7-timecapsule-assets"/{postgres,mysql,redis,qdrant,models,mempalace,logs,nomad-storage}

# Enable and start services
systemctl --user daemon-reload
systemctl --user enable --now s7-skyqubi-pod.service 2>/dev/null || true
systemctl --user enable --now s7-cws-engine.service 2>/dev/null || true
systemctl --user enable --now s7-caddy.service 2>/dev/null || true
systemctl --user enable --now s7-ollama.service 2>/dev/null || true

# Pull starter model
ollama pull llama3.2:1b 2>/dev/null &

touch "$MARKER"
echo "S7 SkyCAIR — Ready. Love is the architecture."
