#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Apply Tonya-approved theme system-wide
#
# This script applies the sandy sunset palette to:
#   • Plymouth boot splash (s7-qubi theme in /usr/share/plymouth/themes/)
#   • GRUB boot menu background
#   • Desktop wallpaper (via gsettings for the user running this script)
#
# Canonical source of truth for colors: branding/palette.json
# Source design: Tonya + Trinity approved 2026-04-12
#
# REQUIRES SUDO. Parts that touch /usr/share, /etc, and run dracut.
# Parts that only affect the current user (gsettings) run without sudo.
#
# Usage:
#   ./apply-theme.sh          – dry run, shows what would change
#   sudo ./apply-theme.sh -y  – actually apply
#
# After a successful apply, reboot to see the new Plymouth splash.
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

REPO="/s7/skyqubi-private"
BRAND="$REPO/branding"
PLYMOUTH_DEST="/usr/share/plymouth/themes/s7-qubi"

DRY_RUN=true
if [[ "${1:-}" == "-y" ]]; then DRY_RUN=false; fi

run() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    echo "  $*"
    eval "$@"
  fi
}

echo "═══════════════════════════════════════════════════════"
echo "  S7 SkyQUBi — Applying Tonya-approved theme"
if $DRY_RUN; then echo "  MODE: dry-run (use 'sudo ./apply-theme.sh -y' to apply)"; fi
echo "═══════════════════════════════════════════════════════"
echo

# ── Check we're running from the right place ─────────────────────
if [[ ! -f "$BRAND/palette.json" ]]; then
  echo "ERROR: palette.json not found at $BRAND/palette.json"
  echo "Run this script from $BRAND or ensure the private repo is at $REPO"
  exit 1
fi

# ── 1. Plymouth theme files ──────────────────────────────────────
echo "[1/5] Plymouth theme → $PLYMOUTH_DEST"
if ! $DRY_RUN && [[ $EUID -ne 0 ]]; then
  echo "  Plymouth install requires sudo. Re-run as: sudo $0 -y"
  exit 1
fi
run "mkdir -p $PLYMOUTH_DEST"
run "cp $BRAND/plymouth/s7-qubi.script $PLYMOUTH_DEST/"
run "cp $BRAND/plymouth/progress_bar.png $PLYMOUTH_DEST/"
run "cp $BRAND/plymouth/progress_box.png $PLYMOUTH_DEST/"
# Only copy watermark/logo if they exist and have been regenerated for new palette
if [[ -f "$BRAND/plymouth/s7-plymouth-watermark.png" ]]; then
  run "cp $BRAND/plymouth/s7-plymouth-watermark.png $PLYMOUTH_DEST/watermark.png"
fi
if [[ -f "$BRAND/plymouth/s7-plymouth-logo.png" ]]; then
  run "cp $BRAND/plymouth/s7-plymouth-logo.png $PLYMOUTH_DEST/logo.png"
fi

# ── 2. Plymouth theme config ─────────────────────────────────────
echo "[2/5] Plymouth default theme"
run "plymouth-set-default-theme s7-qubi"

# ── 3. Rebuild initrd (takes 1-2 min) ────────────────────────────
echo "[3/5] Rebuilding initrd (dracut --force)"
run "dracut --force"

# ── 4. GRUB background ───────────────────────────────────────────
echo "[4/5] GRUB background"
if [[ -f "$BRAND/grub/s7-grub-background.png" ]]; then
  run "cp $BRAND/grub/s7-grub-background.png /boot/grub2/themes/s7/background.png 2>/dev/null || true"
fi

# ── 5. Desktop wallpaper (per-user, no sudo needed) ─────────────
echo "[5/5] Desktop wallpaper (current user only)"
SUDO_USER_REAL="${SUDO_USER:-$USER}"
WALLP="$BRAND/wallpapers/s7-octi-wallpaper-3840x2160.png"
if [[ -f "$WALLP" ]]; then
  # Run gsettings as the invoking user, not root
  run "sudo -u $SUDO_USER_REAL DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u $SUDO_USER_REAL)/bus gsettings set org.gnome.desktop.background picture-uri 'file://$WALLP'"
  run "sudo -u $SUDO_USER_REAL DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u $SUDO_USER_REAL)/bus gsettings set org.gnome.desktop.background picture-uri-dark 'file://$WALLP'"
  run "sudo -u $SUDO_USER_REAL DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u $SUDO_USER_REAL)/bus gsettings set org.gnome.desktop.background picture-options 'zoom'"
  run "sudo -u $SUDO_USER_REAL DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u $SUDO_USER_REAL)/bus gsettings set org.gnome.desktop.background primary-color '#1a0f1c'"
fi

echo
echo "═══════════════════════════════════════════════════════"
if $DRY_RUN; then
  echo "  Dry-run complete. Re-run with 'sudo $0 -y' to apply."
else
  echo "  Theme applied. Reboot to see the new Plymouth splash."
  echo "  Desktop wallpaper should already be updated (no reboot)."
fi
echo "═══════════════════════════════════════════════════════"
