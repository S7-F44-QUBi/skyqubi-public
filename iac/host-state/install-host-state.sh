#!/usr/bin/env bash
# iac/host-state/install-host-state.sh
#
# Idempotently install the S7 host-state files on a fresh QUBi appliance.
# Run AFTER the bootc base image is installed and the s7 user has logged
# in at least once (so $HOME exists and is writable).
#
# What this installs:
#   - 5 Quadlet .container files     → ~/.config/containers/systemd/
#   - rootless storage.conf          → ~/.config/containers/storage.conf
#   - TimeCapsule verify systemd unit→ ~/.config/systemd/user/
#   - TimeCapsule verify script      → ~/.local/bin/
#   - 4 desktop entries (S7, S7 Chat, S7 Vivaldi, S7 Browser)
#                                    → ~/.local/share/applications/
#   - chromium sovereign policy      → ~/.var/app/io.github.ungoogled_software.ungoogled_chromium/config/chromium/policies/managed/
#   - vivaldi sovereign policy       → ~/.config/vivaldi/policies/managed/
#   - dconf pinned-launchers value   → set via `dconf write`
#
# Idempotency: safe to re-run. Existing files are overwritten with the
# canonical version from this directory. systemd daemon-reload + dconf
# update happen at the end.
#
# Exit codes:
#   0  installed (or already up to date)
#   1  prerequisite missing (HOME unwritable, dconf missing, etc.)
#   2  partial install (one or more files failed — see stderr)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTSTATE="$SCRIPT_DIR"

err() { echo "FAIL: $*" >&2; FAIL=$((FAIL+1)); }
ok() { echo "  $*"; }
FAIL=0

[[ -n "${HOME:-}" && -w "$HOME" ]] || { echo "FAIL: \$HOME ($HOME) not writable" >&2; exit 1; }
command -v dconf >/dev/null || { echo "FAIL: dconf binary missing" >&2; exit 1; }

echo "═══════════════════════════════════════════════════════════════"
echo "  S7 host-state install"
echo "  source: $HOSTSTATE"
echo "  target: $HOME"
echo "═══════════════════════════════════════════════════════════════"

# 1. Quadlet container files
mkdir -p "$HOME/.config/containers/systemd"
for f in "$HOSTSTATE/containers/systemd"/*.container; do
  cp "$f" "$HOME/.config/containers/systemd/" && ok "installed Quadlet: $(basename "$f")" || err "Quadlet copy failed: $f"
done

# 2. rootless storage.conf (additionalimagestores → /s7/timecapsule/registry/store)
mkdir -p "$HOME/.config/containers"
cp "$HOSTSTATE/containers/storage.conf" "$HOME/.config/containers/storage.conf" && ok "installed storage.conf" || err "storage.conf copy failed"

# 3. TimeCapsule systemd user unit
mkdir -p "$HOME/.config/systemd/user"
cp "$HOSTSTATE/systemd-user/s7-timecapsule-verify.service" "$HOME/.config/systemd/user/" && ok "installed s7-timecapsule-verify.service" || err "verify .service copy failed"

# 4. TimeCapsule verify script
mkdir -p "$HOME/.local/bin"
cp "$HOSTSTATE/local-bin/s7-timecapsule-verify.sh" "$HOME/.local/bin/" && chmod +x "$HOME/.local/bin/s7-timecapsule-verify.sh" && ok "installed s7-timecapsule-verify.sh" || err "verify script copy failed"

# 5. Desktop entries
mkdir -p "$HOME/.local/share/applications"
for f in "$HOSTSTATE/applications"/*.desktop; do
  cp "$f" "$HOME/.local/share/applications/" && ok "installed desktop: $(basename "$f")" || err "desktop copy failed: $f"
done

# 5b. XDG menu category for S7 SkyQUBi (groups all S7 apps under one
#     menu entry). Requires both a .directory file and a .menu merge file.
mkdir -p "$HOME/.local/share/desktop-directories" "$HOME/.config/menus/applications-merged"
cp "$HOSTSTATE/desktop-directories/s7-skyqubi.directory" "$HOME/.local/share/desktop-directories/" && ok "installed s7-skyqubi.directory" || err "directory copy failed"
cp "$HOSTSTATE/menus-applications-merged/s7-skyqubi.menu" "$HOME/.config/menus/applications-merged/" && ok "installed s7-skyqubi.menu" || err "menu copy failed"

# 5c. User profile branding — S7 logo in user icon theme + .face avatar
#     so Settings/About panels and the user profile picture show S7
#     instead of the Fedora fallback.
mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps" "$HOME/.local/share/icons/hicolor/scalable/apps"
cp "$HOSTSTATE/icons-hicolor-256-apps/s7-logo.png" "$HOME/.local/share/icons/hicolor/256x256/apps/" && ok "installed s7-logo.png in user icon theme" || err "s7-logo.png copy failed"
cp "$HOSTSTATE/icons-hicolor-scalable-apps/s7-logo.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/" && ok "installed s7-logo.svg in user icon theme" || err "s7-logo.svg copy failed"
cp "$HOSTSTATE/face/face.png" "$HOME/.face" && ok "installed user avatar" || err "avatar copy failed"
gtk-update-icon-cache -t "$HOME/.local/share/icons/hicolor" 2>/dev/null && ok "refreshed user icon cache" || ok "icon cache refresh skipped (gtk-update-icon-cache missing)"

# 5d. FastFetch config — S7 ASCII logo + system info layout.
#     Replaces the Fedora-glyph fallback with the S7 brand block.
mkdir -p "$HOME/.config/fastfetch"
cp "$HOSTSTATE/fastfetch/config.jsonc" "$HOME/.config/fastfetch/" && ok "installed fastfetch config.jsonc" || err "fastfetch config copy failed"
cp "$HOSTSTATE/fastfetch/s7-logo.txt" "$HOME/.config/fastfetch/" && ok "installed fastfetch s7-logo.txt" || err "fastfetch logo copy failed"

# 5e. Jellyfin S7 branding overlay — twilight purple + sandy sunset + gold,
#     plus civilian-only login disclaimer. Drop-in to the jellyfin config
#     volume; jellyfin reads it natively, no plugin needed.
JF_CONFIG_DIR="$HOME/.local/share/s7-jellyfin/config/config"
if [[ -d "$JF_CONFIG_DIR" ]]; then
  cp "$HOSTSTATE/jellyfin-config/branding.xml" "$JF_CONFIG_DIR/branding.xml" \
    && ok "installed jellyfin S7 branding.xml" \
    || err "jellyfin branding.xml copy failed"
else
  ok "jellyfin config dir not present yet — branding.xml will be applied on first jellyfin start"
fi

# 6. Chromium sovereign policy
mkdir -p "$HOME/.var/app/io.github.ungoogled_software.ungoogled_chromium/config/chromium/policies/managed"
cp "$HOSTSTATE/chromium-policies/s7-sovereign.json" "$HOME/.var/app/io.github.ungoogled_software.ungoogled_chromium/config/chromium/policies/managed/" && ok "installed chromium sovereign policy" || err "chromium policy copy failed"

# 7. Vivaldi sovereign policy
mkdir -p "$HOME/.config/vivaldi/policies/managed"
cp "$HOSTSTATE/vivaldi-policies/s7-sovereign.json" "$HOME/.config/vivaldi/policies/managed/" && ok "installed vivaldi sovereign policy" || err "vivaldi policy copy failed"

# 8. (REMOVED) — Conky desktop widget was here. Removed 2026-04-13:
#    Budgie+Wayland refused to honor either alignment-or-stacking
#    correctly for any own_window_type combination Conky offers.
#    See docs/internal/host-state/2026-04-13-restart-fix-and-icons.md
#    for the trade-off matrix. If a desktop widget is wanted again,
#    it should be a real Wayland layer-shell client (gtk-layer-shell
#    or similar), not Conky.

# 9. dconf — clear both icon-tasklist pinned launchers (no S7 icons by clock).
#    All S7 apps live in the menu under "S7 SkyQUBi", not in the panel.
if dconf write "/com/solus-project/budgie-panel/instance/icon-tasklist/{aa000001-0000-0000-0000-000000000001}/pinned-launchers" "@as []" 2>/dev/null \
   && dconf write "/com/solus-project/budgie-panel/instance/icon-tasklist/{aa000002-0000-0000-0000-000000000002}/pinned-launchers" "@as []" 2>/dev/null; then
  ok "cleared dconf pinned-launchers (no panel icons by design)"
else
  err "dconf pinned-launchers clear failed"
fi

# 10. Refresh systemd + desktop database
systemctl --user daemon-reload && ok "systemctl --user daemon-reload" || err "daemon-reload failed"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null && ok "update-desktop-database" || ok "update-desktop-database (skipped — binary missing)"

echo
echo "═══════════════════════════════════════════════════════════════"
if [[ $FAIL -eq 0 ]]; then
  echo "  install complete — 0 failures"
  echo "  next: enable + start the units you want running:"
  echo "    systemctl --user enable --now s7-kiwix s7-jellyfin s7-cyberchef s7-kolibri s7-flatnotes s7-timecapsule-verify"
  exit 0
else
  echo "  install partial — $FAIL failure(s) above"
  exit 2
fi
