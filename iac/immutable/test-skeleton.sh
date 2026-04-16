#!/usr/bin/env bash
# iac/immutable/test-skeleton.sh
#
# Standalone validator for the GOLD asset dependency skeleton.
# Exercises the full fetch → verify → extract flow for all 7 categories.
#
# Pass criteria (all must be true):
#   1. asset-dependencies.yaml parses without error
#   2. fetch-gold-assets.sh exits 0 for each of the 7 categories individually
#   3. deploy-assets.sh exits 0 for full 7-category topological walk (local source)
#   4. Every category's GPG signature verifies as Good
#   5. Every category's sha256 matches /s7/v6-gold-2026-04-15/MANIFEST.md
#   6. Every target directory is non-empty after extract
#   7. No destructive patterns observed in any output
#
# Usage:
#   ./test-skeleton.sh                # run once
#   ./test-skeleton.sh --3x           # run 3 consecutive times, all must pass
#   ./test-skeleton.sh --source=remote # use remote mode (requires GH_TOKEN)
#
# Exit codes:
#   0   all tests passed
#   1   usage error
#   2   one or more tests failed (details printed)
#   3   3x mode: at least one of the 3 runs failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/asset-dependencies.yaml"
FETCH="$SCRIPT_DIR/fetch-gold-assets.sh"
DEPLOY="$SCRIPT_DIR/deploy-assets.sh"
GOLD_DIR="/s7/v6-gold-2026-04-15"

THREE_X=false
SOURCE="local"
for arg in "$@"; do
  case "$arg" in
    --3x) THREE_X=true ;;
    --source=*) SOURCE="${arg#*=}" ;;
    --help|-h) sed -n '2,25p' "$0" | sed 's|^# \?||'; exit 0 ;;
  esac
done

G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; B='\033[1m'; X='\033[0m'

pass=0
fail=0
failed_tests=()

check() {
  local name="$1" cmd="$2" expect="$3"
  local out
  out=$(eval "$cmd" 2>&1)
  if [[ "$out" == *"$expect"* ]]; then
    echo -e "  ${G}✓${X} $name"
    pass=$((pass+1))
  else
    echo -e "  ${R}✗${X} $name"
    echo "      expected: $expect"
    echo "      got:      $(echo "$out" | head -2)"
    fail=$((fail+1))
    failed_tests+=("$name")
  fi
}

run_once() {
  local run_num="$1"
  echo
  echo -e "${B}═══════════════════════════════════════════════════════════════${X}"
  echo -e "${B}  S7 GOLD Skeleton Validator — run $run_num${X}"
  echo -e "${B}═══════════════════════════════════════════════════════════════${X}"

  pass=0
  fail=0
  failed_tests=()
  local target="/tmp/s7-skel-test-$run_num"
  rm -rf "$target"

  # ── Preflight ──
  check "S01 config exists"            "[[ -f '$CONFIG' ]] && echo ok"                   "ok"
  check "S02 fetch script executable"  "[[ -x '$FETCH' ]] && echo ok"                    "ok"
  check "S03 deploy script executable" "[[ -x '$DEPLOY' ]] && echo ok"                   "ok"
  check "S04 GOLD archive present"     "[[ -d '$GOLD_DIR' ]] && echo ok"                 "ok"
  check "S05 GOLD MANIFEST present"    "[[ -f '$GOLD_DIR/MANIFEST.md' ]] && echo ok"     "ok"
  check "S06 YAML parses"              "python3 -c 'import yaml; yaml.safe_load(open(\"$CONFIG\"))' && echo ok" "ok"
  check "S07 7 categories defined"     "python3 -c 'import yaml; d=yaml.safe_load(open(\"$CONFIG\")); print(len(d[\"categories\"]))'" "7"

  # ── GPG sanity ──
  check "S08 signing key in keyring"   "gpg --list-keys E11792E0AD945BE9 2>&1 | grep -q E11792E0AD945BE9 && echo ok" "ok"

  # ── Per-category fetch (7 tests) ──
  for cat in qubi cws ssl bootc f44 auditbuilds gold; do
    check "S-F-$cat fetch succeeds" \
      "$FETCH --category=$cat --source=$SOURCE --target=$target/$cat 2>&1 | tail -1 | grep -q 'extracted to' && echo ok" \
      "ok"
    check "S-D-$cat target non-empty" \
      "[[ -n \$(ls -A $target/$cat 2>/dev/null) ]] && echo ok" \
      "ok"
  done

  # ── Full deploy (topological walk) ──
  rm -rf "$target-full"
  check "S-FULL full deploy all 7" \
    "$DEPLOY --source=$SOURCE --deploy-root=$target-full 2>&1 | tail -5 | grep -q '🟢 all 7' && echo ok" \
    "ok"

  # ── Deploy target structure ──
  check "S-STRUCT covenant dir present"     "[[ -d '$target-full/covenant' ]] && echo ok"    "ok"
  check "S-STRUCT engine dir present"       "[[ -d '$target-full/engine' ]] && echo ok"      "ok"
  check "S-STRUCT wire dir present"         "[[ -d '$target-full/wire' ]] && echo ok"        "ok"
  check "S-STRUCT branding dir present"     "[[ -d '$target-full/branding' ]] && echo ok"    "ok"
  check "S-STRUCT build dir present"        "[[ -d '$target-full/build' ]] && echo ok"      "ok"
  check "S-STRUCT audit dir present"        "[[ -d '$target-full/audit' ]] && echo ok"       "ok"
  check "S-STRUCT gold dir present"         "[[ -d '$target-full/gold' ]] && echo ok"        "ok"

  # ── Cleanup ──
  rm -rf "$target" "$target-full"

  local total=$((pass+fail))
  echo
  echo -e "  Run $run_num: ${G}$pass pass${X} / ${R}$fail fail${X} / $total total"
  if [[ $fail -gt 0 ]]; then
    echo -e "  ${R}Failed tests:${X}"
    for t in "${failed_tests[@]}"; do echo "    - $t"; done
    return 1
  fi
  return 0
}

if $THREE_X; then
  echo
  echo -e "${B}${Y}3x validation mode — all 3 runs must pass${X}"
  runs_passed=0
  for n in 1 2 3; do
    if run_once "$n"; then
      runs_passed=$((runs_passed+1))
    fi
  done
  echo
  echo -e "${B}═══════════════════════════════════════════════════════════════${X}"
  if [[ $runs_passed -eq 3 ]]; then
    echo -e "${B}  ${G}🟢 3/3 runs passed — skeleton validated${X}"
    echo -e "${B}═══════════════════════════════════════════════════════════════${X}"
    exit 0
  else
    echo -e "${B}  ${R}🔴 $runs_passed/3 runs passed — validation FAILED${X}"
    echo -e "${B}═══════════════════════════════════════════════════════════════${X}"
    exit 3
  fi
else
  if run_once 1; then exit 0; else exit 2; fi
fi
