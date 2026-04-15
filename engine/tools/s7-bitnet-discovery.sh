#!/usr/bin/env bash
# s7-bitnet-discovery.sh
# ═══════════════════════════════════════════════════════════════════
# Discover 1-bit / BitNet / ternary-quantized models on the Hugging
# Face Hub suitable for SkyQUANTi's dual-path benchmark (standard vs
# sovereign ternary inference).
#
# Ranks by downloads within results, filters for models actually
# tagged "bitnet" or carrying the "1-bit"/"ternary" signal.
#
# Output: NDJSON, one model per line.
#
# Usage:
#   ./s7-bitnet-discovery.sh                 # top 20 by downloads
#   ./s7-bitnet-discovery.sh --limit 50      # top 50
#   ./s7-bitnet-discovery.sh --pretty        # human-readable table
#   ./s7-bitnet-discovery.sh | jq -s 'sort_by(.downloads) | reverse | .[0:5]'
#
# Env:
#   HF_TOKEN   optional — higher rate limits
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,22p' "$0" | sed 's|^# \?||'
  exit 0
fi

LIMIT=20
PRETTY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) LIMIT="$2"; shift 2 ;;
    --pretty) PRETTY=true; shift ;;
    *) shift ;;
  esac
done

AUTH=()
if [[ -n "${HF_TOKEN:-}" ]]; then
  AUTH=(-H "Authorization: Bearer ${HF_TOKEN}")
fi

# Query HF for models tagged with bitnet or mentioning 1-bit/ternary in
# the search index. The /api/models endpoint supports `search` and `filter`.
query() {
  local term="$1"
  curl -sSL --max-time 10 "${AUTH[@]}" \
    "https://huggingface.co/api/models?search=${term}&limit=${LIMIT}&sort=downloads&direction=-1" 2>/dev/null
}

# Aggregate results from multiple search terms, dedupe by id
OUT=$(mktemp)
trap "rm -f $OUT" EXIT

{
  query "bitnet"
  query "1.58-bit"
  query "ternary"
} | jq -c '.[]? | {id: (.id // .modelId), downloads: (.downloads // 0), likes: (.likes // 0), tags: (.tags // []), lastModified: (.lastModified // "")}' \
  | sort -u > "$OUT"

# Filter to genuinely bitnet-signal models, dedupe by id, sort by downloads desc
jq -s '
  unique_by(.id)
  | map(select(
      (.tags | map(ascii_downcase) | any(test("bitnet|1-?bit|1\\.58|ternary"))) or
      (.id   | ascii_downcase | test("bitnet|1-?bit|1\\.58|ternary"))
    ))
  | sort_by(.downloads)
  | reverse
  | .[0:'"$LIMIT"']
  | .[]
' "$OUT" | jq -c '{
    id: .id,
    downloads: .downloads,
    likes: .likes,
    lastModified: .lastModified,
    signal: (
      .tags | map(ascii_downcase) |
      if any(test("bitnet")) then "bitnet"
      elif any(test("1\\.58")) then "1.58-bit"
      elif any(test("ternary")) then "ternary"
      elif any(test("1-?bit")) then "1-bit"
      else "other" end
    )
  }' > "${OUT}.filtered"

if $PRETTY; then
  printf "%-50s  %-10s  %-10s  %-12s\n" "id" "downloads" "likes" "signal"
  printf "%-50s  %-10s  %-10s  %-12s\n" "-------------------------------------------------" "----------" "----------" "------------"
  jq -r '"\(.id[0:50] | . + (" " * (50-length))[0:50])  \(.downloads|tostring | . + (" " * (10-length))[0:10])  \(.likes|tostring | . + (" " * (10-length))[0:10])  \(.signal)"' < "${OUT}.filtered"
else
  cat "${OUT}.filtered"
fi
rm -f "${OUT}.filtered"
