#!/usr/bin/env bash
# Integration test for pull-container.sh modified to write to TimeCapsule.
#
# Pulls a tiny real upstream image (quay.io/quay/busybox:latest) through
# the modified adapter, verifies the resulting signed tar lands in
# /tmp/test-timecapsule/registry/images/, and that manifest.json gains
# an entry. Cleans up after itself.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_REG="/tmp/test-timecapsule/registry"

cleanup() {
  rm -rf /tmp/test-timecapsule /tmp/test-iac-manifest.yaml /tmp/test-quarantine
  podman --root /tmp/test-quarantine rmi --all --force 2>/dev/null || true
}
trap cleanup EXIT
cleanup  # pre-clean any leftover from prior runs

# 1. Stage a fresh empty registry with the real KEY.fingerprint.
mkdir -p "$TEST_REG/images" "$TEST_REG/store"
echo '80F0291480E25C0F683E9714E11792E0AD945BE9' > "$TEST_REG/KEY.fingerprint"
echo '{"version": 1, "images": []}' > "$TEST_REG/manifest.json"

# 2. Compute the busybox digest and write a temporary manifest copy.
TEST_MANIFEST="/tmp/test-iac-manifest.yaml"
cp "$REPO/iac/manifest.yaml" "$TEST_MANIFEST"
DIGEST=$(podman inspect quay.io/quay/busybox:latest --format '{{.Digest}}' 2>/dev/null \
  | sed 's/^sha256://' \
  || echo "")
test -n "$DIGEST" || { echo "FAIL: could not get busybox digest (network or registry issue)"; exit 1; }

python3 - "$TEST_MANIFEST" "$DIGEST" <<'PYEOF'
import sys, yaml
path, digest = sys.argv[1], sys.argv[2]
with open(path) as f: m = yaml.safe_load(f)
m.setdefault("intake", {}).setdefault("containers", []).append({
    "name": "quay.io/quay/busybox:latest",
    "sha256": digest,
    "promote_to": "localhost/s7/busybox:latest",
})
with open(path, "w") as f: yaml.safe_dump(m, f)
PYEOF

# 3. Run the adapter with the test registry + test manifest + test quarantine.
S7_TIMECAPSULE_REGISTRY="$TEST_REG" \
S7_INTAKE_MANIFEST="$TEST_MANIFEST" \
S7_QUARANTINE_ROOT=/tmp/test-quarantine/containers \
"$REPO/iac/intake/pull-container.sh" quay.io/quay/busybox:latest

# 4. Verify the artifacts.
TAR="$TEST_REG/images/busybox-latest.tar"
SIG="$TAR.sig"
test -f "$TAR" || { echo "FAIL: tar not written to $TAR"; exit 1; }
test -f "$SIG" || { echo "FAIL: sig not written to $SIG"; exit 1; }

gpg --verify "$SIG" "$TAR" 2>&1 | grep -q 'Good signature' \
  || { echo "FAIL: sig does not verify"; gpg --verify "$SIG" "$TAR"; exit 1; }

ENTRY=$(python3 -c "
import json
m = json.load(open('$TEST_REG/manifest.json'))
matches = [e for e in m['images'] if e['name']=='busybox' and e['version']=='latest']
assert len(matches) == 1, f'expected 1 entry, got {len(matches)}'
print(json.dumps(matches[0]))
")
echo "$ENTRY" | python3 -m json.tool

echo "PASS: pull-container.sh writes signed tar + manifest entry to TimeCapsule"
