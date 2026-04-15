#!/usr/bin/env bash
# iac/immutable/create-missing-repos.sh
#
# Check which of the 5 immutable-constellation repos exist under
# skycair-code, and optionally create the missing ones.
#
# Run AFTER the PAT is rotated (this script uses gh api which
# requires GH_TOKEN to be set from a non-compromised token).
#
# Usage:
#   ./create-missing-repos.sh               # check only, no creation
#   ./create-missing-repos.sh --create      # create any missing repos
#   ./create-missing-repos.sh --help        # print this header
#
# Covenant notes:
#   - All 4 sibling repos are created as PRIVATE by default.
#   - skyqubi-immutable is listed here for the check but the script
#     WILL NOT try to create it — that one was the only successful
#     ceremony-attempt-1 target and is already populated.
#   - No pushes, no commits, no protection — just repo existence.
#   - The real ceremony push is jamie-run-me.sh --real.

set -uo pipefail

ORG="skycair-code"

# 5 immutable-constellation repos — same list as jamie-run-me.sh.
REPOS=(
  "SafeSecureLynX"
  "immutable-S7-F44"
  "immutable-assets"
  "skyqubi-immutable"
  "immutable-qubi"
)

CREATE_MODE=false
for arg in "$@"; do
  case "$arg" in
    --create) CREATE_MODE=true ;;
    --help|-h) sed -n '2,22p' "$0" | sed 's|^# \?||'; exit 0 ;;
  esac
done

# Preflight: PAT loaded and working
if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "  🔴 FAIL: GH_TOKEN env var not set."
  echo "     Run: export GH_TOKEN=\"\$(cat /s7/.config/s7/github-token)\""
  exit 1
fi
if ! gh api user --jq '.login' >/dev/null 2>&1; then
  echo "  🔴 FAIL: gh api user call failed — auth is not working."
  exit 1
fi
gh_user=$(gh api user --jq '.login' 2>/dev/null)
echo "  ✓ gh auth works (as $gh_user)"
echo

MISSING=()
EXISTING=()
for repo in "${REPOS[@]}"; do
  if gh api "repos/$ORG/$repo" --jq '.name' >/dev/null 2>&1; then
    vis=$(gh api "repos/$ORG/$repo" --jq '.private' 2>/dev/null)
    [[ "$vis" == "true" ]] && vis_label="private" || vis_label="public"
    updated=$(gh api "repos/$ORG/$repo" --jq '.updated_at' 2>/dev/null)
    echo "  ✓ $repo exists ($vis_label, updated $updated)"
    EXISTING+=("$repo")
  else
    echo "  ✗ $repo MISSING"
    MISSING+=("$repo")
  fi
done
echo

if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo "  🟢 All 5 repos exist. Ready for jamie-run-me.sh --real."
  exit 0
fi

echo "  ── ${#MISSING[@]} missing repo(s) ──"
for repo in "${MISSING[@]}"; do
  if [[ "$repo" == "skyqubi-immutable" ]]; then
    echo "  ⚠ skyqubi-immutable is missing — this is unusual."
    echo "    Attempt 1 already pushed v6-genesis to this repo."
    echo "    Do NOT create it without understanding why it's gone."
    echo "    STOPPING before any create operation."
    exit 2
  fi
done

if ! $CREATE_MODE; then
  echo
  echo "  Re-run with --create to create the ${#MISSING[@]} missing repo(s)."
  echo
  echo "  The command that would run:"
  for repo in "${MISSING[@]}"; do
    echo "    gh repo create $ORG/$repo --private --description \"S7 SkyQUBi immutable — $repo\" --disable-wiki"
  done
  exit 0
fi

echo "  Creating ${#MISSING[@]} missing repo(s)..."
echo
FAILED=()
for repo in "${MISSING[@]}"; do
  echo "  + gh repo create $ORG/$repo --private"
  if gh repo create "$ORG/$repo" --private \
       --description "S7 SkyQUBi immutable — $repo" \
       --disable-wiki 2>&1 | sed 's/^/    /'; then
    echo "    ✓ created"
  else
    echo "    ✗ create failed"
    FAILED+=("$repo")
  fi
  echo
done

if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo "  🟢 All ${#MISSING[@]} missing repo(s) created."
  echo "     Next: bash iac/immutable/jamie-run-me.sh --real"
else
  echo "  🔴 ${#FAILED[@]} create(s) failed:"
  for r in "${FAILED[@]}"; do echo "    ✗ $r"; done
  exit 1
fi
