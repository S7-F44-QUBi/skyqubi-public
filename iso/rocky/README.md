# iso/rocky — S7 SkyCAIR 7 Rocky/Fedora Live Slipstream

Produces a bootable SkyCAIR 7 live ISO by slipstreaming the S7 update payload as a top-level `/s7-update/` directory on the ISO. Does NOT modify the inner squashfs (which would require real root + loop mount).

## Quick start

```bash
./iso/rocky/slipstream.sh
```

Output: `iso/rocky/dist/s7-skycair-rocky-vYYYY.MM.DD.iso`, signed with `/s7/.config/s7/s7-image-signing`.

## 4 phases

1. **Copy source USB** (`/run/media/s7/SKYCAIR7`) → writable `work/` (~857 MB)
2. **Stage S7 payload** from `skyqubi-private` (allowlist: iac/, engine/tools/, branding/, profiles/, services/, s7-manager.sh, etc.)
3. **mkisofs + isohybrid** → 906 MB bootable hybrid ISO (via `quay.io/fedora/fedora:44` container)
4. **ssh-keygen -Y sign** with identifier `s7-skyqubi`

## Why "payload" slipstream (not deep merge)

The SKYCAIR7 ISO has a **nested format**:

```
SKYCAIR7.iso → LiveOS/squashfs.img → LiveOS/rootfs.img (ext4)
```

Modifying the inner rootfs requires:
1. `unsquashfs` the outer squashfs
2. **Loop-mount** the inner rootfs.img (real root + `/dev/loop*`)
3. Modify files
4. `mkfs.ext4` → new rootfs.img
5. Re-squash
6. Replace in the ISO

Steps 2 and 4 break reproducibility and need root that rootless podman doesn't have. Leaving the squashfs untouched and adding `/s7-update/` at the ISO top level is simpler, cleaner, and the content is still discoverable at runtime via `/run/initramfs/live/s7-update/`.

## Activating the payload on the live system

```bash
sudo cp -a /run/initramfs/live/s7-update/. /opt/s7/
cd /opt/s7
./s7-manager.sh doctor
./profiles/import-profile.sh
```

## Related

- `../porteux/slipstream.sh` — PorteuX XZM modular (auto-merging)
- `../build-iso.sh` — bootc-image-builder path
- `../ventoy/` — multi-layer loopback architecture (the new target)
