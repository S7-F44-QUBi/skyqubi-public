#!/usr/bin/env bash
# iso/build-iso.sh
# Thin wrapper around Fedora's bootc-image-builder. Two real commands,
# plus signing. That's it.
#
# Usage: ./build-iso.sh [--tag TAG] [--skip-oci-build]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST="$SCRIPT_DIR/dist"
mkdir -p "$DIST"

# /var/tmp is a 3 GB tmpfs on this Fedora/PorteuX system — not enough
# for podman to stash the intermediate layer during a 1000-package dnf
# install. Point TMPDIR at the real disk (same filesystem as podman's
# graphRoot) so layer commits don't run out of space.
export TMPDIR="${TMPDIR:-$SCRIPT_DIR/dist/tmp}"
mkdir -p "$TMPDIR"

OCI_IMAGE="localhost/s7-skycair:latest"
BUILDER="quay.io/centos-bootc/bootc-image-builder:latest"
TAG=$(date -u +"v%Y.%m.%d")
SKIP_OCI=false

for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --help|-h) sed -n '2,7p' "$0" | sed 's|^# \?||'; exit 0 ;;
    --tag) j=$((i+1)); TAG="${!j}" ;;
    --skip-oci-build) SKIP_OCI=true ;;
  esac
done

# 1. Build the OCI image from the root Containerfile
if ! $SKIP_OCI; then
  echo "[1/3] podman build -t $OCI_IMAGE -f $REPO/Containerfile"
  podman build -t "$OCI_IMAGE" -f "$REPO/Containerfile" "$REPO"
fi

# 2. Run bootc-image-builder to produce the ISO
#
# IMPORTANT: bootc-image-builder requires ROOTFUL podman (real root).
# Running under rootless podman fails with:
#   error: cannot validate the setup: this command must be run in
#   rootful (not rootless) podman
# This is because it creates real loopback devices for the ISO build.
# If we're rootless, print the exact sudo command and exit cleanly.
if [[ "$(id -u)" -ne 0 ]]; then
  echo
  echo "  ⚠  bootc-image-builder needs rootful podman (real root)."
  echo "     OCI image is ready: $OCI_IMAGE"
  echo
  echo "     Run this command as root to produce the ISO:"
  echo
  echo "     sudo podman run --rm \\"
  echo "       --privileged \\"
  echo "       --pull=newer \\"
  echo "       --security-opt label=type:unconfined_t \\"
  echo "       -v $DIST:/output \\"
  echo "       -v /s7/.local/share/containers/storage:/var/lib/containers/storage \\"
  echo "       $BUILDER \\"
  echo "       --type iso \\"
  echo "       --local \\"
  echo "       $OCI_IMAGE"
  echo
  echo "     Note: the -v for containers/storage points at the rootless"
  echo "     graphRoot so root podman can still see the image you built."
  echo
  echo "     When done, sign the output with:"
  echo "       ssh-keygen -Y sign -f /s7/.config/s7/s7-image-signing \\"
  echo "                  -n file -I s7-skycair-iso \\"
  echo "                  $DIST/*.iso"
  echo
  exit 0
fi
echo "[2/3] bootc-image-builder → anaconda-iso"
podman run --rm \
  --privileged \
  --pull=newer \
  --security-opt label=type:unconfined_t \
  -v "$DIST:/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  "$BUILDER" \
  --type iso \
  --local \
  "$OCI_IMAGE"

# bootc-image-builder drops the output as bootiso/install.iso by convention
FOUND=$(find "$DIST" -type f -name '*.iso' | head -1)
[[ -n "$FOUND" ]] || { echo "no .iso produced"; exit 1; }
FINAL="$DIST/s7-skycair-${TAG}.iso"
mv "$FOUND" "$FINAL"
rm -rf "$DIST/bootiso" "$DIST/image"

# 3. Sign with the sovereign key (if present)
echo "[3/3] sign"
SIG_KEY="${S7_IMAGE_SIGNING_KEY:-/s7/.config/s7/s7-image-signing}"
if [[ -f "$SIG_KEY" ]]; then
  ssh-keygen -Y sign -f "$SIG_KEY" -n file -I s7-skycair-iso "$FINAL"
  echo "  signed: ${FINAL}.sig"
fi

echo
echo "done: $FINAL ($(stat -c %s "$FINAL") bytes)"
ls -la "$DIST"/*.iso* 2>/dev/null
