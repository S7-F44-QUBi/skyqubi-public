#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi — Pod stats (read-only, Samuel-runnable)
#
# Wraps `podman pod stats s7-skyqubi --no-stream --format json` and
# emits a Samuel-shaped JSON envelope summarizing how hard the pod
# is working: container count, total CPU%, total RAM, top container
# by RAM. Real user question ("how hard is it working"), no SELinux
# escalation, no state changes.
#
# Usage:
#   bash install/pod-stats.sh              # text summary to stdout
#   bash install/pod-stats.sh --json       # single JSON object to stdout
#
# Exit codes:
#   0 — stats collected successfully
#   1 — pod not running (no containers reported)
#   2 — podman not available
#
# Governing rules:
#   feedback_three_rules.md     Rule 3: Protect the QUBi (read-only)
#   engine/agents/samuel_runnable_scripts.yaml  Catalog entry
#
# Copyright 2026 Jamie Lee Clayton / 2XR LLC · CWS-BSL-1.1
# ═══════════════════════════════════════════════════════════════════

set -u
set -o pipefail

POD_NAME="s7-skyqubi"
JSON_OUT=0
for arg in "$@"; do
    case "$arg" in
        --json) JSON_OUT=1 ;;
        --help|-h) sed -n '3,18p' "$0" | sed 's|^# \?||'; exit 0 ;;
        *) echo "unknown flag: $arg" >&2; exit 1 ;;
    esac
done

# Same FD juggling as the other scripts: in JSON mode, all human
# output goes to stderr so the final JSON is the only thing on stdout.
if [ "$JSON_OUT" -eq 1 ]; then
    exec 3>&1
    exec 1>&2
fi

if ! command -v podman >/dev/null 2>&1; then
    echo "podman not installed" >&2
    if [ "$JSON_OUT" -eq 1 ]; then
        printf '{"script":"pod-stats.sh","state":"podman_missing","exit_code":2,"containers":0,"running":0,"cpu_total_pct":0,"mem_total_mib":0,"top":null}\n' >&3
    fi
    exit 2
fi

raw=$(podman pod stats "$POD_NAME" --no-stream --format json 2>/dev/null || echo "[]")

# Parse with python3 (already a hard preflight requirement). We pass
# raw via env var because a `python3 - <<'PY'` heredoc would override
# stdin and the piped JSON would never reach the script.
parsed=$(POD_STATS_RAW="$raw" python3 - <<'PY'
import os, sys, json, re
RAW = os.environ.get("POD_STATS_RAW", "[]")

def to_mib(s):
    """Parse podman MemUsageBytes left side: '202.2MiB' / '12.07MiB' / '237kB' etc."""
    if not s:
        return 0.0
    s = s.strip().split("/")[0].strip()
    m = re.match(r"([\d.]+)\s*([a-zA-Z]+)", s)
    if not m:
        return 0.0
    val = float(m.group(1))
    unit = m.group(2).lower()
    factor = {
        "b": 1.0 / (1024 * 1024),
        "kb": 1.0 / 1024,
        "kib": 1.0 / 1024,
        "mb": 1.0,
        "mib": 1.0,
        "gb": 1024.0,
        "gib": 1024.0,
    }.get(unit, 0.0)
    return val * factor

def to_pct(s):
    if not s:
        return 0.0
    return float(s.replace("%", "").strip() or 0)

try:
    rows = json.loads(RAW)
except json.JSONDecodeError:
    rows = []

if not isinstance(rows, list):
    rows = []

containers = len(rows)
running = sum(1 for r in rows if to_pct(r.get("CPU", "0")) >= 0)  # any reporting row counts as running
cpu_total = sum(to_pct(r.get("CPU", "0")) for r in rows)
mem_total_mib = sum(to_mib(r.get("MemUsage", "")) for r in rows)

top = None
if rows:
    top_row = max(rows, key=lambda r: to_mib(r.get("MemUsage", "")))
    top = {
        "name": top_row.get("Name", "?"),
        "mem_mib": round(to_mib(top_row.get("MemUsage", "")), 1),
        "cpu_pct": round(to_pct(top_row.get("CPU", "0")), 2),
    }

out = {
    "containers": containers,
    "running": running,
    "cpu_total_pct": round(cpu_total, 2),
    "mem_total_mib": round(mem_total_mib, 1),
    "top": top,
}
print(json.dumps(out))
PY
)

containers=$(echo "$parsed" | python3 -c 'import sys,json; print(json.load(sys.stdin)["containers"])')
running=$(echo "$parsed" | python3 -c 'import sys,json; print(json.load(sys.stdin)["running"])')
cpu_total=$(echo "$parsed" | python3 -c 'import sys,json; print(json.load(sys.stdin)["cpu_total_pct"])')
mem_total=$(echo "$parsed" | python3 -c 'import sys,json; print(json.load(sys.stdin)["mem_total_mib"])')
top_name=$(echo "$parsed" | python3 -c 'import sys,json; t=json.load(sys.stdin)["top"]; print(t["name"] if t else "")')
top_mem=$(echo "$parsed" | python3 -c 'import sys,json; t=json.load(sys.stdin)["top"]; print(t["mem_mib"] if t else 0)')

if [ "$containers" = "0" ]; then
    state="pod_not_running"
    exit_code=1
else
    state="ok"
    exit_code=0
fi

echo "  pod: $POD_NAME"
echo "  containers: $running/$containers running"
echo "  cpu total: ${cpu_total}%"
echo "  mem total: ${mem_total} MiB"
[ -n "$top_name" ] && echo "  top: $top_name (${top_mem} MiB)"

if [ "$JSON_OUT" -eq 1 ]; then
    printf '{"script":"pod-stats.sh","state":"%s","exit_code":%d,"pod":"%s","containers":%s,"running":%s,"cpu_total_pct":%s,"mem_total_mib":%s,"top":{"name":"%s","mem_mib":%s}}\n' \
        "$state" "$exit_code" "$POD_NAME" \
        "$containers" "$running" "$cpu_total" "$mem_total" \
        "$top_name" "$top_mem" >&3
fi

exit $exit_code
