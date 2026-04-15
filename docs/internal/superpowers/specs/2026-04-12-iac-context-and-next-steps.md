# iac/ — Context, Product-Layer Distinction, and Next Steps

**Date:** 2026-04-12 late evening
**Purpose:** Record a critical finding from the autonomous iac/ pipeline session and lock down the correct understanding of S7's image layering before the next session makes the same mistake I almost did.

## The mistake I almost made

After building `iac/` with `Containerfile.base` targeting `quay.io/fedora/fedora-minimal:44`, my next-step reflex was *"rebase the root Containerfile onto `localhost/s7-fedora-base:latest`."*

**That is wrong.** The root `Containerfile` is a **bootc OS image** — a bootable Fedora + Budgie desktop + systemd + full DNF groups + Plymouth + SDDM + the whole desktop stack, built `FROM quay.io/fedora/fedora:44` (full Fedora, not minimal). Running `dnf group install "Budgie"` against fedora-minimal would fail because fedora-minimal uses `microdnf`, which has no concept of groups.

**The two images are for different products, not different versions of the same product:**

| Image | Base | Tool | Purpose | Tag |
|---|---|---|---|---|
| `ghcr.io/skycair-code/skycair:latest` (root Containerfile) | `quay.io/fedora/fedora:44` | `dnf` + groups | **bootc install** — boots as an OS | ~~ghcr.io~~ per feedback_no_ghcr.md, shipped differently |
| `localhost/s7-fedora-base:latest` (`iac/Containerfile.base`) | `quay.io/fedora/fedora-minimal:44` | `microdnf` | **runtime container** — base for pod containers | `localhost/` only |
| `localhost/s7-skyqubi-admin:v2.6` (pod container) | **unknown — not in tree** | unknown | runs inside the s7-skyqubi pod | loaded from `s7-skyqubi-admin-v2.6.tar` |

## The missing piece I discovered

`skyqubi-pod.yaml` references `localhost/s7-skyqubi-admin:v2.6`. `start-pod.sh` loads this image from a pre-built `s7-skyqubi-admin-v2.6.tar` fixture at repo root and even verifies an ssh-keygen signature (`s7-image-signing.pub`) against it. **There is no `Containerfile` in the repo that produces this image.** It's built externally and shipped as a signed tarball. I can't find the build recipe for it in the current private or public repos.

**This means:**
- The `s7-fedora-base` pipeline I built tonight has no immediate consumer in the repo — the runtime container it would serve as base for (`s7-skyqubi-admin`) is built out-of-tree.
- To actually USE `s7-fedora-base` as the base for `s7-skyqubi-admin`, we need to EITHER (a) find the external build recipe and update it, OR (b) create a new in-tree `engine/Containerfile` or similar that rebuilds `s7-skyqubi-admin` from our controlled base.

## What this means for the subsystem #4 plan

**Blocked.** Not by anything technical — by the simple fact that the source of `s7-skyqubi-admin:v2.6` is not in the repo. Until Jamie either (a) provides the existing build recipe for the admin image, or (b) approves creating a new one from scratch, there is no code to rebase.

**The bootc OS image (root `Containerfile`) should NOT be rebased onto `s7-fedora-base`.** It has different requirements (systemd, DNF groups, desktop environment) that fedora-minimal cannot satisfy. Leave it alone.

## What `iac/Containerfile.base` is actually for

**Runtime pod containers.** When we write the build recipe for `s7-skyqubi-admin` (or any other runtime container like a future BitNet inference sidecar), THAT recipe should start `FROM localhost/s7-fedora-base:latest`. Tonight's iac/ pipeline produces the base layer. The consumers come later.

## Next steps (tomorrow or later)

1. **Find or create the `s7-skyqubi-admin` build recipe.** Ask Jamie where the `.tar` comes from. If it's hand-built with `podman commit` or comes from an external CI, document the process and bring it in-tree as `engine/admin/Containerfile` or similar.
2. **Then** rebase the new in-tree admin Containerfile onto `localhost/s7-fedora-base:latest`. That IS subsystem #4, properly scoped.
3. **Separately:** the root bootc `Containerfile` for the OS image stays on `fedora:44` (full) forever or moves to a hypothetical `quay.io/fedora/fedora-bootc:44` if Jamie wants a pure bootc path. But it does NOT use `iac/Containerfile.base`.

## Note to future sessions reading this

If you see `iac/Containerfile.base` and think *"I should rebase the root Containerfile onto this"* — **don't**. Read this spec first. The two images are for different products. The iac/ pipeline is for runtime containers in the pod. The root Containerfile is for the bootable OS. They stay separate.

The word "fork" was ambiguous in the original session: "fork of Fedora Server Minimal 44 Latest" applies only to runtime containers. The bootc OS image was never in scope for that fork.
