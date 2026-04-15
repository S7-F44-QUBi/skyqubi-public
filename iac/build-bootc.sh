#!/usr/bin/env bash
# iac/build-bootc.sh
# S7 SkyCAIR bootc image builder with scratch-space fix
#
# Wraps `podman build` against the root Containerfile with a
# TMPDIR override so buildah's commit-time layer copy doesn't
# fail on /var/tmp being a 512M tmpfs.
#
# Background: the 2026-04-14→15 SOLO block's rebuild attempt
# failed at commit time with:
#   copying layers and metadata for container "...": initializing
#   source containers-storage:...: storing layer "..." to file:
#   on copy: writing to tar filter pipe (closed=false,
#   err=reading tar archive: copying content for "usr/lib64/
#   liblpsolve55.so": write /var/tmp/buildah.../layer: no space
#   left on device
#
# Root cause: /var/tmp is a tmpfs capped at 512 MB on this host
# (Fedora 44 default for systemd-tmpfiles). Buildah's commit
# step needs to stage the full layer before writing to podman
# storage, and a ~10 GB S7 bootc image overflows 512 MB.
#
# Fix: set TMPDIR to a directory on the main xfs filesystem
# (/s7/.cache/buildah) which has 325 GB free. This is the same
# pattern Fedora's own docs recommend for large builds.
#
# Usage:
#   ./iac/build-bootc.sh                    # build with default tags
#   ./iac/build-bootc.sh --tag v6-genesis   # explicit tag
#   ./iac/build-bootc.sh --no-cache         # force fresh layer pulls
#   ./iac/build-bootc.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTAINERFILE="$REPO_ROOT/Containerfile"
LOG="/tmp/s7-bootc-build.log"

TAG="v6-genesis"
NO_CACHE=false
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --help|-h)
      sed -n '2,35p' "$0" | sed 's|^# \?||'
      exit 0 ;;
    --tag)     j=$((i+1)); TAG="${!j}" ;;
    --no-cache) NO_CACHE=true ;;
  esac
done

# Preflight: containerfile exists
if [[ ! -f "$CONTAINERFILE" ]]; then
  echo "  🔴 FAIL: Containerfile not found at $CONTAINERFILE"
  exit 1
fi

# Preflight: scratch space exists and has room
mkdir -p /s7/.cache/buildah
avail_kb=$(df --output=avail /s7 2>/dev/null | tail -1)
avail_gb=$((avail_kb / 1024 / 1024))
if [[ $avail_gb -lt 20 ]]; then
  echo "  🔴 FAIL: /s7 has only ${avail_gb} GB free — need at least 20 GB for a bootc build"
  exit 1
fi
echo "  ✓ /s7 has ${avail_gb} GB free"

# Preflight: base image pulled
if ! podman image exists quay.io/fedora/fedora-bootc:44; then
  echo "  🔴 FAIL: quay.io/fedora/fedora-bootc:44 not in local store"
  echo "     Run: podman pull quay.io/fedora/fedora-bootc:44"
  exit 1
fi
echo "  ✓ quay.io/fedora/fedora-bootc:44 is cached locally"

echo
echo "  ── Building localhost/s7-skycair:$TAG ──"
echo "  Containerfile: $CONTAINERFILE"
echo "  TMPDIR:        /s7/.cache/buildah  (fix for /var/tmp 512M tmpfs cap)"
echo "  Log:           $LOG"
echo

NO_CACHE_ARG=""
$NO_CACHE && NO_CACHE_ARG="--no-cache"

TMPDIR=/s7/.cache/buildah \
  podman build \
    $NO_CACHE_ARG \
    -t "localhost/s7-skycair:$TAG" \
    -t "localhost/s7-skycair:latest" \
    -f "$CONTAINERFILE" \
    "$REPO_ROOT" 2>&1 | tee "$LOG"

BUILD_EXIT=${PIPESTATUS[0]}
if [[ $BUILD_EXIT -eq 0 ]]; then
  echo
  echo "  🟢 BUILD COMPLETE — localhost/s7-skycair:$TAG"
  podman images localhost/s7-skycair
  exit 0
else
  echo
  echo "  🔴 BUILD FAILED (exit $BUILD_EXIT)"
  echo "     Last 20 lines of $LOG:"
  tail -20 "$LOG" | sed 's/^/       /'
  exit $BUILD_EXIT
fi
