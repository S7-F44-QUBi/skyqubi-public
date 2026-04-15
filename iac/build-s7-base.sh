#!/usr/bin/env bash
# iac/build-s7-base.sh
# S7 Fedora Base — end-to-end build orchestrator.
#
# Pipeline:
#   [1/4] audit-pre.sh      gate: must exit 0
#   [2/4] podman build      gate: must exit 0
#   [3/4] audit-post.sh     gate: must exit 0
#   [4/4] pack-chunks.sh    emit dist/*.tar.NN + manifest.json
#
# Usage:
#   ./build-s7-base.sh                   # full build, tag = today's date
#   ./build-s7-base.sh --tag v1.0.0      # explicit tag
#   ./build-s7-base.sh --dry-run         # pre-audit only, no build
#   ./build-s7-base.sh --verify          # re-run post-audit on existing image
#   ./build-s7-base.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.yaml"
CONTAINERFILE="$SCRIPT_DIR/Containerfile.base"
DIST="$SCRIPT_DIR/dist"
LOG="$DIST/build.log"
mkdir -p "$DIST"

DRY_RUN=false
VERIFY=false
TAG=""
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --help|-h)
      sed -n '2,15p' "$0" | sed 's|^# \?||'
      exit 0 ;;
    --dry-run) DRY_RUN=true ;;
    --verify)  VERIFY=true ;;
    --tag)     j=$((i+1)); TAG="${!j}" ;;
  esac
done

if [[ -z "$TAG" ]]; then
  TAG=$(date -u +"v%Y.%m.%d")
fi

IMAGE_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('$MANIFEST'))['build']['image_name'])")
IMAGE="${IMAGE_NAME}:${TAG}"
IMAGE_LATEST="${IMAGE_NAME}:latest"

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { printf '%s  %s\n' "$(timestamp)" "$*" | tee -a "$LOG"; }

log "═════════════════════════════════════════════════════"
log "  S7 Fedora Base build"
log "  tag:   $TAG"
log "  image: $IMAGE"
log "═════════════════════════════════════════════════════"

if $VERIFY; then
  log "[VERIFY mode] running post-audit on existing image only"
  "$SCRIPT_DIR/audit-post.sh" --image "$IMAGE_LATEST"
  exit $?
fi

# --- Phase 1: pre-audit ---
log "[1/4] audit-pre.sh"
if $DRY_RUN; then
  "$SCRIPT_DIR/audit-pre.sh" --dry-run || { log "pre-audit failed — abort"; exit 1; }
else
  "$SCRIPT_DIR/audit-pre.sh" || { log "pre-audit failed — abort"; exit 1; }
fi

if $DRY_RUN; then
  log "=== DRY-RUN: skipping build/audit-post/pack ==="
  log "=== build-s7-base.sh dry-run complete ==="
  exit 0
fi

# --- Phase 2: podman build ---
log "[2/4] podman build -t $IMAGE -f $CONTAINERFILE"
if ! podman build -t "$IMAGE" -t "$IMAGE_LATEST" -f "$CONTAINERFILE" "$SCRIPT_DIR" 2>&1 | tee -a "$LOG"; then
  log "podman build failed — abort"
  exit 1
fi
log "  built: $IMAGE"

# --- Phase 3: post-audit ---
log "[3/4] audit-post.sh"
if ! "$SCRIPT_DIR/audit-post.sh" --image "$IMAGE"; then
  log "post-audit failed — refusing to pack"
  exit 1
fi

# --- Phase 4: save ---
log "[4/5] podman save"
SAVE_PATH="$DIST/s7-fedora-base-${TAG}.tar"
if ! podman save -o "$SAVE_PATH" "$IMAGE" 2>&1 | tee -a "$LOG"; then
  log "podman save failed"
  exit 1
fi
log "  saved: $SAVE_PATH ($(stat -c %s "$SAVE_PATH") bytes)"

# --- Phase 5: sign ---
# Uses the dedicated s7-image-signing key (ed25519) via ssh-keygen -Y sign.
# Matches the verification pattern in start-pod.sh so both the admin pod
# image and the base image use identical signing semantics.
SIG_KEY="${S7_IMAGE_SIGNING_KEY:-/s7/.config/s7/s7-image-signing}"
SIG_PATH="${SAVE_PATH}.sig"
log "[5/5] ssh-keygen -Y sign → $(basename "$SIG_PATH")"
if [[ ! -f "$SIG_KEY" ]]; then
  log "  WARNING: signing key not found at $SIG_KEY"
  log "  set S7_IMAGE_SIGNING_KEY=/path/to/key, or generate with:"
  log "    ssh-keygen -t ed25519 -f $SIG_KEY -N ''"
  log "  proceeding UNSIGNED — receivers will fail signature verification"
else
  if ssh-keygen -Y sign -f "$SIG_KEY" -n file -I s7-skyqubi "$SAVE_PATH" 2>>"$LOG"; then
    log "  signed: $SIG_PATH"
  else
    log "  ssh-keygen sign failed — see $LOG"
    exit 1
  fi
fi

# --- Phase 6: pack chunks ---
log "[6/5] pack-chunks.sh"
PACK_ARGS=(--input "$SAVE_PATH" --tag "$TAG")
if [[ -f "$SIG_PATH" ]]; then
  PACK_ARGS+=(--sig "$SIG_PATH")
fi
if ! "$SCRIPT_DIR/pack-chunks.sh" "${PACK_ARGS[@]}"; then
  log "pack-chunks.sh failed"
  exit 1
fi

# Clean up the single monolithic tar after chunking (but keep the .sig in dist/)
rm -f "$SAVE_PATH"

log "═════════════════════════════════════════════════════"
log "  build complete"
log "  image:  $IMAGE"
log "  dist:   $DIST/s7-fedora-base-${TAG}.tar.NN + SHA256SUMS + reassemble.sh"
log "═════════════════════════════════════════════════════"
exit 0
