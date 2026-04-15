#!/usr/bin/env bash
# build/s7-build-f44-skycair.sh
# 1-click builder for S7-F44-SkyCAIR (full installer ISO via bootc).
#
# This wraps iso/build-iso.sh — which builds the root Containerfile
# (Budgie + systemd + S7 stack) and converts it to a bootable anaconda
# ISO via bootc-image-builder. bootc-image-builder REQUIRES rootful
# podman (loopback devices for ISO assembly), so this wrapper uses
# pkexec to prompt graphically for root privileges.
#
# From the desktop shortcut this pops the standard polkit dialog —
# Tonya/Trinity enter their password once, then the build runs unattended.

set -euo pipefail
source /s7/skyqubi-private/install/builders/s7-build-common.sh

FLAVOR="F44"
LOG="$LOG_DIR/s7-build-f44-$(date -u +%Y%m%d-%H%M%S).log"

notify_start "$FLAVOR"

{
  echo "═════════════════════════════════════════════════════"
  echo "  S7-${FLAVOR}-SkyCAIR build"
  echo "  started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "  This build needs root (bootc-image-builder uses"
  echo "  loopback devices). A password prompt will appear."
  echo "═════════════════════════════════════════════════════"

  # Step 1: build the OCI image rootlessly (no pkexec needed)
  # This is the big work — ~20-30 min on first run, ~1 min cached.
  "$REPO/iso/build-iso.sh" --tag "$TAG" || {
    echo "OCI build phase returned non-zero, but this is expected"
    echo "because build-iso.sh detects rootless podman and exits 0"
    echo "after printing the sudo invocation. We'll now escalate."
  }

  # Step 2: run bootc-image-builder under pkexec (real root)
  echo
  echo "[escalating via pkexec for bootc-image-builder]"
  echo "A password prompt will appear. This is your S7 user password."
  echo

  # Disable set -e for this single command so we can catch the failure
  # ourselves and give a clean retry instruction instead of a silent
  # stack trace ending at pam_authenticate.
  set +e
  pkexec env DISPLAY="${DISPLAY:-}" XAUTHORITY="${XAUTHORITY:-}" \
    podman run --rm \
      --privileged \
      --pull=newer \
      --security-opt label=type:unconfined_t \
      -v "$REPO/iso/dist:/output" \
      -v /s7/.local/share/containers/storage:/var/lib/containers/storage \
      quay.io/centos-bootc/bootc-image-builder:latest \
      --type iso \
      --local \
      localhost/s7-skycair:latest
  pkexec_rc=$?
  set -e

  if [[ $pkexec_rc -ne 0 ]]; then
    echo
    echo "═════════════════════════════════════════════════════"
    echo "  F44 ISO step FAILED at pkexec (exit $pkexec_rc)"
    echo "═════════════════════════════════════════════════════"
    if [[ $pkexec_rc -eq 126 || $pkexec_rc -eq 127 ]]; then
      echo "  Likely cause: wrong password in the polkit dialog,"
      echo "  or the dialog was cancelled."
    else
      echo "  Likely cause: bootc-image-builder itself failed."
      echo "  Check the output above for details."
    fi
    echo
    echo "  To retry:"
    echo "    - Open S7 SkyQUBi → S7 SkyBuilder"
    echo "    - Pick [2] (S7-F44-SkyCAIR)"
    echo "    - Enter your S7 user password when the dialog appears"
    echo
    echo "  The OCI image (localhost/s7-skycair:latest) is already built,"
    echo "  so the retry will skip straight to the pkexec step."
    echo "═════════════════════════════════════════════════════"
    notify_fail "S7-${FLAVOR}-SkyCAIR" "$LOG"
    exit "$pkexec_rc"
  fi

  # Step 3: find the produced ISO, sign, rename
  SRC=$(find "$REPO/iso/dist" -type f -name '*.iso' | head -1)
  if [[ -z "$SRC" ]]; then
    echo "FAIL: bootc-image-builder produced no .iso"
    exit 1
  fi

  # Sign
  if [[ -f /s7/.config/s7/s7-image-signing ]]; then
    ssh-keygen -Y sign -f /s7/.config/s7/s7-image-signing \
               -n file -I s7-skyqubi "$SRC"
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
