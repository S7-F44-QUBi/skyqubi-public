#!/usr/bin/env bash
# s7-witness-inventory.sh
# ═══════════════════════════════════════════════════════════════════
# Fetch metadata for the 7 canonical S7 SkyQUBi witnesses from the
# Hugging Face Hub and emit NDJSON suitable for piping into jq or
# feeding the OCTi witness card generator.
#
# Output one JSON object per witness with:
#   id, plane, downloads, likes, license, lastModified, tags
#
# Usage:
#   ./s7-witness-inventory.sh                    # all 7 witnesses as NDJSON
#   ./s7-witness-inventory.sh --pretty           # human-readable table
#   ./s7-witness-inventory.sh | jq -s .          # JSON array
#   ./s7-witness-inventory.sh | jq '.id + " " + .license'
#
# Env:
#   HF_TOKEN   optional — higher rate limits if set
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,22p' "$0" | sed 's|^# \?||'
  exit 0
fi

PRETTY=false
if [[ "${1:-}" == "--pretty" ]]; then PRETTY=true; fi

# Canonical S7 witness set per project_octi_witness_set.md (full 7+1).
# Each row: HF model id | cognitive plane
WITNESSES=(
  "meta-llama/Llama-3.2-3B-Instruct|Sensory"
  "mistralai/Mistral-7B-Instruct-v0.3|Episodic"
  "google/gemma-2-9b-it|Semantic"
  "microsoft/phi-4|Associative"
  "Qwen/Qwen2.5-32B-Instruct|Procedural"
  "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B|Relational"
  "bigscience/bloom-7b1|Lexical"
)

AUTH=()
if [[ -n "${HF_TOKEN:-}" ]]; then
  AUTH=(-H "Authorization: Bearer ${HF_TOKEN}")
fi

fetch_one() {
  local id="$1"
  local plane="$2"
  local url="https://huggingface.co/api/models/${id}"
  local resp
  resp=$(curl -sSL --max-time 10 "${AUTH[@]}" "$url" 2>/dev/null) || return 0
  # Guard: empty response or error
  if [[ -z "$resp" ]] || echo "$resp" | jq -e '.error' >/dev/null 2>&1; then
    jq -nc --arg id "$id" --arg plane "$plane" \
      '{id: $id, plane: $plane, status: "error"}'
    return 0
  fi
  echo "$resp" | jq -c \
    --arg plane "$plane" \
    '{
      id: .id,
      plane: $plane,
      downloads: (.downloads // 0),
      likes: (.likes // 0),
      license: (
        .cardData.license //
        ((.tags // []) | map(select(type == "string" and startswith("license:"))) | first // "unknown" | sub("^license:"; ""))
      ),
      lastModified: (.lastModified // ""),
      pipeline: (.pipeline_tag // ""),
      library: (.library_name // ""),
      status: "ok"
    }'
}

OUT=$(mktemp)
for row in "${WITNESSES[@]}"; do
  id="${row%%|*}"
  plane="${row##*|}"
  fetch_one "$id" "$plane"
done > "$OUT"

if $PRETTY; then
  printf "%-42s  %-12s  %-12s  %-10s  %-10s\n" "id" "plane" "license" "downloads" "likes"
  printf "%-42s  %-12s  %-12s  %-10s  %-10s\n" "------------------------------------------" "------------" "------------" "----------" "----------"
  jq -r '"\(.id[0:42] | .  + (" " * (42 - length))[0:42])  \(.plane[0:12] | . + (" " * (12-length))[0:12])  \(.license // "?" | tostring[0:12] | . + (" " * (12-length))[0:12])  \(.downloads|tostring | . + (" " * (10-length))[0:10])  \(.likes|tostring)"' < "$OUT" 2>/dev/null || cat "$OUT"
else
  cat "$OUT"
fi
rm -f "$OUT"
