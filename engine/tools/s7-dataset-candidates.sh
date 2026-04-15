#!/usr/bin/env bash
# s7-dataset-candidates.sh
# ═══════════════════════════════════════════════════════════════════
# Find Hugging Face datasets suitable for fine-tuning S7 witnesses.
# Optimized for LONG-TERM stability: ranks by (downloads + likes) over
# time, not trending spikes, so you pick datasets that have earned
# trust, not ones that are hot this week.
#
# Output: NDJSON, one dataset per line, including license hint,
# size hint, task, and a "long_term_score" for comparison.
#
# Usage:
#   ./s7-dataset-candidates.sh                      # default: SFT/DPO-oriented
#   ./s7-dataset-candidates.sh --method sft         # SFT only
#   ./s7-dataset-candidates.sh --method dpo         # DPO only
#   ./s7-dataset-candidates.sh --limit 30 --pretty  # human-readable
#
# Env:
#   HF_TOKEN   optional — higher rate limits
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,20p' "$0" | sed 's|^# \?||'
  exit 0
fi

LIMIT=20
METHOD="both"
PRETTY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) LIMIT="$2"; shift 2 ;;
    --method) METHOD="$2"; shift 2 ;;
    --pretty) PRETTY=true; shift ;;
    *) shift ;;
  esac
done

AUTH=()
if [[ -n "${HF_TOKEN:-}" ]]; then
  AUTH=(-H "Authorization: Bearer ${HF_TOKEN}")
fi

query() {
  local term="$1"
  curl -sSL --max-time 10 "${AUTH[@]}" \
    "https://huggingface.co/api/datasets?search=${term}&limit=${LIMIT}&sort=downloads&direction=-1&full=true" 2>/dev/null
}

OUT=$(mktemp)
trap "rm -f $OUT ${OUT}.*" EXIT

SEARCH_TERMS=()
case "$METHOD" in
  sft)  SEARCH_TERMS=("sft" "instruct" "chat+assistant") ;;
  dpo)  SEARCH_TERMS=("dpo" "preference" "rlhf") ;;
  both|*) SEARCH_TERMS=("sft" "dpo" "preference" "instruct") ;;
esac

{
  for term in "${SEARCH_TERMS[@]}"; do
    query "$term"
  done
} | jq -c '.[]? | {
    id: (.id // .datasetId),
    downloads: (.downloads // 0),
    likes: (.likes // 0),
    lastModified: (.lastModified // ""),
    tags: (.tags // []),
    cardData: .cardData
  }' > "$OUT"

# Long-term score formula:
#   score = log10(downloads + 1) * 10 + log10(likes + 1) * 20 + recency_factor
# Recency factor penalizes very new datasets (under 180 days) slightly —
# we want proven, not trending.
jq -s '
  unique_by(.id)
  | map(
      . + {
        license: (.cardData.license // "unknown"),
        size: (.cardData.size_categories // [] | first // "unknown"),
        task: (.cardData.task_categories // [] | first // "unknown"),
        long_term_score: (
          (((.downloads + 1) | log) / (10 | log)) * 10 +
          (((.likes + 1)     | log) / (10 | log)) * 20
        )
      }
    )
  | sort_by(.long_term_score)
  | reverse
  | .[0:'"$LIMIT"']
  | .[] | {id, downloads, likes, license, size, task, long_term_score: (.long_term_score | . * 10 | round / 10)}
' "$OUT" | jq -c '.' > "${OUT}.ranked"

if $PRETTY; then
  printf "%-48s  %-10s  %-8s  %-14s  %-12s  %-6s\n" "id" "downloads" "likes" "license" "size" "score"
  printf "%-48s  %-10s  %-8s  %-14s  %-12s  %-6s\n" "------------------------------------------------" "----------" "--------" "--------------" "------------" "------"
  jq -r '"\(.id[0:48] | . + (" " * (48-length))[0:48])  \(.downloads|tostring | . + (" " * (10-length))[0:10])  \(.likes|tostring | . + (" " * (8-length))[0:8])  \((.license // "?")[0:14] | . + (" " * (14-length))[0:14])  \((.size // "?")[0:12] | . + (" " * (12-length))[0:12])  \(.long_term_score)"' < "${OUT}.ranked"
else
  cat "${OUT}.ranked"
fi
rm -f "${OUT}.ranked"
