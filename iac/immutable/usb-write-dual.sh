#!/usr/bin/env bash
# iac/immutable/usb-write-dual.sh
#
# Writes F44 installer ISO + QUBi bootc oci-archive to a USB drive
# in a single operation. Produces a bootable USB that also carries
# the QUBi image for post-install 'bootc switch'.
#
# Pipeline:
#   1. All 10 Samuel guards from usb-write-f44.sh
#   2. dd the F44 ISO to the raw device (wipes partition table)
#   3. sync + re-read partition table
#   4. Add a third partition in the free space after the ISO's
#      hybrid partitions
#   5. Format the third partition ext4
#   6. Copy the QUBi oci-archive tar into the partition
#   7. sync + unmount
#   8. sudo -k to clear credential cache
#
# The result: a USB that boots into the F44 installer AND has a
# data partition labeled 's7-qubi' containing the QUBi oci-archive.
# On the test machine, install Fedora normally, then mount the
# s7-qubi partition and run:
#   sudo bootc switch --transport oci-archive:/mnt/s7-qubi/s7-skycair-v6-genesis-covenant-clean.oci-archive.tar localhost/s7-skycair:v6-genesis
#
# Usage:
#   sudo ./usb-write-dual.sh --device /dev/sdX --serial <serial>
#                            [--iso /path/to/F44.iso]
#                            [--qubi /path/to/oci-archive.tar]
#                            [--dry-run]
#                            [--force]
#
# Defaults:
#   --iso  /s7/skyqubi-private/iso/fedora-x44/dist/S7-X44-SkyCAIR-v2026.04.13.iso
#   --qubi /s7/Local-Private-Assets/s7-skycair-v6-genesis-covenant-clean.oci-archive.tar

set -uo pipefail

ISO="/s7/skyqubi-private/iso/fedora-x44/dist/S7-X44-SkyCAIR-v2026.04.13.iso"
QUBI_TAR="/s7/Local-Private-Assets/s7-skycair-v6-genesis-covenant-clean.oci-archive.tar"
DEVICE=""
EXPECTED_SERIAL=""
DRY_RUN=false
FORCE=false

LOG_DIR="/tmp/s7-gold-reset"
LOG="$LOG_DIR/usb-write-dual.log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --serial) EXPECTED_SERIAL="$2"; shift 2 ;;
    --iso)    ISO="$2"; shift 2 ;;
    --qubi)   QUBI_TAR="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --force)  FORCE=true; shift ;;
    --help|-h)
      sed -n '2,34p' "$0" | sed 's|^# \?||'
      exit 0 ;;
    *) echo "unknown arg: $1"; exit 1 ;;
  esac
done

# Guard 1 — root
if [[ "$(id -u)" -ne 0 ]]; then
  echo "  🔴 Guard 1 FAIL: must run as root."
  echo "     Try: sudo $0 --device <dev> --serial <serial>"
  exit 2
fi

mkdir -p "$LOG_DIR"
log() {
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$ts] $*" >> "$LOG"
  echo "  $*"
}

log "== usb-write-dual.sh starting =="
log "iso:      $ISO"
log "qubi:     $QUBI_TAR"
log "device:   $DEVICE"
log "serial:   $EXPECTED_SERIAL (expected)"

if [[ -z "$DEVICE" || -z "$EXPECTED_SERIAL" ]]; then
  log "🔴 missing --device or --serial"
  exit 1
fi

# Guard 2 — block device of TYPE=disk
if [[ ! -b "$DEVICE" ]]; then
  log "🔴 Guard 2 FAIL: $DEVICE not a block device"
  exit 2
fi
DEV_TYPE=$(lsblk -no TYPE "$DEVICE" | head -1)
if [[ "$DEV_TYPE" != "disk" ]]; then
  log "🔴 Guard 2 FAIL: $DEVICE TYPE=$DEV_TYPE (need disk)"
  exit 2
fi
log "✓ Guard 2: block device of TYPE=disk"

# Guard 3 — removable
DEV_NAME="${DEVICE##*/}"
RM_FILE="/sys/block/$DEV_NAME/removable"
if [[ ! -f "$RM_FILE" ]]; then
  log "🔴 Guard 3 FAIL: no $RM_FILE"
  exit 2
fi
if [[ "$(cat "$RM_FILE")" != "1" ]]; then
  log "🔴 Guard 3 FAIL: $DEVICE not removable (not a USB flash drive)"
  exit 2
fi
log "✓ Guard 3: removable"

# Guard 4 — not root device
ROOT_SRC=$(findmnt -no SOURCE / 2>/dev/null)
ROOT_PARENT=$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null | head -1)
[[ -z "$ROOT_PARENT" ]] && ROOT_PARENT=$(basename "$ROOT_SRC")
if [[ "$DEV_NAME" == "$ROOT_PARENT" || "$DEVICE" == "$ROOT_SRC" ]]; then
  log "🔴 Guard 4 FAIL: $DEVICE is the root device"
  exit 2
fi
log "✓ Guard 4: not root device"

# Guard 5 — serial match
ACTUAL_SERIAL=$(lsblk -no SERIAL "$DEVICE" 2>/dev/null | head -1)
if [[ "$ACTUAL_SERIAL" != "$EXPECTED_SERIAL" ]]; then
  log "🔴 Guard 5 FAIL: serial mismatch"
  log "    expected: $EXPECTED_SERIAL"
  log "    actual:   $ACTUAL_SERIAL"
  exit 2
fi
log "✓ Guard 5: serial matches"

# Guard 6 — no mounted partitions
MOUNTED=$(lsblk -no MOUNTPOINT "$DEVICE" 2>/dev/null | grep -v '^$' | head -5)
if [[ -n "$MOUNTED" ]]; then
  log "🔴 Guard 6 FAIL: $DEVICE has mounted partitions:"
  echo "$MOUNTED" | while read -r mp; do log "    $mp"; done
  log "    Unmount first: sudo umount ${DEVICE}?*"
  exit 2
fi
log "✓ Guard 6: no mounts"

# Guard 7 — size 4G-256G
DEV_SIZE_BYTES=$(blockdev --getsize64 "$DEVICE")
MIN_B=$((4*1024*1024*1024)); MAX_B=$((256*1024*1024*1024))
if [[ "$DEV_SIZE_BYTES" -lt $MIN_B || "$DEV_SIZE_BYTES" -gt $MAX_B ]]; then
  log "🔴 Guard 7 FAIL: size $DEV_SIZE_BYTES bytes outside 4G-256G"
  exit 2
fi
DEV_SIZE_GB=$((DEV_SIZE_BYTES / 1024 / 1024 / 1024))
log "✓ Guard 7: ${DEV_SIZE_GB}G"

# Guard 8 — ISO sanity
if [[ ! -f "$ISO" ]]; then
  log "🔴 Guard 8 FAIL: ISO missing: $ISO"
  exit 2
fi
ISO_MAGIC=$(file -b "$ISO")
if [[ "$ISO_MAGIC" != *"ISO 9660"* && "$ISO_MAGIC" != *"boot sector"* ]]; then
  log "🔴 Guard 8 FAIL: not an ISO: $ISO_MAGIC"
  exit 2
fi
ISO_SIZE=$(stat --format='%s' "$ISO")
ISO_SHA=$(sha256sum "$ISO" | awk '{print $1}')
log "✓ Guard 8: ISO valid ($(numfmt --to=iec "$ISO_SIZE"), sha256=${ISO_SHA:0:16}...)"

# Guard 8b — QUBI tar sanity
if [[ ! -f "$QUBI_TAR" ]]; then
  log "🔴 Guard 8b FAIL: QUBi tar missing: $QUBI_TAR"
  exit 2
fi
QUBI_SIZE=$(stat --format='%s' "$QUBI_TAR")
QUBI_SHA=$(sha256sum "$QUBI_TAR" | awk '{print $1}')
log "✓ Guard 8b: QUBi tar valid ($(numfmt --to=iec "$QUBI_SIZE"), sha256=${QUBI_SHA:0:16}...)"

# Size check — ISO + QUBi must fit on device with room to spare
TOTAL_NEEDED=$((ISO_SIZE + QUBI_SIZE + 512*1024*1024))  # + 512MB headroom
if [[ "$DEV_SIZE_BYTES" -lt $TOTAL_NEEDED ]]; then
  log "🔴 Guard 8c FAIL: device $DEV_SIZE_BYTES bytes too small for ISO+QUBi+headroom ($TOTAL_NEEDED)"
  exit 2
fi
log "✓ Guard 8c: device has room for both payloads"

log ""
log "── About to write ──"
log "  device:   $DEVICE (${DEV_SIZE_GB}G, serial $EXPECTED_SERIAL)"
log "  payload1: $ISO"
log "  payload2: $QUBI_TAR"
log ""
log "  This DESTROYS all existing data on $DEVICE."
log ""

if ! $FORCE && ! $DRY_RUN; then
  read -r -p "  Type YES to proceed: " CONFIRM
  if [[ "$CONFIRM" != "YES" ]]; then
    log "🟡 aborted at confirmation"
    exit 4
  fi
fi

if $DRY_RUN; then
  log "[DRY RUN] would dd $ISO to $DEVICE, add third partition, copy $QUBI_TAR"
  exit 0
fi

# ── Step A: dd the ISO to the raw device ─────────────────────
log ""
log "A) dd ISO → $DEVICE  (this may take several minutes)"
T=$(date +%s)
if ! dd if="$ISO" of="$DEVICE" bs=4M conv=fsync status=progress 2>&1 | tee -a "$LOG"; then
  log "🔴 dd FAILED"
  exit 3
fi
log "   dd complete in $(( $(date +%s) - T )) seconds"

log "   sync..."
sync
log "   ✓ sync"

# ── Step B: verify first ISO_SIZE bytes match ────────────────
log ""
log "B) verify dd sha256..."
DEV_SHA=$(dd if="$DEVICE" bs=4M count=$((ISO_SIZE / 4194304 + 1)) 2>/dev/null \
          | head -c "$ISO_SIZE" | sha256sum | awk '{print $1}')
if [[ "$DEV_SHA" != "$ISO_SHA" ]]; then
  log "🔴 ISO sha256 mismatch after dd"
  log "   ISO: $ISO_SHA"
  log "   DEV: $DEV_SHA"
  exit 3
fi
log "   ✓ ISO sha256 matches"

# ── Step C: re-read partition table, find free space ─────────
log ""
log "C) re-read partition table..."
partprobe "$DEVICE" 2>&1 | tee -a "$LOG" || blockdev --rereadpt "$DEVICE" 2>&1 | tee -a "$LOG" || true
sleep 2

log "   partitions after dd:"
parted -s "$DEVICE" unit MiB print 2>&1 | tee -a "$LOG"

# Find the end of the last partition
LAST_END_MIB=$(parted -s "$DEVICE" unit MiB print 2>/dev/null | awk '/^ [0-9]/ {end=$3} END {gsub("MiB","",end); print end}')
TOTAL_MIB=$((DEV_SIZE_BYTES / 1024 / 1024))
FREE_MIB=$((TOTAL_MIB - LAST_END_MIB - 4))  # 4 MiB safety margin

log "   last partition ends at ${LAST_END_MIB}MiB, total ${TOTAL_MIB}MiB, free ~${FREE_MIB}MiB"

# ── Step D: create a third partition in the free space ──────
log ""
log "D) create QUBi data partition..."
NEW_START_MIB=$((LAST_END_MIB + 1))
parted -s "$DEVICE" mkpart primary ext4 "${NEW_START_MIB}MiB" 100% 2>&1 | tee -a "$LOG"
sync
partprobe "$DEVICE" 2>&1 | tee -a "$LOG" || true
sleep 2

# Identify the new partition (should be the last one)
NEW_PART=$(lsblk -lnp -o NAME "$DEVICE" | tail -1)
if [[ "$NEW_PART" == "$DEVICE" ]]; then
  log "🔴 partition creation failed — no new partition visible"
  exit 3
fi
log "   new partition: $NEW_PART"

# ── Step E: format ext4 with label s7-qubi ─────────────────
log ""
log "E) mkfs.ext4 on $NEW_PART..."
mkfs.ext4 -F -L s7-qubi "$NEW_PART" 2>&1 | tee -a "$LOG"

# ── Step F: mount, copy QUBi tar, unmount ─────────────────
log ""
log "F) mount + copy QUBi oci-archive..."
MNT="/mnt/s7-qubi-$$"
mkdir -p "$MNT"
mount "$NEW_PART" "$MNT"
trap 'umount "$MNT" 2>/dev/null; rmdir "$MNT" 2>/dev/null' EXIT

log "   cp $(numfmt --to=iec "$QUBI_SIZE") to $MNT (this will take a minute)..."
T=$(date +%s)
cp -v "$QUBI_TAR" "$MNT/" 2>&1 | tee -a "$LOG"
sync
log "   copy+sync complete in $(( $(date +%s) - T )) seconds"

# Verify the copy
TAR_NAME=$(basename "$QUBI_TAR")
COPIED_SHA=$(sha256sum "$MNT/$TAR_NAME" | awk '{print $1}')
if [[ "$COPIED_SHA" != "$QUBI_SHA" ]]; then
  log "🔴 QUBi tar sha256 mismatch after copy"
  exit 3
fi
log "   ✓ copied tar sha256 matches"

# Write a tiny README explaining what the partition is
cat > "$MNT/README.txt" <<EOF
S7 SkyQUB*i* — QUBi bootc data partition
=========================================
Label: s7-qubi

This partition contains the S7 SkyCAIR bootc OCI archive:
  $TAR_NAME
  sha256: $QUBI_SHA

After installing Fedora 44 from the installer on partition 1
of this USB, boot into the installed Fedora, plug this USB
back in, then run:

  sudo mount LABEL=s7-qubi /mnt
  sudo bootc switch --transport oci-archive:/mnt/$TAR_NAME localhost/s7-skycair:v6-genesis
  sudo systemctl reboot

On next boot, the system becomes S7 SkyQUB*i*.

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Device:    $DEVICE
Serial:    $EXPECTED_SERIAL
EOF
log "   README.txt written to $MNT"

umount "$MNT"
rmdir "$MNT"
trap - EXIT

sync
log ""
log "🟢 USB WRITE COMPLETE — $DEVICE"
log "   Partition 1: F44 installer (bootable)"
log "   Partition 2: F44 EFI"
log "   Partition 3: s7-qubi (ext4, contains oci-archive + README.txt)"
log ""
log "   Eject:  sudo eject $DEVICE"
log "   Or:     sudo udisksctl power-off -b $DEVICE"
exit 0
