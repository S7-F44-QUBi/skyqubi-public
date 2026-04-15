#!/usr/bin/env bash
# iso/skyloop/setup-skyloop-usb.sh
# Set up an S7 SkyLoop sovereign multiboot USB.
#
# SkyLoop is our own grub2-native loopback boot stack — no Ventoy,
# no third-party bootloader, S7 owns the full chain of custody.
#
# Architecture:
#   USB partition table:
#     sdX1 ESP  (FAT32, 256 MB)  — holds grub2 EFI binary + grub.cfg
#     sdX2 data (exFAT, rest)    — holds /s7-layers/ with .iso files
#                                    and /s7-keys/ with pub keys
#
# Boot flow:
#   UEFI firmware → /EFI/BOOT/BOOTX64.EFI (our grub2)
#                → grub.cfg (signed if --signed was used)
#                → user picks a layer
#                → loopback mount of /s7-layers/<layer>.iso
#                → chain-load that ISO's own kernel + initrd
#
# Sovereignty modes:
#   --unsigned         grub2 binary from distro packages, no sig checks
#                       (fastest setup, works immediately)
#   --signed KEY_ID    grub2-mkstandalone with --pubkey, sign grub.cfg,
#                       sign each layer ISO, enforce check_signatures
#                       (requires a GPG key, see iso/skyloop/docs/full-custody.md)
#
# Usage:
#   ./setup-skyloop-usb.sh --target /dev/sdX                   (DESTRUCTIVE)
#   ./setup-skyloop-usb.sh --refresh /dev/sdX                  (re-copy layers only)
#   ./setup-skyloop-usb.sh --signed <gpg-key-id> --target ...  (full custody)
#   ./setup-skyloop-usb.sh --dry-run --target ...              (no changes)
#   ./setup-skyloop-usb.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=/s7/skyqubi-private
TARGET=""
REFRESH=false
DRY_RUN=false
SIGNED=false
GPG_KEY_ID=""

for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --help|-h) sed -n '2,33p' "$0" | sed 's|^# \?||'; exit 0 ;;
    --target)  j=$((i+1)); TARGET="${!j}" ;;
    --refresh) REFRESH=true; j=$((i+1)); TARGET="${!j}" ;;
    --dry-run) DRY_RUN=true ;;
    --signed)  SIGNED=true; j=$((i+1)); GPG_KEY_ID="${!j}" ;;
  esac
done

[[ -n "$TARGET" ]] || { echo "FAIL: --target /dev/sdX required"; exit 1; }
if ! $DRY_RUN; then
  [[ -b "$TARGET" ]] || { echo "FAIL: $TARGET is not a block device"; exit 1; }
fi

run() { if $DRY_RUN; then echo "  [dry-run] $*"; else echo "  $*"; eval "$@"; fi; }

# ── Safety: refuse system disks ──
case "$TARGET" in
  /dev/sda|/dev/nvme0n1|/dev/mmcblk0)
    echo "REFUSING: $TARGET looks like a system disk — pick a USB"
    exit 1 ;;
esac

echo "═════════════════════════════════════════════════════"
echo "  S7 SkyLoop sovereign multiboot setup"
echo "  target:  $TARGET"
echo "  mode:    $(if $SIGNED; then echo "SIGNED (full custody, key $GPG_KEY_ID)"; else echo "unsigned (fast setup)"; fi)"
echo "  refresh: $REFRESH"
if $DRY_RUN; then echo "  MODE:    dry-run"; fi
echo "═════════════════════════════════════════════════════"
echo

lsblk -f -o NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT "$TARGET" 2>&1 || true
echo

# ── Layer inventory ──
echo "=== S7 layers on dev machine ==="
LAYERS=(
  "$REPO/iso/porteux/dist/s7-porteux-v2026.04.12.iso"
  "$REPO/iso/rocky/dist/s7-skycair-rocky-v2026.04.12.iso"
)
FOUND=()
for iso in "${LAYERS[@]}"; do
  if [[ -f "$iso" ]]; then
    FOUND+=("$iso")
    echo "  [OK]      $(basename "$iso") ($(du -h "$iso" | cut -f1))"
  else
    echo "  [MISSING] $(basename "$iso") — build with iso/*/slipstream.sh"
  fi
done
[[ ${#FOUND[@]} -gt 0 ]] || { echo "FAIL: no layers to install"; exit 1; }
echo

# ── Confirmation gate ──
if ! $DRY_RUN && ! $REFRESH; then
  echo "██████████████████████████████████████████████████████████"
  echo "█  DESTRUCTIVE OPERATION ON $TARGET"
  echo "█  Every byte on $TARGET will be erased and replaced"
  echo "█  with a GPT partition table + SkyLoop grub2 + S7 layers."
  echo "█  Ctrl+C NOW if this is the wrong device."
  echo "██████████████████████████████████████████████████████████"
  echo
  read -rp "Type the target device path to confirm ($TARGET): " confirm
  [[ "$confirm" == "$TARGET" ]] || { echo "confirmation mismatch — aborting"; exit 1; }
fi

# ── Phase 1: partition + format (skipped on --refresh) ──
if ! $REFRESH; then
  echo "[1/5] partition + format"
  run "sudo wipefs -a '$TARGET'"
  run "sudo parted -s '$TARGET' mklabel gpt"
  # ESP: 1 MiB → 257 MiB (256 MiB)
  run "sudo parted -s '$TARGET' mkpart ESP fat32 1MiB 257MiB"
  run "sudo parted -s '$TARGET' set 1 esp on"
  # Data: rest
  run "sudo parted -s '$TARGET' mkpart S7LOOP 257MiB 100%"
  run "sudo partprobe '$TARGET'"
  sleep 2

  ESP="${TARGET}1"
  DATA="${TARGET}2"
  [[ -b "$ESP" ]] || ESP="${TARGET}p1"
  [[ -b "$DATA" ]] || DATA="${TARGET}p2"

  run "sudo mkfs.vfat -F32 -n S7ESP '$ESP'"
  run "sudo mkfs.exfat -n S7LOOP '$DATA' || sudo mkfs.vfat -F32 -n S7LOOP '$DATA'"
fi

ESP="${TARGET}1"; [[ -b "$ESP" ]] || ESP="${TARGET}p1"
DATA="${TARGET}2"; [[ -b "$DATA" ]] || DATA="${TARGET}p2"

# ── Phase 2: mount + install grub2 to ESP ──
echo "[2/5] mount + grub2 install"
run "udisksctl mount -b '$ESP' >/dev/null 2>&1 || true"
run "udisksctl mount -b '$DATA' >/dev/null 2>&1 || true"
ESP_MNT=$(findmnt -n -o TARGET "$ESP" 2>/dev/null || echo "")
DATA_MNT=$(findmnt -n -o TARGET "$DATA" 2>/dev/null || echo "")
if ! $DRY_RUN; then
  [[ -n "$ESP_MNT" && -n "$DATA_MNT" ]] || { echo "FAIL: mount points not resolved"; exit 1; }
else
  ESP_MNT="${ESP_MNT:-/tmp/skyloop-dryrun-esp}"
  DATA_MNT="${DATA_MNT:-/tmp/skyloop-dryrun-data}"
fi

# Install grub2 EFI binary to the ESP
if $SIGNED; then
  echo "  building standalone grub2 with embedded GPG key $GPG_KEY_ID"
  TMPD=$(mktemp -d)
  trap 'rm -rf "$TMPD"' EXIT
  gpg --export "$GPG_KEY_ID" > "$TMPD/boot-key.gpg"
  # Generate a minimal grub.cfg that loads the main cfg from the data partition
  cat > "$TMPD/boot-grub.cfg" <<EOF
set check_signatures=enforce
search --label S7LOOP --set=root
configfile (\$root)/boot/grub/grub.cfg
EOF
  run "sudo grub2-mkstandalone \
        --format=x86_64-efi \
        --output='$ESP_MNT/EFI/BOOT/BOOTX64.EFI' \
        --pubkey='$TMPD/boot-key.gpg' \
        'boot/grub/grub.cfg=$TMPD/boot-grub.cfg'"
else
  echo "  installing standard grub2 EFI (unsigned)"
  run "sudo mkdir -p '$ESP_MNT/EFI/BOOT'"
  run "sudo grub2-install \
        --target=x86_64-efi \
        --efi-directory='$ESP_MNT' \
        --boot-directory='$ESP_MNT/EFI' \
        --removable \
        --recheck"
fi

# ── Phase 3: write grub.cfg + layers to data partition ──
echo "[3/5] write grub.cfg + copy layers"
run "sudo mkdir -p '$DATA_MNT/boot/grub' '$DATA_MNT/s7-layers' '$DATA_MNT/s7-keys'"

# Render grub.cfg from template (simple envsubst — no variables for now)
run "sudo cp '$SCRIPT_DIR/grub.cfg.template' '$DATA_MNT/boot/grub/grub.cfg'"

# Copy layers
for iso in "${FOUND[@]}"; do
  run "sudo cp '$iso' '$DATA_MNT/s7-layers/'"
  [[ -f "${iso}.sig" ]] && run "sudo cp '${iso}.sig' '$DATA_MNT/s7-layers/'"
done

# Copy pub key + signing key info
run "sudo cp '$REPO/s7-image-signing.pub' '$DATA_MNT/s7-keys/'"

# ── Phase 4: optional sign grub.cfg + layer ISOs ──
if $SIGNED; then
  echo "[4/5] GPG sign grub.cfg + layer ISOs with $GPG_KEY_ID"
  run "sudo gpg --default-key '$GPG_KEY_ID' --detach-sign '$DATA_MNT/boot/grub/grub.cfg'"
  for iso in "${FOUND[@]}"; do
    DEST_ISO="$DATA_MNT/s7-layers/$(basename "$iso")"
    run "sudo gpg --default-key '$GPG_KEY_ID' --detach-sign '$DEST_ISO'"
  done
  # Export pub key to the USB for runtime verification
  run "sudo gpg --export '$GPG_KEY_ID' > '$DATA_MNT/s7-keys/skyloop-boot.gpg'"
else
  echo "[4/5] signing SKIPPED (unsigned mode — rerun with --signed <KEY> for full custody)"
fi

# ── Phase 5: README + sync + unmount ──
echo "[5/5] README + sync + unmount"
cat > "/tmp/skyloop-readme.txt" <<EOF
S7 SkyLoop Sovereign Multiboot USB
==================================
Built:    $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Mode:     $(if $SIGNED; then echo "SIGNED (full custody, $GPG_KEY_ID)"; else echo "UNSIGNED (dev mode)"; fi)

LAYOUT
------
ESP (${ESP}, FAT32, 256 MB):
  EFI/BOOT/BOOTX64.EFI    — grub2 (standalone if --signed, else distro)

Data (${DATA}, exFAT):
  boot/grub/grub.cfg      — S7 SkyLoop menu configuration
  boot/grub/grub.cfg.sig  — GPG signature (signed mode only)
  s7-layers/              — one .iso per bootable S7 variant
                            plus .iso.sig (ssh-ed25519) and .iso.gpg (gpg, signed mode)
  s7-keys/
    s7-image-signing.pub        — ssh-ed25519 ISO signature pub key
    skyloop-boot.gpg            — GPG boot-signing pub key (signed mode only)
  README.txt              — this file

LAYERS LOADED
-------------
$(for iso in "${FOUND[@]}"; do echo "  $(basename "$iso") ($(du -h "$iso" | cut -f1))"; done)

BOOTING
-------
Plug into any x86_64 UEFI machine, pick this USB as boot device.
SkyLoop grub menu appears with 5s timeout. Pick a layer.

UPDATING A LAYER
----------------
On the dev machine:
  ./iso/porteux/slipstream.sh         # rebuild porteux
  ./iso/rocky/slipstream.sh           # rebuild rocky
  ./iso/skyloop/setup-skyloop-usb.sh --refresh ${TARGET}

Or manually: mount the data partition, cp new ISO to /s7-layers/,
sync, unmount. No reformat needed.

AUTO-HEAL
---------
If a layer fails to boot, pick a different one from the grub menu.
From that working layer, re-copy the broken .iso from the dev
machine back to /s7-layers/. No reflash needed.

SOVEREIGNTY
-----------
This USB contains NO third-party boot loader. The grub2 binary at
EFI/BOOT/BOOTX64.EFI is either:
  - the stock Fedora/Rocky grub2 (unsigned mode), or
  - a standalone binary with the S7 GPG key embedded (signed mode,
    check_signatures=enforce refuses unsigned .cfg or kernels)

In signed mode, every file grub loads must be signed by the S7
boot key or grub refuses to boot. Complete chain of custody:
UEFI firmware → S7 grub → S7 grub.cfg.sig → S7 kernel.sig → ISO.sig

Love is the architecture.
EOF
run "sudo cp /tmp/skyloop-readme.txt '$DATA_MNT/README.txt'"
rm -f /tmp/skyloop-readme.txt

run "sync"
run "udisksctl unmount -b '$DATA'"
run "udisksctl unmount -b '$ESP'"

echo
echo "═════════════════════════════════════════════════════"
echo "  S7 SkyLoop USB ready"
echo "  target: $TARGET"
echo "  layers: ${#FOUND[@]}"
if $SIGNED; then
  echo "  mode:   SIGNED — full custody chain active"
else
  echo "  mode:   UNSIGNED — re-run with --signed for full custody"
fi
echo "  Eject the USB and boot any x86_64 UEFI machine from it."
echo "═════════════════════════════════════════════════════"
