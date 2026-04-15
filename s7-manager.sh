#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Service Manager
# Manage pod, Ollama, and CWS Engine from a single terminal menu.
# Usage: ./s7-manager.sh [start|stop|restart|status]
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
SECRETS_FILE="${SKYQUBI_SECRETS:-/s7/.env.secrets}"
POD_YAML="${SCRIPT_DIR}/skyqubi-pod.yaml"
POD_RENDERED="/tmp/s7-skyqubi-pod-rendered.yaml"
ENGINE_DIR="${SCRIPT_DIR}/engine"

S7_BLUE='\033[38;5;75m'
S7_CYAN='\033[38;5;38m'
S7_GREEN='\033[38;5;40m'
S7_RED='\033[38;5;196m'
S7_AMBER='\033[38;5;214m'
S7_RESET='\033[0m'
S7_BOLD='\033[1m'

banner() {
  echo -e "${S7_BLUE}${S7_BOLD}"
  echo "  ╔═══════════════════════════════════════════╗"
  echo "  ║   S7 SkyQUBi — Service Manager            ║"
  echo "  ║   123Tech / 2XR LLC                       ║"
  echo "  ╚═══════════════════════════════════════════╝"
  echo -e "${S7_RESET}"
}

load_env() {
  if [[ -f "$SECRETS_FILE" ]]; then
    set -a
    source "$SECRETS_FILE"
    set +a
  elif [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
  fi
  # Auto-detect paths if not set
  export SKYQUBI_STORAGE="${SKYQUBI_STORAGE:-${HOME}/.skyqubi/data}"
  export SKYQUBI_SQL="${SKYQUBI_SQL:-${SCRIPT_DIR}/engine/sql}"
  export PODMAN_SOCK="${PODMAN_SOCK:-/run/user/$(id -u)/podman/podman.sock}"
  mkdir -p "${SKYQUBI_STORAGE}"/{admin,mysql,postgres,redis,qdrant}
}

render_pod_yaml() {
  envsubst < "$POD_YAML" > "$POD_RENDERED"
}

# ── Service: Pod ─────────────────────────────────────────────────────
pod_start() {
  if podman pod exists s7-skyqubi 2>/dev/null; then
    local state
    state=$(podman pod inspect s7-skyqubi --format '{{.State}}' 2>/dev/null || echo "unknown")
    if [[ "$state" == "Running" ]]; then
      echo -e "${S7_GREEN}Pod already running.${S7_RESET}"
      return
    fi
    echo -e "${S7_CYAN}Pod exists but stopped — removing and recreating...${S7_RESET}"
    podman play kube --down "$POD_YAML" 2>/dev/null || true
    podman pod rm -f s7-skyqubi 2>/dev/null || true
  fi
  echo -e "${S7_CYAN}Starting S7 SkyQUBi pod...${S7_RESET}"
  load_env
  render_pod_yaml
  podman play kube "$POD_RENDERED"
  rm -f "$POD_RENDERED"
  echo -e "${S7_GREEN}Pod started.${S7_RESET}"
}

pod_stop() {
  echo -e "${S7_AMBER}Stopping S7 SkyQUBi pod...${S7_RESET}"
  load_env
  render_pod_yaml
  podman play kube --down "$POD_RENDERED" || true
  rm -f "$POD_RENDERED"
  echo -e "${S7_GREEN}Pod stopped.${S7_RESET}"
}

pod_status() {
  echo -e "${S7_CYAN}Pod status:${S7_RESET}"
  podman pod ps --format "table {{.Name}}\t{{.Status}}\t{{.Containers}}" 2>/dev/null || echo "  (no pods running)"
  echo -e "${S7_CYAN}Containers:${S7_RESET}"
  podman ps --pod --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  (none)"
}

# ── Service: Ollama ───────────────────────────────────────────────────
ollama_start() {
  if pgrep -x ollama &>/dev/null; then
    echo -e "${S7_AMBER}Ollama already running.${S7_RESET}"
    return
  fi
  echo -e "${S7_CYAN}Starting Ollama on :7081...${S7_RESET}"
  OLLAMA_HOST=0.0.0.0:7081 ollama serve &>/tmp/s7-ollama.log &
  disown
  sleep 1
  pgrep -x ollama &>/dev/null && echo -e "${S7_GREEN}Ollama started.${S7_RESET}" || echo -e "${S7_RED}Ollama failed to start — check /tmp/s7-ollama.log${S7_RESET}"
}

ollama_stop() {
  echo -e "${S7_AMBER}Stopping Ollama...${S7_RESET}"
  pkill -x ollama 2>/dev/null && echo -e "${S7_GREEN}Ollama stopped.${S7_RESET}" || echo -e "  (Ollama was not running)"
}

ollama_status() {
  if pgrep -x ollama &>/dev/null; then
    echo -e "${S7_GREEN}Ollama: RUNNING${S7_RESET} (port 7081)"
  else
    echo -e "${S7_RED}Ollama: STOPPED${S7_RESET}"
  fi
}

# ── Service: CWS Engine ──────────────────────────────────────────────
engine_pid_file="/tmp/s7-cws-engine.pid"

engine_start() {
  if [[ -f "$engine_pid_file" ]] && kill -0 "$(cat "$engine_pid_file")" 2>/dev/null; then
    echo -e "${S7_AMBER}CWS Engine already running (pid $(cat "$engine_pid_file")).${S7_RESET}"
    return
  fi
  load_env
  if [[ -z "${CWS_ENGINE_TOKEN:-}" ]]; then
    echo -e "${S7_RED}ERROR: CWS_ENGINE_TOKEN not set in $ENV_FILE${S7_RESET}"
    return 1
  fi
  echo -e "${S7_CYAN}Starting CWS Engine on 127.0.0.1:57077...${S7_RESET}"
  (
    export CWS_ENGINE_TOKEN
    export S7_PG_PASSWORD
    cd "$ENGINE_DIR"
    python3 -m uvicorn s7_server:app --host 127.0.0.1 --port 57077 \
      &>/tmp/s7-cws-engine.log &
    echo $! > "$engine_pid_file"
  )
  sleep 1
  if [[ -f "$engine_pid_file" ]] && kill -0 "$(cat "$engine_pid_file")" 2>/dev/null; then
    echo -e "${S7_GREEN}CWS Engine started (pid $(cat "$engine_pid_file")).${S7_RESET}"
  else
    echo -e "${S7_RED}CWS Engine failed — check /tmp/s7-cws-engine.log${S7_RESET}"
  fi
}

engine_stop() {
  echo -e "${S7_AMBER}Stopping CWS Engine...${S7_RESET}"
  if [[ -f "$engine_pid_file" ]]; then
    kill "$(cat "$engine_pid_file")" 2>/dev/null && rm -f "$engine_pid_file" \
      && echo -e "${S7_GREEN}CWS Engine stopped.${S7_RESET}" \
      || echo "  (process already gone)"
  else
    pkill -f "s7_server:app" 2>/dev/null && echo -e "${S7_GREEN}CWS Engine stopped.${S7_RESET}" \
      || echo "  (CWS Engine was not running)"
  fi
}

engine_status() {
  if [[ -f "$engine_pid_file" ]] && kill -0 "$(cat "$engine_pid_file")" 2>/dev/null; then
    echo -e "${S7_GREEN}CWS Engine: RUNNING${S7_RESET} (pid $(cat "$engine_pid_file"), port 57077)"
    return
  fi
  local found=""
  found=$(pgrep -f "uvicorn.*s7_server:app" 2>/dev/null || true)
  found="${found%%$'\n'*}"
  if [[ -n "$found" ]]; then
    echo "$found" > "$engine_pid_file"
    echo -e "${S7_GREEN}CWS Engine: RUNNING${S7_RESET} (pid $found, port 57077, adopted)"
  else
    echo -e "${S7_RED}CWS Engine: STOPPED${S7_RESET}"
  fi
}

# ── All-in-one ────────────────────────────────────────────────────────
start_all() {
  pod_start
  echo ""
  ollama_start
  echo ""
  engine_start
}

stop_all() {
  engine_stop
  echo ""
  ollama_stop
  echo ""
  pod_stop
}

restart_all() {
  stop_all
  echo ""
  sleep 2
  start_all
}

status_all() {
  echo -e "${S7_BOLD}── Pod ─────────────────────────────────────────${S7_RESET}"
  pod_status
  echo ""
  echo -e "${S7_BOLD}── Ollama ──────────────────────────────────────${S7_RESET}"
  ollama_status
  echo ""
  echo -e "${S7_BOLD}── CWS Engine ──────────────────────────────────${S7_RESET}"
  engine_status
}

# ── Doctor subcommand ────────────────────────────────────────────────
# One-shot platform health check. Runs independent checks and prints a
# pass/fail/warn summary. Use this when something feels off — it's
# faster than remembering 10 different commands.
doctor_s7() {
  local repo="/s7/skyqubi-private"
  local fail=0 warn=0 pass=0

  ok()   { echo -e "  ${S7_GREEN}[PASS]${S7_RESET} $*"; pass=$((pass+1)); }
  flag() { echo -e "  ${S7_RED}[FAIL]${S7_RESET} $*"; fail=$((fail+1)); }
  warn() { echo -e "  ${S7_AMBER}[WARN]${S7_RESET} $*"; warn=$((warn+1)); }

  echo -e "${S7_BOLD}── S7 doctor ──────────────────────────────────${S7_RESET}"

  # 1. repo present + clean + in sync
  echo -e "${S7_BOLD}[1/8] private repo${S7_RESET}"
  if [[ -d "$repo/.git" ]]; then
    if (cd "$repo" && git diff-index --quiet HEAD -- 2>/dev/null); then
      ok "working tree clean"
    else
      warn "working tree has uncommitted changes — 'cd $repo && git status'"
    fi
    (cd "$repo" && git fetch origin main 2>/dev/null) || true
    local behind
    behind=$(cd "$repo" && git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
    if [[ "$behind" -eq 0 ]]; then
      ok "in sync with origin/main"
    else
      warn "$behind commit(s) behind origin/main — run: $0 update"
    fi
  else
    flag "$repo is not a git repo"
  fi

  # 2. signing key sovereign + usable
  echo -e "${S7_BOLD}[2/8] signing key${S7_RESET}"
  if [[ -x "$repo/iac/keyops/verify-key.sh" ]]; then
    if "$repo/iac/keyops/verify-key.sh" >/dev/null 2>&1; then
      ok "iac/keyops/verify-key.sh verdict: PASS"
    else
      flag "iac/keyops/verify-key.sh returned non-zero — run it directly for details"
    fi
  else
    warn "iac/keyops/verify-key.sh not present — key health unchecked"
  fi

  # 3. pod running
  echo -e "${S7_BOLD}[3/8] s7-skyqubi pod${S7_RESET}"
  if command -v podman >/dev/null 2>&1; then
    if podman pod exists s7-skyqubi 2>/dev/null; then
      local pod_state
      pod_state=$(podman pod inspect s7-skyqubi --format '{{.State}}' 2>/dev/null)
      if [[ "$pod_state" == "Running" ]]; then
        ok "pod s7-skyqubi state=Running"
      else
        flag "pod s7-skyqubi state=$pod_state"
      fi
      local running
      running=$(podman ps --filter "pod=s7-skyqubi" --format '{{.Names}}' 2>/dev/null | wc -l)
      if [[ "$running" -ge 4 ]]; then
        ok "$running container(s) running in pod"
      else
        flag "only $running container(s) running — expected ≥4"
      fi
    else
      flag "pod s7-skyqubi does not exist — run: $0 start"
    fi
  else
    flag "podman not installed"
  fi

  # 4. engine health (if pod is up)
  echo -e "${S7_BOLD}[4/8] engine health${S7_RESET}"
  local engine_code
  engine_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://127.0.0.1:57088/health 2>/dev/null || echo "000")
  if [[ "$engine_code" == "200" ]]; then
    ok "engine :57088/health HTTP 200"
  else
    flag "engine :57088/health HTTP $engine_code"
  fi

  # 5. systemd user services
  echo -e "${S7_BOLD}[5/8] systemd user services${S7_RESET}"
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user is-active s7-update-check.timer >/dev/null 2>&1; then
      ok "s7-update-check.timer active"
    else
      warn "s7-update-check.timer not active — run: systemctl --user enable --now s7-update-check.timer"
    fi
  else
    warn "systemctl not available — cannot check user services"
  fi

  # 6. public site live (any 2xx/3xx counts — skyqubi.com sends 301 to www)
  echo -e "${S7_BOLD}[6/8] public site${S7_RESET}"
  local site_code
  site_code=$(curl -sL -o /dev/null -w "%{http_code}" --max-time 5 https://skyqubi.com/ 2>/dev/null || echo "000")
  if [[ "$site_code" =~ ^(200|301|302|304)$ ]]; then
    ok "skyqubi.com HTTP $site_code"
  else
    warn "skyqubi.com HTTP $site_code (network or upstream)"
  fi

  # 7. wallpaper applied (Tonya-approved OCTi)
  echo -e "${S7_BOLD}[7/8] desktop wallpaper${S7_RESET}"
  if command -v gsettings >/dev/null 2>&1; then
    local wp
    wp=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null || echo "")
    if [[ "$wp" == *"s7-octi-wallpaper"* ]]; then
      ok "OCTi wallpaper active"
    else
      warn "wallpaper is not the OCTi version: $wp"
    fi
  else
    warn "gsettings not available — cannot check wallpaper"
  fi

  # 8. iac/ pipeline present + healthy
  echo -e "${S7_BOLD}[8/8] iac/ pipeline${S7_RESET}"
  if [[ -x "$repo/iac/build-s7-base.sh" ]]; then
    ok "iac/build-s7-base.sh present"
    if [[ -f "$repo/iac/trusted-upstream-hashes.txt" ]]; then
      local n
      n=$(wc -l < "$repo/iac/trusted-upstream-hashes.txt")
      ok "$n trusted upstream hash(es) recorded"
    else
      warn "no trusted-upstream-hashes.txt — first build will create it"
    fi
    if podman image exists localhost/s7-fedora-base:latest 2>/dev/null; then
      ok "localhost/s7-fedora-base:latest loaded"
    else
      warn "s7-fedora-base image not loaded — run: cd $repo/iac && ./build-s7-base.sh"
    fi
  else
    warn "iac/ pipeline not present"
  fi

  # ── Verdict ──
  echo -e "${S7_BOLD}───────────────────────────────────────────────${S7_RESET}"
  if [[ "$fail" -eq 0 && "$warn" -eq 0 ]]; then
    echo -e "  ${S7_GREEN}${S7_BOLD}VERDICT: HEALTHY${S7_RESET}  ($pass pass, 0 warn, 0 fail)"
    return 0
  elif [[ "$fail" -eq 0 ]]; then
    echo -e "  ${S7_AMBER}${S7_BOLD}VERDICT: OK WITH WARNINGS${S7_RESET}  ($pass pass, $warn warn, 0 fail)"
    return 0
  else
    echo -e "  ${S7_RED}${S7_BOLD}VERDICT: NEEDS ATTENTION${S7_RESET}  ($pass pass, $warn warn, $fail fail)"
    return 1
  fi
}

# ── Update subcommand ────────────────────────────────────────────────
# Pulls the latest from the private repo. Does NOT auto-apply — per
# the covenant, updates require a human decision. If the pull brings
# in changes to iac/ or the root Containerfile, the user is told to
# rerun the relevant build step.
update_s7() {
  local repo="/s7/skyqubi-private"
  echo -e "${S7_BOLD}── S7 update check ────────────────────────────${S7_RESET}"
  if [[ ! -d "$repo/.git" ]]; then
    echo -e "${S7_RED}Not a git repo: $repo${S7_RESET}"
    return 1
  fi

  cd "$repo" || return 1

  # Guard: refuse if working tree dirty (don't clobber Jamie's WIP)
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "${S7_RED}Working tree has uncommitted changes — refusing to pull.${S7_RESET}"
    echo "  Commit or stash first:"
    echo "    git status --short"
    return 1
  fi

  local before
  before=$(git rev-parse HEAD)
  echo "  before: $before"

  echo "  fetching..."
  if ! git fetch origin 2>&1 | sed 's/^/    /'; then
    echo -e "${S7_RED}  fetch failed${S7_RESET}"
    return 1
  fi

  local behind
  behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")
  if [[ "$behind" -eq 0 ]]; then
    echo -e "${S7_GREEN}  already up to date${S7_RESET}"
    return 0
  fi

  echo "  $behind new commit(s) on origin/main:"
  git log --oneline HEAD..origin/main | sed 's/^/    /'

  echo ""
  read -rp "  Pull and apply? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "  skipped — no changes applied"
    return 0
  fi

  if ! git pull --ff-only origin main 2>&1 | sed 's/^/    /'; then
    echo -e "${S7_RED}  pull failed — manual resolution required${S7_RESET}"
    return 1
  fi
  local after
  after=$(git rev-parse HEAD)
  echo "  after:  $after"

  # Detect categories of changes so the operator knows what to rerun
  local changed
  changed=$(git diff --name-only "$before" "$after")
  local need_iac_build=false
  local need_pod_restart=false
  local need_site_sync=false

  echo "$changed" | grep -q '^iac/'                      && need_iac_build=true
  echo "$changed" | grep -qE '^(engine/|services/|skyqubi-pod.yaml|start-pod.sh)' && need_pod_restart=true
  echo "$changed" | grep -q '^docs/public/'              && need_site_sync=true

  echo ""
  echo -e "${S7_BOLD}  next steps:${S7_RESET}"
  if $need_iac_build; then
    echo -e "    ${S7_CYAN}iac/ changed${S7_RESET} → run:  cd iac && ./build-s7-base.sh --tag v\$(date -u +%Y.%m.%d)"
  fi
  if $need_pod_restart; then
    echo -e "    ${S7_CYAN}pod sources changed${S7_RESET} → run:  $0 restart"
  fi
  if $need_site_sync; then
    echo -e "    ${S7_CYAN}public docs changed${S7_RESET} → run:  ./s7-sync-public.sh"
  fi
  if ! $need_iac_build && ! $need_pod_restart && ! $need_site_sync; then
    echo "    no runtime changes — update complete"
  fi

  # Log to systemd-cat if available, for audit trail
  if command -v systemd-cat >/dev/null 2>&1; then
    echo "s7-manager update: $before → $after ($behind commits)" | systemd-cat -t s7-manager -p info
  fi
  return 0
}

# ── Interactive menu ──────────────────────────────────────────────────
interactive_menu() {
  banner
  status_all
  echo ""
  echo -e "${S7_BOLD}  What would you like to do?${S7_RESET}"
  echo "  1) Start all services"
  echo "  2) Stop all services"
  echo "  3) Restart all services"
  echo "  4) Refresh status"
  echo "  5) Start pod only"
  echo "  6) Stop pod only"
  echo "  7) Start Ollama only"
  echo "  8) Stop Ollama only"
  echo "  9) Start CWS Engine only"
  echo " 10) Stop CWS Engine only"
  echo "  q) Quit"
  echo ""
  read -rp "  Choice: " choice
  echo ""
  case "$choice" in
    1) start_all ;;
    2) stop_all ;;
    3) restart_all ;;
    4) interactive_menu ;;
    5) pod_start ;;
    6) pod_stop ;;
    7) ollama_start ;;
    8) ollama_stop ;;
    9) engine_start ;;
    10) engine_stop ;;
    q|Q) echo "Goodbye." ; exit 0 ;;
    *) echo -e "${S7_RED}Unknown option.${S7_RESET}" ;;
  esac
  echo ""
  echo -e "  ${S7_CYAN}Press any key to return to menu...${S7_RESET}"
  read -rn1
  interactive_menu
}

# ── Entry point ───────────────────────────────────────────────────────
case "${1:-menu}" in
  start)   banner; start_all ;;
  stop)    banner; stop_all ;;
  restart) banner; restart_all ;;
  status)  banner; status_all ;;
  update)  banner; update_s7 ;;
  doctor)  banner; doctor_s7 ;;
  menu|"") interactive_menu ;;
  *)
    echo "Usage: $0 [start|stop|restart|status|update|doctor|menu]"
    exit 1
    ;;
esac
