#!/usr/bin/env bash
# iac/receive-from-wix.sh
# Download a chunked s7-fedora-base build from Wix Media storage
# and reassemble + verify + podman-load on the receiving machine.
#
# This is the counterpart to publish-to-wix.sh. Runs on any S7
# machine that needs to install the base image from the sovereign
# Wix-hosted bundle.
#
# Input: a URL list file (one URL per line) OR a manifest.json URL.
# Output: localhost/s7-fedora-base:${TAG} loaded into podman.
#
# Usage:
#   ./receive-from-wix.sh --tag v1.0.0 --urls /path/to/urls.txt
#   ./receive-from-wix.sh --manifest https://static.wixstatic.com/.../manifest.json
#   ./receive-from-wix.sh --help
#
# The URL list contains (one per line, any order):
#   https://static.wixstatic.com/.../s7-fedora-base-v1.0.0.tar.00
#   https://static.wixstatic.com/.../s7-fedora-base-v1.0.0.tar.01
#   ...
#   https://static.wixstatic.com/.../SHA256SUMS
#   https://static.wixstatic.com/.../reassemble.sh
#   https://static.wixstatic.com/.../s7-fedora-base-v1.0.0.json

set -euo pipefail

TAG=""
URLS=""
MANIFEST_URL=""
WORKDIR="${TMPDIR:-/tmp}/s7-fedora-base-fetch"
KEEP=false

for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --help|-h)
      sed -n '2,20p' "$0" | sed 's|^# \?||'
      exit 0 ;;
    --tag)      j=$((i+1)); TAG="${!j}" ;;
    --urls)     j=$((i+1)); URLS="${!j}" ;;
    --manifest) j=$((i+1)); MANIFEST_URL="${!j}" ;;
    --workdir)  j=$((i+1)); WORKDIR="${!j}" ;;
    --keep)     KEEP=true ;;
  esac
done

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { printf '%s  %s\n' "$(timestamp)" "$*"; }
fail() { log "FAIL: $*"; exit 1; }

[[ -n "$TAG" ]] || fail "--tag required"

if [[ -z "$URLS" && -z "$MANIFEST_URL" ]]; then
  fail "either --urls <file> or --manifest <url> required"
fi

mkdir -p "$WORKDIR"
cd "$WORKDIR"

log "=== receive-from-wix.sh start ==="
log "tag:     $TAG"
log "workdir: $WORKDIR"

# ── Resolve URL list ─────────────────────────────────────────────
if [[ -n "$MANIFEST_URL" ]]; then
  log "[1/5] fetching manifest.json"
  curl -fsSL -o "$WORKDIR/manifest.json" "$MANIFEST_URL" || fail "could not fetch manifest from $MANIFEST_URL"
  # Extract chunk URLs assuming they're relative to the same base
  BASE_URL="${MANIFEST_URL%/*}"
  log "  base URL: $BASE_URL"
  python3 <<PY > "$WORKDIR/_urls.txt"
import json
m = json.load(open("$WORKDIR/manifest.json"))
base = "$BASE_URL"
for c in m["chunks"]:
    print(base + "/" + c["file"])
print(base + "/SHA256SUMS")
print(base + "/reassemble.sh")
PY
  URLS="$WORKDIR/_urls.txt"
fi

[[ -f "$URLS" ]] || fail "URL list file $URLS does not exist"

# ── Download every file ─────────────────────────────────────────
log "[2/5] downloading files"
while IFS= read -r url; do
  [[ -z "$url" || "$url" =~ ^# ]] && continue
  fname=$(basename "${url%%\?*}")
  log "  $fname"
  curl -fsSL -o "$WORKDIR/$fname" "$url" || fail "download failed: $url"
done < "$URLS"

# ── Verify hashes ────────────────────────────────────────────────
log "[3/5] verifying chunk hashes"
[[ -f "$WORKDIR/SHA256SUMS" ]] || fail "SHA256SUMS missing from the downloaded set"
cd "$WORKDIR"
sha256sum -c SHA256SUMS --ignore-missing || fail "chunk hash verification failed"

# ── Reassemble ───────────────────────────────────────────────────
log "[4/5] reassembling chunks"
BASENAME="s7-fedora-base-${TAG}.tar"
cat "$BASENAME".[0-9][0-9] > "$BASENAME"
# Verify the reassembled hash too
sha256sum -c SHA256SUMS --ignore-missing --quiet || fail "reassembled tar hash verification failed"

# ── Load into podman ─────────────────────────────────────────────
log "[5/5] podman load"
podman load -i "$BASENAME"

log "=== receive-from-wix.sh complete ==="
podman images | grep s7-fedora-base || log "WARNING: image did not appear in 'podman images' — check podman error"

if ! $KEEP; then
  log "cleaning workdir $WORKDIR"
  cd /
  rm -rf "$WORKDIR"
fi
exit 0
