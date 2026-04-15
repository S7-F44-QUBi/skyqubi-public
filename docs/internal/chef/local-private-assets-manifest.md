---
title: Local-Private-Assets manifest
date: 2026-04-15 (SOLO block day 2)
location: /s7/Local-Private-Assets/ (filesystem, NOT in git)
purpose: Covenant-visible record of what binary artifacts live in the filesystem staging area, since the filesystem itself is not tracked by git.
---

# Local-Private-Assets — current contents

Per Jamie's three-sentence covenant framing:

> *"Local-Private-Assets contain TAR GZIP ETC, all push to private then we have Public and Immutable for Business to pull from for Testing."*

This directory is the INSIDE staging area that feeds the OUTSIDE distribution surfaces. Its contents are NOT committed to git — they are raw binary artifacts staged here, their existence + sha256 + purpose recorded in this manifest, and they are moved into the immutable constellation via signed ceremony (not git commit).

## Current contents (2026-04-15 SOLO block)

### s7-skycair-v6-genesis-covenant-clean.oci-archive.tar ⭐ (preferred for ship)

- **Size:** 2.7 GB (compressed oci-archive; uncompressed image is 6.6 GB)
- **sha256:** `bc7b36b016b9c573d16e7d3891f89b15e16f0cb6cbdf4ec2c94c19f9de7fc525`
- **Created:** 2026-04-15 00:34 UTC (during the SOLO block, via `iac/build-bootc.sh --tag v6-genesis`)
- **Contents:** OCI archive of the fresh `localhost/s7-skycair:v6-genesis` / `localhost/s7-skycair:latest` build with the Chair's Containerfile cleanup applied
- **Image id:** `b0693a78e3fe`
- **Labels:**
  - `org.opencontainers.image.title=S7 SkyCAIR`
  - `org.opencontainers.image.licenses=Apache-2.0 AND BSL-1.1`
  - `org.skycair.civilian-only=true`
- **Base:** `quay.io/fedora/fedora-bootc:44`
- **Purpose:** Covenant-clean hardware test + eventual ship. Transfer to test HW and run `bootc switch --transport oci-archive:/path/to/this.tar localhost/s7-skycair:v6-genesis`.

**Covenant status:**

- ✅ Self-contained, no network needed to unpack
- ✅ Pure OCI archive (bootc-compatible)
- ✅ **No NPM** (Layer 2 cleanup applied)
- ✅ **No Ollama curl|sh at build time** (Layer 4 deferred to first-boot from vendored binary)
- ✅ **No ghcr.io refs** (hints updated to localhost/s7-skycair:v6-genesis)
- ✅ **No inline-comment dnf bug** (all section comments moved outside RUN blocks)
- ✅ All four covenant gaps from the 2-day-old build are CLOSED

**This is the image for the ship.** Use it for tonight's hardware test AND as the v6-genesis baseline for the first real immutable-S7-F44 advance.

### s7-skycair-existing-build-2026-04-12.oci-archive.tar (fallback, gappy)

- **Size:** 5.0 GB (5,296,627,712 bytes)
- **sha256:** `405e3fe9af902e5ee24421690026704c3e0aa9201b65158cf9744f7851dfa882`
- **Created:** 2026-04-15 00:20 UTC (during the SOLO block, from an existing 2-day-old image)
- **Contents:** OCI archive of `localhost/s7-skycair:latest` as it existed at 2026-04-12T22:15:35Z
- **Image id:** `a9cd72806677`
- **Layer count:** 29
- **Labels:**
  - `org.opencontainers.image.title=S7 SkyCAIR`
  - `org.opencontainers.image.licenses=Apache-2.0 AND BSL-1.1`
  - `org.skycair.civilian-only=true`
  - `maintainer=Jamie Lee Clayton <jamie@2xr.llc>`
- **Base:** `quay.io/fedora/fedora-bootc:44`
- **Purpose:** Hardware test on a second physical machine. Transfer to test HW via USB or rsync, then `bootc switch --transport oci-archive:/path/to/this.tar localhost/s7-skycair:latest` after Fedora 44 is installed from the USB.

**Covenant status of this artifact:**

- ✅ Self-contained (no network needed to unpack or install)
- ✅ Pure OCI archive (bootc-compatible)
- ✅ Has S7 branding baked in (Layer 5 copied `branding/` into `/usr/share/`)
- ✅ Has CWS engine in `/opt/s7/engine/`
- ✅ Has systemd user services in `/usr/lib/systemd/user/`
- 🟡 **Known covenant gaps in this specific build (pre-tonight's Containerfile cleanup):**
  - Contains `nodejs24-npm` from the old Layer 2 (the No-NPM rule was violated in the build 2 days ago; fixed in `Containerfile` tonight at commit `51dbef1` but this saved image is from BEFORE that fix)
  - Contains Ollama installed via `curl | sh` from ollama.com (violated sovereignty; fixed tonight by removing Layer 4 entirely; this saved image was built BEFORE that fix)
  - Contains references to `ghcr.io/skycair-code/...` in some internal hints (covenant says no external registries)
- 🟢 **All three gaps are documented. The next build via `iac/build-bootc.sh` produces a covenant-clean image that closes them.**

### Which image to use

**Default: `s7-skycair-v6-genesis-covenant-clean.oci-archive.tar`.** It's smaller (2.7 GB vs 5.0 GB), covenant-clean (all four gaps closed), and built tonight with the tightened Containerfile. This is the preferred artifact for both the hardware verification and the eventual v6-genesis ship.

**Fallback: the 2-day-old build.** If for some reason the clean image doesn't work on the test hardware (e.g., a missing package Fedora 44 wants but the clean build excluded), the older build is still present as a known-working baseline. The covenant gaps matter for ship, not for test. Mark the test result honestly if you have to use the fallback.

### How the clean image was built

```bash
# From the skyqubi-private working tree, as the s7 user, no sudo:
bash iac/build-bootc.sh --tag v6-genesis
```

The script wraps `podman build` with `TMPDIR=/s7/.cache/buildah` because `/var/tmp` is a 512M tmpfs on this host and the commit step needs multi-GB scratch space. Takes ~10 minutes on a warm cache. Output tagged both `localhost/s7-skycair:v6-genesis` and `localhost/s7-skycair:latest`.

The save step (same TMPDIR fix required):

```bash
TMPDIR=/s7/.cache/buildah podman save \
  --format oci-archive \
  -o /s7/Local-Private-Assets/s7-skycair-v6-genesis-covenant-clean.oci-archive.tar \
  localhost/s7-skycair:v6-genesis
```

## Not yet in Local-Private-Assets

- Ollama vendored binary (for the offline first-boot install path Layer 4 now delegates to)
- Signed image manifest (sha256 + gpg signature) — produced by the ceremony, not by the Chair during SOLO
- F44 installer USB image (lives in `iso/fedora-x44/dist/`, not here)
- PorteuX X27 ISOs (live in `iso/porteux/dist/`, not here)

## Maintenance rules

1. **Append-only manifest.** New artifacts get a new section here. Removed artifacts get a timestamped "removed" section. The filesystem itself may have items come and go; this manifest is the audit trail.

2. **Every entry gets a sha256.** A manifest entry without a hash is worthless for verification.

3. **Covenant gaps are named honestly.** If a file has known issues, say so here. Do not let a reader think a gap-ridden artifact is covenant-clean.

4. **No commits of the artifacts themselves.** Git tracks the manifest; the filesystem holds the binaries. This is the same discipline as the git-bundle model in `reset-to-genesis.sh` — bundles live in `/tmp/s7-gold-reset/`, not in the repo.

5. **This file is PRIVATE** (`docs/internal/` prefix). It does NOT sync to public. Business partners see only what the immutable constellation releases — this manifest is the household's audit layer beneath that.
