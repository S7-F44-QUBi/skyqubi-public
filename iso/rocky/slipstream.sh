#!/usr/bin/env bash
# iso/rocky/slipstream.sh
# Slipstream the S7 update payload into the SkyCAIR 7 Rocky/Fedora
# Live ISO (SKYCAIR7 USB). Adds /s7-update/ at the ISO top level
# WITHOUT modifying the inner squashfs.img — the content is discoverable
# post-boot at /run/initramfs/live/s7-update/.
#
# Why not modify the squashfs:
#   The SKYCAIR7 ISO uses the nested format squashfs.img → rootfs.img
#   (ext4) which requires real root + loop mount to modify. Adding a
#   top-level /s7-update/ directory is much simpler and signs cleanly.
#
# Usage:
#   ./slipstream.sh                    # default: /run/media/s7/SKYCAIR7
#   ./slipstream.sh --source /path/USB # explicit source mount
#   ./slipstream.sh --refresh          # re-copy source USB (destroys work/)
#   ./slipstream.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=/s7/skyqubi-private
SOURCE_USB="/run/media/s7/SKYCAIR7"
WORK="$SCRIPT_DIR/work"
MODBUILD="$SCRIPT_DIR/module-build"
DIST="$SCRIPT_DIR/dist"
REFRESH=false

for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --help|-h) sed -n '2,20p' "$0" | sed 's|^# \?||'; exit 0 ;;
    --source)  j=$((i+1)); SOURCE_USB="${!j}" ;;
    --refresh) REFRESH=true ;;
  esac
done

fail() { echo "FAIL: $*"; exit 1; }
TAG="v$(date -u +%Y.%m.%d)"
ISO_NAME="s7-skycair-rocky-${TAG}.iso"

echo "═════════════════════════════════════════════════════"
echo "  S7 Rocky slipstream"
echo "  source:  $SOURCE_USB"
echo "  work:    $WORK"
echo "  dist:    $DIST"
echo "  iso:     $ISO_NAME"
echo "═════════════════════════════════════════════════════"

# ── Phase 1: copy source USB ──
echo "[1/4] source USB → work"
if [[ -d "$WORK" && "$REFRESH" != "true" ]]; then
  echo "  work/ exists, reusing (--refresh to force recopy)"
else
  [[ -d "$SOURCE_USB/LiveOS" ]] || fail "source $SOURCE_USB has no LiveOS/ — is the USB mounted?"
  rm -rf "$WORK"
  mkdir -p "$WORK"
  cp -a "$SOURCE_USB/." "$WORK/"
  echo "  copied $(du -sh "$WORK" | cut -f1)"
fi

# ── Phase 2: stage S7 payload (allowlist) ──
echo "[2/4] stage S7 update payload"
rm -rf "$MODBUILD"
mkdir -p "$MODBUILD"
for path in \
    iac engine/tools branding profiles services autostart desktop \
    install docs/public mcp os \
    s7-manager.sh s7-lifecycle-test.sh s7-sync-public.sh \
    start-pod.sh skyqubi-pod.yaml Containerfile \
    s7-image-signing.pub .env.example README.md LICENSE CWS-LICENSE NOTICE
do
  [[ -e "$REPO/$path" ]] || continue
  rsync -a --exclude='.git' --exclude='__pycache__' --exclude='*.log' \
        --exclude='dist/*.tar*' --exclude='dist/tmp' --exclude='dist/*.iso*' \
        --relative "$REPO/./$path" "$MODBUILD/"
done
rm -rf "$MODBUILD/iac/dist"
mkdir -p "$MODBUILD/iac/dist"
touch "$MODBUILD/iac/dist/.gitkeep"

# Write the overlay README
cat > "$MODBUILD/README.md" <<EOF
# S7 SkyQUBi Live USB Update Payload

At runtime, accessible via:
  /run/initramfs/live/s7-update/

To activate:
  sudo cp -a /run/initramfs/live/s7-update/. /opt/s7/
  cd /opt/s7
  ./s7-manager.sh doctor

Built: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# Place at work/s7-update/
rm -rf "$WORK/s7-update"
mkdir -p "$WORK/s7-update"
cp -a "$MODBUILD/." "$WORK/s7-update/"
echo "  staged $(du -sh "$WORK/s7-update" | cut -f1) at work/s7-update/"

# ── Phase 3: mkisofs + isohybrid → bootable ISO ──
echo "[3/4] mkisofs + isohybrid → $ISO_NAME"
mkdir -p "$DIST"
rm -f "$DIST/$ISO_NAME"
podman run --rm \
  -v "$WORK:/iso-work:rw" \
  -v "$DIST:/iso-dist:rw" \
  quay.io/fedora/fedora:44 \
  bash -c "dnf install -y genisoimage syslinux-nonlinux syslinux >/dev/null 2>&1 && \
           cd /iso-work && \
           mkisofs -o /iso-dist/$ISO_NAME -l -J -joliet-long -R -D \
             -A 'SKYCAIR7' -V 'SKYCAIR7' \
             -no-emul-boot -boot-info-table -boot-load-size 4 \
             -b isolinux/isolinux.bin \
             -c boot.catalog \
             . 2>&1 | tail -5 && \
           isohybrid /iso-dist/$ISO_NAME 2>&1 | tail -3"
echo "  built $(du -h "$DIST/$ISO_NAME" | cut -f1)"

# ── Phase 4: sign ──
echo "[4/4] ssh-keygen -Y sign"
SIG_KEY="${S7_IMAGE_SIGNING_KEY:-/s7/.config/s7/s7-image-signing}"
if [[ -f "$SIG_KEY" ]]; then
  rm -f "$DIST/${ISO_NAME}.sig"
  ssh-keygen -Y sign -f "$SIG_KEY" -n file -I s7-skyqubi "$DIST/$ISO_NAME" 2>&1 | head -2
  echo "  signed: $DIST/${ISO_NAME}.sig"
else
  echo "  WARNING: signing key $SIG_KEY not found — ISO will be UNSIGNED"
fi

# ── Report ──
echo
echo "═════════════════════════════════════════════════════"
echo "  rocky slipstream complete"
echo "  ISO:    $DIST/$ISO_NAME ($(du -h "$DIST/$ISO_NAME" | cut -f1))"
echo "  sha256: $(sha256sum "$DIST/$ISO_NAME" | awk '{print $1}')"
if [[ -f "$DIST/${ISO_NAME}.sig" ]]; then
  echo "  sig:    $DIST/${ISO_NAME}.sig"
fi
echo
echo "  To test in KVM:"
echo "    qemu-system-x86_64 -m 4G -cdrom $DIST/$ISO_NAME -boot d -enable-kvm"
echo
echo "  To burn to a USB (destructive):"
echo "    lsblk -f && sudo dd if=$DIST/$ISO_NAME of=/dev/sdX bs=4M status=progress oflag=sync"
echo "═════════════════════════════════════════════════════"
