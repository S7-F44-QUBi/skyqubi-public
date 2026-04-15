#!/usr/bin/env bash
# iac/publish-to-wix.sh
# Upload a chunked s7-fedora-base build to Wix Media storage.
#
# Reads all files in iac/dist/ matching s7-fedora-base-${TAG}.tar.NN
# + the manifest.json + SHA256SUMS + reassemble.sh, and uploads each
# to the Wix Media Manager via the documented REST API.
#
# Requires:
#   WIX_API_KEY   — Wix account-level API key with media.upload scope
#   WIX_SITE_ID   — the Wix site ID to upload into (the skyqubi.com premium site)
#   WIX_ACCOUNT_ID — the Wix account ID (see https://manage.wix.com)
#
# Until those env vars are set, the script prints a detailed setup guide
# and exits 0 without uploading anything — safe to run as a smoke test.
#
# Usage:
#   ./publish-to-wix.sh --tag v1.0.0
#   WIX_API_KEY=... WIX_SITE_ID=... WIX_ACCOUNT_ID=... ./publish-to-wix.sh --tag v1.0.0
#   ./publish-to-wix.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$SCRIPT_DIR/dist"
LOG="$DIST/publish.log"

TAG=""
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --help|-h)
      sed -n '2,20p' "$0" | sed 's|^# \?||'
      exit 0 ;;
    --tag) j=$((i+1)); TAG="${!j}" ;;
  esac
done

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { printf '%s  %s\n' "$(timestamp)" "$*" | tee -a "$LOG"; }
fail() { log "FAIL: $*"; exit 1; }

mkdir -p "$DIST"
[[ -n "$TAG" ]] || fail "--tag required (use the tag you gave to build-s7-base.sh)"

log "=== publish-to-wix.sh start ==="
log "tag: $TAG"

# ── Env check ────────────────────────────────────────────────────
MISSING=()
[[ -n "${WIX_API_KEY:-}" ]]   || MISSING+=("WIX_API_KEY")
[[ -n "${WIX_SITE_ID:-}" ]]   || MISSING+=("WIX_SITE_ID")
[[ -n "${WIX_ACCOUNT_ID:-}" ]] || MISSING+=("WIX_ACCOUNT_ID")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  log "Wix credentials missing: ${MISSING[*]}"
  log ""
  log "To set these up:"
  log "  1. Log into https://manage.wix.com → Settings → API Keys → Create new"
  log "  2. Grant scopes: wix.media.manage (media.upload is enough if available)"
  log "  3. Copy the key, the Site ID (from Settings → Domains), and the Account ID"
  log "  4. Save them as:"
  log "       /s7/.config/s7/wix-api-key      (mode 600)"
  log "       /s7/.config/s7/wix-site-id"
  log "       /s7/.config/s7/wix-account-id"
  log "  5. Export before running:"
  log "       export WIX_API_KEY=\$(cat /s7/.config/s7/wix-api-key)"
  log "       export WIX_SITE_ID=\$(cat /s7/.config/s7/wix-site-id)"
  log "       export WIX_ACCOUNT_ID=\$(cat /s7/.config/s7/wix-account-id)"
  log "  6. Re-run: ./publish-to-wix.sh --tag $TAG"
  log ""
  log "Script exiting 0 (smoke test only, no upload attempted)."
  exit 0
fi

# ── Collect files to upload ──────────────────────────────────────
BASENAME="s7-fedora-base-${TAG}.tar"
FILES=()
for f in "$DIST/${BASENAME}."[0-9][0-9]; do
  [[ -f "$f" ]] && FILES+=("$f")
done
[[ -f "$DIST/SHA256SUMS"         ]] && FILES+=("$DIST/SHA256SUMS")
[[ -f "$DIST/${BASENAME%.tar}.json" ]] && FILES+=("$DIST/${BASENAME%.tar}.json")
[[ -f "$DIST/reassemble.sh"      ]] && FILES+=("$DIST/reassemble.sh")

if [[ ${#FILES[@]} -eq 0 ]]; then
  fail "no files to upload — run build-s7-base.sh --tag $TAG first"
fi

log "files to upload: ${#FILES[@]}"
for f in "${FILES[@]}"; do
  log "  $(basename "$f") ($(stat -c %s "$f") bytes)"
done

# ── Upload each file via Wix Media Manager REST API ──────────────
# Wix Media Manager supports two upload flows:
#   1. Generate upload URL → PUT file to that URL (for larger files)
#   2. Direct POST with file body (for small files)
# We use flow 1 for all files for consistency (works for any size).
#
# Reference: https://dev.wix.com/docs/rest/business-solutions/media/media-manager/files/upload-api
#
UPLOAD_BASE="https://www.wixapis.com/site-media/v1/files"
ACC_HDR="wix-account-id: $WIX_ACCOUNT_ID"
SITE_HDR="wix-site-id: $WIX_SITE_ID"
AUTH_HDR="Authorization: $WIX_API_KEY"

for f in "${FILES[@]}"; do
  bn=$(basename "$f")
  log "[upload] $bn"

  # Step 1: generate upload URL
  gen_url=$(curl -sS -X POST \
    -H "$AUTH_HDR" -H "$ACC_HDR" -H "$SITE_HDR" \
    -H "Content-Type: application/json" \
    -d "{\"mimeType\":\"application/octet-stream\",\"fileName\":\"s7-releases/${TAG}/${bn}\"}" \
    "${UPLOAD_BASE}/generate-upload-url" 2>&1)
  upload_url=$(echo "$gen_url" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('uploadUrl',''))" 2>/dev/null || echo "")

  if [[ -z "$upload_url" ]]; then
    log "  ERR: generate-upload-url returned no uploadUrl"
    log "  response: $gen_url"
    log "  skipping — does the API key have media.upload scope?"
    continue
  fi

  # Step 2: PUT the file to the generated URL
  if curl -sS -X PUT --data-binary @"$f" \
       -H "Content-Type: application/octet-stream" \
       "$upload_url" >>"$LOG" 2>&1; then
    log "  [OK] uploaded $bn"
  else
    log "  [ERR] PUT failed for $bn"
  fi
done

log "=== publish-to-wix.sh complete ==="
log "Files now live under Wix Media → Files → s7-releases/${TAG}/"
log "Public-facing URLs will be of the form:"
log "  https://static.wixstatic.com/media/<path-wix-generates>"
log "Fetch these URLs via the Wix Media API after upload, and store them"
log "in iac/dist/${BASENAME%.tar}-urls.txt for the receive-from-wix.sh script."
exit 0
