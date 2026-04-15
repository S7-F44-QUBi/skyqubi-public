#!/usr/bin/env bash
# s7-timecapsule-verify.sh
# Boot-time TimeCapsule registry verification.
#
# Walks /s7/timecapsule/registry/manifest.json, GPG-verifies each tar
# against KEY.fingerprint, sha256-checks each tar, and `podman load`s
# any tar whose image is not yet in the additional store.
#
# Always exits 0 — broken images are logged but boot continues. Services
# that depend on a broken image will fail loudly when they try to start
# with --pull=never.
#
# Environment variables (for testing + rootless override):
#   S7_TIMECAPSULE_REGISTRY  — override registry path (default /s7/timecapsule/registry)
#   S7_TIMECAPSULE_LOG       — override log path (default rootless-friendly)
#   S7_TIMECAPSULE_RUNROOT   — podman --runroot (default $XDG_RUNTIME_DIR/...)

set -uo pipefail

REGISTRY="${S7_TIMECAPSULE_REGISTRY:-/s7/timecapsule/registry}"
# Default log: rootless-friendly. Production root install can override
# S7_TIMECAPSULE_LOG=/var/log/s7/timecapsule.log via systemd Environment=.
LOG="${S7_TIMECAPSULE_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/s7/timecapsule.log}"
# Podman runroot for the additional-store load operations. Rootless podman
# cannot write to /run/containers; use $XDG_RUNTIME_DIR which is always
# user-writable on a logged-in session.
RUNROOT="${S7_TIMECAPSULE_RUNROOT:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/containers/timecapsule-store}"
MANIFEST="$REGISTRY/manifest.json"
KEY_FILE="$REGISTRY/KEY.fingerprint"
STORE="$REGISTRY/store"

mkdir -p "$(dirname "$LOG")" "$RUNROOT"

log() { echo "$@" | tee -a "$LOG"; }

[[ -f "$MANIFEST" ]] || { log "no manifest at $MANIFEST — nothing to verify"; exit 0; }
[[ -f "$KEY_FILE" ]] || { log "FAIL: missing $KEY_FILE"; exit 0; }

KEY_FP=$(tr -d ' \n' < "$KEY_FILE")
COUNT=$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))['images']))" "$MANIFEST")

if [[ "$COUNT" == "0" ]]; then
  log "no images to verify"
  exit 0
fi

log "verifying $COUNT image(s) against key $KEY_FP"

# Read entries via python (jq isn't guaranteed at boot), pipe TSV to bash.
python3 - "$MANIFEST" <<'PYEOF' | while IFS=$'\t' read -r NAME VERSION TAR SIG EXPECTED_SHA PROMOTE_TO; do
import json, sys
data = json.load(open(sys.argv[1]))
for e in data["images"]:
    print("\t".join([
        e["name"], e["version"], e["tar"], e["sig"],
        e["sha256"], e["promote_to"],
    ]))
PYEOF
  TAR_PATH="$REGISTRY/$TAR"
  SIG_PATH="$REGISTRY/$SIG"

  # ── Check 1: GPG verify ──
  if ! gpg --verify "$SIG_PATH" "$TAR_PATH" >/dev/null 2>&1; then
    log "  $NAME:$VERSION  verdict: fail  reason: gpg verification failed"
    continue
  fi

  # ── Check 2: sha256 ──
  ACTUAL_SHA=$(sha256sum "$TAR_PATH" | awk '{print $1}')
  if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
    log "  $NAME:$VERSION  verdict: fail  reason: sha256 mismatch (expected $EXPECTED_SHA got $ACTUAL_SHA)"
    continue
  fi

  # ── Load into additional store if not already present ──
  # Use --runroot for rootless compatibility (rootless podman cannot
  # write to the default /run/containers).
  if podman --root "$STORE" --runroot "$RUNROOT" images --quiet "$PROMOTE_TO" 2>/dev/null | grep -q .; then
    log "  $NAME:$VERSION  verdict: ok  (already in store)"
  else
    if podman --root "$STORE" --runroot "$RUNROOT" load -i "$TAR_PATH" >/dev/null 2>&1; then
      log "  $NAME:$VERSION  verdict: ok  (loaded into store)"
    else
      log "  $NAME:$VERSION  verdict: fail  reason: podman load failed"
    fi
  fi
done

log "verification complete"
exit 0
