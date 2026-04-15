#!/usr/bin/env bash
# iac/immutable/usb-write-f44.sh
#
# Writes the S7 F44 (Fedora 44) ISO to a USB drive with Samuel-grade
# guards. Produced by the Chair during the 2026-04-14 SOLO block
# after the first USB operation was blocked on TWO gates:
#   1. Two USB candidates, neither unambiguously empty
#   2. No sudo in the Chair's session (physical operations need root)
#
# This script is designed for Jamie (or another steward with sudo)
# to run with full Samuel guards enforced. It does NOT auto-pick
# the target device — Jamie must pass the device path AND its
# expected serial as arguments, both must match, or the script
# refuses.
#
# Usage:
#   sudo ./usb-write-f44.sh --device /dev/sdX --serial <serial>
#                          [--iso /path/to/iso]    # default: the only
#                                                  #   S7-X44 dist
#                          [--dry-run]              # print what would run
#                          [--force]                # skip final confirmation
#
# Samuel's guards, enforced in order:
#   1. Must run as root (sudo). No fallback.
#   2. Target device must exist, be a block device, and be of TYPE=disk.
#   3. Target device must be removable (RM=1 in /sys/block/.../removable).
#   4. Target device MUST NOT be the root filesystem's backing device.
#   5. Target device's reported serial MUST match --serial argument.
#   6. Target device MUST NOT be currently mounted (any partition).
#   7. Target device size MUST be between 4GB and 256GB (reasonable USB range).
#   8. ISO must exist, be a regular file, and pass 'file' magic check.
#   9. Final interactive confirmation (unless --force).
#  10. Pre-dd and post-dd states written to /tmp/s7-gold-reset/usb-write.log.
#
# Exit codes:
#   0 — dd completed and verified
#   1 — argument error
#   2 — guard failure (see which guard in output)
#   3 — dd failed or verification mismatch
#   4 — user aborted at confirmation prompt

set -uo pipefail

# Defaults
ISO=""
DEVICE=""
EXPECTED_SERIAL=""
DRY_RUN=false
FORCE=false

LOG_DIR="/tmp/s7-gold-reset"
LOG="$LOG_DIR/usb-write.log"

# ── Parse args ─────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --serial) EXPECTED_SERIAL="$2"; shift 2 ;;
    --iso)    ISO="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --force)  FORCE=true; shift ;;
    --help|-h)
      sed -n '2,48p' "$0" | sed 's|^# \?||'
      exit 0 ;;
    *)
      echo "  unknown arg: $1"; exit 1 ;;
  esac
done

# ── Guard 1: root privilege ────────────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
  echo "  🔴 Guard 1 FAIL: this script must run as root."
  echo "     Try: sudo $0 --device <dev> --serial <serial>"
  exit 2
fi

# ── Resolve ISO default ────────────────────────────────────────
if [[ -z "$ISO" ]]; then
  ISO="/s7/skyqubi-private/iso/fedora-x44/dist/S7-X44-SkyCAIR-v2026.04.13.iso"
fi

if [[ -z "$DEVICE" || -z "$EXPECTED_SERIAL" ]]; then
  echo "  🔴 Missing required args."
  echo "     Usage: sudo $0 --device /dev/sdX --serial <serial>"
  exit 1
fi

mkdir -p "$LOG_DIR"

log() {
  local msg="$1"
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$ts] $msg" >> "$LOG"
  echo "  $msg"
}

log "== usb-write-f44.sh starting =="
log "iso:    $ISO"
log "device: $DEVICE"
log "serial: $EXPECTED_SERIAL (expected)"

# ── Guard 2: device exists, is a block device, TYPE=disk ──────
if [[ ! -b "$DEVICE" ]]; then
  log "🔴 Guard 2 FAIL: $DEVICE is not a block device."
  exit 2
fi
DEV_TYPE=$(lsblk -no TYPE "$DEVICE" | head -1)
if [[ "$DEV_TYPE" != "disk" ]]; then
  log "🔴 Guard 2 FAIL: $DEVICE is TYPE=$DEV_TYPE (expected 'disk')."
  exit 2
fi
log "✓ Guard 2: $DEVICE is a block device of TYPE=disk"

# ── Guard 3: removable (RM=1) ──────────────────────────────────
DEV_NAME="${DEVICE##*/}"
RM_FILE="/sys/block/$DEV_NAME/removable"
if [[ ! -f "$RM_FILE" ]]; then
  log "🔴 Guard 3 FAIL: $RM_FILE not found — cannot verify removable flag"
  exit 2
fi
RM_VAL=$(cat "$RM_FILE")
if [[ "$RM_VAL" != "1" ]]; then
  log "🔴 Guard 3 FAIL: $DEVICE is not marked removable (RM=$RM_VAL)"
  log "    This may be an external SSD, not a flash drive. Refusing."
  exit 2
fi
log "✓ Guard 3: $DEVICE is removable (RM=1)"

# ── Guard 4: not the root device ───────────────────────────────
ROOT_SRC=$(findmnt -no SOURCE / 2>/dev/null)
ROOT_PARENT=$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null | head -1)
[[ -z "$ROOT_PARENT" ]] && ROOT_PARENT=$(basename "$ROOT_SRC")
if [[ "$DEV_NAME" == "$ROOT_PARENT" || "$DEVICE" == "$ROOT_SRC" ]]; then
  log "🔴 Guard 4 FAIL: $DEVICE appears to be the root filesystem backing device."
  log "    root source: $ROOT_SRC  (parent: $ROOT_PARENT)"
  log "    ABSOLUTE REFUSAL."
  exit 2
fi
log "✓ Guard 4: $DEVICE is NOT the root device (root is $ROOT_SRC)"

# ── Guard 5: serial matches ────────────────────────────────────
ACTUAL_SERIAL=$(lsblk -no SERIAL "$DEVICE" 2>/dev/null | head -1)
if [[ "$ACTUAL_SERIAL" != "$EXPECTED_SERIAL" ]]; then
  log "🔴 Guard 5 FAIL: serial mismatch"
  log "    expected: $EXPECTED_SERIAL"
  log "    actual:   $ACTUAL_SERIAL"
  log "    Aborting — this prevents writing to the wrong device if"
  log "    /dev/sdX has been re-enumerated between steps."
  exit 2
fi
log "✓ Guard 5: serial matches expected ($EXPECTED_SERIAL)"

# ── Guard 6: not currently mounted ─────────────────────────────
MOUNTED=$(lsblk -no MOUNTPOINT "$DEVICE" 2>/dev/null | grep -v '^$' | head -5)
if [[ -n "$MOUNTED" ]]; then
  log "🔴 Guard 6 FAIL: $DEVICE has mounted partitions:"
  echo "$MOUNTED" | while read -r mp; do log "    - $mp"; done
  log "    Unmount all partitions before running this script."
  log "    Try: sudo umount ${DEVICE}?*"
  exit 2
fi
log "✓ Guard 6: no partitions of $DEVICE are currently mounted"

# ── Guard 7: size sanity (4GB - 256GB) ─────────────────────────
DEV_SIZE_BYTES=$(blockdev --getsize64 "$DEVICE" 2>/dev/null)
MIN_BYTES=$((4 * 1024 * 1024 * 1024))      # 4 GB
MAX_BYTES=$((256 * 1024 * 1024 * 1024))    # 256 GB
if [[ "$DEV_SIZE_BYTES" -lt "$MIN_BYTES" || "$DEV_SIZE_BYTES" -gt "$MAX_BYTES" ]]; then
  log "🔴 Guard 7 FAIL: device size $DEV_SIZE_BYTES bytes outside 4-256 GB range"
  log "    Refusing to dd to a device of unexpected size class."
  exit 2
fi
DEV_SIZE_GB=$(( DEV_SIZE_BYTES / 1024 / 1024 / 1024 ))
log "✓ Guard 7: $DEVICE is ${DEV_SIZE_GB} GB (within 4-256 GB range)"

# ── Guard 8: ISO sanity ────────────────────────────────────────
if [[ ! -f "$ISO" ]]; then
  log "🔴 Guard 8 FAIL: ISO not found at $ISO"
  exit 2
fi
ISO_MAGIC=$(file -b "$ISO" 2>/dev/null)
if [[ "$ISO_MAGIC" != *"ISO 9660"* && "$ISO_MAGIC" != *"boot sector"* ]]; then
  log "🔴 Guard 8 FAIL: $ISO does not look like an ISO"
  log "    file magic: $ISO_MAGIC"
  exit 2
fi
ISO_SIZE=$(stat --format='%s' "$ISO")
ISO_SHA=$(sha256sum "$ISO" | awk '{print $1}')
log "✓ Guard 8: ISO is valid ($(numfmt --to=iec "$ISO_SIZE"), sha256=${ISO_SHA:0:16}...)"

# ── Final confirmation ────────────────────────────────────────
log ""
log "── About to write ──"
log "    $ISO"
log "  → $DEVICE (${DEV_SIZE_GB} GB, serial $EXPECTED_SERIAL)"
log ""
log "  This will DESTROY all existing data on $DEVICE."
log ""

if ! $FORCE && ! $DRY_RUN; then
  read -r -p "  Type YES to proceed (any other input aborts): " CONFIRM
  if [[ "$CONFIRM" != "YES" ]]; then
    log "🟡 aborted by user at confirmation prompt"
    exit 4
  fi
fi

if $DRY_RUN; then
  log "[DRY RUN] would run: dd if=$ISO of=$DEVICE bs=4M conv=fsync status=progress"
  log "[DRY RUN] complete — no write performed"
  exit 0
fi

# ── The dd itself ─────────────────────────────────────────────
log "dd starting..."
T_START=$(date +%s)
if ! dd if="$ISO" of="$DEVICE" bs=4M conv=fsync status=progress 2>&1 | tee -a "$LOG"; then
  log "🔴 dd FAILED — see output above"
  exit 3
fi
T_END=$(date +%s)
log "dd complete in $((T_END - T_START)) seconds"

log "sync..."
sync
log "✓ sync complete"

# ── Post-dd verification ───────────────────────────────────────
log "verifying first ${ISO_SIZE} bytes of $DEVICE match the ISO..."
DEV_SHA=$(dd if="$DEVICE" bs=4M count=$((ISO_SIZE / 4194304 + 1)) 2>/dev/null \
          | head -c "$ISO_SIZE" \
          | sha256sum | awk '{print $1}')
if [[ "$DEV_SHA" == "$ISO_SHA" ]]; then
  log "✓ sha256 matches: $DEV_SHA"
  log "🟢 USB WRITE COMPLETE — $DEVICE now boots as F44 installer"
  log ""
  log "  Next step: eject with 'sudo eject $DEVICE', insert into"
  log "  test hardware, boot, follow Fedora installer, then use"
  log "  'bootc switch' to point at the S7 OCI image for first-boot"
  log "  QUBi lineage."
  exit 0
else
  log "🔴 sha256 MISMATCH — $DEVICE may be incomplete or corrupt"
  log "    ISO sha:    $ISO_SHA"
  log "    Device sha: $DEV_SHA"
  exit 3
fi
