#!/usr/bin/env bash
# iac/audit/tonya-digest.sh
#
# The household-facing projection of the Living Audit Document.
# Reads the newest entry from docs/internal/chef/audit-living.md and
# prints a one-screen summary in plain language — Jamie's voice, no
# terminal jargon, no stack traces.
#
# This is the surface Tonya, Trinity, Jonathan, and Noah see. It does
# not run the audit — it reads the audit's witness trail. Run the
# pre-sync gate FIRST to make sure the trail is current.
#
# Usage:
#   ./tonya-digest.sh           # plain text, one screen
#   ./tonya-digest.sh --html    # HTML for the persona-chat surface

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIVING_DOC="$REPO_DIR/docs/internal/chef/audit-living.md"
DIST_DIR="$REPO_DIR/iac/audit/dist"
HTML=false

for arg in "$@"; do
  case "$arg" in
    --html) HTML=true ;;
  esac
done

if [[ ! -f "$LIVING_DOC" ]]; then
  echo "  No audit on file yet. Ask Jamie or Samuel to run a check."
  exit 1
fi

# Read the newest entry — it's the first ## block after the --- header
# Use a small awk to extract the first ## block
ENTRY=$(awk '
  /^## / { in_block++; if (in_block == 2) exit }
  in_block >= 1 { print }
' "$LIVING_DOC")

# Pull counts from the table row "| count | N | N | N | N |"
COUNTS_LINE=$(echo "$ENTRY" | grep -E '^\| count' | head -1)
PASS=$(echo "$COUNTS_LINE"   | awk -F'|' '{gsub(/ /, "", $3); print $3}')
PINNED=$(echo "$COUNTS_LINE" | awk -F'|' '{gsub(/ /, "", $4); print $4}')
WARN=$(echo "$COUNTS_LINE"   | awk -F'|' '{gsub(/ /, "", $5); print $5}')
BLOCK=$(echo "$COUNTS_LINE"  | awk -F'|' '{gsub(/ /, "", $6); print $6}')

# Pull the timestamp + verdict from the first ## line
HEADER=$(echo "$ENTRY" | head -1)
TS=$(echo "$HEADER" | sed -E 's/^## ([^ ]+) — verdict:.*/\1/')
VERDICT=$(echo "$HEADER" | sed -E 's/.*verdict: ([A-Z]+).*/\1/')

# Plain-language sentence in Jamie's voice
case "$VERDICT" in
  PASS)
    if [[ "$PINNED" == "0" ]]; then
      MOOD="The household is clean."
      DETAIL="Nothing on the watch list. Nothing waiting on a steward. Quiet day, in the good way."
    else
      MOOD="The household is clean today."
      DETAIL="There are $PINNED older items still on the list — they're known, they're written down, and a steward will look at them on the next Core Update day. Nothing new came up. Nothing for Tonya to do tonight."
    fi
    ;;
  WARNING)
    MOOD="Something new came up."
    DETAIL="$WARN new finding(s) need a steward to look. The build is still running fine, but a sync to the public side is paused until Trinity or Jonathan signs."
    ;;
  BLOCK)
    MOOD="Sync is held."
    DETAIL="$BLOCK hard finding(s) — the audit refuses to let anything cross to the public side until they're fixed at the source. This is the gate doing its job."
    ;;
esac

if $HTML; then
  STATUS_COLOR="#3a7d44"
  STATUS_ICON="🟢"
  case "$VERDICT" in
    WARNING) STATUS_COLOR="#c9a227"; STATUS_ICON="🟡" ;;
    BLOCK)   STATUS_COLOR="#a83232"; STATUS_ICON="🔴" ;;
  esac
  cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>S7 SkyQUB·i — Household Audit Digest</title>
<link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,600;1,400;1,600&family=Lora:wght@400;500&display=swap" rel="stylesheet">
<style>
  :root {
    --void: #1a0f1c; --deep: #261624; --surface: #301a27;
    --raised: #3d2232; --border: #6b3f4f;
    --text: #faebd4; --text-soft: #f0e1cf;
    --status: ${STATUS_COLOR};
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 2rem;
    background: var(--void); color: var(--text);
    font-family: 'Lora', Georgia, serif;
    font-size: 18px; line-height: 1.6;
    min-height: 100vh;
  }
  .card {
    max-width: 640px; margin: 2rem auto;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 12px; padding: 2rem;
  }
  h1 {
    font-family: 'Cormorant Garamond', serif;
    font-style: italic; font-weight: 600;
    font-size: 2.4rem; margin: 0 0 .5rem 0;
    color: var(--text);
  }
  .ts { color: var(--text-soft); opacity: .7; font-size: .85rem; }
  .status {
    display: inline-block; margin: 1.5rem 0 .5rem 0;
    padding: .4rem 1rem; border-radius: 999px;
    background: var(--status); color: #fff;
    font-weight: 600; font-size: 1rem;
  }
  .mood { font-size: 1.4rem; margin: 1rem 0 .5rem 0; }
  .detail { color: var(--text-soft); margin: 0 0 1.5rem 0; }
  .counts {
    display: grid; grid-template-columns: repeat(4, 1fr);
    gap: .5rem; margin-top: 1rem;
  }
  .count {
    background: var(--raised); border: 1px solid var(--border);
    border-radius: 8px; padding: .8rem; text-align: center;
  }
  .count .n { font-size: 1.6rem; font-weight: 600; }
  .count .l { font-size: .75rem; opacity: .7; text-transform: uppercase; }
  .footer {
    margin-top: 2rem; padding-top: 1rem;
    border-top: 1px solid var(--border);
    font-size: .85rem; color: var(--text-soft); opacity: .7;
  }
</style>
</head>
<body>
  <div class="card">
    <h1>The household, today</h1>
    <div class="ts">${TS}</div>
    <div class="status">${STATUS_ICON} ${VERDICT}</div>
    <div class="mood">${MOOD}</div>
    <p class="detail">${DETAIL}</p>
    <div class="counts">
      <div class="count"><div class="n">${PASS}</div><div class="l">clean</div></div>
      <div class="count"><div class="n">${PINNED}</div><div class="l">on the list</div></div>
      <div class="count"><div class="n">${WARN}</div><div class="l">new</div></div>
      <div class="count"><div class="n">${BLOCK}</div><div class="l">held</div></div>
    </div>
    <div class="footer">
      Love is the architecture. Read the full audit any time —
      Samuel keeps the long version in the binder.
    </div>
  </div>
</body>
</html>
EOF
else
  cat <<EOF

  ═══════════════════════════════════════════════════════
    The household, today
    ${TS}
  ═══════════════════════════════════════════════════════

    ${VERDICT}

    ${MOOD}
    ${DETAIL}

    Clean: ${PASS}      On the list: ${PINNED}      New: ${WARN}      Held: ${BLOCK}

  ═══════════════════════════════════════════════════════
    Love is the architecture. Samuel keeps the long
    version in the binder if anyone wants to read it.
  ═══════════════════════════════════════════════════════

EOF
fi
