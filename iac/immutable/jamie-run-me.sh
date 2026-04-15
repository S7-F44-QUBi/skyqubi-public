#!/usr/bin/env bash
# iac/immutable/jamie-run-me.sh
#
# Paste-ready ceremony script for the FIRST GOLD advance.
# Produced by iac/immutable/reset-to-genesis.sh.
#
# WHAT THIS DOES:
#   1. For each of the 5 immutable-constellation repos, force-
#      pushes the orphan-genesis bundle as the new main branch,
#      replacing any existing history.
#   2. Applies branch protection (required_signatures off during
#      the initial orphan push, then toggled back on).
#   3. Tightens branch protection: enforce_admins, required_linear_
#      history, allow_force_pushes=false, allow_deletions=false,
#      required_conversation_resolution=true.
#
# PRECONDITIONS (all must be true before you run this):
#   [ ] You have reviewed iac/immutable/reset-to-genesis.sh output
#       in /tmp/s7-gold-reset/ and you approve every bundle's
#       content class.
#   [ ] Tonya has witnessed (for immutable-assets, immutable-qubi,
#       and skyqubi-immutable).
#   [ ] The image-signing key is unlocked (gpg-agent has the
#       passphrase cached OR you are ready to enter it).
#   [ ] gh CLI is authenticated with a PAT that has repo:write,
#       admin:repo, and force_push scope on skycair-code.
#   [ ] You have a terminal where interruption will not leave the
#       branches in a half-pushed state.
#
# IF ANY PRECONDITION IS FALSE: close this script without running.
#
# Covenant: this script is the ONLY covenant-authorized way to
# advance the immutable constellation from its current state to
# the v6-genesis state. There is no alternative path — not force-
# push from a clone, not `gh repo sync`, not manual upload.
#
# HOW TO USE:
#   Review this file. Read the commented commands. Then:
#     bash iac/immutable/jamie-run-me.sh         # DRY RUN (default)
#     bash iac/immutable/jamie-run-me.sh --real  # real execution
#
# The --real flag is mandatory. A bare run will print each command
# it WOULD execute and exit 0 without touching any repository.

set -uo pipefail

REAL_RUN=false
for arg in "$@"; do
  case "$arg" in
    --real) REAL_RUN=true ;;
    --help|-h) sed -n '2,47p' "$0" | sed 's|^# \?||'; exit 0 ;;
  esac
done

# ── Samuel guard (added 2026-04-15 after v6-genesis orphan fracture) ──
# Refuses --real execution unless the covenant witness chain has been
# assembled. Defense in depth: the script MUST NOT run just because its
# scripts are ready. Readiness is not authorization.
#
# Required environment:
#   S7_CEREMONY_WITNESS_COUNT  — integer count of witnesses present
#                                (must be 4: Jamie + Tonya + audit + council)
#   S7_CEREMONY_TONYA_PRESENT  — must be "yes" (Chief of Covenant witness)
#   S7_CEREMONY_SIGNING_KEY    — must be "unlocked" (image-signing key)
#
# Checks:
#   1. Today must be an authorized Core Update day
#      (iac/audit/core-update-days.txt)
#   2. Audit gate must have run in the last 15 minutes
#      (iac/audit/dist/<timestamp>.json)
#   3. All four witness env vars must be set to their required values
#
# Bypass (for testing): S7_CEREMONY_OK=BYPASS (logged loudly)
#
# See postmortem: docs/internal/postmortems/2026-04-15-v6-genesis-orphan-fracture.md
if $REAL_RUN; then
  SCRIPT_DIR_SG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT_SG="$(cd "$SCRIPT_DIR_SG/../.." && pwd)"
  CORE_DAYS="$REPO_ROOT_SG/iac/audit/core-update-days.txt"
  AUDIT_DIST="$REPO_ROOT_SG/iac/audit/dist"
  TODAY_SG="$(date -u +%Y-%m-%d)"

  if [[ "${S7_CEREMONY_OK:-0}" == "BYPASS" ]]; then
    echo "  🟡 Samuel guard BYPASSED via S7_CEREMONY_OK=BYPASS — this is logged." >&2
  else
    # Check 1: Core Update day
    if [[ ! -f "$CORE_DAYS" ]] || ! grep -q "^$TODAY_SG$" "$CORE_DAYS" 2>/dev/null; then
      echo "  🔴 Samuel guard: today ($TODAY_SG) is not on iac/audit/core-update-days.txt." >&2
      echo "     --real refused. A ceremony push outside the Core Update window is a covenant violation." >&2
      exit 10
    fi
    # Check 2: recent audit gate (within 15 minutes)
    RECENT_AUDIT=$(find "$AUDIT_DIST" -maxdepth 1 -name '*.json' -mmin -15 2>/dev/null | head -1)
    if [[ -z "$RECENT_AUDIT" ]]; then
      echo "  🔴 Samuel guard: no audit-gate run found in iac/audit/dist/ within the last 15 minutes." >&2
      echo "     --real refused. Run pre-sync-gate.sh immediately before --real and confirm 🟢 PASS." >&2
      exit 11
    fi
    # Check 3: witness env vars
    WC="${S7_CEREMONY_WITNESS_COUNT:-0}"
    TP="${S7_CEREMONY_TONYA_PRESENT:-no}"
    SK="${S7_CEREMONY_SIGNING_KEY:-locked}"
    if [[ "$WC" -lt 4 || "$TP" != "yes" || "$SK" != "unlocked" ]]; then
      echo "  🔴 Samuel guard: witness chain not assembled." >&2
      echo "     S7_CEREMONY_WITNESS_COUNT = $WC (need ≥4)" >&2
      echo "     S7_CEREMONY_TONYA_PRESENT = $TP (need 'yes')" >&2
      echo "     S7_CEREMONY_SIGNING_KEY   = $SK (need 'unlocked')" >&2
      echo "     --real refused. Ready scripts are not authorization." >&2
      exit 12
    fi
    echo "  🟢 Samuel guard: all three checks passed. Proceeding with --real." >&2
    echo "     Core Update day: $TODAY_SG" >&2
    echo "     Recent audit:    $(basename "$RECENT_AUDIT")" >&2
    echo "     Witnesses:       count=$WC tonya=$TP signing=$SK" >&2
  fi
fi

STAGING="/tmp/s7-gold-reset"

# The 5 immutable-constellation repos, in the order of least-to-most
# covenant weight. Start with the documentation/wire layer, end with
# the kernel-of-kernel.
REPOS=(
  "SafeSecureLynX"     # wire protocol — minimal seed, least weight
  "immutable-S7-F44"   # bootc image lineage
  "immutable-assets"   # branding (Tonya-witnessed)
  "skyqubi-immutable"  # landing + manifests
  "immutable-qubi"     # kernel-of-kernel — highest weight, last
)

ORG="skycair-code"

# Track per-repo success/failure so the summary at the end tells
# the truth even when individual steps fail.
FAILED_REPOS=()
SUCCEEDED_REPOS=()

# run_or_echo: dry-run prints, real-run EXECUTES AND CHECKS EXIT CODE.
# Defense-in-depth redaction: any ghp_*, gho_*, ghu_*, ghs_*, ghr_*
# token-looking string in the command line OR the URL (oauth2:*@github)
# gets redacted before echo. The primary fix is to NEVER pass tokens
# via command-line args — this filter is the second witness.
redact_secrets() {
  sed -E \
    -e 's#oauth2:[^@[:space:]]+@github\.com#oauth2:REDACTED@github.com#g' \
    -e 's#gh[pousr]_[A-Za-z0-9]{36,}#ghX_REDACTED#g'
}
run_or_echo() {
  if $REAL_RUN; then
    echo "+ $*" | redact_secrets
    "$@"
    return $?
  else
    echo "[DRY] $*" | redact_secrets
    return 0
  fi
}

# safe_rm: rm -rf with path-prefix guard. Refuses to proceed if the
# target is empty, doesn't start with /tmp/, or contains shell
# metacharacters. Exit 3 on guard failure (irreversible, so hard fail).
safe_rm() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo "  🔴 safe_rm: refusing empty path"
    return 3
  fi
  if [[ "$target" != /tmp/s7-gold-* ]]; then
    echo "  🔴 safe_rm: refusing path outside /tmp/s7-gold-* ('$target')"
    return 3
  fi
  if [[ "$target" == *".."* || "$target" == *"*"* ]]; then
    echo "  🔴 safe_rm: refusing path with metacharacters ('$target')"
    return 3
  fi
  rm -rf -- "$target"
}

# ── Preflight — fail fast if the environment isn't ready ──────
# Runs ONLY on --real. Dry-run skips preflight so you can inspect
# the commands without loading credentials.
if $REAL_RUN; then
  echo
  echo "  ── Preflight ──"

  # Check 1: gh auth must be loaded and working. Use 'gh api user'
  # as the canonical 'does auth actually function' test instead of
  # parsing gh auth status output (which has a ✓ UTF-8 char that
  # breaks some grep locales and reports BOTH the working GH_TOKEN
  # account AND the broken keyring account with exit != 0).
  if ! gh api user --jq '.login' >/dev/null 2>&1; then
    echo
    echo "  🔴 FAIL: gh api user call failed — auth is not working."
    echo "     Run: export GH_TOKEN=\"\$(cat /s7/.config/s7/github-token)\""
    echo "     Then re-run this script."
    echo
    gh auth status 2>&1 | sed 's/^/     /'
    exit 1
  fi
  gh_user=$(gh api user --jq '.login' 2>/dev/null)
  echo "  ✓ gh auth works (as $gh_user)"

  # Check 2: every bundle exists
  for repo in "${REPOS[@]}"; do
    if [[ ! -f "$STAGING/${repo}.bundle" ]]; then
      echo
      echo "  🔴 FAIL: $STAGING/${repo}.bundle missing."
      echo "     Run: bash iac/immutable/reset-to-genesis.sh"
      exit 1
    fi
  done
  echo "  ✓ all 5 bundles present"

  # Check 3: HTTPS + credential-helper auth is ready. We use a git
  # credential helper fed by stdin, so the token NEVER appears in
  # a URL, a command-line arg, a log, or a git config file. The
  # GH_TOKEN env var must exist; it is used only as input to the
  # credential helper stdin, never as a positional arg.
  if [[ -z "${GH_TOKEN:-}" ]]; then
    echo
    echo "  🔴 FAIL: GH_TOKEN env var not set."
    echo "     Run: export GH_TOKEN=\"\$(cat /s7/.config/s7/github-token)\""
    echo "     Then re-run this script."
    exit 1
  fi
  if [[ "${GH_TOKEN}" != gh[pousr]_* ]]; then
    echo
    echo "  🔴 FAIL: GH_TOKEN does not look like a github PAT."
    echo "     Expected a prefix of ghp_, gho_, ghu_, ghs_, or ghr_."
    echo "     Got ${#GH_TOKEN} bytes starting with: ${GH_TOKEN:0:3}..."
    exit 1
  fi
  echo "  ✓ GH_TOKEN exported (${#GH_TOKEN} bytes, ${GH_TOKEN:0:4}...) — credential helper ready"
  echo
else
  echo
  echo "  ┌────────────────────────────────────────────────────┐"
  echo "  │  DRY RUN — no repository is being touched          │"
  echo "  │  Preflight skipped. Add --real to execute.         │"
  echo "  └────────────────────────────────────────────────────┘"
  echo
fi

for repo in "${REPOS[@]}"; do
  bundle="$STAGING/${repo}.bundle"
  if [[ ! -f "$bundle" ]]; then
    echo "  ✗ $repo: bundle missing at $bundle"
    FAILED_REPOS+=("$repo (bundle missing)")
    continue
  fi

  echo
  echo "  ── $repo ──"
  repo_failed=false

  # Step 1: Disable branch protection temporarily. This is allowed
  # to fail (404) because the branch may not exist yet, or protection
  # may not be configured. We swallow the error and continue.
  run_or_echo gh api -X DELETE "repos/$ORG/$repo/branches/main/protection/required_signatures" 2>/dev/null || true

  # Step 2: Clone the bundle into a temporary dir. git clone of a
  # bundle sets the new repo's 'origin' remote to point at the bundle
  # file, so we REPLACE origin with the clean HTTPS URL. Also need
  # explicit -b main because bundle HEAD is unclear.
  tmp="/tmp/s7-gold-push-$repo"
  run_or_echo safe_rm "$tmp" || { repo_failed=true; }

  if ! $repo_failed; then
    run_or_echo git clone -q -b main "$bundle" "$tmp" || { repo_failed=true; }
  fi

  # Replace origin with a CLEAN HTTPS URL — no token embedded.
  if ! $repo_failed; then
    run_or_echo git -C "$tmp" remote set-url origin "https://github.com/$ORG/$repo.git" || { repo_failed=true; }
  fi

  # Step 2.5: Push via stdin credential helper. The token is passed
  # on stdin to `git credential approve`, which caches it in git's
  # in-memory credential cache for 60 seconds. The push then picks
  # it up automatically. The token is NEVER in a URL, a command-line
  # arg, or a git config file on disk.
  if ! $repo_failed; then
    echo "+ git -C $tmp push --force origin main  (via credential cache)"
    if $REAL_RUN; then
      # Approve the credential silently (no echo).
      {
        printf 'protocol=https\n'
        printf 'host=github.com\n'
        printf 'username=oauth2\n'
        printf 'password=%s\n' "$GH_TOKEN"
        printf '\n'
      } | git -C "$tmp" \
          -c 'credential.helper=cache --timeout=60' \
          credential approve >/dev/null 2>&1

      if ! git -C "$tmp" \
          -c 'credential.helper=cache --timeout=60' \
          push --force origin main 2>&1 | redact_secrets
      then
        repo_failed=true
      fi

      # Revoke the credential from the cache as soon as push finishes.
      {
        printf 'protocol=https\n'
        printf 'host=github.com\n'
        printf 'username=oauth2\n'
        printf '\n'
      } | git -C "$tmp" \
          -c 'credential.helper=cache --timeout=60' \
          credential reject >/dev/null 2>&1 || true
    fi
  fi

  # Step 3: Re-enable required_signatures. Only run if the push
  # actually succeeded — we don't want to re-enable protection on
  # a repo we failed to push to.
  if ! $repo_failed; then
    run_or_echo gh api -X POST "repos/$ORG/$repo/branches/main/protection/required_signatures" || {
      echo "  ⚠ required_signatures re-enable failed — repo was pushed but protection may not be restored"
      repo_failed=true
    }
  fi

  # Step 4: Apply strict branch protection.
  if ! $repo_failed; then
    run_or_echo gh api -X PUT "repos/$ORG/$repo/branches/main/protection" \
      -f 'required_status_checks={"strict":true,"contexts":[]}' \
      -F enforce_admins=true \
      -f 'required_pull_request_reviews={"required_approving_review_count":1,"dismiss_stale_reviews":true,"require_code_owner_reviews":false}' \
      -f 'restrictions=null' \
      -F required_linear_history=true \
      -F allow_force_pushes=false \
      -F allow_deletions=false \
      -F required_conversation_resolution=true \
      -F lock_branch=false \
      -F allow_fork_syncing=false \
      || {
        echo "  ⚠ branch protection apply failed — repo was pushed but protection is incomplete"
        repo_failed=true
      }
  fi

  # Step 5: Cleanup the temp clone (always, even on failure, to
  # avoid leaving half-states in /tmp). safe_rm enforces the
  # /tmp/s7-gold-* prefix guard.
  run_or_echo safe_rm "$tmp" || true

  if $repo_failed; then
    echo "  ✗ $repo FAILED — see output above"
    FAILED_REPOS+=("$repo")
  else
    echo "  ✓ $repo advanced to v6-genesis"
    SUCCEEDED_REPOS+=("$repo")
  fi
done

echo
echo "  ── Summary ──"
if $REAL_RUN; then
  echo "  Succeeded: ${#SUCCEEDED_REPOS[@]} / ${#REPOS[@]}"
  for r in "${SUCCEEDED_REPOS[@]}"; do echo "    ✓ $r"; done
  if [[ ${#FAILED_REPOS[@]} -gt 0 ]]; then
    echo "  Failed:    ${#FAILED_REPOS[@]} / ${#REPOS[@]}"
    for r in "${FAILED_REPOS[@]}"; do echo "    ✗ $r"; done
    echo
    echo "  🔴 CEREMONY INCOMPLETE. Stop, investigate, do not re-run"
    echo "     until the failures are understood. The partial state is"
    echo "     visible: some repos may be advanced, others may not."
    exit 2
  fi
  echo
  echo "  🟢 All 5 immutable-constellation repos advanced to v6-genesis."
  echo "     Verify with: gh repo view $ORG/<repo> + git log on each."
  echo "     Update iac/audit/frozen-trees.txt pins from PENDING to"
  echo "     the commit sha that landed on each repo's main branch."
else
  echo "  [DRY RUN complete — add --real to execute]"
fi
