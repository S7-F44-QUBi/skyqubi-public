# iso/ — S7 SkyCAIR Bootable ISO Pipeline

This directory builds the **S7 SkyCAIR bootable installer ISO** from the root `Containerfile`. It's the counterpart to `iac/` — where `iac/` produces small runtime containers, `iso/` produces the **full bootable OS image** you burn to a USB and install on bare metal.

## Files

| File | Purpose |
|---|---|
| `manifest.yaml` | Source of truth — OCI image name, builder image, output formats, sign key, chunk size |
| `config.toml` | bootc-image-builder configuration — users, kickstart, customizations |
| `build-iso.sh` | Orchestrator — 7 gated phases from preflight to signed ISO |
| `dist/` | Build outputs. Git-ignored except `.gitkeep`. |

## Status: SCAFFOLD, NOT YET EXECUTED

The build pipeline is **fully scaffolded but has not been run end-to-end in production**. First-run failures are expected — most commonly:

- `bootc-image-builder` version compatibility with Fedora 44 (package pinning may drift)
- Root `Containerfile` package availability — `dnf group install "Budgie"` requires full Fedora (not minimal), so this runs on a different base than `iac/`
- Disk pressure — ~10 GB peak during build (4 GB OCI image + 2 GB ISO + work area)
- `bootc-image-builder` needs **privileged podman** for loopback devices; this means either rootful podman or carefully-scoped capabilities

Treat the first real run as an iteration session, not "ship it."

## Prerequisites

Before running `./build-iso.sh`:

1. **Podman** — already installed on every S7 machine (verified by `s7-manager.sh doctor` phase 3)
2. **Signing key** — `/s7/.config/s7/s7-image-signing` must pass `iac/keyops/verify-key.sh`. If not, the ISO builds but is unsigned (warning emitted, not a hard fail)
3. **Disk** — ≥10 GB free at `iso/dist/`. Preflight checks this.
4. **bootc-image-builder** — auto-pulled from `quay.io/centos-bootc/bootc-image-builder:latest` on first run (~2 GB download)
5. **Network** — needed for the upstream pulls (Fedora 44 repo + Ollama installer + pip packages)

## Usage

### Dry run — just preflight

```bash
./build-iso.sh --dry-run
```

Checks podman, signing key, disk space, and Containerfile presence. Exits 0 if ready. Does not actually build.

### Full build — today's date tag

```bash
./build-iso.sh
```

Produces `dist/s7-skycair-v$(date +%Y.%m.%d).iso` + `.sig`. **Takes 30-60 minutes** on typical hardware.

### Full build — explicit tag

```bash
./build-iso.sh --tag v1.0.0
```

### Reuse existing OCI image (skip the 15-min build)

```bash
# First time:
podman build -t localhost/s7-skycair:latest -f ../Containerfile ..

# Then any number of times:
./build-iso.sh --skip-oci-build --tag v1.0.0
```

Useful for iterating on the ISO layer without rebuilding the whole OS every time.

## Output

After a successful run, `dist/` contains:

```
s7-skycair-v1.0.0.iso       ← the bootable installer
s7-skycair-v1.0.0.iso.sig   ← ssh-keygen signature (if key was healthy)
build-iso.log               ← full build transcript
```

## Testing the ISO

### In KVM (fastest)

```bash
qemu-system-x86_64 \
  -m 4G \
  -smp 2 \
  -cdrom dist/s7-skycair-v1.0.0.iso \
  -boot d \
  -enable-kvm
```

### On a physical USB (destructive — check the device first!)

```bash
# Find the target USB
lsblk -f -o NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT

# Write the ISO (replaces EVERYTHING on the stick)
sudo dd if=dist/s7-skycair-v1.0.0.iso of=/dev/sdX bs=4M status=progress oflag=sync
sync
```

**Before running `dd`**, double-check `sdX` is the USB you intended, not your internal disk. Worth running `lsblk` twice — once before unplugging the USB, once after — and diffing.

## How this fits the iac/ + signing story

`iac/Containerfile.base` builds **small runtime containers** (fedora-minimal base, microdnf). `iso/build-iso.sh` builds the **bootable OS** (full fedora:44 + Budgie + systemd + Ollama + S7 stack).

**Both sign with the same key** (`/s7/.config/s7/s7-image-signing`) using identical `ssh-keygen -Y sign -n file -I <identifier>` semantics. Different identifiers distinguish them:

- `iac/` uses identifier `s7-skyqubi`
- `iso/` uses identifier `s7-skycair-iso`

This keeps one sovereign key for all S7 artifacts but lets the verifier know *what* it's verifying.

## Known work still needed

1. **Generalize `iac/pack-chunks.sh`** to accept a `--basename` argument so it can chunk ISOs with S7-SkyCAIR naming, not just iac base naming. Currently phase 6 of `build-iso.sh` logs a TODO and skips chunking.
2. **Add bootc-image-builder digest pinning** in `manifest.yaml` — currently tracks `:latest`, which is fine for development but should pin to a specific sha256 before any ISO ships to production.
3. **Test the full pipeline end-to-end** on real hardware — this scaffold has been syntax-checked but not run. The first real invocation is the integration test.
4. **Decide on PorteuX vs bootc-image-builder** long-term — the existing S7 live USBs (SKYCAIR7, S7) are PorteuX-based, not bootc. This pipeline is the bootc path. Jamie may want both: bootc ISO for bare-metal installs, PorteuX XZM for the live-USB learn/demo path. That's a separate pipeline if needed.

## When to run this

- **For testing:** run `--dry-run` first, then `--skip-oci-build` after one good OCI build exists, to iterate on ISO config fast
- **For release:** run the full pipeline, test the resulting ISO in KVM, THEN `dd` to USB
- **Never in the middle of the demo** — burns ~60 min of CPU and disk, will make the laptop slow

## Related

- `/s7/skyqubi-private/Containerfile` — the root OCI image this ISO is built from
- `iac/Containerfile.base` — the runtime container base (DIFFERENT purpose)
- `iac/keyops/verify-key.sh` — signing key health check (shared with iac/)
- `iac/pack-chunks.sh` — chunk helper (needs generalization to use here)
- `docs/internal/superpowers/specs/2026-04-12-iac-context-and-next-steps.md` — why iac/ and iso/ are separate product layers
