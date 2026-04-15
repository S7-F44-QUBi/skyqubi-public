#!/usr/bin/env bash
# iso/porteux/slipstream.sh
# Slipstream tonight's S7 content into the PorteuX live USB ISO.
#
# Pipeline:
#   1. Copy the existing PorteuX USB tree to a writable work dir
#      (skipped if work/ already exists and --refresh is not given)
#   2. Stage module content from /s7/skyqubi-private (allowlist)
#   3. mksquashfs the staging into modules/012-s7-update-<DATE>.xzm
#   4. mkisofs + isohybrid the work tree into a new bootable ISO
#   5. ssh-keygen -Y sign the ISO with /s7/.config/s7/s7-image-signing
#
# Tools (mksquashfs + mkisofs + isohybrid + isoinfo) are NOT installed
# locally — this script runs them inside quay.io/fedora/fedora:44 via
# rootless podman. The only local requirement is podman itself plus
# the private repo + the source USB mounted read-only somewhere.
#
# Usage:
#   ./slipstream.sh                      # default: uses /run/media/s7/S7 as source
#   ./slipstream.sh --source /path/USB   # explicit source mount
#   ./slipstream.sh --refresh            # re-copy source USB (destroys work/)
#   ./slipstream.sh --help
#
# Environment:
#   S7_IMAGE_SIGNING_KEY — override the signing key path
#                         (default /s7/.config/s7/s7-image-signing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=/s7/skyqubi-private
SOURCE_USB="/run/media/s7/S7"
WORK="$SCRIPT_DIR/work"
MODBUILD="$SCRIPT_DIR/module-build"
DIST="$SCRIPT_DIR/dist"
REFRESH=false

for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --help|-h) sed -n '2,22p' "$0" | sed 's|^# \?||'; exit 0 ;;
    --source)  j=$((i+1)); SOURCE_USB="${!j}" ;;
    --refresh) REFRESH=true ;;
  esac
done

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "  $*"; }
fail() { echo "FAIL: $*"; exit 1; }

TAG_ISO="v$(date -u +%Y.%m.%d)"
TAG_XZM="$(date -u +%Y%m%d)"
XZM_NAME="012-s7-update-${TAG_XZM}.xzm"
ISO_NAME="S7-X27-SkyCAIR-${TAG_ISO}.iso"

echo "═════════════════════════════════════════════════════"
echo "  S7 PorteuX slipstream"
echo "  source:  $SOURCE_USB"
echo "  work:    $WORK"
echo "  dist:    $DIST"
echo "  module:  $XZM_NAME"
echo "  iso:     $ISO_NAME"
echo "═════════════════════════════════════════════════════"

# ── Phase 1: copy source USB → writable work ──
log "[1/5] source USB → writable work tree"
if [[ -d "$WORK" && "$REFRESH" != "true" ]]; then
  log "  work/ exists, reusing (--refresh to force recopy)"
else
  [[ -d "$SOURCE_USB/porteux" ]] || fail "source $SOURCE_USB has no porteux/ dir — is the USB mounted?"
  rm -rf "$WORK"
  mkdir -p "$WORK"
  cp -a "$SOURCE_USB/." "$WORK/"
  log "  copied $(du -sh "$WORK" | cut -f1)"
fi

# ── Phase 2: stage module content (allowlist) ──
log "[2/5] staging module content from $REPO"
rm -rf "$MODBUILD"
DST="$MODBUILD/opt/s7/skyqubi-private"
mkdir -p "$DST"
for path in \
    iac engine/tools branding profiles services autostart desktop \
    install docs/public mcp os \
    s7-manager.sh s7-lifecycle-test.sh s7-sync-public.sh \
    start-pod.sh skyqubi-pod.yaml Containerfile \
    s7-image-signing.pub .env.example README.md LICENSE CWS-LICENSE NOTICE
do
  [[ -e "$REPO/$path" ]] || continue
  rsync -a --exclude='.git' --exclude='__pycache__' --exclude='*.log' \
        --exclude='dist/*.tar*' --exclude='dist/tmp' \
        --relative "$REPO/./$path" "$DST/"
done
# Clean any leftover iac/dist artifacts that slipped through
rm -rf "$DST/iac/dist"
mkdir -p "$DST/iac/dist"
touch "$DST/iac/dist/.gitkeep"
log "  staged $(du -sh "$MODBUILD" | cut -f1)"

# ── Phase 3: mksquashfs → XZM ──
# S7 recall store: the XZM is a deterministic function of the
# staged content under $MODBUILD. If we've built the same content
# before, RECALL the prior module instead of burning 2-3 minutes
# on mksquashfs. The recall store is INSERT-only — it keeps every
# prior build keyed by its content hash, so a broken rebuild never
# overwrites a known-good output; we can always roll back.
#
# (Note: 'cheat' in PorteuX means boot-time kernel cheatcodes.
# Using 'recall store' here to avoid the naming collision.)
log "[3/5] mksquashfs → $XZM_NAME"
mkdir -p "$WORK/porteux/modules"

RECALL_DIR="$SCRIPT_DIR/recall"
mkdir -p "$RECALL_DIR"

# Content hash of the staged tree. find → stable sort → tar with
# fixed mtime → sha256 is reproducible across runs on identical input.
CONTENT_HASH=$(cd "$MODBUILD" && find . -type f -print0 \
    | LC_ALL=C sort -z \
    | tar --null --no-recursion --mtime='1970-01-01' -cf - -T - 2>/dev/null \
    | sha256sum | cut -d' ' -f1)
RECALL_XZM="$RECALL_DIR/${CONTENT_HASH}.xzm"
RECALL_SENTINEL="$RECALL_DIR/${CONTENT_HASH}.sentinel"

if [[ -f "$RECALL_XZM" ]] && [[ -f "$RECALL_SENTINEL" ]]; then
    log "  recall HIT — reusing $RECALL_XZM (hash ${CONTENT_HASH:0:12})"
    cp "$RECALL_XZM" "$WORK/porteux/modules/$XZM_NAME"
else
    log "  recall MISS — running mksquashfs"
    podman run --rm \
      -v "$MODBUILD:/src:ro" \
      -v "$WORK/porteux/modules:/out:rw" \
      quay.io/fedora/fedora:44 \
      bash -c "dnf install -y squashfs-tools >/dev/null 2>&1 && \
               mksquashfs /src /out/$XZM_NAME \
                 -comp xz -b 1M -Xbcj x86 -noappend 2>&1 | tail -5"
    cp "$WORK/porteux/modules/$XZM_NAME" "$RECALL_XZM"
    touch "$RECALL_SENTINEL"
    log "  saved to recall store: $RECALL_XZM"
fi
log "  built $(du -h "$WORK/porteux/modules/$XZM_NAME" | cut -f1)"

# ── Phase 4: mkisofs + isohybrid → bootable ISO ──
log "[4/5] mkisofs + isohybrid → $ISO_NAME"
mkdir -p "$DIST"
rm -f "$DIST/$ISO_NAME"
podman run --rm \
  -v "$WORK:/iso-work:rw" \
  -v "$DIST:/iso-dist:rw" \
  quay.io/fedora/fedora:44 \
  bash -c "dnf install -y genisoimage syslinux-nonlinux syslinux >/dev/null 2>&1 && \
           cd /iso-work && \
           mkisofs -o /iso-dist/$ISO_NAME -l -J -joliet-long -R -D \
             -A 'S7' -V 'S7' \
             -no-emul-boot -boot-info-table -boot-load-size 4 \
             -b boot/syslinux/isolinux.bin \
             -c boot/syslinux/isolinux.boot \
             . 2>&1 | tail -5 && \
           isohybrid /iso-dist/$ISO_NAME 2>&1 | tail -5"
log "  built $(du -h "$DIST/$ISO_NAME" | cut -f1)"

# ── Phase 5: sign ──
log "[5/5] ssh-keygen -Y sign"
SIG_KEY="${S7_IMAGE_SIGNING_KEY:-/s7/.config/s7/s7-image-signing}"
if [[ -f "$SIG_KEY" ]]; then
  rm -f "$DIST/${ISO_NAME}.sig"
  ssh-keygen -Y sign -f "$SIG_KEY" -n file -I s7-skyqubi "$DIST/$ISO_NAME" 2>&1 | head -2
  log "  signed: $DIST/${ISO_NAME}.sig"
else
  log "  WARNING: signing key $SIG_KEY not found — ISO will be UNSIGNED"
fi

# ── Report ──
echo
echo "═════════════════════════════════════════════════════"
echo "  slipstream complete"
echo "  ISO:      $DIST/$ISO_NAME"
echo "  size:     $(du -h "$DIST/$ISO_NAME" | cut -f1)"
echo "  sha256:   $(sha256sum "$DIST/$ISO_NAME" | awk '{print $1}')"
if [[ -f "$DIST/${ISO_NAME}.sig" ]]; then
  echo "  sig:      $DIST/${ISO_NAME}.sig"
fi
echo
echo "  To burn to a USB (destructive — verify the target device!):"
echo "    lsblk -f"
echo "    sudo dd if=$DIST/$ISO_NAME of=/dev/sdX bs=4M status=progress oflag=sync"
echo "    sync"
echo
echo "  To test in KVM:"
echo "    qemu-system-x86_64 -m 4G -cdrom $DIST/$ISO_NAME -boot d -enable-kvm"
echo "═════════════════════════════════════════════════════"
