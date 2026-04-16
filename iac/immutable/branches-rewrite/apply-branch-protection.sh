#!/usr/bin/env bash
# iac/immutable/branches-rewrite/apply-branch-protection.sh
#
# Applies branch protection to every immutable branch listed in branches.yaml
# (plus optionally main). Reads the topology from the same YAML as
# create-immutable-branches.sh.
#
# TWO PROTECTION MODES:
#
#   --minimal  (default)  The payload Jamie accepted on 2026-04-15 for
#                         skyqubi-public/main:
#                           enforce_admins: true
#                         Plus GitHub's defaults when protection is enabled:
#                           allow_force_pushes: false
#                           allow_deletions: false
#                         Nothing else. No PR requirement, no signed commits,
#                         no linear history, no status checks, no bypass
#                         actors, no rulesets.
#
#   --strict              The full S7 covenant stack from the original
#                         iac/immutable/apply-standard-protection.sh,
#                         adapted for solo maintainer (no PR review
#                         requirement):
#                           enforce_admins: true
#                           required_linear_history: true
#                           allow_force_pushes: false
#                           allow_deletions: false
#                           required_conversation_resolution: true
#                           required_pull_request_reviews: null (solo)
#                           required_status_checks: null
#                           restrictions: null
#                         Plus separately:
#                           required_signatures: true
#
# DRY RUN (default): prints each API call that would be made.
# REAL RUN: pass --real.
#
# IDEMPOTENT: PUT on branch protection is replace-semantics; re-running is
# safe and always produces the same final state.
#
# COVENANT NOTES:
#   - Neither mode adds bypass_actors. No backdoors.
#   - Neither mode creates rulesets. Branch protection only.
#   - --strict requires --real AND a second confirmation flag (--i-know)
#     because it's covenant-grade and the user has already specified
#     "no hidden additions." Double-ack.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/branches.yaml"
OWNER="skycair-code"
REPO="skyqubi-private"

MODE=minimal
REAL_RUN=false
INCLUDE_MAIN=false
I_KNOW=false

for arg in "$@"; do
  case "$arg" in
    --minimal) MODE=minimal ;;
    --strict)  MODE=strict ;;
    --real)    REAL_RUN=true ;;
    --include-main) INCLUDE_MAIN=true ;;
    --i-know)  I_KNOW=true ;;
    --help|-h) sed -n '2,50p' "$0" | sed 's|^# \?||'; exit 0 ;;
  esac
done

say() { echo "  $*"; }
fail() { echo "  🔴 FAIL: $*" >&2; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────
say "── Preflight ──"
[[ -f "$CONFIG" ]] || fail "config missing: $CONFIG"
if $REAL_RUN; then
  [[ -n "${GH_TOKEN:-}" ]] || fail "GH_TOKEN not set"
  [[ "$GH_TOKEN" == gh[pousr]_* ]] || fail "GH_TOKEN doesn't look like a PAT"
fi
if [[ "$MODE" == "strict" ]] && $REAL_RUN && ! $I_KNOW; then
  echo
  echo "  🟡 --strict is covenant-grade. It applies required_signatures +"
  echo "     required_linear_history + required_conversation_resolution on"
  echo "     top of the minimal payload Jamie accepted on 2026-04-15."
  echo "     Re-run with --strict --real --i-know to proceed."
  echo
  exit 1
fi

say "✓ config: $CONFIG"
say "mode: $MODE"
$INCLUDE_MAIN && say "include main: yes" || say "include main: no (immutable branches only)"
if $REAL_RUN; then
  say "real: 🔴 YES — protection will be applied to GitHub"
else
  say "real: 🟡 NO (dry run — add --real to execute)"
fi
echo

# ── Load branch list from YAML ────────────────────────────────────
BRANCH_LIST=$(python3 - "$CONFIG" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    doc = yaml.safe_load(f)
for b in doc.get("immutable_branches", []):
    print(b["branch"])
PY
) || fail "branches.yaml parse failed"

if $INCLUDE_MAIN; then
  BRANCH_LIST=$(printf 'main\n%s' "$BRANCH_LIST")
fi

branch_count=$(echo "$BRANCH_LIST" | grep -c . || true)
say "target branches: $branch_count"
echo

# ── Fetch existing branches on remote ─────────────────────────────
EXISTING=""
if $REAL_RUN; then
  EXISTING=$(curl -sS -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$OWNER/$REPO/branches?per_page=100" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(' '.join(b['name'] for b in d))" 2>/dev/null || echo "")
fi

# ── Build payload ─────────────────────────────────────────────────
if [[ "$MODE" == "minimal" ]]; then
  PAYLOAD='{"required_status_checks":null,"enforce_admins":true,"required_pull_request_reviews":null,"restrictions":null}'
  REQUIRE_SIGS=false
else
  # strict
  PAYLOAD='{
    "required_status_checks": null,
    "enforce_admins": true,
    "required_pull_request_reviews": null,
    "restrictions": null,
    "required_linear_history": true,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "required_conversation_resolution": true
  }'
  REQUIRE_SIGS=true
fi

echo "  ── Payload (mode=$MODE) ──"
echo "$PAYLOAD" | python3 -m json.tool | sed 's|^|    |'
if $REQUIRE_SIGS; then
  echo "    + POST /branches/<b>/protection/required_signatures"
fi
echo

# ── Apply loop ────────────────────────────────────────────────────
SUCCEEDED=()
SKIPPED_MISSING=()
FAILED=()

while read -r branch; do
  [[ -z "$branch" ]] && continue

  # Check branch exists on remote (in real mode)
  if $REAL_RUN && ! echo " $EXISTING " | grep -q " $branch "; then
    say "↷ $branch — not on remote yet, skipping (create branch first)"
    SKIPPED_MISSING+=("$branch")
    continue
  fi

  if ! $REAL_RUN; then
    echo "  [DRY] PUT repos/$OWNER/$REPO/branches/$branch/protection"
    $REQUIRE_SIGS && echo "  [DRY] POST repos/$OWNER/$REPO/branches/$branch/protection/required_signatures"
    SUCCEEDED+=("$branch")
    continue
  fi

  # Real: PUT the payload
  tmp=$(mktemp)
  status=$(curl -sS -o "$tmp" -w "%{http_code}" \
    -X PUT \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$OWNER/$REPO/branches/$branch/protection" \
    -d "$PAYLOAD")
  if [[ "$status" == "200" ]]; then
    say "✓ $branch protected (PUT $status)"
    if $REQUIRE_SIGS; then
      sigs_status=$(curl -sS -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Authorization: token $GH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$OWNER/$REPO/branches/$branch/protection/required_signatures")
      if [[ "$sigs_status" == "200" ]]; then
        say "  ✓ $branch required_signatures enabled"
      else
        say "  ⚠ $branch required_signatures POST returned $sigs_status"
      fi
    fi
    SUCCEEDED+=("$branch")
  else
    say "✗ $branch PUT failed ($status)"
    head -2 "$tmp" | sed 's|^|      |'
    FAILED+=("$branch")
  fi
  rm -f "$tmp"
done <<< "$BRANCH_LIST"

echo
say "── Summary ──"
say "target:      $branch_count"
say "✓ applied:   ${#SUCCEEDED[@]}"
for b in "${SUCCEEDED[@]}"; do echo "    ✓ $b"; done
if [[ ${#SKIPPED_MISSING[@]} -gt 0 ]]; then
  say "↷ skipped (branch missing): ${#SKIPPED_MISSING[@]}"
  for b in "${SKIPPED_MISSING[@]}"; do echo "    ↷ $b"; done
fi
if [[ ${#FAILED[@]} -gt 0 ]]; then
  say "✗ failed: ${#FAILED[@]}"
  for b in "${FAILED[@]}"; do echo "    ✗ $b"; done
  exit 2
fi
exit 0
