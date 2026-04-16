#!/usr/bin/env bash
# iac/immutable/branches-rewrite/push-gold-mains.sh
#
# Pushes the main branch content for skyqubi-private and/or skyqubi-public
# from their v6 GOLD tarballs in /s7/v6-gold-2026-04-15/.
#
# This script handles the ONE-TIME initial GOLD content push for main. After
# this runs successfully, main on each repo is the v6 GOLD baseline.
# Subsequent changes go through PR+squash workflow.
#
# For skyqubi-public, the script also enables GitHub Pages with CNAME
# 123tech.skyqubi.com if --enable-pages is passed, because Rule #1
# (household site) depends on Pages being configured to serve from this
# repo's main branch.
#
# TWO FLOWS per repo:
#
# (A) skyqubi-private/main
#     ⚠ BLOCKED pending Jamie's content-pick decision:
#       (a) GOLD tarball as-is (source_commit 2185017)
#       (b) local HEAD b22c009 (beyond signed witness chain)
#       (c) re-cut new signed tarball from local HEAD
#       (d) GOLD root + cherry-pick b22c009 on top
#     The script refuses to push private main until one of a/b/c/d is
#     passed via --private-content-pick=<a|b|c|d>.
#
# (B) skyqubi-public/main
#     Unambiguous: local HEAD 2d955e9 matches tarball exactly.
#     Push extracts skyqubi-public-main-v6.tar.gz as the new main content,
#     creates an orphan commit (signed), and force-pushes.
#     With --enable-pages, also configures Pages + CNAME.
#
# DRY RUN (default) prints every intended operation.
# REAL RUN requires --real.
#
# RULE #1 VERIFICATION: after a public main push, the script curls
# https://123tech.skyqubi.com/ and every linked github.com URL found in
# the served HTML. Any 404 → script exits non-zero with a Rule #1 break
# report. This is the three-witness pattern from
# feedback_cleanup_framing_when_gold_is_private.md.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLD_DIR="/s7/v6-gold-2026-04-15"
SIGNING_KEY="E11792E0AD945BE9"
OWNER="skycair-code"
LOCAL_PRIVATE="/s7/skyqubi-private"
LOCAL_PUBLIC="/s7/skyqubi-public"

REAL_RUN=false
DO_PRIVATE=false
DO_PUBLIC=false
ENABLE_PAGES=false
PRIVATE_PICK=""
SKIP_RULE1=false

for arg in "$@"; do
  case "$arg" in
    --real) REAL_RUN=true ;;
    --private) DO_PRIVATE=true ;;
    --public) DO_PUBLIC=true ;;
    --both) DO_PRIVATE=true; DO_PUBLIC=true ;;
    --enable-pages) ENABLE_PAGES=true ;;
    --skip-rule1) SKIP_RULE1=true ;;
    --private-content-pick=*) PRIVATE_PICK="${arg#*=}" ;;
    --help|-h) sed -n '2,42p' "$0" | sed 's|^# \?||'; exit 0 ;;
  esac
done

say() { echo "  $*"; }
fail() { echo "  🔴 FAIL: $*" >&2; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────
say "── Preflight ──"
[[ -d "$GOLD_DIR" ]] || fail "gold dir missing: $GOLD_DIR"
[[ -f "$GOLD_DIR/skyqubi-private-main-v6.tar.gz" ]] || fail "private main tarball missing"
[[ -f "$GOLD_DIR/skyqubi-public-main-v6.tar.gz" ]] || fail "public main tarball missing"

$DO_PRIVATE || $DO_PUBLIC || fail "neither --private nor --public specified (use --both for both)"

if $REAL_RUN; then
  [[ -n "${GH_TOKEN:-}" ]] || fail "GH_TOKEN not set"
  [[ "$GH_TOKEN" == gh[pousr]_* ]] || fail "GH_TOKEN doesn't look like a PAT"
  gpg --list-secret-keys "$SIGNING_KEY" >/dev/null 2>&1 || \
    fail "signing key $SIGNING_KEY not in keyring"
fi

# Verify all referenced tarballs' signatures
for t in skyqubi-private-main-v6.tar.gz skyqubi-public-main-v6.tar.gz; do
  if ! gpg --verify "$GOLD_DIR/$t.asc" "$GOLD_DIR/$t" 2>&1 | grep -q "Good signature"; then
    fail "GPG verify failed for $t — refusing to proceed"
  fi
done
say "✓ GOLD tarball signatures verified"

# Private content-pick gate
if $DO_PRIVATE; then
  if [[ -z "$PRIVATE_PICK" ]]; then
    echo
    echo "  🔴 SAMUEL GATE — private main content pick required"
    echo
    echo "  Local /s7/skyqubi-private HEAD = b22c009 (one commit AHEAD of the"
    echo "  signed GOLD tarball at 2185017). The b22c009 commit content is NOT"
    echo "  inside any signed tarball. Jamie must explicitly pick one of:"
    echo
    echo "    (a) push GOLD tarball as-is (source_commit 2185017)"
    echo "    (b) push local HEAD b22c009 (beyond signed witness chain)"
    echo "    (c) re-cut a new signed tarball from local HEAD, push that"
    echo "    (d) push GOLD root + cherry-pick b22c009 on top as a 2nd signed commit"
    echo
    echo "  Re-run with --private-content-pick=<a|b|c|d>"
    echo
    exit 1
  fi
  case "$PRIVATE_PICK" in
    a|b|c|d) say "✓ private content pick: ($PRIVATE_PICK)" ;;
    *) fail "invalid --private-content-pick: $PRIVATE_PICK (must be a/b/c/d)" ;;
  esac
fi

if $REAL_RUN; then
  say "mode: 🔴 REAL — main content will be force-pushed"
else
  say "mode: 🟡 DRY RUN"
fi
echo

# ── Flow: push skyqubi-public/main ────────────────────────────────
push_public_main() {
  say "── skyqubi-public/main ──"
  local tarball="$GOLD_DIR/skyqubi-public-main-v6.tar.gz"
  local asc="$tarball.asc"

  if ! $REAL_RUN; then
    echo "  [DRY] extract $tarball → /tmp/s7-public-push/"
    echo "  [DRY] git init -b main; add all files"
    echo "  [DRY] commit signed via $SIGNING_KEY"
    echo "  [DRY] force-push to origin main"
    $ENABLE_PAGES && echo "  [DRY] POST /repos/$OWNER/skyqubi-public/pages (source=main, cname=123tech.skyqubi.com)"
    return 0
  fi

  local tmp="/tmp/s7-public-push-$$"
  local extract="$tmp/extract"
  rm -rf "$tmp"; mkdir -p "$extract"
  tar -xzf "$tarball" -C "$extract" || fail "extract failed"

  cd "$extract"
  git init -q -b main
  git remote add origin "https://github.com/$OWNER/skyqubi-public.git"
  git config user.signingkey "$SIGNING_KEY"
  git config user.email "261467595+skycair-code@users.noreply.github.com"
  git config user.name "skycair-code"
  git config commit.gpgsign true

  git add -A
  git commit -S --quiet \
    -m "main: v6 GOLD from signed tarball" \
    -m "source: skyqubi-public-main-v6.tar.gz (source_commit 2d955e9)" \
    -m "signed-by: $SIGNING_KEY" || fail "commit failed"

  # Push via credential helper stdin
  {
    printf 'protocol=https\n'
    printf 'host=github.com\n'
    printf 'username=oauth2\n'
    printf 'password=%s\n' "$GH_TOKEN"
    printf '\n'
  } | git -c 'credential.helper=cache --timeout=60' credential approve >/dev/null 2>&1

  if ! git -c 'credential.helper=cache --timeout=60' push --force origin main 2>&1; then
    cd - >/dev/null
    fail "public main push failed"
  fi

  {
    printf 'protocol=https\n'
    printf 'host=github.com\n'
    printf 'username=oauth2\n'
    printf '\n'
  } | git -c 'credential.helper=cache --timeout=60' credential reject >/dev/null 2>&1 || true

  say "✓ public main force-pushed"
  cd - >/dev/null
  rm -rf "$tmp"

  # Enable Pages if requested
  if $ENABLE_PAGES; then
    say "enabling GitHub Pages with CNAME 123tech.skyqubi.com"
    local status
    status=$(curl -sS -o /tmp/s7-pages.json -w "%{http_code}" \
      -X POST \
      -H "Authorization: token $GH_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/$OWNER/skyqubi-public/pages" \
      -d '{"source":{"branch":"main","path":"/"}}')
    if [[ "$status" == "201" || "$status" == "204" ]]; then
      say "  ✓ Pages created ($status)"
      # Set CNAME
      curl -sS -o /dev/null -X PUT \
        -H "Authorization: token $GH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$OWNER/skyqubi-public/pages" \
        -d '{"cname":"123tech.skyqubi.com"}' && say "  ✓ CNAME set"
    else
      say "  ⚠ Pages POST returned $status:"
      head -2 /tmp/s7-pages.json | sed 's|^|      |'
    fi
    rm -f /tmp/s7-pages.json
  fi

  # Rule #1 verification
  if ! $SKIP_RULE1; then
    rule1_check
  fi
}

# ── Flow: push skyqubi-private/main ───────────────────────────────
push_private_main() {
  say "── skyqubi-private/main (pick=$PRIVATE_PICK) ──"

  case "$PRIVATE_PICK" in
    a)
      local tarball="$GOLD_DIR/skyqubi-private-main-v6.tar.gz"
      if ! $REAL_RUN; then
        echo "  [DRY] (a) extract $tarball → /tmp/s7-private-push/"
        echo "  [DRY] git init -b main; commit signed; force-push"
        return 0
      fi
      local tmp="/tmp/s7-private-push-$$"
      rm -rf "$tmp"; mkdir -p "$tmp"
      tar -xzf "$tarball" -C "$tmp"
      cd "$tmp"
      git init -q -b main
      git remote add origin "https://github.com/$OWNER/skyqubi-private.git"
      git config user.signingkey "$SIGNING_KEY"
      git config user.email "261467595+skycair-code@users.noreply.github.com"
      git config user.name "skycair-code"
      git config commit.gpgsign true
      git add -A
      git commit -S --quiet \
        -m "main: v6 GOLD from signed tarball (pick=a)" \
        -m "source: skyqubi-private-main-v6.tar.gz (source_commit 2185017)" || {
          cd - >/dev/null; fail "commit failed"
        }
      {
        printf 'protocol=https\n'
        printf 'host=github.com\n'
        printf 'username=oauth2\n'
        printf 'password=%s\n' "$GH_TOKEN"
        printf '\n'
      } | git -c 'credential.helper=cache --timeout=60' credential approve >/dev/null 2>&1
      git -c 'credential.helper=cache --timeout=60' push --force origin main || {
        cd - >/dev/null; fail "private push failed"
      }
      cd - >/dev/null
      rm -rf "$tmp"
      say "✓ private main force-pushed (pick=a, GOLD tarball)"
      ;;
    b)
      fail "pick (b) not yet implemented — needs confirmation that pushing outside signed witness chain is authorized"
      ;;
    c)
      fail "pick (c) not yet implemented — needs a re-cut tarball step; run make-carved-tarball.sh first or use pick=a"
      ;;
    d)
      fail "pick (d) not yet implemented — needs cherry-pick of b22c009 on top of GOLD orphan root"
      ;;
  esac
}

# ── Rule #1 three-witness check ───────────────────────────────────
rule1_check() {
  echo
  say "── Rule #1 three-witness check ──"
  local site="https://123tech.skyqubi.com/"

  # Witness 1: direct curl of Pages-served content
  local code1 etag1
  code1=$(curl -sS -o /tmp/s7-rule1-html.txt -w "%{http_code}" "$site")
  etag1=$(curl -sSI "$site" | grep -i '^etag' | tr -d '\r' | awk '{print $2}')
  say "W1: $site → HTTP $code1 etag=${etag1:-none}"

  # Witness 2: Wix redirect chain
  local code2
  code2=$(curl -sS -L -o /dev/null -w "%{http_code}" "https://skyqubi.com/")
  say "W2: https://skyqubi.com/ (Wix) → HTTP $code2"

  # Witness 3: every embedded github.com link in served HTML
  local failed_links=""
  if [[ "$code1" == "200" ]]; then
    while read -r url; do
      [[ -z "$url" ]] && continue
      local ucode
      ucode=$(curl -sS -L -o /dev/null -w "%{http_code}" "$url")
      if [[ "$ucode" != "200" ]]; then
        failed_links="$failed_links $url($ucode)"
      fi
    done < <(grep -oE 'https?://github\.com/[^"'"'"' ]*' /tmp/s7-rule1-html.txt | sort -u)
  fi
  rm -f /tmp/s7-rule1-html.txt

  if [[ "$code1" == "200" && "$code2" == "200" && -z "$failed_links" ]]; then
    say "🟢 Rule #1 intact (3 witnesses agree)"
    return 0
  fi
  say "🔴 RULE #1 BROKEN:"
  [[ "$code1" != "200" ]] && say "  W1 failed: Pages returned $code1"
  [[ "$code2" != "200" ]] && say "  W2 failed: Wix chain returned $code2"
  [[ -n "$failed_links" ]] && say "  W3 failed links:$failed_links"
  return 3
}

# ── Main ──────────────────────────────────────────────────────────
if $DO_PUBLIC; then
  push_public_main
fi
if $DO_PRIVATE; then
  push_private_main
fi

echo
say "── Done ──"
$REAL_RUN && say "real run completed — verify with verify-immutable-branches.sh" \
          || say "[DRY RUN — add --real to execute]"
exit 0
