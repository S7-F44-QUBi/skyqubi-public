# iso/porteux — S7 PorteuX Slipstream Pipeline

This directory produces a **bootable S7 PorteuX live USB ISO** by slipstreaming the latest S7 content into the existing PorteuX build.

| Path | Output | Use case |
|---|---|---|
| `iso/build-iso.sh` | Anaconda installer ISO from root Containerfile | Install S7 on a new machine's internal disk |
| `iso/porteux/slipstream.sh` | PorteuX live USB ISO (squashfs-layered) | Boot S7 from USB without touching the host disk |

## Quick start

```bash
# Plug in the existing PorteuX USB (auto-mounts to /run/media/s7/S7 on Budgie)
./iso/porteux/slipstream.sh
```

Output lands at `iso/porteux/dist/s7-porteux-vYYYY.MM.DD.iso`, signed with `/s7/.config/s7/s7-image-signing`.

## What it does (5 phases)

1. **Copy source USB** to writable `work/` (~1.9 GB)
2. **Stage module content** from `/s7/skyqubi-private` with an allowlist (iac/, engine/tools, branding/, profiles/, services/, autostart/, desktop/, install/, docs/public/, mcp/, os/, s7-manager.sh, etc.)
3. **`mksquashfs`** → `work/porteux/modules/012-s7-update-YYYYMMDD.xzm` (xz compression, 1 MiB blocks, x86 BCJ)
4. **`mkisofs + isohybrid`** → `dist/s7-porteux-vYYYY.MM.DD.iso` (ISO 9660, hybrid MBR, Volume ID `S7`)
5. **`ssh-keygen -Y sign`** with identifier `s7-skyqubi` (consistent with iac/ verify)

## Why run tools in a container

`mksquashfs`, `mkisofs`, and `isohybrid` are NOT installed on the dev laptop. The script runs each phase inside a rootless `quay.io/fedora/fedora:44` container (cached from earlier iac/ work). No host tools installed, no sudo needed except for the final `dd` to a physical USB.

## PorteuX module numbering

| Directory | Purpose | Loaded |
|---|---|---|
| `porteux/base/` | Kernel, core, gui, xfce (the PorteuX base) | Always |
| `porteux/modules/` | Always-loaded add-ons | Always |
| `porteux/optional/` | Conditional — loaded only if in porteux.cfg | Conditional |

Modules load in **filename-sorted order**:

```
000-kernel-6.19.5-20260228.xzm       (base/)
001-core-current-20260228.xzm         (base/)
002-gui-current-20260228.xzm          (base/)
002-xtra-current-20260228.xzm         (base/)
003-xfce-4.20-current-20260228.xzm    (base/)
010-skyark.xzm                        (optional/)
011-skyview.xzm                       (optional/)
012-s7-update-20260412.xzm            (modules/) ← slipstream.sh output
```

`012-s7-update-*` loads AFTER everything else, so S7 content overlays on top. Files in the module at `/opt/s7/skyqubi-private/` merge into the live root at boot.

## Testing the ISO

**In KVM (fastest)**:

```bash
qemu-system-x86_64 -m 4G -smp 2 \
  -cdrom iso/porteux/dist/s7-porteux-v2026.04.12.iso \
  -boot d -enable-kvm
```

**On a physical USB (destructive — verify the device first!)**:

```bash
lsblk -f -o NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT
sudo dd if=iso/porteux/dist/s7-porteux-v2026.04.12.iso of=/dev/sdX bs=4M status=progress oflag=sync
sync
```

## Boot flow after slipstream

1. isolinux loads the kernel
2. Base XZMs mount
3. **012-s7-update-YYYYMMDD.xzm overlays** → `/opt/s7/skyqubi-private/` available
4. skybuilder auto-logs in (per porteux.cfg)
5. XFCE session loads
6. rc.s7-user runs
7. New S7 content ready at `/opt/s7/skyqubi-private/`:
   - `./s7-manager.sh doctor` — platform health check
   - `./profiles/import-profile.sh --name s7-desktop-default` — apply Tonya palette
   - `./iac/build-s7-base.sh` — Fedora base OCI build
   - `./iac/keyops/verify-key.sh` — signing key check

## Known limitations

- `isohybrid` prints a warning `more than 1024 cylinders: 1916` — informational, modern BIOSes and all UEFI systems boot fine
- Signature identifier hardcoded to `s7-skyqubi` for consistency with iac/
- Source USB must be mounted before running
- Re-runs reuse `work/` unless `--refresh` is passed (saves the 1.9 GB re-copy)
- The XZM module is a SNAPSHOT at build time; edit-then-re-run to refresh

## Related

- `../build-iso.sh` — the sibling bootc-image-builder path
- `iac/keyops/verify-key.sh` — signing key health check
- `docs/internal/runbooks/s7-image-signing-key-ops.md` — key lifecycle runbook
- `/run/media/s7/S7/porteux/create-iso.sh` — the original PorteuX build script this slipstream borrows from
