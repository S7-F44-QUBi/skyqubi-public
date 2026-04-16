#!/usr/bin/env bash
# iac/immutable/build-with-skeleton.sh
#
# Thin wrapper that stages GOLD assets via the skeleton, then calls the
# existing iac/build-bootc.sh unchanged. Does NOT modify build-bootc.sh
# or the Containerfile — those remain load-bearing and untouched.
#
# Staging location is /s7/.cache/s7-build-assets/. When Jamie is ready to
# bake the assets into the image, the Containerfile can add COPY directives
# from that path. Until then, staging runs but the image build ignores it.
#
# Usage:
#   ./build-with-skeleton.sh                       # stage + build (dry mode, skeleton only by default)
#   ./build-with-skeleton.sh --stage-only          # only stage, skip build
#   ./build-with-skeleton.sh --real                # stage + actual podman build
#   ./build-with-skeleton.sh --source=remote       # fetch assets from immutable branches (needs GH_TOKEN)
#
# Exit codes:
#   0  success
#   1  usage error
#   2  skeleton staging failed
#   3  build-bootc.sh failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOY="$SCRIPT_DIR/deploy-assets.sh"
BUILD="$REPO_ROOT/iac/build-bootc.sh"
STAGE_DIR="/s7/.cache/s7-build-assets"

STAGE_ONLY=false
REAL_BUILD=false
SOURCE="local"

for arg in "$@"; do
  case "$arg" in
    --stage-only) STAGE_ONLY=true ;;
    --real)       REAL_BUILD=true ;;
    --source=*)   SOURCE="${arg#*=}" ;;
    --help|-h)    sed -n '2,25p' "$0" | sed 's|^# \?||'; exit 0 ;;
  esac
done

say() { echo "  [build-wrapper] $*"; }
fail() { echo "  🔴 [build-wrapper] $*" >&2; exit "${2:-1}"; }

# ── Preflight ─────────────────────────────────────────────────────
[[ -x "$DEPLOY" ]] || fail "deploy-assets.sh missing or not executable" 1
[[ -x "$BUILD" ]] || fail "build-bootc.sh missing or not executable" 1

# ── Stage assets ──────────────────────────────────────────────────
say "── Phase 1: stage GOLD assets via skeleton ──"
say "stage dir: $STAGE_DIR"
say "source:    $SOURCE"

rm -rf "$STAGE_DIR"
if ! "$DEPLOY" --source="$SOURCE" --deploy-root="$STAGE_DIR" 2>&1 | sed 's|^|    |'; then
  fail "skeleton staging failed" 2
fi
say "✓ skeleton staging complete"

# Report what landed
say "staged categories:"
for d in "$STAGE_DIR"/*/; do
  [[ -d "$d" ]] || continue
  cat_name=$(basename "$d")
  size=$(du -sh "$d" 2>/dev/null | awk '{print $1}')
  echo "    $cat_name ($size)"
done
echo

if $STAGE_ONLY; then
  say "🟢 stage-only mode — build skipped"
  say "   staged assets at: $STAGE_DIR"
  say "   Containerfile can COPY from \$STAGE_DIR when ready to bake"
  exit 0
fi

# ── Phase 2: call build-bootc.sh (unchanged) ──────────────────────
if ! $REAL_BUILD; then
  say "── Phase 2: build-bootc.sh (DRY RUN — pass --real to execute) ──"
  say "would call: $BUILD"
  exit 0
fi

say "── Phase 2: calling $BUILD ──"
if ! "$BUILD"; then
  fail "build-bootc.sh failed" 3
fi
say "🟢 build complete with staged skeleton assets"
exit 0
