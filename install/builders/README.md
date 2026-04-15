# S7 SkyBuilder

One menu entry under S7 SkyQUBi. Opens a terminal picker. Pick a USB
flavor, the build runs, the signed `.iso` lands in `build/output/`,
then you flash it with **Fedora Media Writer**.

## Recommended flow

```
 ┌──────────────┐     ┌──────────────────┐     ┌──────────────────┐
 │ S7 SkyQUBi → │     │ Signed ISO in    │     │ Fedora Media     │
 │ S7 SkyBuilder│ ──▶ │ build/output/    │ ──▶ │ Writer → USB     │
 └──────────────┘     └──────────────────┘     └──────────────────┘
  pick 1/2/3           S7-<flavor>-            point-and-click
                       SkyCAIR-<ver>.iso       any family member
```

1. **Open the menu** → S7 SkyQUBi → **S7 SkyBuilder**.

2. **Pick a flavor** in the terminal picker:
   - `[1]` **S7-X27-SkyCAIR**  — modular layered live (Trinity 0 DOOR)
   - `[2]` **S7-F44-SkyCAIR**  — full installer       (Trinity +1 REST)
   - `[3]` **S7-R101-SkyCAIR** — core-fixed updates   (Trinity -1 ROCK)

3. **Wait.** Logs stream in the same terminal. Output lands at
   `build/output/S7-<flavor>-SkyCAIR-<ver>.iso`.

4. **Launch Fedora Media Writer** (picker option `[f]`, or the app menu).

5. **Click "Custom image"**, pick the ISO, pick the USB, hit Write.

6. **Eject, plug into the target machine, boot.**

## Admin options in the picker

- `[o]` open `build/output/` in the file manager
- `[l]` tail the latest build log
- `[f]` launch Fedora Media Writer
- `[q]` quit

## Why Fedora Media Writer

- Already Fedora-trusted, handles UEFI + isohybrid automatically
- Graphical, no terminal, no sudo prompts the user has to judge
- Detects USBs, refuses to write to the system disk
- One tool for all three S7 flavors (no per-flavor flashing logic)
- Anyone in the family can flash a USB without a shell

## If Fedora Media Writer is not installed

```bash
sudo dnf install mediawriter
```

One-time. After that it lives in the application menu.

## Direct wrapper invocation (for stewards)

The picker is a convenience. Each wrapper is still directly invokable
from a terminal if you know what you're doing:

```bash
/s7/skyqubi-private/install/builders/s7-build-x27-skycair.sh
/s7/skyqubi-private/install/builders/s7-build-f44-skycair.sh
/s7/skyqubi-private/install/builders/s7-build-r101-skycair.sh
```

Logs: `build/logs/` · Output: `build/output/` (both gitignored)

## Advanced: full-custody multiboot

For users who want **one USB that boots all three flavors** with S7
owning the grub chain, see `iso/skyloop/README.md`. SkyBuilder +
Fedora Media Writer is the everyday path; SkyLoop is the sovereignty
path.

## Files

| File | Purpose |
|---|---|
| `s7-skybuilder.sh` | The picker (what the menu entry launches) |
| `s7-build-common.sh` | Shared notify-send + `rebrand_output` + `print_flash_instructions` helpers |
| `s7-build-x27-skycair.sh` | Wraps `iso/porteux/slipstream.sh` |
| `s7-build-f44-skycair.sh` | Wraps `iso/build-iso.sh` (uses `pkexec` for bootc-image-builder) |
| `s7-build-r101-skycair.sh` | Wraps `iso/rocky/slipstream.sh` |
