#!/usr/bin/env bash
# s7-paper-watch.sh
# ═══════════════════════════════════════════════════════════════════
# Watch Hugging Face daily papers for research relevant to S7 SkyQUBi:
# sovereignty, consensus, BitNet, witness ensembles, circuit breakers,
# hallucination detection, offline inference, ternary quantization.
#
# Output: NDJSON, one paper per line. Designed to be cron-runnable
# and email/Slack-pipeable — only emits papers matching at least one
# S7 keyword.
#
# Usage:
#   ./s7-paper-watch.sh                # default: last 3 days, all keywords
#   ./s7-paper-watch.sh --days 7       # last 7 days
#   ./s7-paper-watch.sh --pretty       # human-readable
#   ./s7-paper-watch.sh --json         # single JSON array (for APIs)
#
# Env:
#   HF_TOKEN   optional
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,20p' "$0" | sed 's|^# \?||'
  exit 0
fi

DAYS=3
PRETTY=false
JSON_ARRAY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)  DAYS="$2"; shift 2 ;;
    --pretty) PRETTY=true; shift ;;
    --json)   JSON_ARRAY=true; shift ;;
    *) shift ;;
  esac
done

AUTH=()
if [[ -n "${HF_TOKEN:-}" ]]; then
  AUTH=(-H "Authorization: Bearer ${HF_TOKEN}")
fi

# S7-relevant keywords. Case-insensitive, compiled into one regex.
# Keep this list in sync with project_octi_witness_set.md + CWS vocabulary.
KEYWORDS='bitnet|1-?bit|1\.58|ternary|sovereign|offline|consensus|ensemble|witness|babel|circuit.?breaker|hallucin|covenant|discernment|retrieval.?aug|retrieval|quantiz|akashic|local.?llm|on.?device|trust.?threshold'

OUT=$(mktemp)
trap "rm -f $OUT" EXIT

# Cutoff timestamp in ISO-8601
CUTOFF=$(date -u -d "$DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ")

curl -sSL --max-time 15 "${AUTH[@]}" "https://huggingface.co/api/daily_papers?limit=100" 2>/dev/null \
  | jq -c --arg cutoff "$CUTOFF" --arg kw "$KEYWORDS" '
    .[]? | select(.publishedAt >= $cutoff) |
    . as $p |
    ($p.title + " " + ($p.paper.summary // "")) as $corpus |
    select($corpus | test($kw; "i")) |
    {
      title: $p.title,
      paper: $p.paper.id,
      url: ("https://huggingface.co/papers/" + $p.paper.id),
      publishedAt: $p.publishedAt,
      upvotes: ($p.paper.upvotes // 0),
      matched_keywords: (
        [$corpus | scan("(?i)(" + $kw + ")")] | flatten | map(ascii_downcase) | unique
      )
    }
  ' > "$OUT"

if $PRETTY; then
  rows=$(wc -l < "$OUT")
  echo "S7 paper-watch — matched $rows papers in last $DAYS days"
  echo "---"
  jq -r '"\(.publishedAt[:10])  ▲\(.upvotes)  \(.title[0:72])\n           \(.url)\n           keywords: \((.matched_keywords // []) | join(", "))\n"' < "$OUT"
elif $JSON_ARRAY; then
  jq -s '.' < "$OUT"
else
  cat "$OUT"
fi
