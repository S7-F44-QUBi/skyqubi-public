#!/usr/bin/env bash
# iac/immutable/fetch-gold-assets.sh
#
# Fetches ONE asset category's signed tarball + signature from either:
#   --source=local          /s7/v6-gold-2026-04-15/<tarball> (for local lifecycle tests)
#   --source=remote         skycair-code/skyqubi-private branch <branch> (for real deploys)
#
# Usage:
#   fetch-gold-assets.sh --category=qubi --source=local --target=/tmp/s7-deploy/covenant
#   fetch-gold-assets.sh --category=qubi --source=remote --target=/opt/s7/covenant
#
# What it does:
#   1. Reads iac/immutable/asset-dependencies.yaml to resolve the category
#   2. Locates the tarball (local file or remote branch blob)
#   3. Verifies GPG detached signature against E11792E0AD945BE9
#   4. Verifies sha256 against local GOLD archive MANIFEST (always, even in remote mode)
#   5. Extracts the tarball to the target directory
#
# Exit codes:
#   0  success
#   1  usage / config error
#   2  category not found
#   3  tarball not found at source
#   4  GPG verification failed
#   5  sha256 mismatch
#   6  extract failed
#
# This script is the ONLY path content flows from an immutable branch to a
# running system. No other script should bypass it and extract tarballs directly.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/asset-dependencies.yaml"
GOLD_LOCAL_DIR="/s7/v6-gold-2026-04-15"
GOLD_REMOTE_OWNER="skycair-code"
GOLD_REMOTE_REPO="skyqubi-private"
SIGNING_KEY="E11792E0AD945BE9"

CATEGORY=""
SOURCE="local"
TARGET=""
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    --category=*) CATEGORY="${arg#*=}" ;;
    --source=*)   SOURCE="${arg#*=}" ;;
    --target=*)   TARGET="${arg#*=}" ;;
    --verbose|-v) VERBOSE=true ;;
    --help|-h)    sed -n '2,30p' "$0" | sed 's|^# \?||'; exit 0 ;;
  esac
done

say()     { echo "  [fetch:$CATEGORY] $*"; }
verbose() { $VERBOSE && echo "    [v] $*" || true; }
fail()    { echo "  🔴 [fetch:$CATEGORY] $*" >&2; exit "${2:-1}"; }

[[ -n "$CATEGORY" ]] || fail "missing --category" 1
[[ -n "$TARGET" ]]   || fail "missing --target" 1
[[ -f "$CONFIG" ]]   || fail "config missing: $CONFIG" 1
case "$SOURCE" in
  local|remote) ;;
  *) fail "invalid --source: $SOURCE (must be local or remote)" 1 ;;
esac

# ── Resolve category from YAML (tab-separated, no eval) ─────────
CAT_LINE=$(python3 - "$CONFIG" "$CATEGORY" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    doc = yaml.safe_load(f)
target_id = sys.argv[2]
for c in doc.get("categories", []):
    if c.get("id") == target_id:
        fields = [
            c.get("branch", ""),
            c.get("tarball", ""),
            c.get("signature", ""),
            (c.get("role", "") or "").replace("\t", " ").replace("\n", " "),
        ]
        print("\t".join(fields))
        sys.exit(0)
sys.exit(2)
PY
)
if [[ $? -ne 0 || -z "$CAT_LINE" ]]; then
  fail "category not found in $CONFIG: $CATEGORY" 2
fi
IFS=$'\t' read -r branch tarball signature role <<< "$CAT_LINE"
verbose "branch=$branch tarball=$tarball"

# ── Locate tarball ───────────────────────────────────────────────
WORK=$(mktemp -d /tmp/s7-fetch-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

if [[ "$SOURCE" == "local" ]]; then
  LOCAL_TAR="$GOLD_LOCAL_DIR/$tarball"
  LOCAL_SIG="$GOLD_LOCAL_DIR/$signature"
  [[ -f "$LOCAL_TAR" ]] || fail "local tarball missing: $LOCAL_TAR" 3
  [[ -f "$LOCAL_SIG" ]] || fail "local signature missing: $LOCAL_SIG" 3
  cp "$LOCAL_TAR" "$WORK/$tarball"
  cp "$LOCAL_SIG" "$WORK/$signature"
  verbose "copied from local archive"
else
  # remote mode: fetch via GitHub API raw content endpoint
  [[ -n "${GH_TOKEN:-}" ]] || fail "GH_TOKEN not set (required for remote fetch)" 1
  TOKEN="$GH_TOKEN"
  RAW_BASE="https://raw.githubusercontent.com/$GOLD_REMOTE_OWNER/$GOLD_REMOTE_REPO/$branch"
  verbose "fetching $RAW_BASE/$tarball"
  curl -sS -L -H "Authorization: token $TOKEN" -o "$WORK/$tarball" "$RAW_BASE/$tarball" || fail "remote tarball fetch failed" 3
  curl -sS -L -H "Authorization: token $TOKEN" -o "$WORK/$signature" "$RAW_BASE/$signature" || fail "remote signature fetch failed" 3
  [[ -s "$WORK/$tarball" ]] || fail "remote tarball is empty" 3
  [[ -s "$WORK/$signature" ]] || fail "remote signature is empty" 3
fi

# ── Verify GPG signature ─────────────────────────────────────────
if ! gpg --verify "$WORK/$signature" "$WORK/$tarball" 2>&1 | grep -q "Good signature"; then
  fail "GPG verification failed for $tarball" 4
fi
say "✓ GPG signature valid ($SIGNING_KEY)"

# ── Verify sha256 against local GOLD archive MANIFEST ────────────
# Always cross-check against the local MANIFEST — this catches drift even
# in remote mode, because the local MANIFEST is the covenant witness.
LOCAL_MANIFEST="$GOLD_LOCAL_DIR/MANIFEST.md"
if [[ -f "$LOCAL_MANIFEST" ]]; then
  expected_sha=$(grep -E "^[a-f0-9]{64}  $tarball$" "$LOCAL_MANIFEST" | awk '{print $1}')
  if [[ -n "$expected_sha" ]]; then
    actual_sha=$(sha256sum "$WORK/$tarball" | awk '{print $1}')
    if [[ "$actual_sha" != "$expected_sha" ]]; then
      fail "sha256 MISMATCH — expected $expected_sha, got $actual_sha" 5
    fi
    say "✓ sha256 matches MANIFEST.md"
  else
    verbose "no sha256 entry in MANIFEST.md for $tarball (skipping hash check)"
  fi
else
  verbose "local MANIFEST.md not found (skipping hash check)"
fi

# ── Extract to target ────────────────────────────────────────────
mkdir -p "$TARGET" || fail "cannot create target dir: $TARGET" 6
if ! tar -xzf "$WORK/$tarball" -C "$TARGET" 2>&1; then
  fail "tar extract failed for $tarball → $TARGET" 6
fi
say "✓ extracted to $TARGET ($role)"

exit 0
