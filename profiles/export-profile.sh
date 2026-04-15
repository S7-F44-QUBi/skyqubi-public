#!/usr/bin/env bash
# profiles/export-profile.sh
# Capture the current user's S7 desktop state into a portable profile
# directory that import-profile.sh can apply to any other S7 machine.
#
# Usage:
#   ./export-profile.sh                    # exports to profiles/s7-desktop-default/
#   ./export-profile.sh --name custom      # exports to profiles/custom/
#   ./export-profile.sh --help
#
# What gets captured:
#   - dconf dump of /org/gnome/desktop/ + /com/solus-project/budgie-panel/
#     + /org/buddiesofbudgie/ (all the UI config)
#   - ~/.config/kitty/kitty.conf
#   - ~/.local/share/applications/s7-*.desktop
#   - ~/.local/share/desktop-directories/s7-skyqubi.directory
#   - ~/.config/menus/applications-merged/s7-skyqubi.menu
#   - ~/.config/autostart/s7-*.desktop
#   - ~/.config/systemd/user/s7-*.{service,timer}
#   - metadata.yaml with capture timestamp + fingerprint
#
# What does NOT get captured:
#   - Secrets (/s7/.env.secrets, /s7/.config/s7/*)
#   - Signing keys
#   - Git repos
#   - Large binary wallpapers (they live in branding/ already;
#     profile references the canonical path instead)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_NAME="s7-desktop-default"

for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --help|-h) sed -n '2,30p' "$0" | sed 's|^# \?||'; exit 0 ;;
    --name) j=$((i+1)); PROFILE_NAME="${!j}" ;;
  esac
done

DEST="$SCRIPT_DIR/$PROFILE_NAME"
mkdir -p "$DEST"

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "  $*"; }

echo "=== S7 profile export: $PROFILE_NAME ==="
echo "dest: $DEST"
echo

# ── dconf dump (budgie panel, gnome desktop, buddiesofbudgie) ──
log "[1/8] dconf dump → dconf.ini"
{
  echo "# S7 desktop profile — dconf export"
  echo "# Captured: $(timestamp)"
  echo "# Host: $(hostname)"
  echo "# User: $USER"
  echo
  dconf dump /com/solus-project/budgie-panel/       2>/dev/null | sed 's|^|[com/solus-project/budgie-panel/|g'
  echo
  dconf dump /org/gnome/desktop/background/          2>/dev/null | sed 's|^|[org/gnome/desktop/background/|g'
  echo
  dconf dump /org/gnome/desktop/interface/           2>/dev/null | sed 's|^|[org/gnome/desktop/interface/|g'
} > "$DEST/dconf.ini"
# Use the simpler full-path dump format that dconf load actually accepts
dconf dump / 2>/dev/null \
  | grep -E '^\[(com/solus-project/budgie-|org/gnome/desktop/background|org/gnome/desktop/interface|org/buddiesofbudgie/|com/github/ungoogled-software)' -A 100 \
  > "$DEST/dconf.ini" || true
# Simpler, more reliable: dump each subtree into its own file
dconf dump /com/solus-project/budgie-panel/  > "$DEST/dconf-budgie-panel.ini"   2>/dev/null || true
dconf dump /org/gnome/desktop/background/    > "$DEST/dconf-gnome-background.ini" 2>/dev/null || true
dconf dump /org/gnome/desktop/interface/     > "$DEST/dconf-gnome-interface.ini"  2>/dev/null || true
dconf dump /org/buddiesofbudgie/             > "$DEST/dconf-buddiesofbudgie.ini"  2>/dev/null || true
log "  captured 4 dconf subtrees"

# ── kitty config ──
log "[2/8] kitty.conf"
mkdir -p "$DEST/config/kitty"
if [[ -f ~/.config/kitty/kitty.conf ]]; then
  cp ~/.config/kitty/kitty.conf "$DEST/config/kitty/kitty.conf"
  log "  copied ~/.config/kitty/kitty.conf"
else
  log "  (none)"
fi

# ── menu launchers ──
log "[3/8] menu launchers (s7-*.desktop)"
mkdir -p "$DEST/local/share/applications"
found=0
for f in ~/.local/share/applications/s7-*.desktop; do
  [[ -f "$f" ]] || continue
  cp "$f" "$DEST/local/share/applications/"
  found=$((found + 1))
done
log "  copied $found launcher(s)"

# ── menu directory + menu merge ──
log "[4/8] menu structure (s7-skyqubi submenu)"
mkdir -p "$DEST/local/share/desktop-directories"
mkdir -p "$DEST/config/menus/applications-merged"
if [[ -f ~/.local/share/desktop-directories/s7-skyqubi.directory ]]; then
  cp ~/.local/share/desktop-directories/s7-skyqubi.directory \
     "$DEST/local/share/desktop-directories/"
  log "  copied s7-skyqubi.directory"
fi
if [[ -f ~/.config/menus/applications-merged/s7-skyqubi.menu ]]; then
  cp ~/.config/menus/applications-merged/s7-skyqubi.menu \
     "$DEST/config/menus/applications-merged/"
  log "  copied s7-skyqubi.menu"
fi

# ── autostart entries ──
log "[5/8] autostart (~/.config/autostart/s7-*)"
mkdir -p "$DEST/config/autostart"
found=0
for f in ~/.config/autostart/s7-*.desktop; do
  [[ -f "$f" ]] || continue
  cp "$f" "$DEST/config/autostart/"
  found=$((found + 1))
done
log "  copied $found autostart entries"

# ── systemd user units (s7-*) ──
log "[6/8] systemd user units"
mkdir -p "$DEST/config/systemd/user"
found=0
for f in ~/.config/systemd/user/s7-*.service ~/.config/systemd/user/s7-*.timer; do
  [[ -f "$f" ]] || continue
  cp "$f" "$DEST/config/systemd/user/"
  found=$((found + 1))
done
log "  copied $found unit(s)"

# ── background/wallpaper reference ──
log "[7/8] wallpaper reference"
WP=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'")
cat > "$DEST/wallpaper.txt" <<EOF
# S7 desktop wallpaper reference
# import-profile.sh uses this to re-apply the wallpaper via gsettings
picture-uri=$WP
primary-color=$(gsettings get org.gnome.desktop.background primary-color 2>/dev/null | tr -d "'")
picture-options=$(gsettings get org.gnome.desktop.background picture-options 2>/dev/null | tr -d "'")
EOF
log "  $(grep picture-uri= "$DEST/wallpaper.txt" | cut -d= -f2)"

# ── metadata ──
log "[8/8] metadata"
cat > "$DEST/metadata.yaml" <<EOF
name: $PROFILE_NAME
description: S7 SkyQUBi desktop profile — Tonya-approved sandy-sunset palette
captured_at: $(timestamp)
captured_host: $(hostname)
captured_user: $USER
captured_by: profiles/export-profile.sh
sha256:
  dconf-budgie-panel:   $(sha256sum "$DEST/dconf-budgie-panel.ini" 2>/dev/null | awk '{print $1}')
  dconf-gnome-bg:       $(sha256sum "$DEST/dconf-gnome-background.ini" 2>/dev/null | awk '{print $1}')
  dconf-gnome-ui:       $(sha256sum "$DEST/dconf-gnome-interface.ini" 2>/dev/null | awk '{print $1}')
  kitty-conf:           $(sha256sum "$DEST/config/kitty/kitty.conf" 2>/dev/null | awk '{print $1}')
contents:
  - dconf-*.ini
  - config/kitty/kitty.conf
  - local/share/applications/s7-*.desktop
  - local/share/desktop-directories/s7-skyqubi.directory
  - config/menus/applications-merged/s7-skyqubi.menu
  - config/autostart/s7-*.desktop
  - config/systemd/user/s7-*.{service,timer}
  - wallpaper.txt
apply_with: profiles/import-profile.sh --name $PROFILE_NAME
EOF

echo
echo "=== exported ==="
find "$DEST" -type f | sed 's|^|  |'
echo
echo "profile ready at $DEST"
echo "to apply on a new machine: cd profiles && ./import-profile.sh --name $PROFILE_NAME"
