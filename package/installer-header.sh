#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi self-extracting installer — bash header
#
# This file is the "wrapper" half of a self-extracting bash + tar.zst
# bundle. The build-installer.sh tool concatenates this header with
# (a) a small marker line, (b) a sha256 manifest, and (c) a tar.zst
# payload of the inner installer + the repo + container images.
#
# How it self-extracts:
#   1. The user runs `bash s7-skyqubi-installer.sh`
#   2. This header runs first — it parses flags, locates the marker
#      line `__S7_PAYLOAD_BELOW__`, then takes everything after that
#      line as the binary payload
#   3. The payload is extracted to a tempdir
#   4. The extracted inner installer (./inner.sh) is invoked
#
# The user touches the internet at most ONCE — when they download
# this file. Everything else lives in the payload.
#
# Governing rules:
#   feedback_three_rules.md   Rule 3: Protect the QUBi
#   project_intake_gate.md    Verify-before-trust on every artifact
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Flag parsing ────────────────────────────────────────────────────
KEEP_TMP=0
DRY_RUN=0
EXTRACT_ONLY=""
SKIP_VERIFY=0
for arg in "$@"; do
    case "$arg" in
        --keep-tmp)     KEEP_TMP=1 ;;
        --dry-run)      DRY_RUN=1 ;;
        --extract=*)    EXTRACT_ONLY="${arg#--extract=}" ;;
        --skip-verify)  SKIP_VERIFY=1 ;;
        --help|-h)
            sed -n '3,21p' "$0" | sed 's|^# \?||'
            cat <<EOF

Flags:
  --dry-run        Verify the payload but don't run the inner installer
  --extract=DIR    Extract the payload to DIR and exit (no install)
  --keep-tmp       Don't delete the extraction tempdir on exit
  --skip-verify    Skip the manifest sha256 check (NOT recommended)
  --help, -h       Show this message

EOF
            exit 0
            ;;
        *)
            echo "unknown flag: $arg" >&2
            echo "try: $0 --help" >&2
            exit 1
            ;;
    esac
done

# ── Banner ──────────────────────────────────────────────────────────
GREEN='' RED='' CYAN='' YELLOW='' RESET=''
if [ -t 1 ]; then
    GREEN=$'\033[0;32m'
    RED=$'\033[0;31m'
    CYAN=$'\033[0;36m'
    YELLOW=$'\033[0;33m'
    RESET=$'\033[0m'
fi
ok()   { echo "  ${GREEN}✓${RESET} $1"; }
fail() { echo "  ${RED}✗${RESET} $1" >&2; }
warn() { echo "  ${YELLOW}!${RESET} $1"; }
info() { echo "  ${CYAN}→${RESET} $1"; }

echo
echo "${CYAN}  S7 SkyQUBi — Self-Extracting Installer${RESET}"
echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

# ── Locate the payload marker ───────────────────────────────────────
SELF="$(realpath "$0")"
MARKER="__S7_PAYLOAD_BELOW__"
PAYLOAD_LINE=$(awk "/^${MARKER}\$/{print NR + 1; exit 0}" "$SELF" || true)
if [ -z "$PAYLOAD_LINE" ]; then
    fail "Payload marker not found — this file is not a complete self-extractor."
    exit 2
fi
info "Payload starts at line $PAYLOAD_LINE"

# ── Verify the manifest ─────────────────────────────────────────────
# The manifest is a single sha256 line embedded in the header just
# before the marker. The build script writes it; we read it here.
MANIFEST_HASH="__S7_MANIFEST_SHA256_PLACEHOLDER__"
# Sentinel: a real sha256 is exactly 64 hex chars. If the build script
# substituted the placeholder, $MANIFEST_HASH will be 64 chars long.
# If not, we're looking at an unbuilt header.
if [ "$SKIP_VERIFY" -eq 0 ]; then
    if [ "${#MANIFEST_HASH}" -ne 64 ]; then
        warn "Manifest hash looks unbuilt (length ${#MANIFEST_HASH}, expected 64)."
    else
        actual=$(tail -n +"$PAYLOAD_LINE" "$SELF" | sha256sum | awk '{print $1}')
        if [ "$actual" = "$MANIFEST_HASH" ]; then
            ok "Payload sha256 verified: $MANIFEST_HASH"
        else
            fail "Payload sha256 MISMATCH"
            fail "  expected: $MANIFEST_HASH"
            fail "  got:      $actual"
            fail "Refusing to extract a tampered or corrupt installer."
            exit 3
        fi
    fi
else
    warn "Skipping manifest verification (--skip-verify)"
fi

# ── Extract target preflight ────────────────────────────────────────
# Pick a tempdir that actually has room. /tmp is often a small tmpfs
# (1 GB on many systems), and a bundled installer with images +
# models is multiple GB. We measure the file's payload size, then
# pick a target with at least 2x that free.
SELF_BYTES=$(stat -c%s "$SELF" 2>/dev/null || stat -f%z "$SELF" 2>/dev/null || echo 0)
NEEDED_MB=$(( (SELF_BYTES * 2) / 1048576 + 100 ))

pick_extract_target() {
    for candidate in "$XDG_RUNTIME_DIR" "$HOME/.cache" "$HOME" "/var/tmp" "/tmp"; do
        [ -z "$candidate" ] && continue
        [ ! -d "$candidate" ] && continue
        free_mb=$(df -BM "$candidate" 2>/dev/null | awk 'NR==2 {gsub(/M/,"",$4); print $4}')
        [ -z "$free_mb" ] && continue
        if [ "$free_mb" -ge "$NEEDED_MB" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

# ── Extract ─────────────────────────────────────────────────────────
if [ -n "$EXTRACT_ONLY" ]; then
    target="$EXTRACT_ONLY"
    mkdir -p "$target"
    # Verify the user-supplied target has room
    target_free=$(df -BM "$target" 2>/dev/null | awk 'NR==2 {gsub(/M/,"",$4); print $4}')
    if [ -n "$target_free" ] && [ "$target_free" -lt "$NEEDED_MB" ]; then
        fail "Target $target has only ${target_free} MB free; need ~${NEEDED_MB} MB."
        fail "Pick a different --extract path or free up space."
        exit 5
    fi
else
    parent=$(pick_extract_target)
    if [ -z "$parent" ]; then
        fail "No suitable tempdir found with ${NEEDED_MB} MB free."
        fail "Tried: \$XDG_RUNTIME_DIR \$HOME/.cache \$HOME /var/tmp /tmp"
        fail "Free up space somewhere or use --extract=/path/with/room"
        exit 5
    fi
    info "Picked extract parent: $parent (need ~${NEEDED_MB} MB free)"
    target=$(mktemp -d -p "$parent" "s7-installer-XXXXXX")
    if [ "$KEEP_TMP" -eq 0 ]; then
        trap 'rm -rf "$target"' EXIT
    fi
fi
info "Extracting payload to: $target"

tail -n +"$PAYLOAD_LINE" "$SELF" | zstd -d --stdout 2>/dev/null | tar -x -C "$target"
ok "Payload extracted ($(du -sh "$target" 2>/dev/null | awk '{print $1}'))"

if [ -n "$EXTRACT_ONLY" ]; then
    echo
    ok "Extracted to $target — exiting per --extract"
    exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo
    ok "Dry run — payload verified and extractable. NOT running inner installer."
    exit 0
fi

# ── Hand off to the inner installer ─────────────────────────────────
INNER="$target/inner.sh"
if [ ! -x "$INNER" ]; then
    fail "Inner installer not found or not executable: $INNER"
    exit 4
fi
info "Handing off to inner installer"
echo
exec bash "$INNER"
