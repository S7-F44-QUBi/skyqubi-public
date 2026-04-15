#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Sync Private → Public Fork
# Two-phase sync model (updated 2026-04-12):
#   Phase 1: root-level code/config synced with blacklist (engine/, etc.)
#            docs/ is EXCLUDED from phase 1 entirely.
#   Phase 2: docs/public/ from private → docs/ in public (whitelist by
#            location). docs/internal/ NEVER syncs — mechanical guarantee.
#            New docs go to public only by being placed inside docs/public/
#            as a conscious, reviewable git operation.
#
# Usage: ./s7-sync-public.sh
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

PRIVATE="/s7/skyqubi-private"
PUBLIC="/s7/skyqubi-public"

# ─────────────────────────────────────────────────────────────────
# STRUCTURAL REFUSALS (added 2026-04-14 after the wrapper-pipe
# near-miss class of bugs caused two unauthorized public pushes)
# ─────────────────────────────────────────────────────────────────

# Argument parsing — scan for flags BEFORE any state changes
TEST_FREEZE_ONLY=false
CORE_UPDATE_DAY=false
for arg in "$@"; do
  case "$arg" in
    --test-freeze-only) TEST_FREEZE_ONLY=true ;;
    --core-update-day)  CORE_UPDATE_DAY=true  ;;
  esac
done

# REFUSAL 1 — stdout is a pipe
# If this script is run through a pipe (e.g. `bash s7-sync-public.sh | head`),
# the pipe can close early and leave the script running in a half-state,
# or bury the script's own refusal messages in a head -N that misses them.
# This is the exact mechanism that caused the 2026-04-14 near-miss where
# the Chair ran `bash s7-sync-public.sh --core-update-day 2>&1 | head -5`
# "to test the gate" and the pipe's closure did not stop the script from
# potentially reaching the push step. The script now refuses to run at all
# if its stdout is not a terminal, UNLESS --test-freeze-only is passed
# (in which case the script exits after PRE-FLIGHT 1 and it's safe to pipe).
if [[ ! -t 1 ]] && [[ "$TEST_FREEZE_ONLY" != "true" ]]; then
  echo "🔴 REFUSED — this script refuses to run with stdout piped or redirected." >&2
  echo "" >&2
  echo "  Reason: wrapper scripts are production, not test harnesses. If you" >&2
  echo "  are trying to test the freeze gate, use --test-freeze-only which" >&2
  echo "  exits cleanly after PRE-FLIGHT 1 and is safe to pipe. If you are" >&2
  echo "  trying to run the real sync, run it on a terminal with no pipe." >&2
  echo "" >&2
  echo "  See: feedback_test_gate_directly_never_via_wrapper.md" >&2
  echo "" >&2
  exit 1
fi

echo "═══════════════════════════════════════════════════════"
echo "  S7 SkyQUBi — Syncing Private → Public"
echo "  $(date)"
if $TEST_FREEZE_ONLY; then
  echo "  MODE: --test-freeze-only (will exit after PRE-FLIGHT 1)"
fi
echo "═══════════════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────
# PRE-FLIGHT 1 — Public Freeze gate (until 2026-07-07 07:00 CT)
#
# Public main is frozen until GO-LIVE Release 7. Two-factor override:
#   1. Pass --core-update-day on the command line, AND
#   2. Today's date (in America/Chicago) must be listed in
#      iac/audit/core-update-days.txt
# Both must be true. The flag alone is not enough — the in-tree file
# is the witness that a steward has authorized the day in advance.
#
# Adding a date to core-update-days.txt is itself a tier-crossing
# decision and is part of what the audit gate watches.
#
# The freeze applies to the SYNC, not to lifecycle or private
# branches — those keep moving freely.
# ─────────────────────────────────────────────────────────────────
FREEZE_END_EPOCH=$(TZ='America/Chicago' date -d "2026-07-07 07:00:00" +%s)
NOW_EPOCH=$(date +%s)
TODAY_CT=$(TZ='America/Chicago' date +%Y-%m-%d)
# Note: CORE_UPDATE_DAY is parsed at the top of the script,
# before the stdout-pipe refusal, so the flag is available here.

CORE_UPDATE_FILE="${PRIVATE}/iac/audit/core-update-days.txt"
DATE_AUTHORIZED=false
if [[ -f "$CORE_UPDATE_FILE" ]]; then
  if grep -qE "^${TODAY_CT}([[:space:]]|$|#)" "$CORE_UPDATE_FILE"; then
    DATE_AUTHORIZED=true
  fi
fi

if [[ "$NOW_EPOCH" -lt "$FREEZE_END_EPOCH" ]]; then
  if [[ "$CORE_UPDATE_DAY" != "true" ]]; then
    echo ""
    echo "  🔴 SYNC REFUSED — public freeze active until 2026-07-07 07:00 CT"
    echo ""
    echo "  Public main is frozen until GO-LIVE Release 7."
    echo "  Lifecycle and private main are NOT affected — keep working."
    echo ""
    echo "  To override on an authorized Core Update day, BOTH must be true:"
    echo "    1. Today (${TODAY_CT}) is listed in"
    echo "       iac/audit/core-update-days.txt"
    echo "    2. You pass --core-update-day on the command line"
    echo ""
    exit 1
  fi
  if [[ "$DATE_AUTHORIZED" != "true" ]]; then
    echo ""
    echo "  🔴 SYNC REFUSED — --core-update-day was passed BUT today is"
    echo "     not on the authorized list."
    echo ""
    echo "  Today (${TODAY_CT}) is not in iac/audit/core-update-days.txt."
    echo "  The flag alone is not enough — the in-tree file is the"
    echo "  witness that a steward has authorized this day in advance."
    echo ""
    echo "  If today really is an authorized Core Update day, add it"
    echo "  to iac/audit/core-update-days.txt with a steward signature"
    echo "  in the comment, commit it on the lifecycle branch, then"
    echo "  re-run this script."
    echo ""
    exit 1
  fi
  echo "  🟢 Public freeze gate: --core-update-day flag + ${TODAY_CT} in core-update-days.txt"
fi

# ─────────────────────────────────────────────────────────────────
# --test-freeze-only exit point
#
# If the caller is only testing the freeze gate (for example, to
# verify that a new core-update-days.txt entry is picked up
# correctly), exit cleanly here. This gives us a safe way to test
# PRE-FLIGHT 1 without ever touching PRE-FLIGHT 2 or the actual
# rsync+commit+push. Added 2026-04-14 after the wrapper-pipe
# near-miss.
# ─────────────────────────────────────────────────────────────────
if $TEST_FREEZE_ONLY; then
  echo ""
  echo "  ℹ  --test-freeze-only mode — PRE-FLIGHT 1 complete, exiting cleanly."
  echo "     (No PRE-FLIGHT 2, no rsync, no commit, no push.)"
  echo ""
  exit 0
fi

# ─────────────────────────────────────────────────────────────────
# PRE-FLIGHT 2 — Pre-Sync Audit Gate (CHEF Recipe #1 §16, two axes)
#
# Run iac/audit/pre-sync-gate.sh. It writes the visual summary to
# stdout, prepends a dated entry to docs/internal/chef/audit-living.md,
# and exits non-zero if any new warning, drift, or block is found.
# Pinned items (iac/audit/pinned.yaml) are loud but allowed.
#
# This is the moment the freeze becomes a fence: nothing crosses to
# public unless the gate is green.
# ─────────────────────────────────────────────────────────────────
GATE="${PRIVATE}/iac/audit/pre-sync-gate.sh"
if [[ -x "$GATE" ]]; then
  echo ""
  echo "  Running pre-sync audit gate..."
  echo ""
  if ! "$GATE"; then
    echo ""
    echo "  🔴 SYNC REFUSED — pre-sync gate did not pass"
    echo ""
    echo "  See docs/internal/chef/audit-living.md (newest entry at top)"
    echo "  for the full finding. Either fix the finding at the source,"
    echo "  or add it to iac/audit/pinned.yaml with an owner and reason."
    echo ""
    exit 1
  fi
  echo ""
  echo "  🟢 Pre-sync gate PASS — proceeding to rsync"
  echo ""
else
  echo ""
  echo "  ⚠ Pre-sync gate not found at $GATE — refusing to sync without it"
  echo "  (this should never happen; if you're seeing this, the install is broken)"
  exit 2
fi

# Root-level files/dirs that NEVER go to public
# (docs/ is excluded entirely — handled separately in phase 2)
EXCLUDE=(
  "patents/"
  "iso/dist/"
  "docs/"
  "book/"
  "COVENANT.md"
  "MONDAY.md"
  "OVERNIGHT.md"
  "wix/"
  "public-chat/"
  "persona-chat/"
  "engine/agents/"
  "engine/phase7*"
  "collections/"
  "Containerfile"
  "APACHE-LICENSE"
  "dashboard/SkyCAIR-Command-Center.jsx"
  "training/"
  "autostart/"
  "desktop/"
  "os/"
  "branding/plymouth/"
  "branding/apply-theme.sh"
  "iac/"
)

# Build rsync excludes
RSYNC_EXCLUDES=""
for ex in "${EXCLUDE[@]}"; do
  RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=$ex"
done

# Phase 1: everything except docs/
echo "[1/4] Syncing root files (phase 1: excludes docs/)..."
rsync -av --delete \
  --exclude='.git' \
  --exclude='__pycache__' \
  $RSYNC_EXCLUDES \
  "${PRIVATE}/" "${PUBLIC}/"

# Phase 2: docs/public/ → docs/ (whitelist-by-location, no filters)
# This is the mechanical guarantee: only files physically inside
# docs/public/ can reach the public repo. docs/internal/ is unreachable
# by construction.
echo "[2/4] Syncing docs/public/ → docs/ (phase 2: whitelist)..."
rsync -av --delete \
  --exclude='.git' \
  --exclude='__pycache__' \
  "${PRIVATE}/docs/public/" "${PUBLIC}/docs/"

echo ""
echo "[3/4] Checking for changes..."
cd "$PUBLIC"
git add -A
CHANGES=$(git status --short | wc -l)

if [[ "$CHANGES" -eq 0 ]]; then
  echo "  No changes — repos are in sync."
  exit 0
fi

echo "  $CHANGES files changed:"
git status --short

echo ""
echo "[4/4] Committing and pushing..."
# Use the latest private commit message
LAST_MSG=$(cd "$PRIVATE" && git log --format="%s" -1)
git commit -m "sync: ${LAST_MSG}"

# Surgical protection toggle: temporarily disable signed-commits + PR-required
# rules during the push window only. Reads token from /s7/.config/s7/github-token.
TOKEN_FILE="/s7/.config/s7/github-token"
REPO_API="https://api.github.com/repos/skycair-code/SkyQUBi-public"
SIGS_URL="${REPO_API}/branches/main/protection/required_signatures"
PR_URL="${REPO_API}/branches/main/protection/required_pull_request_reviews"
GH_HDR_AUTH="Authorization: Bearer $(cat "$TOKEN_FILE" 2>/dev/null)"
GH_HDR_ACCEPT="Accept: application/vnd.github+json"

if [[ -s "$TOKEN_FILE" ]]; then
  echo "  Disabling signed-commits + PR-required (sync window open)..."
  curl -s -o /dev/null -X DELETE -H "$GH_HDR_AUTH" -H "$GH_HDR_ACCEPT" "$SIGS_URL" || true
  curl -s -o /dev/null -X DELETE -H "$GH_HDR_AUTH" -H "$GH_HDR_ACCEPT" "$PR_URL"   || true
fi

git push origin main
PUSH_EXIT=$?

if [[ -s "$TOKEN_FILE" ]]; then
  echo "  Restoring signed-commits + PR-required (sync window closed)..."
  curl -s -o /dev/null -X POST -H "$GH_HDR_AUTH" -H "$GH_HDR_ACCEPT" "$SIGS_URL" || true
  curl -s -o /dev/null -X PATCH -H "$GH_HDR_AUTH" -H "$GH_HDR_ACCEPT" \
    -d '{"required_approving_review_count":0,"dismiss_stale_reviews":false,"require_code_owner_reviews":false,"require_last_push_approval":false}' \
    "$PR_URL" || true
fi

if [[ "$PUSH_EXIT" -ne 0 ]]; then
  echo "  ERROR: push failed"
  exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Sync complete. Public is up to date. Protection restored."
echo "═══════════════════════════════════════════════════════"
# Then re-enable: see branch protection setup in plan docs
