#!/usr/bin/env bash
# iac/intake/gate.sh
# Shared intake gate. Reads an intake descriptor (JSON on stdin),
# checks it against iac/manifest.yaml, logs a decision, returns 0/1.
#
# Usage:
#   cat descriptor.json | iac/intake/gate.sh
#   echo '{"kind":"container","name":"...","sha256":"..."}' | iac/intake/gate.sh
#
# Exit codes:
#   0  pass — adapter should promote
#   1  fail — adapter should reject and clean up
#   2  malformed descriptor or missing manifest entry (adapter bug)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="${S7_INTAKE_MANIFEST:-$REPO/iac/manifest.yaml}"
DECISIONS_DIR="$SCRIPT_DIR/decisions"
TODAY=$(date -u +%Y-%m-%d)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

[[ -f "$MANIFEST" ]] || { echo "FAIL: manifest not found at $MANIFEST" >&2; exit 2; }
mkdir -p "$DECISIONS_DIR"

# ── Read descriptor from stdin ──
DESC=$(cat)
[[ -n "$DESC" ]] || { echo "FAIL: empty descriptor on stdin" >&2; exit 2; }

KIND=$(echo "$DESC" | jq -r '.kind // empty')
NAME=$(echo "$DESC" | jq -r '.name // empty')
ACTUAL_SHA=$(echo "$DESC" | jq -r '.sha256 // empty')
SIZE=$(echo "$DESC" | jq -r '.size_bytes // 0')

[[ -n "$KIND" && -n "$NAME" && -n "$ACTUAL_SHA" ]] || {
  echo "FAIL: descriptor missing required fields (kind, name, sha256)" >&2
  exit 2
}

# ── Look up the pinned entry in manifest.yaml ──
# Use python3 to parse YAML (we don't have yq installed).
PINNED=$(python3 - <<PYEOF
import sys, yaml, json
try:
    with open("$MANIFEST") as f:
        m = yaml.safe_load(f)
    section = (m.get("intake") or {}).get("${KIND}s") or []
    for entry in section:
        if entry.get("name") == "${NAME}":
            print(json.dumps(entry))
            sys.exit(0)
    sys.exit(3)
except Exception as e:
    print(f"manifest parse error: {e}", file=sys.stderr)
    sys.exit(4)
PYEOF
) || {
  rc=$?
  if [[ $rc -eq 3 ]]; then
    echo "FAIL: no pinned entry in manifest for kind=$KIND name=$NAME" >&2
    # Log as a structured rejection so it still ends up in the audit trail.
    jq -c -n \
      --arg ts "$NOW" --arg kind "$KIND" --arg name "$NAME" \
      '{ts:$ts,kind:$kind,name:$name,verdict:"fail",reason:"not pinned in manifest.yaml"}' \
      >> "$DECISIONS_DIR/$TODAY.ndjson"
    exit 1
  fi
  echo "FAIL: gate lookup error (rc=$rc)" >&2
  exit 2
}

EXPECTED_SHA=$(echo "$PINNED" | jq -r '.sha256 // empty')
EXPECTED_SIG=$(echo "$PINNED" | jq -r '.signing_key_fingerprint_prefix // empty')

# ── Check 1: sha256 ──
SHA_OK=false
if [[ "$EXPECTED_SHA" == "$ACTUAL_SHA" ]]; then
  SHA_OK=true
fi

# ── Check 2: signature fingerprint (optional — depends on kind) ──
SIG_OK="skipped"
if [[ -n "$EXPECTED_SIG" ]]; then
  # The adapter may have embedded the observed fingerprint in the
  # descriptor under .signing_key_fingerprint. If present, compare.
  # If absent, we cannot verify at this tier and mark skipped (still
  # fail-closed on sha).
  OBS_SIG=$(echo "$DESC" | jq -r '.signing_key_fingerprint // empty')
  if [[ -n "$OBS_SIG" ]]; then
    if [[ "$OBS_SIG" == "$EXPECTED_SIG"* ]]; then
      SIG_OK=true
    else
      SIG_OK=false
    fi
  fi
fi

# ── Check 3: vuln scan — not implemented tonight ──
SCAN_OK="skipped"

# ── Verdict ──
VERDICT="fail"
REASON=""
if ! $SHA_OK; then
  REASON="sha256 mismatch: expected $EXPECTED_SHA, got $ACTUAL_SHA"
elif [[ "$SIG_OK" == "false" ]]; then
  REASON="signature fingerprint mismatch"
else
  VERDICT="pass"
fi

# ── Decision log ──
jq -c -n \
  --arg ts "$NOW" \
  --arg kind "$KIND" \
  --arg name "$NAME" \
  --arg verdict "$VERDICT" \
  --argjson sha_ok "$SHA_OK" \
  --arg sig_ok "$SIG_OK" \
  --arg scan_ok "$SCAN_OK" \
  --argjson size "$SIZE" \
  --arg reason "$REASON" \
  '{ts:$ts,kind:$kind,name:$name,verdict:$verdict,sha256_ok:$sha_ok,sig_ok:$sig_ok,scan_ok:$scan_ok,size_bytes:$size,reason:$reason}' \
  >> "$DECISIONS_DIR/$TODAY.ndjson"

echo "  gate: $KIND $NAME → $VERDICT  (sha256:$SHA_OK sig:$SIG_OK scan:$SCAN_OK)"
if [[ "$VERDICT" == "pass" ]]; then
  exit 0
else
  echo "  reason: $REASON" >&2
  exit 1
fi
