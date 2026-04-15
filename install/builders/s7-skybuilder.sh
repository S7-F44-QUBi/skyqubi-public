#!/usr/bin/env bash
# install/builders/s7-skybuilder.sh
# S7 SkyBuilder — one door, three USB flavors.
#
# Launched from the S7 SkyQUBi menu entry "S7 SkyBuilder".
# Opens a numbered picker. Pick a number, the corresponding builder runs
# in this same terminal so Tonya/Trinity see the progress live.
#
# Keep this file tight: add a menu item, add an action, that's it.

set -uo pipefail

REPO=/s7/skyqubi-private
BUILDERS="$REPO/install/builders"

clear
cat <<'EOF'
═════════════════════════════════════════════════════════════
      ███████╗███████╗    ███████╗██╗  ██╗██╗   ██╗
      ██╔════╝╚════██║    ██╔════╝██║ ██╔╝╚██╗ ██╔╝
      ███████╗    ██╔╝    ███████╗█████╔╝  ╚████╔╝
      ╚════██║   ██╔╝     ╚════██║██╔═██╗   ╚██╔╝
      ███████║   ██║      ███████║██║  ██╗   ██║
      ╚══════╝   ╚═╝      ╚══════╝╚═╝  ╚═╝   ╚═╝
                    SkyBuilder — one door

  Builds a signed S7 USB image, then hand off to
  Fedora Media Writer to flash it to a USB stick.

═════════════════════════════════════════════════════════════
EOF

while true; do
  echo
  echo "  USB Builders"
  echo "   [1] S7-X27-SkyCAIR   — modular layered live   (Trinity 0 DOOR)"
  echo "   [2] S7-F44-SkyCAIR   — full installer         (Trinity +1 REST)"
  echo "   [3] S7-R101-SkyCAIR  — core-fixed updates     (Trinity -1 ROCK)"
  echo
  echo "  Admin"
  echo "   [o] Open build/output/  (where signed ISOs land)"
  echo "   [l] Tail latest build log"
  echo "   [f] Launch Fedora Media Writer"
  echo
  echo "   [q] Quit"
  echo
  read -rp "  Pick: " choice
  echo

  case "$choice" in
    1) "$BUILDERS/s7-build-x27-skycair.sh"; read -rp "Press Enter to return to menu " _ ;;
    2) "$BUILDERS/s7-build-f44-skycair.sh"; read -rp "Press Enter to return to menu " _ ;;
    3) "$BUILDERS/s7-build-r101-skycair.sh"; read -rp "Press Enter to return to menu " _ ;;
    o|O)
      xdg-open "$REPO/build/output/" >/dev/null 2>&1 &
      echo "  opened $REPO/build/output/ in the file manager"
      ;;
    l|L)
      latest=$(\ls -t "$REPO/build/logs/"*.log 2>/dev/null | head -1)
      if [[ -n "$latest" ]]; then
        echo "  tailing $latest  (Ctrl+C to return)"
        tail -n 50 -f "$latest" || true
      else
        echo "  no build logs yet"
      fi
      ;;
    f|F)
      if command -v mediawriter >/dev/null 2>&1; then
        nohup mediawriter >/dev/null 2>&1 &
        echo "  launched Fedora Media Writer"
      else
        echo "  Fedora Media Writer not installed."
        echo "  Install with:  sudo dnf install mediawriter"
      fi
      ;;
    q|Q|"") echo "  ok."; exit 0 ;;
    *) echo "  unknown choice: $choice" ;;
  esac
done
