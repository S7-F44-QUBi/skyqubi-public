#!/usr/bin/env bash
# iac/intake/pull-container.sh
# Container adapter for the S7 intake gate.
#
# Pulls a pinned upstream image into a quarantine podman graph root,
# computes its sha256, emits an intake descriptor, hands it to gate.sh,
# and on pass does a save→load airlock promote into the live graph
# root under the name declared by manifest.yaml `promote_to`.
#
# Usage:
#   iac/intake/pull-container.sh quay.io/fedora/fedora-minimal:44
#   iac/intake/pull-container.sh --dry-run <ref>
#
# Exit codes:
#   0  intake passed and was promoted
#   1  intake failed the gate (artifact rejected, nothing promoted)
#   2  adapter bug (missing tools, invalid args, manifest parse error)
#   3  pull failure (upstream unreachable, registry 404, disk full, ...)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="${S7_INTAKE_MANIFEST:-$REPO/iac/manifest.yaml}"
QUARANTINE_ROOT="${S7_QUARANTINE_ROOT:-$SCRIPT_DIR/quarantine/containers}"
LIVE_ROOT="${S7_LIVE_GRAPH_ROOT:-/s7/.local/share/containers/storage}"
DRY_RUN=false

usage() {
  sed -n '2,20p' "$0" | sed 's|^# \?||'
}

REF=""
for arg in "$@"; do
  case "$arg" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY_RUN=true ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *)  REF="$arg" ;;
  esac
done

[[ -n "$REF" ]] || { usage; exit 2; }
command -v podman >/dev/null || { echo "FAIL: podman not installed" >&2; exit 2; }
command -v jq     >/dev/null || { echo "FAIL: jq not installed" >&2; exit 2; }
command -v python3 >/dev/null || { echo "FAIL: python3 not installed" >&2; exit 2; }

mkdir -p "$QUARANTINE_ROOT"

echo "═════════════════════════════════════════════════════"
echo "  S7 intake (container)"
echo "  ref:          $REF"
echo "  quarantine:   $QUARANTINE_ROOT"
echo "  live root:    $LIVE_ROOT"
echo "  mode:         $(if $DRY_RUN; then echo dry-run; else echo real; fi)"
echo "═════════════════════════════════════════════════════"

# ── Phase 1: look up manifest entry (need promote_to before we pull) ──
ENTRY=$(python3 - <<PYEOF
import sys, yaml, json
with open("$MANIFEST") as f:
    m = yaml.safe_load(f)
for e in ((m.get("intake") or {}).get("containers") or []):
    if e.get("name") == "$REF":
        print(json.dumps(e)); sys.exit(0)
sys.exit(3)
PYEOF
) || {
  echo "FAIL: '$REF' is not pinned in $MANIFEST under intake.containers" >&2
  exit 2
}
PROMOTE_TO=$(echo "$ENTRY" | jq -r '.promote_to // empty')
EXPECTED_SHA=$(echo "$ENTRY" | jq -r '.sha256 // empty')
[[ -n "$PROMOTE_TO" && -n "$EXPECTED_SHA" ]] || {
  echo "FAIL: manifest entry for $REF missing promote_to or sha256" >&2
  exit 2
}

# ── Phase 2: pull into quarantine ──
echo
echo "[1/4] pull into quarantine"
if $DRY_RUN; then
  echo "  [dry-run] podman --root '$QUARANTINE_ROOT' pull '$REF'"
  ACTUAL_SHA="$EXPECTED_SHA"   # pretend it matched
  SIZE=0
else
  if ! podman --root "$QUARANTINE_ROOT" pull "$REF"; then
    echo "FAIL: pull failed (upstream unreachable or registry error)" >&2
    exit 3
  fi
  # Compute actual digest
  ACTUAL_SHA=$(podman --root "$QUARANTINE_ROOT" inspect "$REF" \
    --format '{{.Digest}}' 2>/dev/null | sed 's/^sha256://')
  SIZE=$(podman --root "$QUARANTINE_ROOT" inspect "$REF" \
    --format '{{.Size}}' 2>/dev/null || echo 0)
  echo "  pulled, digest: $ACTUAL_SHA  size: $SIZE"
fi

# ── Phase 3: descriptor → gate ──
echo
echo "[2/4] gate"
DESC=$(jq -c -n \
  --arg kind "container" \
  --arg name "$REF" \
  --arg sha  "$ACTUAL_SHA" \
  --argjson size "$SIZE" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{kind:$kind,name:$name,sha256:$sha,size_bytes:$size,pulled_at:$ts}')

if ! echo "$DESC" | "$SCRIPT_DIR/gate.sh"; then
  echo
  echo "REJECTED by gate — not promoting. Cleaning quarantine copy."
  if ! $DRY_RUN; then
    podman --root "$QUARANTINE_ROOT" rmi "$REF" >/dev/null 2>&1 || true
  fi
  exit 1
fi

# ── Phase 4: promote (save → sign → manifest into TimeCapsule) ──
echo
echo "[3/4] promote → TimeCapsule"
TIMECAPSULE_REG="${S7_TIMECAPSULE_REGISTRY:-/s7/timecapsule/registry}"
KEY_FP=$(tr -d ' \n' < "$TIMECAPSULE_REG/KEY.fingerprint" 2>/dev/null || echo "")
[[ -n "$KEY_FP" ]] || { echo "FAIL: TimeCapsule KEY.fingerprint missing at $TIMECAPSULE_REG/KEY.fingerprint" >&2; exit 2; }

# Derive name+version from PROMOTE_TO (localhost/s7/<name>:<version>)
TC_NAME=$(echo "$PROMOTE_TO" | sed -E 's|^localhost/s7/([^:]+):.*$|\1|')
TC_VERSION=$(echo "$PROMOTE_TO" | sed -E 's|^localhost/s7/[^:]+:(.+)$|\1|')
TC_TAR="$TIMECAPSULE_REG/images/${TC_NAME}-${TC_VERSION}.tar"
TC_SIG="${TC_TAR}.sig"

if $DRY_RUN; then
  echo "  [dry-run] podman --root '$QUARANTINE_ROOT' save '$REF' -o '$TC_TAR'"
  echo "  [dry-run] gpg --detach-sign --armor --local-user '$KEY_FP' -o '$TC_SIG' '$TC_TAR'"
  echo "  [dry-run] timecapsule_manifest_cli add-entry $TC_NAME $TC_VERSION ..."
else
  mkdir -p "$(dirname "$TC_TAR")"
  podman --root "$QUARANTINE_ROOT" save -o "$TC_TAR" "$REF"
  gpg --batch --yes --detach-sign --armor \
      --local-user "$KEY_FP" \
      -o "$TC_SIG" \
      "$TC_TAR"

  PYTHONPATH="$REPO" python3 -m iac.timecapsule.timecapsule_manifest_cli add-entry \
    --manifest "$TIMECAPSULE_REG/manifest.json" \
    --name "$TC_NAME" \
    --version "$TC_VERSION" \
    --tar "$TC_TAR" \
    --sig "$TC_SIG" \
    --upstream "$REF" \
    --promote-to "$PROMOTE_TO"
  echo "  wrote $TC_TAR + .sig + manifest entry"
fi

# ── Phase 5: clean quarantine copy ──
echo
echo "[4/4] clean quarantine"
if $DRY_RUN; then
  echo "  [dry-run] podman --root '$QUARANTINE_ROOT' rmi '$REF'"
else
  podman --root "$QUARANTINE_ROOT" rmi "$REF" >/dev/null 2>&1 || true
fi

echo
echo "═════════════════════════════════════════════════════"
echo "  intake complete: $REF → TimeCapsule:$TC_NAME:$TC_VERSION"
echo "═════════════════════════════════════════════════════"
