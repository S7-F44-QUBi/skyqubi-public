#!/usr/bin/env bash
# iac/immutable/apply-standard-protection.sh
#
# Applies S7's standard branch protection to a named repo under
# skycair-code. This is the script Jamie runs EVERY TIME a new
# skycair-code repo is created, because skycair-code is a User
# account (not an Organization) and GitHub does not provide a
# "default protection for all new repos" setting for user
# accounts.
#
# Standard protection settings (matched to jamie-run-me.sh):
#   enforce_admins: true
#   required_linear_history: true
#   allow_force_pushes: false
#   allow_deletions: false
#   required_conversation_resolution: true
#   required_pull_request_reviews: 1 (dismiss stale, no code owner req)
#
# PLATFORM LIMIT: on the GitHub Free tier, branch protection is
# ONLY available for PUBLIC repos. Private repos require Pro or
# higher ($4/month). This script detects the tier limitation and
# reports it clearly rather than silently failing.
#
# Usage:
#   ./apply-standard-protection.sh <repo-name>
#   ./apply-standard-protection.sh --all           # every skycair-code repo
#   ./apply-standard-protection.sh --help
#
# Precondition: GH_TOKEN exported with a non-compromised PAT that
# has 'repo' + 'admin:org' scopes. Run:
#   export GH_TOKEN="$(cat /s7/.config/s7/github-token)"
#   ./apply-standard-protection.sh SkyQUBi-public

set -uo pipefail

ORG="skycair-code"

APPLY_ALL=false
REPOS=()
for arg in "$@"; do
  case "$arg" in
    --all) APPLY_ALL=true ;;
    --help|-h)
      sed -n '2,25p' "$0" | sed 's|^# \?||'
      exit 0 ;;
    *) REPOS+=("$arg") ;;
  esac
done

# Preflight
if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "  🔴 FAIL: GH_TOKEN not exported."
  echo "     Run: export GH_TOKEN=\"\$(cat /s7/.config/s7/github-token)\""
  exit 1
fi
if ! gh api user --jq '.login' >/dev/null 2>&1; then
  echo "  🔴 FAIL: gh api user call failed — auth is not working."
  exit 1
fi

# Resolve target list
if $APPLY_ALL; then
  mapfile -t REPOS < <(gh repo list "$ORG" --limit 100 --json name --jq '.[].name')
fi

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "  🔴 No repos specified. Pass a repo name or --all."
  exit 1
fi

echo "  Applying standard protection to ${#REPOS[@]} repo(s)..."
echo

# Standard payload
PAYLOAD=$(cat <<'JSON'
{
  "required_status_checks": {"strict": true, "contexts": []},
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
)

# Write payload to tempfile for gh --input
PAYLOAD_FILE=$(mktemp /tmp/s7-protection-XXXXXX.json)
echo "$PAYLOAD" > "$PAYLOAD_FILE"
trap 'rm -f "$PAYLOAD_FILE"' EXIT

SUCCEEDED=()
FAILED_TIER=()
FAILED_OTHER=()

for repo in "${REPOS[@]}"; do
  # Discover visibility — tier limit applies to private repos only
  visibility=$(gh api "repos/$ORG/$repo" --jq '.visibility' 2>/dev/null)
  if [[ -z "$visibility" ]]; then
    echo "  ✗ $repo — cannot read (missing or no access)"
    FAILED_OTHER+=("$repo")
    continue
  fi

  # Discover default branch — may not be 'main'
  default_branch=$(gh api "repos/$ORG/$repo" --jq '.default_branch' 2>/dev/null)
  if [[ -z "$default_branch" || "$default_branch" == "null" ]]; then
    echo "  ✗ $repo — no default branch set (empty repo?)"
    FAILED_OTHER+=("$repo")
    continue
  fi

  # Apply protection
  response=$(gh api -X PUT "repos/$ORG/$repo/branches/$default_branch/protection" \
    --input "$PAYLOAD_FILE" 2>&1)
  if echo "$response" | grep -q '"url":'; then
    echo "  ✓ $repo ($visibility, $default_branch)"
    SUCCEEDED+=("$repo")
  elif echo "$response" | grep -q 'Upgrade to GitHub Pro'; then
    echo "  🟡 $repo ($visibility, $default_branch) — BLOCKED by Free tier"
    echo "     Protection for private repos requires GitHub Pro. This is"
    echo "     a platform limit, not a script bug. Options:"
    echo "       1. Upgrade skycair-code to Pro (\$4/month)"
    echo "       2. Keep covenant discipline as the only enforcement"
    FAILED_TIER+=("$repo")
  else
    echo "  ✗ $repo — protection apply failed:"
    echo "$response" | head -2 | sed 's/^/     /'
    FAILED_OTHER+=("$repo")
  fi
done

echo
echo "  ── Summary ──"
echo "  ✓ Succeeded: ${#SUCCEEDED[@]}"
for r in "${SUCCEEDED[@]}"; do echo "     $r"; done
if [[ ${#FAILED_TIER[@]} -gt 0 ]]; then
  echo "  🟡 Blocked by Free tier: ${#FAILED_TIER[@]}"
  for r in "${FAILED_TIER[@]}"; do echo "     $r (private — needs Pro)"; done
fi
if [[ ${#FAILED_OTHER[@]} -gt 0 ]]; then
  echo "  ✗ Other failures: ${#FAILED_OTHER[@]}"
  for r in "${FAILED_OTHER[@]}"; do echo "     $r"; done
  exit 2
fi
exit 0
