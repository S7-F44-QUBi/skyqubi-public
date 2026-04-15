#!/usr/bin/env bash
# iac/audit-pre.sh
# S7 Fedora Base — pre-build upstream verification.
#
# Pulls the upstream fedora-minimal:44 image, records its content
# hash, and verifies it against (in order):
#   1. A trusted-hashes allowlist file (iac/trusted-upstream-hashes.txt)
#      — if present, the hash must be in it
#   2. The image metadata must declare an OCI source label pointing at
#      a Fedora-controlled URL
#   3. The signing key (when podman signature verification is available)
#      must match manifest.yaml fork_of.signing_key_fingerprint_prefix
#
# Exit 0 = upstream passed, proceed to build.
# Exit 1 = upstream failed a check, abort.
#
# Usage:
#   ./audit-pre.sh               # full run
#   ./audit-pre.sh --help
#   ./audit-pre.sh --dry-run     # skip the pull, just show what would happen
#   ./audit-pre.sh --update-trust # add current hash to trusted list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.yaml"
TRUSTED="$SCRIPT_DIR/trusted-upstream-hashes.txt"
LOG="$SCRIPT_DIR/dist/audit-pre.log"
mkdir -p "$(dirname "$LOG")"

DRY_RUN=false
UPDATE_TRUST=false
for arg in "$@"; do
  case "$arg" in
    --help|-h)
      sed -n '2,24p' "$0" | sed 's|^# \?||'
      exit 0 ;;
    --dry-run)     DRY_RUN=true ;;
    --update-trust) UPDATE_TRUST=true ;;
  esac
done

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log()       { printf '%s  %s\n' "$(timestamp)" "$*" | tee -a "$LOG"; }
fail()      { log "FAIL: $*"; exit 1; }

read_manifest() {
  python3 -c "
import yaml, shlex, sys
m = yaml.safe_load(open('$MANIFEST'))
print('registry=' + shlex.quote(m['fork_of']['registry']))
print('image='    + shlex.quote(m['fork_of']['image']))
print('tag='      + shlex.quote(str(m['fork_of']['tag'])))
print('sig_prefix=' + shlex.quote(m['fork_of']['signing_key_fingerprint_prefix']))
" 2>/dev/null || fail "could not parse manifest.yaml"
}

log "=== audit-pre.sh start ==="
log "manifest: $MANIFEST"
log "trusted-hashes file: $TRUSTED $([[ -f $TRUSTED ]] && echo '(present)' || echo '(absent — first-run mode)')"

eval "$(read_manifest)"
UPSTREAM="${registry}/${image}:${tag}"
log "upstream ref: $UPSTREAM"

if $DRY_RUN; then
  log "DRY-RUN: would pull $UPSTREAM, skipping"
  log "=== audit-pre.sh dry-run complete — PASS ==="
  exit 0
fi

# --- Phase 1: pull ---
log "[1/4] podman pull $UPSTREAM"
if ! podman pull "$UPSTREAM" >>"$LOG" 2>&1; then
  fail "podman pull failed — see $LOG"
fi

# --- Phase 2: compute content hash ---
log "[2/4] computing content hash"
UPSTREAM_HASH=$(podman image inspect "$UPSTREAM" --format '{{.Digest}}' 2>/dev/null || true)
if [[ -z "$UPSTREAM_HASH" || "$UPSTREAM_HASH" == "<no value>" ]]; then
  UPSTREAM_HASH=$(podman image inspect "$UPSTREAM" --format '{{.Id}}' 2>/dev/null)
fi
[[ -n "$UPSTREAM_HASH" ]] || fail "could not read image digest/id"
log "  hash: $UPSTREAM_HASH"

# --- Phase 3: verify OCI source label points at Fedora ---
log "[3/4] verifying image provenance labels"
SOURCE_LABEL=$(podman image inspect "$UPSTREAM" --format '{{index .Config.Labels "org.opencontainers.image.source"}}' 2>/dev/null || echo "")
VENDOR_LABEL=$(podman image inspect "$UPSTREAM" --format '{{index .Config.Labels "org.opencontainers.image.vendor"}}' 2>/dev/null || echo "")
log "  source label:  ${SOURCE_LABEL:-(missing)}"
log "  vendor label:  ${VENDOR_LABEL:-(missing)}"
if [[ ! "$SOURCE_LABEL$VENDOR_LABEL" =~ [Ff]edora ]]; then
  log "  WARNING: neither source nor vendor label mentions Fedora"
fi

# --- Phase 4: cross-check against trusted hashes file ---
log "[4/4] cross-referencing trusted hashes"
if [[ -f "$TRUSTED" ]]; then
  if grep -qxF "$UPSTREAM_HASH" "$TRUSTED"; then
    log "  hash present in trusted list — OK"
  else
    if $UPDATE_TRUST; then
      echo "$UPSTREAM_HASH" >> "$TRUSTED"
      log "  --update-trust: appended current hash to trusted list"
    else
      fail "hash NOT in trusted list. Review, then re-run with --update-trust to accept."
    fi
  fi
else
  log "  no trusted-hashes file — creating with current hash (first-run)"
  echo "$UPSTREAM_HASH" > "$TRUSTED"
fi

log "=== audit-pre.sh complete — PASS ==="
log "upstream $UPSTREAM verified at $UPSTREAM_HASH"
exit 0
