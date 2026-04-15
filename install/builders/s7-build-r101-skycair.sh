#!/usr/bin/env bash
# build/s7-build-r101-skycair.sh
# 1-click builder for S7-R101-SkyCAIR (core-fixed, updates-only OS).
#
# This wraps iso/rocky/slipstream.sh — slipstreams the S7 update payload
# into the Rocky/Fedora Live base ISO and produces a bootable ISO with
# the payload discoverable at /run/initramfs/live/s7-update/.
#
# No sudo needed — rootless throughout (containerized mkisofs, ed25519
# signing with the user's key).
#
# R101 = "Rock 101" — named for the Trinity -1 ROCK foundation.
# Core is fixed, updates flow through the S7 update payload layer.

set -euo pipefail
source /s7/skyqubi-private/install/builders/s7-build-common.sh

FLAVOR="R101"
LOG="$LOG_DIR/s7-build-r101-$(date -u +%Y%m%d-%H%M%S).log"

notify_start "$FLAVOR"

{
  echo "═════════════════════════════════════════════════════"
  echo "  S7-${FLAVOR}-SkyCAIR build"
  echo "  Core Fixed, Updates Only — Trinity -1 ROCK"
  echo "  started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "═════════════════════════════════════════════════════"

  # Run the rocky slipstream (source USB must be mounted)
  if ! [[ -d /run/media/s7/SKYCAIR7 ]]; then
    echo "ERROR: SKYCAIR7 USB is not mounted."
    echo "Plug in the SKYCAIR7 USB and wait for auto-mount, then retry."
    exit 1
  fi

  "$REPO/iso/rocky/slipstream.sh"

  # Rename output
  SRC=$(ls -t "$REPO/iso/rocky/dist"/*.iso 2>/dev/null | head -1)
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
