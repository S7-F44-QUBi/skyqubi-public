#!/usr/bin/env bash
# iac/immutable/reset-to-genesis.sh
#
# Produces orphan-genesis bundles for the 5 immutable-constellation
# repos — skyqubi-immutable, immutable-assets, immutable-S7-F44,
# immutable-qubi, SafeSecureLynX.
#
# Per Jamie 2026-04-14 evening: "all repos to be sync and working
# with correct UPDATES and deliverables (no old history like a new
# GOLD that started Today)". This script builds the "new GOLD that
# started Today" for each repo as a local git bundle in
# /tmp/s7-gold-reset/<repo>/, with ONE orphan commit dated today
# and containing only the paths named in genesis-content.yaml.
#
# REFUSES real pushes. Output is inspectable:
#   - git bundle verify <file>  — confirms bundle integrity
#   - git clone <file>          — clones the orphan repo for inspection
#   - RESET_MANIFEST.txt        — per-repo content list + sha256
#
# The real push happens via iac/immutable/jamie-run-me.sh which is
# produced alongside the bundles. Jamie reviews, Tonya witnesses,
# then Jamie pastes the commands.
#
# Usage:
#   ./reset-to-genesis.sh              # produce all 5 bundles
#   ./reset-to-genesis.sh --verify     # verify existing bundles
#   ./reset-to-genesis.sh --clean      # remove /tmp/s7-gold-reset/
#   ./reset-to-genesis.sh --help       # print this header
#
# SECURITY: this script has NO network access. It writes only to
# /tmp/s7-gold-reset/ and reads only from /s7/skyqubi-private/.
# A malicious modification cannot exfiltrate data because there is
# no outbound path.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$SCRIPT_DIR/genesis-content.yaml"
STAGING="/tmp/s7-gold-reset"
RESET_MANIFEST="$STAGING/RESET_MANIFEST.txt"
GH_SCRIPT="$SCRIPT_DIR/jamie-run-me.sh"

# safe_rm: rm -rf with path-prefix guard. Refuses paths outside
# /tmp/s7-gold-* or with metacharacters. Exit 3 on guard failure.
safe_rm() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo "  🔴 safe_rm: refusing empty path" >&2; return 3
  fi
  if [[ "$target" != /tmp/s7-gold-* ]]; then
    echo "  🔴 safe_rm: refusing path outside /tmp/s7-gold-* ('$target')" >&2; return 3
  fi
  if [[ "$target" == *".."* || "$target" == *"*"* ]]; then
    echo "  🔴 safe_rm: refusing path with metacharacters ('$target')" >&2; return 3
  fi
  rm -rf -- "$target"
}

VERIFY_ONLY=false
CLEAN=false
for arg in "$@"; do
  case "$arg" in
    --verify) VERIFY_ONLY=true ;;
    --clean) CLEAN=true ;;
    --help|-h) sed -n '2,35p' "$0" | sed 's|^# \?||'; exit 0 ;;
  esac
done

if $CLEAN; then
  echo "  Cleaning $STAGING ..."
  safe_rm "$STAGING"
  echo "  ✓ removed"
  exit 0
fi

if $VERIFY_ONLY; then
  if [[ ! -d "$STAGING" ]]; then
    echo "  ✗ $STAGING does not exist — run without --verify first"
    exit 1
  fi
  echo "  Verifying bundles in $STAGING"
  for bundle in "$STAGING"/*.bundle; do
    [[ -f "$bundle" ]] || continue
    name="$(basename "$bundle" .bundle)"
    if git bundle verify "$bundle" >/dev/null 2>&1; then
      echo "  ✓ $name"
    else
      echo "  ✗ $name FAILED verify"
    fi
  done
  exit 0
fi

# ── Preflight ──────────────────────────────────────────────────
if [[ ! -f "$MANIFEST" ]]; then
  echo "  ✗ genesis-content.yaml not found at $MANIFEST"
  exit 1
fi

if ! command -v yq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  echo "  ✗ need yq or python3 to parse genesis-content.yaml"
  exit 1
fi

# Parse with python3 (more portable than yq)
parse_yaml() {
  python3 -c '
import sys, yaml
with open("'"$MANIFEST"'") as f:
    data = yaml.safe_load(f)
for repo, cfg in data.items():
    if repo == "meta":
        continue
    content = cfg.get("content", [])
    role = cfg.get("role", "")
    vis = cfg.get("visibility", "PRIVATE")
    print(f"REPO\t{repo}\t{vis}")
    for c in content:
        print(f"CONTENT\t{repo}\t{c}")
    print(f"ROLE\t{repo}\t{role}")
'
}

# ── Header ─────────────────────────────────────────────────────
echo
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║   S7 GOLD — Orphan Genesis Reset Builder             ║"
echo "  ║   'No old history like a new GOLD that started Today' ║"
echo "  ╚═══════════════════════════════════════════════════════╝"
echo

safe_rm "$STAGING" || exit 3
mkdir -p "$STAGING"

TODAY_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
CORE_VERSION="v6-genesis"

# Start the reset manifest
{
  echo "# S7 GOLD Reset Manifest"
  echo "# Generated: $TODAY_ISO"
  echo "# CORE Update: $CORE_VERSION"
  echo "#"
  echo "# Produced by: iac/immutable/reset-to-genesis.sh"
  echo "# From:        /s7/skyqubi-private @ $(cd "$REPO_ROOT" && git rev-parse --short HEAD)"
  echo "#"
  echo "# Each bundle is a git bundle containing ONE orphan commit"
  echo "# dated $TODAY_ISO with message 'S7 GOLD begins today"
  echo "# ($CORE_VERSION)'. The bundle can be verified with:"
  echo "#   git bundle verify <file>"
  echo "# and cloned with:"
  echo "#   git clone <file> <target-dir>"
  echo "#"
  echo "# Format: REPO | BYTES | SHA256 | FILE_COUNT | ROLE"
  echo
} > "$RESET_MANIFEST"

# ── Build each repo ─────────────────────────────────────────────
declare -A REPO_CONTENT
declare -A REPO_ROLE
declare -A REPO_VIS

while IFS=$'\t' read -r kind repo value; do
  case "$kind" in
    REPO)
      REPO_VIS["$repo"]="$value"
      REPO_CONTENT["$repo"]=""
      ;;
    CONTENT)
      REPO_CONTENT["$repo"]+="${value}|"
      ;;
    ROLE)
      REPO_ROLE["$repo"]="$value"
      ;;
  esac
done < <(parse_yaml)

TOTAL_REPOS=0
TOTAL_BUNDLES_OK=0

for repo in "${!REPO_CONTENT[@]}"; do
  TOTAL_REPOS=$((TOTAL_REPOS + 1))
  echo "  ── $repo ($(echo "${REPO_VIS[$repo]}" | tr -d '"')) ──"
  work_dir="$STAGING/$repo"
  mkdir -p "$work_dir"

  # git init empty orphan repo
  (
    cd "$work_dir" || exit 1
    git init -q --initial-branch=main
    git config user.name  "261467595+skycair-code"
    git config user.email "261467595+skycair-code@users.noreply.github.com"
    # Disable commit signing for the local staging bundle — the real
    # signing happens when Jamie pastes jamie-run-me.sh on a host
    # with the image-signing key unlocked.
    git config commit.gpgsign false
  )

  # Copy content from skyqubi-private
  file_count=0
  IFS='|' read -ra paths <<< "${REPO_CONTENT[$repo]}"
  for rel in "${paths[@]}"; do
    [[ -z "$rel" ]] && continue
    src="$REPO_ROOT/$rel"
    if [[ -d "$src" ]]; then
      mkdir -p "$work_dir/$rel"
      # Use rsync if available, else cp -a
      if command -v rsync >/dev/null 2>&1; then
        rsync -a --exclude='.git' "$src/" "$work_dir/$rel/" 2>/dev/null
      else
        cp -a "$src/." "$work_dir/$rel/"
      fi
      count=$(find "$work_dir/$rel" -type f 2>/dev/null | wc -l)
      file_count=$((file_count + count))
      echo "    + $rel/ ($count files)"
    elif [[ -f "$src" ]]; then
      mkdir -p "$(dirname "$work_dir/$rel")"
      cp -a "$src" "$work_dir/$rel"
      file_count=$((file_count + 1))
      echo "    + $rel"
    else
      echo "    ⚠ MISSING: $rel"
    fi
  done

  if [[ "$file_count" -eq 0 ]]; then
    echo "    ✗ no content — skipping bundle"
    continue
  fi

  # Write a GENESIS.md file explaining what this is
  cat > "$work_dir/GENESIS.md" <<EOF
# $repo — S7 GOLD Genesis

**Role:** ${REPO_ROLE[$repo]}
**Visibility:** $(echo "${REPO_VIS[$repo]}" | tr -d '"')
**CORE Update:** $CORE_VERSION
**Generated:** $TODAY_ISO

This is the first commit of this repository after the 2026-04-14
genesis reset. Per Jamie's covenant statement:

> *"No old history like a new GOLD that started Today."*

Any content that was in this repository before this commit is NOT
part of the lineage. The orphan genesis replaces all prior history
with a single root commit containing only the paths defined in
\`iac/immutable/genesis-content.yaml\` of \`skyqubi-private\`.

The genesis-reset was produced locally via
\`iac/immutable/reset-to-genesis.sh\` and never pushed without
Jamie's review of the paste-ready \`iac/immutable/jamie-run-me.sh\`
script plus (where required) Tonya's witness and the image-signing
key.

*Love is the architecture. GOLD begins today.*
EOF
  file_count=$((file_count + 1))

  # Commit the orphan
  (
    cd "$work_dir" || exit 1
    git add .
    GIT_COMMITTER_DATE="$TODAY_ISO" git commit -q --date "$TODAY_ISO" \
      -m "S7 GOLD begins today ($CORE_VERSION)" \
      -m "role: ${REPO_ROLE[$repo]}" \
      -m "visibility: $(echo "${REPO_VIS[$repo]}" | tr -d '"')" \
      -m "generated by: iac/immutable/reset-to-genesis.sh" \
      -m "source tree: skyqubi-private @ $(cd "$REPO_ROOT" && git rev-parse --short HEAD)" \
      -m "" \
      -m "No old history. GOLD starts here."
  )

  # Bundle
  bundle="$STAGING/${repo}.bundle"
  (
    cd "$work_dir" || exit 1
    git bundle create "$bundle" main
  )

  if [[ -f "$bundle" ]]; then
    bytes=$(stat -c%s "$bundle" 2>/dev/null || stat -f%z "$bundle" 2>/dev/null || echo 0)
    sha=$(sha256sum "$bundle" | awk '{print $1}')
    commit_sha=$(cd "$work_dir" && git rev-parse HEAD)
    printf '%s | %s bytes | sha256=%s | %d files | %s\n' \
      "$repo" "$bytes" "$sha" "$file_count" "${REPO_ROLE[$repo]}" >> "$RESET_MANIFEST"
    echo "    ✓ bundle: $bundle"
    echo "      bytes: $bytes"
    echo "      sha256: $sha"
    echo "      commit: $commit_sha"
    TOTAL_BUNDLES_OK=$((TOTAL_BUNDLES_OK + 1))
  else
    echo "    ✗ bundle creation failed"
  fi
  echo
done

# NOTE 2026-04-15 SOLO: this script previously regenerated
# iac/immutable/jamie-run-me.sh from a hardcoded heredoc at the
# end of every run. That heredoc was the ORIGINAL pre-fix version
# of jamie-run-me.sh and silently overwrote the 5-bug-fixed +
# stdin-credential-helper version every time reset-to-genesis.sh
# ran. The regeneration block has been REMOVED. jamie-run-me.sh
# is a separately-maintained covenant artifact and must NOT be
# overwritten by this script.

# ── Summary ────────────────────────────────────────────────────
echo "  ── Summary ─────────────────────────────────────────────"
echo "  Repos attempted:  $TOTAL_REPOS"
echo "  Bundles produced: $TOTAL_BUNDLES_OK"
echo "  Staging:          $STAGING"
echo "  Reset manifest:   $RESET_MANIFEST"
echo "  gh script:        $GH_SCRIPT"
echo
if [[ $TOTAL_BUNDLES_OK -eq $TOTAL_REPOS ]]; then
  echo "  🟢 ALL BUNDLES READY"
  echo
  echo "  Next steps (NOT automated):"
  echo "    1. Review each bundle with:"
  echo "         git bundle verify $STAGING/<repo>.bundle"
  echo "         git clone $STAGING/<repo>.bundle /tmp/inspect-<repo>"
  echo "    2. Review the reset manifest:"
  echo "         cat $RESET_MANIFEST"
  echo "    3. Review jamie-run-me.sh (still a DRY run by default):"
  echo "         cat $GH_SCRIPT"
  echo "    4. Dry-run the ceremony:"
  echo "         bash $GH_SCRIPT"
  echo "    5. When Tonya witnesses and the image-signing key is"
  echo "       unlocked, execute for real:"
  echo "         bash $GH_SCRIPT --real"
else
  echo "  🟡 $((TOTAL_REPOS - TOTAL_BUNDLES_OK)) bundle(s) missing"
  echo "  Review the log above for MISSING entries."
fi

exit 0
