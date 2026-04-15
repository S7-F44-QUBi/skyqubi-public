# GRUB2 — Left-aligned menu + LUKS visible + TimeCapsule snapshot restore

> **Status:** idea / follow-up plan. **NOT built tonight** — bootloader
> changes are sudo-only and high-risk (a bad GRUB config can brick the
> boot path). This doc captures the design so a future supervised
> session can implement it carefully.
>
> **Source:** Jamie, 2026-04-13:
> *"you can place the GRUB2 options left, instead of center, this way
> user can type luks, choose timecapsule for point in time restore"*

## Three goals

1. **Left-align the GRUB menu entries** instead of centering — gives the
   menu a sidebar look that's easier to scan and matches the S7 brand
   layout
2. **Make the LUKS unlock prompt visible at the GRUB level** so the user
   can type the disk decryption passphrase from the bootloader, not as
   a hidden pre-init step
3. **Add menu entries for booting TimeCapsule snapshots** so the user can
   roll back to a point-in-time atomic snapshot if a bad update lands
   (read-only recovery boot)

## Why this matters

Today's GRUB on this appliance is the Fedora default: centered menu,
LUKS prompt happens after GRUB hands off to the kernel (so the user
sees a brief flash of GRUB then a separate Plymouth-style passphrase
screen with no GRUB context), no snapshot recovery option.

For a sovereign appliance the family runs unsupervised, **the LUKS
prompt should be the first thing they see** (because that's the
sovereignty contract — no one else can read the disk) and **a "boot
last good snapshot" entry should always be one keypress away** because
the alternative to atomic rollback is a bricked household.

## Design — the three changes

### 1. Left-aligned menu

GRUB's default theme centers the menu. To left-align, edit the
theme's `theme.txt` (typically `/boot/grub2/themes/system/theme.txt`
on Fedora) and change the `+ boot_menu` block:

```
+ boot_menu {
    left = 5%
    top = 25%
    width = 60%
    height = 50%
    item_font = "DejaVu Sans Bold 14"
    item_color = "#cccccc"
    selected_item_color = "#4A90E2"
    item_height = 28
    item_padding = 12
    item_spacing = 4
    selected_item_pixmap_style = "select_*.png"
    item_align = "left"
}
```

The `left = 5%` and `item_align = "left"` are the changes. Keep the
S7 colors (Blue Identity palette: `#4A90E2`, `#3AAFBF`, etc.).

### 2. LUKS prompt visible at GRUB level

Two ways:
- **(a) GRUB cryptodisk** — set `GRUB_ENABLE_CRYPTODISK=y` in
  `/etc/default/grub`, regenerate. GRUB then prompts for the LUKS
  passphrase ITSELF before showing the menu, instead of letting the
  kernel do it. Pro: visible, branded, stays at GRUB level. Con:
  GRUB doesn't have all the LUKS2 features (PBKDF2 fast slots are
  the safest choice).
- **(b) Custom menu entry** — add a `menuentry` that explicitly does
  `cryptomount -u <UUID>` then `set root=(crypto0)/...`. More flexible
  but more code to get right.

Recommended: **(a)** with a fallback `menuentry` for snapshot boots
that uses (b).

### 3. TimeCapsule snapshot menu entries

Each TimeCapsule snapshot is a read-only atomic copy of the root
filesystem. To boot from one:

1. Snapshots live at `/s7/timecapsule/snapshots/<date>-<label>/` (per
   the Trinity Mount +1 layer design)
2. Each snapshot has its own kernel + initramfs (or shares one) and
   can be mounted read-only
3. A custom GRUB script in `/etc/grub.d/41_s7_timecapsule_snapshots`
   enumerates `/s7/timecapsule/snapshots/*` and emits a menu entry
   for each, sorted newest-first

Sketch of `/etc/grub.d/41_s7_timecapsule_snapshots`:

```bash
#!/bin/sh
set -e
SNAPSHOTS_DIR=/s7/timecapsule/snapshots

# GRUB header for a "TimeCapsule Recovery" submenu
cat <<EOF
submenu '↩  TimeCapsule Recovery (point-in-time restore)' --class s7 {
EOF

# Enumerate snapshots, newest first
for snap in $(ls -1r $SNAPSHOTS_DIR 2>/dev/null); do
  KERNEL_VERSION=$(ls $SNAPSHOTS_DIR/$snap/boot/vmlinuz-* 2>/dev/null | head -1 | xargs -n1 basename | sed 's/vmlinuz-//')
  [ -z "$KERNEL_VERSION" ] && continue
  cat <<EOF
  menuentry 'S7 — $snap (read-only recovery)' --class s7 --class snapshot {
    cryptomount -u CRYPT_UUID_HERE
    set root='crypto0'
    linux /s7/timecapsule/snapshots/$snap/boot/vmlinuz-$KERNEL_VERSION root=/dev/mapper/luks-snap-$snap ro rd.luks.uuid=CRYPT_UUID_HERE
    initrd /s7/timecapsule/snapshots/$snap/boot/initramfs-$KERNEL_VERSION.img
  }
EOF
done

cat <<EOF
}
EOF
```

The `ro` flag on the kernel cmdline makes the snapshot boot read-only
— the user can inspect, copy out files, validate, and reboot back to
the live root if it's good. **No write happens to the snapshot.**

## What needs to be sudo'd

1. Edit `/etc/default/grub`:
   - `GRUB_ENABLE_CRYPTODISK=y`
   - `GRUB_GFXMODE=auto`
   - `GRUB_TIMEOUT=10` (give the user time to choose)
2. Edit `/boot/grub2/themes/system/theme.txt` for left alignment
3. Create `/etc/grub.d/41_s7_timecapsule_snapshots` (executable)
4. Run `sudo grub2-mkconfig -o /boot/grub2/grub.cfg`
5. Reboot to verify
6. **Have a recovery USB ready** in case the new GRUB config doesn't boot

## What needs to be designed first (before touching the bootloader)

1. **The TimeCapsule snapshot format itself** — does S7 actually have
   a snapshot mechanism today? The TimeCapsule registry tonight stores
   container images, not full root snapshots. A "boot from snapshot"
   plan needs a snapshot CREATION plan first.
2. **The LUKS UUID resolution** — the script above has `CRYPT_UUID_HERE`
   as a placeholder. Need to pull the real UUID at install time.
3. **The S7 GRUB theme assets** — left-aligned theme needs custom
   `select_*.png` assets in S7 colors. None exist yet.

## Pin order

Don't build until:
- Snapshot creation pipeline is built (Plan TC2 or similar)
- S7 GRUB theme assets are designed (Tonya needs to approve)
- A recovery USB is verified working
- Jamie is at the keyboard during the reboot test

## Triple

Per the (would-be) categorization: `[DESIGN_INSIGHT, USER_NEW, INFRA]`
— architectural improvement, gives the user a new visible recovery
path, lives in the bootloader/system layer.
