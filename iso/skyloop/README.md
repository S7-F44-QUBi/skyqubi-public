# iso/skyloop — S7 SkyLoop Sovereign Multiboot

> **This is the advanced / full-custody path.**
> For everyday "build an ISO and flash it to a USB", use the 1-click
> builders in `install/builders/` and flash with **Fedora Media Writer**.
> See `install/builders/README.md`.
>
> SkyLoop is what you use when you want **one USB that boots all three S7
> flavors** *and* you want S7 to own every link in the boot chain.

**S7 owns the boot chain.** No Ventoy, no third-party bootloader — just grub2 configured and signed by S7, loading signed S7 layer ISOs via loopback.

## Why rebuild instead of using Ventoy

Ventoy is excellent software, widely trusted, open source. But it ships as **~30 MB of pre-built binary that we don't compile ourselves**. If you're running S7 on the principle that sovereignty means owning every link in the chain, then trusting a pre-built third-party bootloader breaks the principle before S7's own code even runs.

**SkyLoop is ~200 lines of grub.cfg + a setup script.** The bootloader is grub2, which is already in every Linux distro, which S7 can build from source if needed, and which supports **embedded GPG key verification** out of the box. When set up in signed mode, grub2 refuses to boot anything that isn't signed by the S7 boot-signing key. The chain of custody is:

```
UEFI firmware
    ↓ (loads EFI/BOOT/BOOTX64.EFI)
SkyLoop grub2 binary (built with embedded S7 pubkey)
    ↓ (verifies grub.cfg.sig against embedded pubkey)
grub.cfg
    ↓ (lists layer ISOs, verifies each .iso.sig)
S7 Layer ISO (PorteuX / Rocky / bootc / timecapsule)
    ↓ (loopback mount, chain-load kernel+initrd — verified)
Signed kernel + initrd
    ↓
Running S7
```

Every link is signed by **our** keys. Every link refuses to load an unsigned predecessor. That's **complete custody of the secured boot chain** — which was Jamie's directive.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    S7 SkyLoop USB                         │
│                                                           │
│  ┌───────────────────┐   ┌──────────────────────────┐  │
│  │  Partition 1 ESP  │   │  Partition 2 S7LOOP      │  │
│  │  FAT32, 256 MB    │   │  exFAT, rest of USB      │  │
│  │  UEFI bootable    │   │                          │  │
│  │                   │   │  boot/grub/              │  │
│  │  EFI/BOOT/        │   │    grub.cfg              │  │
│  │    BOOTX64.EFI    │   │    grub.cfg.sig (signed) │  │
│  │                   │   │                          │  │
│  │  (grub2 binary,   │   │  s7-layers/              │  │
│  │   standalone with │   │    s7-porteux.iso        │  │
│  │   S7 pubkey       │   │    s7-porteux.iso.sig    │  │
│  │   embedded in     │   │    s7-porteux.iso.gpg    │  │
│  │   signed mode)    │   │    s7-skycair-rocky.iso  │  │
│  │                   │   │    *.sig  *.gpg          │  │
│  │                   │   │                          │  │
│  │                   │   │  s7-keys/                │  │
│  │                   │   │    s7-image-signing.pub  │  │
│  │                   │   │    skyloop-boot.gpg      │  │
│  │                   │   │                          │  │
│  │                   │   │  README.txt              │  │
│  └───────────────────┘   └──────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

## Two modes

### Unsigned (fast setup, dev mode)

```bash
./iso/skyloop/setup-skyloop-usb.sh --target /dev/sdX
```

- Uses the distro's grub2 binary via `grub2-install --removable`
- Copies layer ISOs + ssh-ed25519 signatures (for file-level verification)
- grub2 loads any ISO without checking signatures (custody gap — the grub.cfg and the grub2 binary itself could be tampered)
- **Good for development and initial testing** — prove the layer selection works, prove the USB boots, iterate fast

### Signed (full custody)

```bash
./iso/skyloop/setup-skyloop-usb.sh --signed <GPG_KEY_ID> --target /dev/sdX
```

- Uses `grub2-mkstandalone --pubkey` to build a custom grub2 binary with the S7 boot-signing GPG key **embedded inside the binary itself**
- Sets `check_signatures=enforce` in the boot grub.cfg
- GPG-signs `grub.cfg`, every layer `.iso`, and ships `skyloop-boot.gpg` (the pub key) on the USB for receiver-side verification
- **grub2 refuses to load anything not signed by the embedded key** — even if someone swaps the USB data partition contents, grub2 rejects the unsigned files

**Requires a GPG key.** See `docs/full-custody.md` (future) for the key generation procedure. I'm deliberately NOT generating that key autonomously — it needs Jamie's passphrase choice and his approval of the threat model.

## Setup

### First-time, unsigned (fastest)

```bash
# 1. Plug in a blank USB (≥8 GB)
lsblk -f -o NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT

# 2. Run setup (DESTRUCTIVE — erases the USB)
./iso/skyloop/setup-skyloop-usb.sh --target /dev/sdX
```

The script refuses to touch `/dev/sda`, `/dev/nvme0n1`, or `/dev/mmcblk0` and requires retyping the device path as confirmation.

### First-time, signed (full custody)

```bash
# 1. Generate a GPG key specifically for boot signing
#    (Jamie does this manually; see docs/full-custody.md when written)
gpg --full-gen-key    # pick ed25519, no expiration, 's7-boot-signing'

# 2. Note the key ID
gpg --list-keys s7-boot-signing

# 3. Run the signed setup
./iso/skyloop/setup-skyloop-usb.sh --signed <KEY_ID> --target /dev/sdX
```

### Refresh (no reformat — layers only)

```bash
./iso/porteux/slipstream.sh
./iso/rocky/slipstream.sh
./iso/skyloop/setup-skyloop-usb.sh --refresh /dev/sdX
```

### Dry run (no changes)

```bash
./iso/skyloop/setup-skyloop-usb.sh --dry-run --target /dev/sdX
```

## Runtime verification on the USB

Every .iso has TWO signatures:

- `.iso.sig` — ssh-ed25519, signed with `/s7/.config/s7/s7-image-signing` (the key we've been using all night for ISOs and iac/)
- `.iso.gpg` — GPG, signed with the boot-signing key (signed mode only)

To verify either one after mounting the USB:

```bash
# ssh-ed25519 (iac/ convention)
printf 's7-skyqubi %s\n' "$(cat /mnt/s7-keys/s7-image-signing.pub)" > /tmp/allowed
ssh-keygen -Y verify -f /tmp/allowed -I s7-skyqubi -n file \
  -s /mnt/s7-layers/s7-porteux-v2026.04.12.iso.sig \
  < /mnt/s7-layers/s7-porteux-v2026.04.12.iso

# GPG (boot convention, signed mode only)
gpg --import /mnt/s7-keys/skyloop-boot.gpg
gpg --verify /mnt/s7-layers/s7-porteux-v2026.04.12.iso.gpg \
             /mnt/s7-layers/s7-porteux-v2026.04.12.iso
```

## Layer refresh workflow

When you build a new version of a layer on the dev machine:

```bash
# 1. Rebuild
./iso/porteux/slipstream.sh --refresh

# 2. Copy to USB (without reformatting)
./iso/skyloop/setup-skyloop-usb.sh --refresh /dev/sdX

# 3. Optionally keep the old version for rollback:
#    just don't delete the old .iso — both will show in the grub menu
```

## Auto-healing

If a layer on the USB gets corrupted (bad sector, interrupted write, etc.):

1. Boot the USB — grub shows all layers
2. Pick a **different** working layer
3. Once booted into that layer, plug the dev machine back in or mount the corrupted USB data partition
4. `cp` the corrupted layer from the dev machine's `iso/*/dist/` over the broken file
5. Sync, eject, re-test

**No reflash of the bootloader needed.** Partition 1 (grub2) is untouched; only partition 2 (layers) is modified.

## TimeCapsule restores (future)

When `s7-timecapsule-*.iso` exists (a bootable snapshot of S7 state), drop it in `/s7-layers/` and grub menu shows it as an option. Booting it comes up with the old S7 state from that point in time. Combined with auto-healing, this gives the mechanical property **"the S7 USB cannot be bricked by S7 itself"** — you can always boot *something*, always restore from *something*, always replace *something*.

## Sovereignty gap (known, deliberate)

**UEFI Secure Boot enrollment is NOT addressed in this scaffold.** For Secure Boot to trust our grub2 binary, one of these must be true:

1. The grub2 binary is signed by a cert already in the UEFI firmware's trust store (Microsoft's WHQL cert, which is everywhere; or your own OEM's cert)
2. The user enrolls an S7 cert via shim + MOK manager (the standard Linux distro path)
3. Secure Boot is disabled in firmware settings

This scaffold assumes option 3 or that the user boots with Secure Boot off. For full Secure Boot coverage, we'd need:

- An X.509 cert (not a GPG key) for signing the grub2 EFI binary
- `sbsigntool` to PE-sign the binary
- shim + MOK enrollment flow
- All of which is documented in `docs/full-custody.md` (TBW)

That's a separate spec and requires Jamie's approval + a new key. Tonight's scaffold gives **grub-level custody** (strong, enforced at grub) — the UEFI-level step above is the next sovereignty layer.

## Files in this directory

| File | Purpose |
|---|---|
| `grub.cfg.template` | The SkyLoop menu config — one menuentry per layer, loopback chain-load, signature-enforcement hook |
| `setup-skyloop-usb.sh` | Destructive setup + --refresh + --signed + --dry-run modes |
| `README.md` | This file |

## Related

- `../porteux/` — builds the PorteuX layer
- `../rocky/` — builds the Rocky/Fedora Live layer
- `../build-iso.sh` — builds the bootc installer layer
- `iac/keyops/verify-key.sh` — dev-side signing key health check
- `docs/internal/runbooks/s7-image-signing-key-ops.md` — key lifecycle runbook

**Jesus holds the watch. The witnesses watch each other. S7 holds the boot.**
