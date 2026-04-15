#!/usr/bin/env bash
# s7-boot-validate.sh
# Boot a built S7 image as a podman container, wait for it to be ready,
# run smoke checks against it, tear down. Exits 0 only if all checks pass.
#
# Usage:
#   iac/boot/s7-boot-validate.sh \
#     --image localhost/s7-base:2026.04 \
#     --port 8080:8080 \
#     --smoke-checks iac/boot/smoke-checks.txt \
#     --timeout 60
#
# Environment:
#   S7_BOOT_VALIDATE_LOG  — NDJSON log path (default /var/log/s7/boot-validate.ndjson)

set -uo pipefail

IMAGE=""
PORT=""
SMOKE=""
TIMEOUT=60
LOG="${S7_BOOT_VALIDATE_LOG:-/var/log/s7/boot-validate.ndjson}"
NAME="s7-boot-validate"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --smoke-checks) SMOKE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "FAIL: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$IMAGE" && -n "$PORT" && -n "$SMOKE" ]] || {
  echo "FAIL: required args: --image, --port, --smoke-checks" >&2
  exit 2
}
[[ -f "$SMOKE" ]] || { echo "FAIL: smoke-checks file not found: $SMOKE" >&2; exit 2; }

mkdir -p "$(dirname "$LOG")"

cleanup() {
  podman stop "$NAME" >/dev/null 2>&1 || true
  podman rm   "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Pre-clean in case a previous run crashed.
cleanup

echo "─── boot validate: $IMAGE ───"

# Verify image exists.
if ! podman image exists "$IMAGE"; then
  echo "FAIL: image $IMAGE not found in podman storage" >&2
  exit 1
fi

# Boot it.
if ! podman run -d --rm --name "$NAME" -p "$PORT" "$IMAGE" >/dev/null 2>&1; then
  echo "FAIL: podman run failed for $IMAGE" >&2
  exit 1
fi

# Wait for the first smoke-check URL to respond at all (any status).
FIRST_URL=$(grep -vE '^\s*(#|$)' "$SMOKE" | head -1 | awk -F'\t' '{print $1}')
DEADLINE=$(( $(date +%s) + TIMEOUT ))
READY=false
while [[ $(date +%s) -lt $DEADLINE ]]; do
  if curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$FIRST_URL" 2>/dev/null | grep -qE '^[1-5][0-9][0-9]$'; then
    READY=true
    break
  fi
  sleep 1
done

if ! $READY; then
  echo "FAIL: $IMAGE did not respond on $FIRST_URL within ${TIMEOUT}s" >&2
  exit 1
fi

# Run the smoke checks.
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FAILED=0
TOTAL=0
while IFS=$'\t' read -r URL EXPECTED DESC; do
  [[ -z "$URL" || "$URL" =~ ^# ]] && continue
  TOTAL=$((TOTAL+1))
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL" 2>/dev/null || echo 000)
  if [[ "$STATUS" == "$EXPECTED" ]]; then
    VERDICT="pass"
    echo "  PASS  $URL → $STATUS  ($DESC)"
  else
    VERDICT="fail"
    FAILED=$((FAILED+1))
    echo "  FAIL  $URL → $STATUS (expected $EXPECTED) ($DESC)"
  fi
  printf '{"ts":"%s","image":"%s","url":"%s","expected":%s,"status":%s,"verdict":"%s","desc":"%s"}\n' \
    "$NOW" "$IMAGE" "$URL" "$EXPECTED" "$STATUS" "$VERDICT" "$DESC" >> "$LOG"
done < "$SMOKE"

echo "─── boot validate: $TOTAL checks, $FAILED failed ───"
if [[ $FAILED -eq 0 ]]; then
  echo "PASS"
  exit 0
else
  echo "FAIL"
  exit 1
fi
