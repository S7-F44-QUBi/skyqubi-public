#!/usr/bin/env bash
# build/s7-build-common.sh
# Shared helpers for the 1-click S7 USB builders.
# Sourced by s7-build-x27-skycair.sh, s7-build-f44-skycair.sh, s7-build-r101-skycair.sh.

REPO=/s7/skyqubi-private
TAG="v$(date -u +%Y.%m.%d)"
LOG_DIR="$REPO/build/logs"
mkdir -p "$LOG_DIR"

notify_start() {
  local flavor="$1"
  notify-send -u normal -i system-software-install \
    "S7 Build: $flavor starting" \
    "Building $flavor-SkyCAIR-$TAG.iso ... this takes a few minutes." 2>/dev/null || true
}

notify_success() {
  local flavor="$1"
  local iso="$2"
  local size=$(du -h "$iso" 2>/dev/null | cut -f1)
  notify-send -u normal -i emblem-default -t 20000 \
    "✓ S7 Build complete: $flavor" \
    "Ready at $iso ($size)\n\nNext: open Fedora Media Writer → Custom Image → this ISO → flash to USB." 2>/dev/null || true
}

# Print the flash-to-USB next-steps block at the end of a build
print_flash_instructions() {
  local iso="$1"
  cat <<EOF

═════════════════════════════════════════════════════
  Flash to USB with Fedora Media Writer
═════════════════════════════════════════════════════

  1. Open Fedora Media Writer  (menu → Fedora Media Writer)
     If missing:  sudo dnf install mediawriter

  2. Click "Custom Image" and pick:
     $iso

  3. Pick your USB, click Write, wait.

  4. Eject and boot the target machine from the USB.

  (Advanced: one-USB multiboot via iso/skyloop/ — full custody path.)

EOF
}

notify_fail() {
  local flavor="$1"
  local log="$2"
  notify-send -u critical -i dialog-error -t 30000 \
    "✗ S7 Build failed: $flavor" \
    "See log: $log" 2>/dev/null || true
}

# Rename a slipstream output to the S7-branded name (X27/F44/R101/SkyCAIR)
# Usage: rebrand_output <flavor> <source-path>
# Produces: $REPO/build/output/S7-<flavor>-SkyCAIR-$TAG.iso (+ .sig)
rebrand_output() {
  local flavor="$1"
  local src="$2"
  local outdir="$REPO/build/output"
  mkdir -p "$outdir"
  local final="$outdir/S7-${flavor}-SkyCAIR-${TAG}.iso"
  cp "$src" "$final"
  [[ -f "${src}.sig" ]] && cp "${src}.sig" "${final}.sig"
  echo "$final"
}
