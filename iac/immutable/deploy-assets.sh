#!/usr/bin/env bash
# iac/immutable/deploy-assets.sh
#
# Walks all 7 asset categories in topological dependency order and calls
# fetch-gold-assets.sh for each. This is the single orchestrator called by:
#   - iac/build-bootc.sh (pre-build step)
#   - s7-lifecycle-test.sh (validation)
#   - .github/workflows/yearly-ceremony.yml (future CI)
#   - any developer running a local dry-build
#
# Usage:
#   deploy-assets.sh --source=local --deploy-root=/tmp/s7-test
#   deploy-assets.sh --source=remote --deploy-root=/opt/s7
#   deploy-assets.sh --profile=qubi_alone --source=local --deploy-root=/tmp/s7-qubi
#
# Profiles are defined in asset-dependencies.yaml:
#   qubi_alone     — Mode 1 (QUBi container)
#   f44_bootc_os   — Mode 2 (F44+BootC OS layers)
#   full_install   — Mode 3 (fresh-install ISO)
#   (default: all 7 categories, full topological order)
#
# The script walks the dependency DAG in topological order. A category is
# only fetched after all its dependencies have been fetched successfully.
# If any category fails, the script refuses to continue with dependents —
# covenant discipline: partial deploys are NOT allowed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/asset-dependencies.yaml"
FETCH="$SCRIPT_DIR/fetch-gold-assets.sh"

SOURCE="local"
DEPLOY_ROOT=""
PROFILE=""
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    --source=*)      SOURCE="${arg#*=}" ;;
    --deploy-root=*) DEPLOY_ROOT="${arg#*=}" ;;
    --profile=*)     PROFILE="${arg#*=}" ;;
    --verbose|-v)    VERBOSE=true ;;
    --help|-h)       sed -n '2,25p' "$0" | sed 's|^# \?||'; exit 0 ;;
  esac
done

say()     { echo "  [deploy] $*"; }
verbose() { $VERBOSE && echo "    [v] $*" || true; }
fail()    { echo "  🔴 [deploy] $*" >&2; exit "${2:-1}"; }

[[ -n "$DEPLOY_ROOT" ]] || fail "missing --deploy-root" 1
[[ -f "$CONFIG" ]] || fail "config missing: $CONFIG" 1
[[ -x "$FETCH" ]] || fail "fetcher missing or not executable: $FETCH" 1

export S7_DEPLOY_ROOT="$DEPLOY_ROOT"
say "deploy-root: $DEPLOY_ROOT"
say "source:      $SOURCE"
[[ -n "$PROFILE" ]] && say "profile:     $PROFILE" || say "profile:     all (full 7-category topological)"
echo

# ── Resolve category list + extract targets via Python ───────────
# Output format (one per line):
#   <order>|<id>|<extracts_to_expanded>|<deps_csv>|<role>
WORK_LIST=$(python3 - "$CONFIG" "$PROFILE" "$DEPLOY_ROOT" <<'PY'
import sys, yaml, os
config_path = sys.argv[1]
profile_id = sys.argv[2]
deploy_root = sys.argv[3]

with open(config_path) as f:
    doc = yaml.safe_load(f)

categories = {c["id"]: c for c in doc.get("categories", [])}
profiles = doc.get("profiles", {})

if profile_id:
    if profile_id not in profiles:
        sys.stderr.write(f"profile not found: {profile_id}\n")
        sys.exit(2)
    selected_ids = profiles[profile_id].get("categories", [])
else:
    selected_ids = list(categories.keys())

# Validate selected
for sid in selected_ids:
    if sid not in categories:
        sys.stderr.write(f"category not found: {sid}\n")
        sys.exit(2)

# Topological sort (Kahn's algorithm over the subgraph of selected)
def topo_sort(selected, cat_map):
    deps_in_selected = {sid: [d for d in cat_map[sid].get("depends_on") or [] if d in selected] for sid in selected}
    reverse = {sid: set() for sid in selected}
    for sid, deps in deps_in_selected.items():
        for d in deps:
            reverse[d].add(sid)
    in_deg = {sid: len(deps_in_selected[sid]) for sid in selected}
    queue = sorted([sid for sid, deg in in_deg.items() if deg == 0])
    out = []
    while queue:
        next_q = []
        for sid in queue:
            out.append(sid)
            for child in sorted(reverse[sid]):
                in_deg[child] -= 1
                if in_deg[child] == 0:
                    next_q.append(child)
        queue = sorted(next_q)
    if len(out) != len(selected):
        sys.stderr.write(f"dependency cycle detected in {selected}\n")
        sys.exit(3)
    return out

order = topo_sort(selected_ids, categories)

for idx, sid in enumerate(order, 1):
    c = categories[sid]
    extracts = c.get("extracts_to", "").replace("${S7_DEPLOY_ROOT}", deploy_root)
    deps = ",".join(c.get("depends_on") or []) or "-"
    role = (c.get("role") or "").replace("|", " ")
    print(f"{idx}|{sid}|{extracts}|{deps}|{role}")
PY
)
[[ $? -eq 0 ]] || fail "YAML resolve failed" 1

total=$(echo "$WORK_LIST" | grep -c . || true)
say "walking $total categories in topological order"
echo

# ── Walk the list ────────────────────────────────────────────────
SUCCEEDED=()
FAILED=()
SKIPPED=()

while IFS='|' read -r idx id extracts deps role; do
  [[ -z "$id" ]] && continue
  echo
  say "── [$idx/$total] $id ($role) ──"
  say "   deps: $deps"
  say "   target: $extracts"

  # If any dep failed, skip dependents
  skip=false
  if [[ "$deps" != "-" ]]; then
    IFS=',' read -ra DEP_LIST <<< "$deps"
    for d in "${DEP_LIST[@]}"; do
      if [[ " ${FAILED[*]} " == *" $d "* ]]; then
        say "⇣ skipping — dependency '$d' failed earlier"
        SKIPPED+=("$id")
        skip=true
        break
      fi
    done
  fi
  $skip && continue

  # Fetch
  if "$FETCH" --category="$id" --source="$SOURCE" --target="$extracts" $($VERBOSE && echo '--verbose'); then
    SUCCEEDED+=("$id")
  else
    say "✗ fetch failed for $id"
    FAILED+=("$id")
  fi
done <<< "$WORK_LIST"

# ── Summary ──────────────────────────────────────────────────────
echo
say "── Summary ──"
say "total:       $total"
say "✓ deployed:  ${#SUCCEEDED[@]}"
for c in "${SUCCEEDED[@]}"; do echo "    ✓ $c"; done
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  say "⇣ skipped (dep failed): ${#SKIPPED[@]}"
  for c in "${SKIPPED[@]}"; do echo "    ⇣ $c"; done
fi
if [[ ${#FAILED[@]} -gt 0 ]]; then
  say "✗ failed:    ${#FAILED[@]}"
  for c in "${FAILED[@]}"; do echo "    ✗ $c"; done
  say "🔴 partial deploy refused — rollback required"
  exit 2
fi
say "🟢 all $total categories deployed successfully"
exit 0
