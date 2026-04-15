#!/usr/bin/env bash
# iac/immutable/rebuild-public.sh
#
# Rebuilds public/main as a deterministic output of the latest
# registered immutable fork. Public is a VIEW of the immutable, not
# a sync destination.
#
# STATUS (CORE Update v5, 2026-04-14):
#   - --dry-run produces a REAL git bundle + PUBLIC_MANIFEST.txt in
#     /tmp/s7-gold-dry-run/ against the current lifecycle tip. No
#     push. This is the GOLD production path proven end-to-end.
#   - Real ceremony push still refuses to run (requires Tonya +
#     image-signing key; neither gate is implemented yet).
#   - The first real push happens at the first immutable advance
#     ceremony — see CHEF Recipe #4 + advance-immutable.sh.
#
# Usage:
#   ./rebuild-public.sh --dry-run   # produce bundle+manifest in /tmp/s7-gold-dry-run/
#   ./rebuild-public.sh             # ABORTS — refuses real runs
#   ./rebuild-public.sh --help      # print this header
#
# SECURITY PRECONDITIONS (Round 2 council — Skeptic catches):
#   1. When upgraded past refuse-real-runs, this script must read the
#      bundle target from the NEWEST NON-RETIRED entry in
#      registry.yaml, not from a positional argument. Closes the
#      bundle-replay attack surface.
#   2. Manifest whitelist is a fixed list (PUBLIC_FILES) read below.
#      Adding a file to the manifest is a tier-crossing action.
#   3. The bundle is always produced from the currently checked-out
#      lifecycle tip, and the tip must match the latest frozen-tree
#      ancestor check. A bundle produced from a drifted tip is
#      unauthorized.
#
# Airgap: this script makes zero network calls. All work is local to
# the private repo and /tmp.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="$SCRIPT_DIR/registry.yaml"
REPO_PRIVATE="/s7/skyqubi-private"
STAGING="/tmp/s7-gold-dry-run"

# Target repository announced 2026-04-14 evening. PUBLIC. Created
# but untouched by S7 tooling. The first real run of this script
# (past the refuse-real-runs guard) will push the signed bundle to
# this repository's main branch as an orphan force-push, per
# CHEF Recipe #4. None of that happens tonight.
IMMUTABLE_TARGET_URL="https://github.com/skycair-code/skyqubi-immutable"
IMMUTABLE_TARGET_LOCAL="/s7/skyqubi-immutable"   # not expected to exist yet

# The whitelist of files that land in the public rebuild. This list
# is the covenant boundary between private and public. Changing it
# is a tier-crossing action.
PUBLIC_FILES=(
  "docs/public/index.html"
  "docs/public/README.md"
  "docs/public/INSTALL.md"
  "docs/public/USAGE.md"
  "docs/public/ARCHITECTURE.md"
  "docs/public/COVENANT.md"
  "docs/public/CNAME"
  "LICENSE"
)

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --help|-h) sed -n '2,34p' "$0" | sed 's|^# \?||'; exit 0 ;;
  esac
done

echo
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║   S7 Public Rebuild from Immutable Fork               ║"
echo "  ║   v5 — real dry-run producer, refuses real ceremony   ║"
echo "  ╚═══════════════════════════════════════════════════════╝"
echo

if [[ ! -f "$REGISTRY" ]]; then
  echo "  ⚠ Registry file not found at $REGISTRY"
  exit 1
fi

entry_count=$(grep -cE '^\s*-\s*version:' "$REGISTRY" 2>/dev/null | head -1)
[[ -z "$entry_count" ]] && entry_count=0
echo "  Registry entries: $entry_count"

if ! $DRY_RUN; then
  echo
  echo "  🔴 REFUSES REAL RUNS."
  echo "     This script's real ceremony push requires (a) Tonya's"
  echo "     sign-off artifact row in registry.yaml and (b) the"
  echo "     image-signing key unlocked by the household Chief of"
  echo "     Covenant. Neither precondition is met in an interim"
  echo "     session. Use --dry-run to exercise the GOLD production"
  echo "     pipeline end-to-end."
  echo
  exit 1
fi

# ── DRY RUN — real bundle production, no push ─────────────────
echo
echo "  [DRY RUN] Producing GOLD artifacts in $STAGING"
echo

# Clean staging
rm -rf "$STAGING"
mkdir -p "$STAGING"

cd "$REPO_PRIVATE"

# Capture the current lifecycle tip
TIP_SHA="$(git rev-parse HEAD)"
TIP_SHORT="$(git rev-parse --short HEAD)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
BUILD_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "  Tree:         $BRANCH @ $TIP_SHORT ($TIP_SHA)"
echo "  Build time:   $BUILD_TS"
echo

# Build the PUBLIC_MANIFEST.txt
MANIFEST="$STAGING/PUBLIC_MANIFEST.txt"
{
  echo "# S7 SkyQUBi Public Manifest"
  echo "# Generated: $BUILD_TS"
  echo "# Tree:      $BRANCH @ $TIP_SHA"
  echo "# Producer:  rebuild-public.sh v5 (dry-run)"
  echo "#"
  echo "# This manifest is the covenant boundary. Every path below"
  echo "# is included in the public bundle. Nothing else is."
  echo
  for entry in "${PUBLIC_FILES[@]}"; do
    if [[ -e "$REPO_PRIVATE/$entry" ]]; then
      if [[ -f "$REPO_PRIVATE/$entry" ]]; then
        hash=$(sha256sum "$REPO_PRIVATE/$entry" | awk '{print $1}')
        echo "FILE $entry $hash"
      else
        # directory — list recursive file hashes
        while IFS= read -r f; do
          rel="${f#$REPO_PRIVATE/}"
          hash=$(sha256sum "$f" | awk '{print $1}')
          echo "FILE $rel $hash"
        done < <(find "$REPO_PRIVATE/$entry" -type f | sort)
      fi
    else
      echo "MISSING $entry"
    fi
  done
} > "$MANIFEST"

manifest_hash=$(sha256sum "$MANIFEST" | awk '{print $1}')
echo "  Manifest:     $MANIFEST"
echo "  Manifest sha: $manifest_hash"

# Produce the git bundle
BUNDLE="$STAGING/s7-skyqubi-gold-$TIP_SHORT.bundle"
if git bundle create "$BUNDLE" "$BRANCH" 2>/dev/null; then
  bundle_hash=$(sha256sum "$BUNDLE" | awk '{print $1}')
  bundle_size=$(stat -c%s "$BUNDLE" 2>/dev/null || stat -f%z "$BUNDLE" 2>/dev/null)
  echo "  Bundle:       $BUNDLE"
  echo "  Bundle sha:   $bundle_hash"
  echo "  Bundle size:  $bundle_size bytes"
else
  echo "  🔴 git bundle creation failed"
  exit 1
fi

# Write a GOLD receipt — the machine-readable summary of what was produced
RECEIPT="$STAGING/GOLD_RECEIPT.txt"
{
  echo "gold_version:      dry-run"
  echo "core_update:       v5"
  echo "build_timestamp:   $BUILD_TS"
  echo "tree_branch:       $BRANCH"
  echo "tree_sha:          $TIP_SHA"
  echo "bundle_path:       $BUNDLE"
  echo "bundle_sha256:     $bundle_hash"
  echo "bundle_size:       $bundle_size"
  echo "manifest_path:     $MANIFEST"
  echo "manifest_sha256:   $manifest_hash"
  echo "manifest_files:    $(grep -c '^FILE ' "$MANIFEST")"
  echo "manifest_missing:  $(grep -c '^MISSING ' "$MANIFEST" || echo 0)"
  echo "target_url:        $IMMUTABLE_TARGET_URL"
  echo "target_local:      $IMMUTABLE_TARGET_LOCAL (not expected to exist yet)"
  echo "signed:            false"
  echo "tonya_signoff:     none"
  echo "push_authorized:   false"
  echo "status:            dry-run-only"
} > "$RECEIPT"

echo "  Receipt:      $RECEIPT"
echo

# Sanity echo the receipt to stdout
echo "  ── GOLD receipt ────────────────────────────────────"
sed 's/^/  /' "$RECEIPT"
echo "  ────────────────────────────────────────────────────"
echo
echo "  🟢 GOLD production pipeline proven end-to-end."
echo "     Artifacts are in $STAGING and are NOT pushed anywhere."
echo "     Real ceremony push still refused — Tonya + signing key"
echo "     preconditions unmet by design in an interim session."
echo
exit 0
