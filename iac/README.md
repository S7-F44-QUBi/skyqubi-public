# iac/ — S7 Fedora Base OCI Fork Pipeline

This directory builds the **S7 Fedora Base** image — a hardened, audited fork of `quay.io/fedora/fedora-minimal:44`. Everything in here is **private-only** (excluded from the public repo per `feedback_no_ghcr.md`).

## Files

| File | Purpose |
|---|---|
| `manifest.yaml` | Source of truth: packages, users, dirs, files, ports. The audit scripts read this file, not the Containerfile. Update this first when making changes. |
| `Containerfile.base` | The hardening recipe. Must stay consistent with `manifest.yaml`. |
| `audit-pre.sh` | Pre-build: pulls upstream, verifies hash + provenance against `trusted-upstream-hashes.txt`. |
| `audit-post.sh` | Post-build: verifies the built image matches every rule in `manifest.yaml`. |
| `pack-chunks.sh` | Splits the built `.tar` into 100 MB chunks with SHA256SUMS, manifest.json, and a self-contained reassemble.sh. |
| `build-s7-base.sh` | Orchestrator. Run this, not the individual scripts. |
| `dist/` | Build outputs. Git-ignored except for `.gitkeep`. |

## Usage

### First build (fresh machine, no trust file yet)

```bash
./build-s7-base.sh --tag v1.0.0
```

On first run, `trusted-upstream-hashes.txt` doesn't exist. The pre-audit script creates it containing whatever hash it pulled. From then on, subsequent builds will only proceed if the pulled hash is in the trust file. Review every new line in that file manually before accepting it.

### Subsequent builds (trust file exists, new upstream)

```bash
./build-s7-base.sh --tag v1.0.1
```

If Fedora published a new minimal:44 image, pre-audit will detect the hash isn't in the trust file and fail. Review the change, then:

```bash
./audit-pre.sh --update-trust
./build-s7-base.sh --tag v1.0.1
```

### Dry run — check the pipeline without building

```bash
./build-s7-base.sh --dry-run
```

Runs only the pre-audit in dry-run mode (no actual pull). Useful for verifying the scripts are healthy.

### Verify an existing image without rebuilding

```bash
./build-s7-base.sh --verify
```

Runs only `audit-post.sh` against the currently-loaded `localhost/s7-fedora-base:latest`. Useful after pulling a shipped bundle from another machine.

## Output

After a successful build, `dist/` contains:

```
s7-fedora-base-v1.0.0.tar.00    ← chunk 0
s7-fedora-base-v1.0.0.tar.01    ← chunk 1
...
s7-fedora-base-v1.0.0.json      ← chunk manifest (sizes, hashes, order)
SHA256SUMS                       ← one hash per chunk + one for the reassembled tar
reassemble.sh                    ← self-contained re-assembly script for the receiver
build.log                        ← the full build transcript
audit-pre.log                    ← pre-audit transcript
audit-post.log                   ← post-audit transcript
```

Upload all files in `dist/` (except the `.log` files) to Wix Storage when ready. Per-file size governed by `manifest.yaml: build.chunk_size_bytes` (default 100 MB, works on any Wix premium plan).

## Receiving end — loading a bundle on another S7 machine

1. Download all chunks + `SHA256SUMS` + `reassemble.sh` into one directory
2. `chmod +x reassemble.sh`
3. `./reassemble.sh`

This verifies all hashes, stitches the chunks back into a single tar, verifies the combined hash, and runs `podman load -i` to register the image locally.

## Publishing to Wix Storage

Once a build produces chunks in `dist/`, publish them to your `skyqubi.com` Wix premium site:

```bash
# One-time credential setup (deferred — do when you generate a Wix API key):
mkdir -p /s7/.config/s7
# Save each value to its own mode-600 file
echo 'YOUR_WIX_API_KEY'   > /s7/.config/s7/wix-api-key   && chmod 600 /s7/.config/s7/wix-api-key
echo 'YOUR_WIX_SITE_ID'   > /s7/.config/s7/wix-site-id
echo 'YOUR_WIX_ACCT_ID'   > /s7/.config/s7/wix-account-id

# Export + run
export WIX_API_KEY=$(cat /s7/.config/s7/wix-api-key)
export WIX_SITE_ID=$(cat /s7/.config/s7/wix-site-id)
export WIX_ACCOUNT_ID=$(cat /s7/.config/s7/wix-account-id)
./publish-to-wix.sh --tag v1.0.0
```

Without the env vars set, `publish-to-wix.sh --tag …` prints the full setup guide and exits 0 (safe smoke test). Once credentials land, re-run to actually upload.

Uploads land under Wix Media in the folder `s7-releases/${TAG}/`.

## Receiving a published build on another S7 machine

```bash
# Option 1 — you have a URL list file
./receive-from-wix.sh --tag v1.0.0 --urls /path/to/urls.txt

# Option 2 — you have a manifest.json URL (script resolves chunk URLs from it)
./receive-from-wix.sh --tag v1.0.0 --manifest https://static.wixstatic.com/.../s7-fedora-base-v1.0.0.json
```

The script downloads all chunks, verifies `SHA256SUMS`, reassembles, verifies the reassembled tar, and `podman load`s the result. No manual steps required on the receiving end.

## What this does NOT do

- **Does not** push to any registry. No `podman push`. No ghcr.io, no Docker Hub, no quay.io. Per `feedback_no_ghcr.md`.
- **Does not** auto-update. There is no cron, no timer, no watcher. Manual invocation only. Per the sovereignty model — no silent updates.
- **Does not** layer the S7 application stack on top. That's the existing root-level `Containerfile` and is covered by a separate spec. This pipeline stops at producing a clean base for S7 to layer on.
- **Does not** scan for CVEs. Future enhancement if you add `trivy` or `oscap` to the post-audit.

## When to update `manifest.yaml`

If the S7 base needs a new package (e.g., something every S7 variant needs at the OS level), update `manifest.yaml` first, then update `Containerfile.base` to match. The Containerfile and manifest are compared package-by-package during the verification step. A mismatch is a hard fail.

If the package is only needed by one S7 application component, it belongs in that component's layer (the root-level `Containerfile`), not here.

## Troubleshooting

- **"pre-audit failed"** — review `dist/audit-pre.log`. Most common cause: upstream hash changed and you need to run `./audit-pre.sh --update-trust` after reviewing the change.
- **"post-audit failed"** — review `dist/audit-post.log`. Look for lines starting with `[FAIL]`. The exact check that failed tells you whether to edit `Containerfile.base` or `manifest.yaml`.
- **"podman build failed"** — a package dropped out of Fedora, or upstream changed a default. Read the podman output in `dist/build.log`.
- **"packing failed: No space left on device"** — `dist/` needs at least ~600 MB free during a full build (the uncompressed tar + the chunks exist simultaneously for a few seconds).

## The rule

No image leaves this directory without a PASS from both `audit-pre.sh` and `audit-post.sh`. The orchestrator enforces this mechanically. Do not bypass by running `podman save` directly.
