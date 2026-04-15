#!/usr/bin/env bash
# profiles/import-profile.sh
# Apply an exported S7 desktop profile to the current user. Idempotent —
# re-running is safe. Uses dconf load + file copies + gsettings nudges.
#
# Usage:
#   ./import-profile.sh                    # imports profiles/s7-desktop-default
#   ./import-profile.sh --name custom
#   ./import-profile.sh --dry-run          # show what would change, make no changes
#   ./import-profile.sh --help
#
# Safe to run:
#   - does NOT touch any signing keys, env secrets, git state
#   - does NOT need sudo (per-user install only)
#   - files that already exist at destination get overwritten
#   - budgie-panel is restarted at the end so dconf changes take effect
#
# Requires:
#   - dconf
#   - gsettings
#   - budgie-panel (re-launch at end)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_NAME="s7-desktop-default"
DRY_RUN=false

for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --help|-h) sed -n '2,22p' "$0" | sed 's|^# \?||'; exit 0 ;;
    --name) j=$((i+1)); PROFILE_NAME="${!j}" ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

SRC="$SCRIPT_DIR/$PROFILE_NAME"
[[ -d "$SRC" ]] || { echo "FAIL: profile $SRC not found"; exit 1; }

run() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    echo "  $*"
    eval "$@"
  fi
}

echo "=== S7 profile import: $PROFILE_NAME ==="
echo "source: $SRC"
if $DRY_RUN; then echo "MODE: dry-run"; fi
echo

# ── 1. dconf subtrees ──
echo "[1/6] dconf load"
for f in "$SRC"/dconf-*.ini; do
  [[ -f "$f" ]] || continue
  base=$(basename "$f" .ini | sed 's|^dconf-||' | tr '-' '/')
  path="/$base/"
  # Map shortnames back to real dconf paths
  case "$base" in
    budgie/panel)          path="/com/solus-project/budgie-panel/" ;;
    gnome/background)      path="/org/gnome/desktop/background/" ;;
    gnome/interface)       path="/org/gnome/desktop/interface/" ;;
    buddiesofbudgie)       path="/org/buddiesofbudgie/" ;;
  esac
  run "dconf load '$path' < '$f'"
done

# ── 2. kitty config ──
echo "[2/6] kitty config"
if [[ -f "$SRC/config/kitty/kitty.conf" ]]; then
  run "mkdir -p ~/.config/kitty"
  run "cp '$SRC/config/kitty/kitty.conf' ~/.config/kitty/kitty.conf"
fi

# ── 3. menu launchers ──
echo "[3/6] menu launchers"
if [[ -d "$SRC/local/share/applications" ]]; then
  run "mkdir -p ~/.local/share/applications"
  for f in "$SRC"/local/share/applications/s7-*.desktop; do
    [[ -f "$f" ]] || continue
    run "cp '$f' ~/.local/share/applications/"
  done
fi

# ── 4. menu structure ──
echo "[4/6] menu submenu"
if [[ -f "$SRC/local/share/desktop-directories/s7-skyqubi.directory" ]]; then
  run "mkdir -p ~/.local/share/desktop-directories"
  run "cp '$SRC/local/share/desktop-directories/s7-skyqubi.directory' ~/.local/share/desktop-directories/"
fi
if [[ -f "$SRC/config/menus/applications-merged/s7-skyqubi.menu" ]]; then
  run "mkdir -p ~/.config/menus/applications-merged"
  run "cp '$SRC/config/menus/applications-merged/s7-skyqubi.menu' ~/.config/menus/applications-merged/"
fi

# ── 5. autostart + systemd user units ──
echo "[5/6] autostart + systemd"
if compgen -G "$SRC/config/autostart/s7-*.desktop" >/dev/null; then
  run "mkdir -p ~/.config/autostart"
  for f in "$SRC"/config/autostart/s7-*.desktop; do
    run "cp '$f' ~/.config/autostart/"
  done
fi
if compgen -G "$SRC/config/systemd/user/s7-*" >/dev/null; then
  run "mkdir -p ~/.config/systemd/user"
  for f in "$SRC"/config/systemd/user/s7-*; do
    run "cp '$f' ~/.config/systemd/user/"
  done
  run "systemctl --user daemon-reload"
fi

# ── 6. refresh + restart budgie-panel ──
echo "[6/6] refresh desktop database + restart budgie-panel"
run "update-desktop-database ~/.local/share/applications/ 2>/dev/null || true"
run "nohup budgie-panel --replace >/dev/null 2>&1 & disown"

# ── gsettings wallpaper nudge (explicit, outside dconf) ──
if [[ -f "$SRC/wallpaper.txt" ]]; then
  WP=$(grep '^picture-uri=' "$SRC/wallpaper.txt" | cut -d= -f2-)
  if [[ -n "$WP" ]]; then
    echo "[bonus] wallpaper re-apply via gsettings"
    run "gsettings set org.gnome.desktop.background picture-uri '$WP'"
    run "gsettings set org.gnome.desktop.background picture-uri-dark '$WP'"
  fi
fi

echo
if $DRY_RUN; then
  echo "=== dry-run complete — nothing applied. Re-run without --dry-run. ==="
else
  echo "=== profile $PROFILE_NAME imported. Log out + log back in for full effect. ==="
fi
