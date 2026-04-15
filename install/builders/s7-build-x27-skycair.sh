#!/usr/bin/env bash
# build/s7-build-x27-skycair.sh
# 1-click builder for S7-X27-SkyCAIR (modular layered live USB).
#
# This wraps iso/porteux/slipstream.sh and renames the output to
# the S7-branded convention. Designed to be invoked from the desktop
# shortcut in ~/.local/share/applications/s7-build-x27-skycair.desktop
#
# No sudo needed — the slipstream runs entirely rootless (containerized
# mksquashfs + mkisofs, signs with the user's ed25519 key).

set -euo pipefail
source /s7/skyqubi-private/install/builders/s7-build-common.sh

FLAVOR="X27"
LOG="$LOG_DIR/s7-build-x27-$(date -u +%Y%m%d-%H%M%S).log"

notify_start "$FLAVOR"

{
  echo "═════════════════════════════════════════════════════"
  echo "  S7-${FLAVOR}-SkyCAIR build"
  echo "  started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "═════════════════════════════════════════════════════"

  # Run the modular slipstream
  "$REPO/iso/porteux/slipstream.sh"

  # Rename output
  SRC=$(ls -t "$REPO/iso/porteux/dist"/*.iso 2>/dev/null | head -1)
  if [[ -z "$SRC" ]]; then
    echo "FAIL: slipstream produced no .iso"
    exit 1
  fi

  FINAL=$(rebrand_output "$FLAVOR" "$SRC")
  echo
  echo "═════════════════════════════════════════════════════"
  echo "  S7-${FLAVOR}-SkyCAIR build complete"
  echo "  output: $FINAL"
  echo "═════════════════════════════════════════════════════"

  print_flash_instructions "$FINAL"
  notify_success "S7-${FLAVOR}-SkyCAIR" "$FINAL"

} 2>&1 | tee "$LOG"

rc=${PIPESTATUS[0]}
if [[ $rc -ne 0 ]]; then
  notify_fail "S7-${FLAVOR}-SkyCAIR" "$LOG"
  exit $rc
fi
