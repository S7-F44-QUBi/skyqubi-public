# docs/internal — Private Only

Everything in this directory is **mechanically unreachable** from the public repo. The `s7-sync-public.sh` script only reads from `docs/public/` when populating public docs; this directory is untouched.

## What belongs here

- Architecture notes that reference ports, IPs, hostnames, credentials paths
- Patent drafts (until filing) and IP memos
- Deploy runbooks with actual deployment steps
- Incident postmortems
- Internal technical reference material
- Anything that contains secrets, tokens, keys, or permission grants

## What does NOT belong here

- User-facing documentation (goes to `docs/public/` instead)
- The website source (lives in `docs/public/`)
- Brand assets intended for public distribution (in `docs/public/branding/`)

## The rule

If you find yourself wondering whether a file belongs in `public/` or `internal/`, default to `internal/`. Moving it later is a conscious git operation (`git mv docs/internal/foo.md docs/public/foo.md`) that is reviewable in a diff. A file accidentally placed in `public/` can leak before anyone notices; a file correctly placed in `internal/` cannot.

## HF ops tools (`engine/tools/`)

Not inside `docs/` but worth noting here because they're private-only by whitelist (they live outside `docs/public/`):

- **`s7-witness-inventory.sh`** — canonical 7 witnesses metadata/license/downloads, NDJSON
- **`s7-bitnet-discovery.sh`** — find 1-bit / BitNet / ternary models for SkyQUANT*i* benchmark
- **`s7-dataset-candidates.sh`** — SFT/DPO dataset search with long-term stability scoring
- **`s7-paper-watch.sh`** — HF daily-papers filter for S7-relevant research (sovereign, consensus, BitNet, witness, offline, retrieval, quantiz, hallucin)

All four support `--help` and `--pretty`, emit NDJSON by default for shell composability, and use `HF_TOKEN` if set for higher API rate limits. Cron-runnable.

## Patent filing trigger

See `docs/internal/ip/GO-LIVE-2026-04-12.md` for the machine-readable record of the public go-live event, the 11 claims now on the open web, and the dates that matter for the patent disclosure clock.

## iac/ — Fedora OCI fork pipeline

Not inside `docs/` but worth noting — the `iac/` directory at repo root builds the **S7 Fedora Base** image, a hardened audited fork of `quay.io/fedora/fedora-minimal:44`.

- `iac/manifest.yaml` — declarative source of truth
- `iac/Containerfile.base` — the hardening recipe
- `iac/audit-pre.sh` + `iac/audit-post.sh` — verification gates
- `iac/build-s7-base.sh` — orchestrator (this is the entrypoint)
- `iac/pack-chunks.sh` — chunked distribution packaging
- `iac/README.md` — operator guide

Private-only (excluded from public sync). See `docs/internal/superpowers/specs/2026-04-12-s7-fedora-oci-fork-design.md` for the full design and `docs/internal/superpowers/plans/2026-04-12-s7-fedora-oci-fork.md` for the implementation plan.

## Subdirectories

- `architecture/` — internal architecture notes
- `ip/` — patent and IP documentation
- `reference/` — internal technical reference (schemas, credentials paths, etc.)
- `superpowers/` — private process docs, runbooks

See `../README.md` for the top-level documentation structure guide.
