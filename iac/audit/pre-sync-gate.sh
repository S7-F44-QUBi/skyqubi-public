#!/usr/bin/env bash
# iac/audit/pre-sync-gate.sh
#
# S7 Pre-Sync Audit Gate — runs CHEF Recipe #1 §16 (the nine zeros)
# and refuses to let private main cross to public main if any new
# warning or drift is detected.
#
# Two-axis gate:
#   Axis A — Drift           (zeros 1–8): does what's running match the recipe?
#   Axis B — Vulnerability   (zero 9):    is the code we ship itself safe?
#
# Severity ladder:
#   PASS       — clean, sync may proceed
#   PINNED     — pre-existing item on iac/audit/pinned.yaml, loud but allowed
#   WARNING    — new finding, BLOCKS sync until acknowledged or fixed
#   BLOCK      — hard violation (drift / new injection / new secret), BLOCKS sync
#
# Output:
#   - human-readable visual summary on stdout
#   - appends a dated entry to docs/internal/chef/audit-living.md
#   - writes JSON snapshot to dist/audit/<timestamp>.json (machine-readable)
#
# Exit codes:
#   0  — PASS or PASS-WITH-PINNED, sync may proceed
#   1  — WARNING or BLOCK, sync refused
#   2  — gate itself errored (tool missing in mandatory mode, etc.)
#
# Usage:
#   ./pre-sync-gate.sh                 # full run, write Living Document, gate verdict
#   ./pre-sync-gate.sh --dry-run       # run checks, do not write Living Document
#   ./pre-sync-gate.sh --no-vuln       # skip Axis B (use only when tools not installed yet)
#   ./pre-sync-gate.sh --help

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIVING_DOC="$REPO_DIR/docs/internal/chef/audit-living.md"
PINNED_FILE="$SCRIPT_DIR/pinned.yaml"
DIST_DIR="$REPO_DIR/iac/audit/dist"
mkdir -p "$DIST_DIR"

DRY_RUN=false
SKIP_VULN=false
for arg in "$@"; do
  case "$arg" in
    --help|-h)
      sed -n '2,29p' "$0" | sed 's|^# \?||'
      exit 0 ;;
    --dry-run) DRY_RUN=true ;;
    --no-vuln) SKIP_VULN=true ;;
  esac
done

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TS_FILE="$(date -u +%Y%m%d-%H%M%S)"
SNAPSHOT="$DIST_DIR/$TS_FILE.json"

# ─────────────────────────────────────────────────────────────────
# Visual badges (only used in audit output — explicit user request)
# ─────────────────────────────────────────────────────────────────
B_PASS="🟢"
B_WARN="🟡"
B_FAIL="🔴"
B_PIN="📌"
B_INFO="ℹ️ "

# Counters
hard_fail=0
new_warning=0
pinned_warning=0
pass_count=0

# Findings table — accumulated, then rendered at the end
declare -a findings  # "STATUS|axis|zero|title|detail"

add_finding() {
  findings+=("$1|$2|$3|$4|$5")
  case "$1" in
    PASS)    pass_count=$((pass_count + 1)) ;;
    PINNED)  pinned_warning=$((pinned_warning + 1)) ;;
    WARNING) new_warning=$((new_warning + 1)) ;;
    BLOCK)   hard_fail=$((hard_fail + 1)) ;;
  esac
}

# Pinned-id check: is a finding-id already on the acknowledged list?
is_pinned() {
  local id="$1"
  [[ -f "$PINNED_FILE" ]] || return 1
  grep -qE "^\s*-\s*id:\s*${id}\s*$" "$PINNED_FILE"
}

# ─────────────────────────────────────────────────────────────────
# Axis A — Drift
# ─────────────────────────────────────────────────────────────────

# Zero 1 — Inconsistencies (the recipe matches reality)
# Compare live ss/ps to recipe §3a/§4. The recipe is an .md, so this
# step at gate time is "are there listeners or PIDs whose port/comm
# is not mentioned in the recipe?" Heuristic match against §3.
check_zero_1() {
  local recipe="$REPO_DIR/docs/internal/chef/01-trinity-foundation.md"
  if [[ ! -f "$recipe" ]]; then
    add_finding BLOCK A 1 "Recipe missing" "$recipe not found"
    return
  fi
  # Get port + owning process pairs. Skip Ollama runner subprocess
  # ephemeral ports — Ollama spawns a model runner on a dynamic
  # high port (>32768) for each loaded model. These cannot be in
  # the static recipe by design. The main Ollama port (57081) is
  # still checked against the recipe because it's not ephemeral.
  local listeners
  listeners=$(ss -tlnHp 2>/dev/null | awk '{
    port = $4; sub(/.*:/, "", port);
    proc = "";
    if (match($0, /users:\(\("[^"]+"/)) {
      proc = substr($0, RSTART+9, RLENGTH-10);
    }
    if (proc == "ollama" && port+0 > 32768) next;
    print port;
  }' | sort -u)
  local missing=""
  while read -r port; do
    [[ -z "$port" ]] && continue
    if ! grep -qE "[^0-9]${port}[^0-9]|^${port}$" "$recipe" 2>/dev/null; then
      missing+="$port "
    fi
  done <<< "$listeners"
  if [[ -z "$missing" ]]; then
    add_finding PASS A 1 "Inconsistencies" "every listening port is named in the recipe"
  else
    add_finding WARNING A 1 "Listening ports not in recipe" "$missing"
  fi
}

# Zero 2 — Drift in frozen surfaces
check_zero_2() {
  local dirty_priv dirty_pub
  dirty_priv=$(cd "$REPO_DIR" && git status -s 2>/dev/null | wc -l)
  if [[ -d /s7/skyqubi-public/.git ]]; then
    dirty_pub=$(cd /s7/skyqubi-public && git status -s 2>/dev/null | wc -l)
  else
    dirty_pub=0
  fi
  if [[ "$dirty_pub" -gt 0 ]]; then
    add_finding BLOCK A 2 "Public repo dirty" "$dirty_pub uncommitted changes in /s7/skyqubi-public"
  else
    add_finding PASS A 2 "Public repo clean" "0 uncommitted changes"
  fi
  if [[ "$dirty_priv" -gt 0 ]]; then
    add_finding PINNED A 2 "Private repo has work-in-progress" "$dirty_priv uncommitted changes (expected on lifecycle)"
  fi
}

# Zero 3 — Injection points (shell=True, compound shell)
check_zero_3() {
  local hits
  hits=$(grep -rn "shell=True" "$REPO_DIR/engine" "$REPO_DIR/services" 2>/dev/null | grep -v '#.*shell=True' || true)
  if [[ -z "$hits" ]]; then
    add_finding PASS A 3 "Injection points" "no shell=True in engine/ or services/"
  else
    if is_pinned "shell-true-monitors"; then
      add_finding PINNED A 3 "shell=True (acknowledged)" "$(echo "$hits" | head -1)"
    else
      add_finding BLOCK A 3 "shell=True (NEW)" "$(echo "$hits" | head -3)"
    fi
  fi
}

# Zero 4 — Secrets in tracked files
check_zero_4() {
  local hits
  hits=$(cd "$REPO_DIR" && git ls-files 2>/dev/null \
    | xargs grep -lE "ghp_[A-Za-z0-9]{36}|-----BEGIN (RSA |EC |OPENSSH |PGP |)PRIVATE KEY-----" 2>/dev/null || true)
  if [[ -z "$hits" ]]; then
    add_finding PASS A 4 "Secrets in tracked files" "0 hits"
  else
    add_finding BLOCK A 4 "Secret pattern in tracked file" "$hits"
  fi
}

# Zero 5 — Unrecognized outbound links in published surfaces
check_zero_5() {
  local approved='skyqubi\.(com|ai)|123tech\.(net|com)|skycair\.[a-z]+|omegaanswers\.|linuxalternatives\.|microsoftalternatives\.|windowsalternatives\.|skynetcair\.|unifiedlinuxwith|fonts\.googleapis\.com|fonts\.gstatic\.com|github\.com/skycair-code|127\.0\.0\.1|localhost|::1|www\.w3\.org'
  local hits
  hits=$(grep -rEh \
      --exclude-dir=.pytest_cache \
      --exclude-dir=__pycache__ \
      --exclude-dir=node_modules \
      --exclude-dir=.git \
      'https?://[a-zA-Z0-9.-]+' \
      "$REPO_DIR/wix" "$REPO_DIR/dashboard" "$REPO_DIR/persona-chat" 2>/dev/null \
    | grep -oE 'https?://[a-zA-Z0-9.-]+' | sort -u \
    | grep -vE "$approved" || true)
  if [[ -z "$hits" ]]; then
    add_finding PASS A 5 "Outbound links" "all links resolve to the approved domain set"
  else
    add_finding WARNING A 5 "Unrecognized outbound link(s)" "$(echo "$hits" | head -5 | tr '\n' ' ')"
  fi
}

# Zero 6 — DNS resolver matches documented stance
check_zero_6() {
  local resolver
  resolver=$(resolvectl status 2>/dev/null | awk '/Current DNS Server:/ {print $NF; exit}')
  if [[ -z "$resolver" ]]; then
    add_finding WARNING A 6 "DNS resolver unknown" "resolvectl returned empty"
  elif [[ "$resolver" == "9.9.9.9" ]]; then
    add_finding PASS A 6 "DNS resolver matches stance" "Quad9 9.9.9.9"
  else
    if is_pinned "dns-router-not-quad9"; then
      add_finding PINNED A 6 "DNS resolver $resolver (acknowledged)" "expected 9.9.9.9 per project_security_model.md"
    else
      add_finding WARNING A 6 "DNS resolver drift" "$resolver (expected 9.9.9.9)"
    fi
  fi
}

# Zero 7 — Wildcard / non-loopback binds outside the recognized set
check_zero_7() {
  local wild
  wild=$(ss -tlnH 2>/dev/null | awk '{print $4}' | grep -E '^\*:|^0\.0\.0\.0:|^\[::\]:' | sort -u)
  local unrec=""
  while read -r ent; do
    [[ -z "$ent" ]] && continue
    case "$ent" in
      *:22|*:5355) ;;  # standard host services
      *:57081)
        is_pinned "ollama-wildcard-bind" || unrec+="$ent " ;;
      *:8080)
        is_pinned "caddy-frontdoor-wildcard" || unrec+="$ent " ;;
      *)
        unrec+="$ent " ;;
    esac
  done <<< "$wild"
  if [[ -z "$unrec" ]]; then
    add_finding PASS A 7 "Non-loopback binds" "all accounted for (sshd, LLMNR, pinned: Ollama, Caddy)"
  else
    add_finding WARNING A 7 "New non-loopback bind(s)" "$unrec"
  fi
  # Also pin the existing ones for visibility
  is_pinned "ollama-wildcard-bind"     && add_finding PINNED A 7 "Ollama *:57081"    "wildcard bind (acknowledged)"
  is_pinned "caddy-frontdoor-wildcard" && add_finding PINNED A 7 "Caddy *:8080"      "wildcard bind (acknowledged)"
}

# Zero 8 — Unrecognized processes / users
check_zero_8() {
  local users
  users=$(ps -eo user= 2>/dev/null | sort -u)
  local approved='^(s7|skybuilder|root|dbus|polkitd|chrony|avahi|pcscd|rtkit|systemd-resolve|systemd-oom|systemd-coredump|nobody|messagebus|sshd|tss|colord|geoclue|gdm|sssd|cockpit-ws|cockpit-wsinstance|gnome-initial-setup|524388|525286|525287|525288)$'
  local unrec=""
  while read -r u; do
    [[ -z "$u" ]] && continue
    [[ "$u" =~ $approved ]] || unrec+="$u "
  done <<< "$users"
  if [[ -z "$unrec" ]]; then
    add_finding PASS A 8 "Process owners" "all accounted for"
  else
    add_finding WARNING A 8 "Unrecognized process owner(s)" "$unrec"
  fi
}

# Zero 10 — Frozen tree integrity (council-merged design 2026-04-14)
# Reads iac/audit/frozen-trees.txt and compares each pinned ref's
# actual sha against the pinned sha. Mismatch = BLOCK unless the ref
# has a `frozen-tree-<name>-pending` entry in pinned.yaml, in which
# case the BLOCK converts to PINNED. Local-only by invariant of zeros
# 1-9 (no git ls-remote — public/main is read from /s7/skyqubi-public
# local mirror).
check_zero_10() {
  local frozen_file="$SCRIPT_DIR/frozen-trees.txt"
  if [[ ! -f "$frozen_file" ]]; then
    add_finding PINNED A 10 "Frozen tree integrity" "frozen-trees.txt not present (zero #10 disabled until pinned)"
    return
  fi

  # Anti-fracture guard (added 2026-04-15 after v6-genesis orphan fracture):
  # Read frozen-trees.txt from HEAD, not from the working tree. Uncommitted
  # working-tree edits to the pins must not be able to silently change the
  # gate's witness of what is pinned. If the working tree differs from HEAD,
  # loudly announce the drift so the operator must commit or revert before
  # the gate can trust the pins. See docs/internal/postmortems/2026-04-15-v6-genesis-orphan-fracture.md
  local frozen_content=""
  local rel_path="iac/audit/frozen-trees.txt"
  frozen_content=$(git -C "$REPO_DIR" show "HEAD:$rel_path" 2>/dev/null || true)
  if [[ -z "$frozen_content" ]]; then
    frozen_content=$(cat "$frozen_file")
  fi
  if ! git -C "$REPO_DIR" diff --quiet HEAD -- "$rel_path" 2>/dev/null; then
    add_finding PINNED A 10 "Frozen tree pins drift" "frozen-trees.txt has uncommitted working-tree edits — gate is reading HEAD version, not the edits. Commit or revert."
  fi

  while IFS=' ' read -r ref_spec sha_pinned _rest; do
    [[ -z "$ref_spec" ]] && continue
    [[ "$ref_spec" =~ ^# ]] && continue
    local sha_actual="" repo="" branch=""
    case "$ref_spec" in
      lifecycle|private/lifecycle)
        repo="/s7/skyqubi-private"; branch="lifecycle" ;;
      private/main)
        repo="/s7/skyqubi-private"; branch="main" ;;
      public/main)
        repo="/s7/skyqubi-public";  branch="main" ;;
      immutable/main)
        repo="/s7/skyqubi-immutable"; branch="main" ;;
      immutable-assets/main)
        repo="/s7/immutable-assets"; branch="main" ;;
      immutable-S7-F44/main)
        repo="/s7/immutable-S7-F44"; branch="main" ;;
      immutable-qubi/main)
        repo="/s7/immutable-qubi"; branch="main" ;;
      SafeSecureLynX/main)
        repo="/s7/SafeSecureLynX"; branch="main" ;;
      *)
        add_finding WARNING A 10 "Frozen tree spec unknown" "$ref_spec"
        continue ;;
    esac
    # PENDING short-circuit MUST fire before the git read — a PENDING
    # ref may point at a repo that does not yet exist locally (e.g. the
    # skyqubi-immutable target created 2026-04-14 but not yet cloned).
    # A pre-ceremony PENDING is answered by pinned.yaml, not by the tree.
    if [[ "$sha_pinned" == "PENDING" ]]; then
      local pin_id="frozen-tree-${ref_spec//\//-}-pending"
      if is_pinned "$pin_id"; then
        add_finding PINNED A 10 "Frozen tree ($ref_spec)" "PENDING — acknowledged via pinned.yaml ($pin_id)"
      else
        add_finding BLOCK A 10 "Frozen tree ($ref_spec)" "PENDING but no pinned.yaml entry — add ${pin_id} or pin a real sha"
      fi
      continue
    fi
    sha_actual=$(git -C "$repo" rev-parse "$branch" 2>/dev/null || echo "ERROR")
    if [[ "$sha_actual" == "ERROR" ]]; then
      add_finding WARNING A 10 "Frozen tree ($ref_spec)" "could not read $branch in $repo"
      continue
    fi
    # Two acceptable states:
    #  (1) EXACT match — lifecycle tip is literally the pinned sha
    #  (2) FAST-FORWARD — the pinned sha is an ancestor of the tip,
    #      meaning the branch has moved forward since the pin but
    #      hasn't been rewritten. This avoids the lag-by-1 pattern
    #      where committing the pin update itself would always fail
    #      the exact check.
    # Only BLOCK if neither holds — the branch diverged from the pin
    # (force push, hard reset to a sibling history, or tampering).
    if [[ "$sha_actual" == "$sha_pinned"* || "$sha_pinned" == "$sha_actual"* ]]; then
      add_finding PASS A 10 "Frozen tree ($ref_spec)" "matches pinned ${sha_pinned:0:7}"
    elif git -C "$repo" merge-base --is-ancestor "$sha_pinned" "$sha_actual" 2>/dev/null; then
      local ahead
      ahead=$(git -C "$repo" rev-list --count "${sha_pinned}..${sha_actual}" 2>/dev/null || echo "?")
      add_finding PASS A 10 "Frozen tree ($ref_spec)" "fast-forward from pinned ${sha_pinned:0:7} (+${ahead} commits, ancestor intact)"
    else
      add_finding BLOCK A 10 "Frozen tree DIVERGED ($ref_spec)" "pinned=${sha_pinned:0:7} actual=${sha_actual:0:7} — branch history rewritten or moved to sibling"
    fi
  done <<< "$frozen_content"
}

# Zero 11 — Legacy-path service detection (Axis A — Drift)
# Sweeps every s7-*.service systemd user unit for ExecStart,
# WorkingDirectory, and Environment=PATH references rooted outside
# the tracked tiers. An orphan reference is any /s7/... path that
# isn't /s7/skyqubi-private/, /s7/skyqubi-public/, /s7/.config,
# /s7/.env.secrets, or /s7/.local/bin. Catalogs the finding and
# converts BLOCK→PINNED if the summary pin exists.
check_zero_11() {
  local sd_dir="$HOME/.config/systemd/user"
  if [[ ! -d "$sd_dir" ]]; then
    add_finding PINNED A 11 "Legacy-path service detection" "no systemd user dir at $sd_dir"
    return
  fi
  local orphans
  # Exclude tracked code tiers (skyqubi-private, skyqubi-public),
  # user system paths (.config, .env.secrets, .local), and
  # runtime data storage (.ollama, .podman-tmp, .s7-chat-sessions,
  # timecapsule asset stores). Only orphaned CODE paths should fire.
  orphans=$(grep -rEh '^(ExecStart|WorkingDirectory|Environment)' "$sd_dir"/s7-*.service 2>/dev/null \
    | grep -oE '/s7/[^ '\''"]+' \
    | grep -vE '^/s7/(skyqubi-private|skyqubi-public|\.config|\.env\.secrets|\.local|\.ollama|\.podman-tmp|\.s7-chat-sessions|s7-timecapsule-assets|timecapsule)' \
    | sort -u)
  if [[ -z "$orphans" ]]; then
    add_finding PASS A 11 "Legacy-path service detection" "all s7 systemd units point at tracked tiers"
    return
  fi
  local orphan_count
  orphan_count=$(echo "$orphans" | wc -l)
  if is_pinned "legacy-path-operational-tier"; then
    local summary
    summary=$(echo "$orphans" | head -3 | tr '\n' ' ')
    add_finding PINNED A 11 "Legacy-path service detection (acknowledged)" "$orphan_count orphan refs, incl: $summary"
  else
    add_finding BLOCK A 11 "Legacy-path service detection (NEW)" "$(echo "$orphans" | tr '\n' ' ')"
  fi
}

# Zero 12 — Immutable lineage integrity (Axis A — Drift)
# Verifies the immutable fork registry is in a known state:
#   - Missing file or empty list: PINNED via immutable-registry-empty
#     (pre-first-ceremony state, acknowledged)
#   - Populated and parseable: PASS with entry count
#   - Populated but malformed: BLOCK (registry tampering)
# When populated post-first-ceremony, this check will also verify
# the bundle file exists, the sha256 matches, the signature verifies,
# and public/main's current content byte-matches a rebuild from the
# latest non-retired entry. Those extensions land AFTER the first
# ceremony because they require a real bundle to verify against.
check_zero_12() {
  local registry="$REPO_DIR/iac/immutable/registry.yaml"
  if [[ ! -f "$registry" ]]; then
    if is_pinned "immutable-registry-empty"; then
      add_finding PINNED A 12 "Immutable registry" "not present (pre-ceremony, acknowledged)"
    else
      add_finding BLOCK A 12 "Immutable registry missing" "$registry not found — expected after first advance ceremony"
    fi
    return
  fi
  # Schema check: parse-able YAML with an `immutable:` top-level key
  if ! python3 -c "import yaml,sys; d=yaml.safe_load(open('$registry')); sys.exit(0 if 'immutable' in d else 1)" 2>/dev/null; then
    add_finding BLOCK A 12 "Immutable registry malformed" "YAML parse failed or missing 'immutable:' key"
    return
  fi
  # Count actual entries via YAML parse (grep would count commented
  # schema examples inside the file as false positives)
  local entry_count
  entry_count=$(python3 -c "import yaml; d=yaml.safe_load(open('$registry')); print(len(d.get('immutable') or []))" 2>/dev/null || echo "0")
  if [[ "$entry_count" -eq 0 ]]; then
    if is_pinned "immutable-registry-empty"; then
      add_finding PINNED A 12 "Immutable registry" "0 entries (pre-ceremony, acknowledged)"
    else
      add_finding BLOCK A 12 "Immutable registry empty" "no immutable advances recorded — run the first advance ceremony"
    fi
    return
  fi
  # TODO post-first-ceremony: verify bundle exists + sha256 + signature
  # + byte-match rebuild against public/main
  add_finding PASS A 12 "Immutable registry" "$entry_count entries recorded (schema valid)"
}

# Zero 13 — PRISM/GRID/WALL integrity (Axis C — Covenant)
# A new axis introduced by the 2026-04-14 CORE reframe: QUBi is
# CORE, CORE secures three concentric things (PRISM epistemology,
# GRID connectivity, WALL defense). This zero checks that each of
# the three is in an expected state.
#
# Because the CORE reframe is JAMIE-AUTHORIZED-IN-TONYAS-STEAD (not
# yet full covenant-grade — pending Tonya's witness), zero #13 is
# implemented in graceful-degradation mode:
#   - If the reframe memory is still marked CHAIR-DRAFT or
#     JAMIE-AUTHORIZED-IN-TONYAS-STEAD, zero #13 emits PINNED
#     (pre-covenant state, acknowledged)
#   - If the reframe is promoted to COVENANT-GRADE, zero #13 runs
#     the three checks and emits PASS/BLOCK per each
#
# Pinned acknowledgment: `prism-grid-wall-pre-covenant` in pinned.yaml
check_zero_13() {
  local core_memory="/s7/.claude/projects/-s7/memory/feedback_qubi_is_core_prism_grid_wall.md"
  if [[ ! -f "$core_memory" ]]; then
    if is_pinned "prism-grid-wall-pre-covenant"; then
      add_finding PINNED C 13 "PRISM/GRID/WALL integrity" "reframe memory not present (pre-reframe state, acknowledged)"
    else
      add_finding BLOCK C 13 "PRISM/GRID/WALL reframe missing" "core memory file not found"
    fi
    return
  fi
  # Read the status field from the memory file's frontmatter
  local status
  status=$(grep -E '^status:' "$core_memory" | head -1 | sed 's/^status:[[:space:]]*//;s/[[:space:]]*$//')
  case "$status" in
    "COVENANT-GRADE")
      # TODO — post-covenant-grade, run the three actual checks:
      #   PRISM: classify a test corpus through the verdict engine
      #          and compare to expected distribution
      #   GRID:  walk MemPalace rooms, verify pillar+weight
      #          distribution is within expected bounds
      #   WALL:  count refusal events since last check, verify
      #          baseline count is within drift tolerance
      # For now, post-covenant-grade just emits PASS because the
      # implementation of the three checks waits for the first
      # CORE ceremony to define the expected baselines.
      add_finding PASS C 13 "PRISM/GRID/WALL integrity" "CORE reframe COVENANT-GRADE (baseline checks pending first ceremony)"
      ;;
    "JAMIE-APPROVED-PENDING-TONYA"|"JAMIE-AUTHORIZED-IN-TONYAS-STEAD")
      if is_pinned "prism-grid-wall-pre-covenant"; then
        add_finding PINNED C 13 "PRISM/GRID/WALL integrity" "reframe at ${status} (pre-covenant, pending Tonya)"
      else
        add_finding WARNING C 13 "PRISM/GRID/WALL reframe not yet covenant-grade" "add 'prism-grid-wall-pre-covenant' to pinned.yaml to acknowledge pre-covenant state"
      fi
      ;;
    "CHAIR-DRAFT")
      if is_pinned "prism-grid-wall-pre-covenant"; then
        add_finding PINNED C 13 "PRISM/GRID/WALL integrity" "reframe at CHAIR-DRAFT (acknowledged)"
      else
        add_finding WARNING C 13 "PRISM/GRID/WALL reframe at CHAIR-DRAFT" "pending promotion"
      fi
      ;;
    *)
      add_finding WARNING C 13 "PRISM/GRID/WALL reframe status unknown" "status: '$status'"
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────
# Axis B — Vulnerability (graceful degradation)
# ─────────────────────────────────────────────────────────────────

tool_present() { command -v "$1" >/dev/null 2>&1; }

check_zero_9() {
  if $SKIP_VULN; then
    add_finding PINNED B 9 "Axis B skipped (--no-vuln)" "vulnerability scan deferred"
    return
  fi
  local any=false
  for t in bandit shellcheck gitleaks pip-audit trivy; do
    if tool_present "$t"; then
      any=true
      add_finding PASS B 9 "$t available" "vuln scan tool present"
    else
      add_finding PINNED B 9 "$t missing" "install during next Core Update window"
    fi
  done
  if ! $any; then
    add_finding PINNED B 9 "Axis B tools not yet installed" "bandit, shellcheck, gitleaks, pip-audit, trivy — all FOSS, all local, install at next Core Update"
  fi
  # When any tool IS present, run it (smallest first)
  if tool_present bandit; then
    if bandit -r "$REPO_DIR/engine" "$REPO_DIR/services" -ll -q 2>/dev/null | grep -q "No issues identified"; then
      add_finding PASS B 9 "bandit" "no high/medium issues"
    else
      if is_pinned "shell-true-monitors"; then
        add_finding PINNED B 9 "bandit findings (one acknowledged)" "see iac/audit/pinned.yaml"
      else
        add_finding WARNING B 9 "bandit findings" "review required"
      fi
    fi
  fi
}

# ─────────────────────────────────────────────────────────────────
# Run the gate
# ─────────────────────────────────────────────────────────────────

check_zero_1
check_zero_2
check_zero_3
check_zero_4
check_zero_5
check_zero_6
check_zero_7
check_zero_8
check_zero_9
check_zero_10
check_zero_11
check_zero_12
check_zero_13

# Verdict
if [[ $hard_fail -gt 0 ]]; then
  verdict="BLOCK"; badge="$B_FAIL"
elif [[ $new_warning -gt 0 ]]; then
  verdict="WARNING"; badge="$B_WARN"
else
  verdict="PASS"; badge="$B_PASS"
fi

# ─────────────────────────────────────────────────────────────────
# Render visual summary to stdout
# ─────────────────────────────────────────────────────────────────
echo
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║   S7 Pre-Sync Audit Gate                              ║"
echo "  ║   $TS                              ║"
echo "  ╚═══════════════════════════════════════════════════════╝"
echo
printf "  %s VERDICT: %-10s   %s pass: %d   %s pinned: %d   %s warn: %d   %s block: %d\n" \
  "$badge" "$verdict" "$B_PASS" "$pass_count" "$B_PIN" "$pinned_warning" "$B_WARN" "$new_warning" "$B_FAIL" "$hard_fail"
echo
echo "  ── Findings ────────────────────────────────────────────"
for f in "${findings[@]}"; do
  IFS='|' read -r status axis zero title detail <<< "$f"
  case "$status" in
    PASS)    icon="$B_PASS" ;;
    PINNED)  icon="$B_PIN"  ;;
    WARNING) icon="$B_WARN" ;;
    BLOCK)   icon="$B_FAIL" ;;
  esac
  printf "  %s [%s%d] %-44s %s\n" "$icon" "$axis" "$zero" "$title" "$detail"
done
echo

# ─────────────────────────────────────────────────────────────────
# JSON snapshot
# ─────────────────────────────────────────────────────────────────
{
  printf '{"timestamp":"%s","verdict":"%s","counts":{"pass":%d,"pinned":%d,"warning":%d,"block":%d},"findings":[' \
    "$TS" "$verdict" "$pass_count" "$pinned_warning" "$new_warning" "$hard_fail"
  first=true
  for f in "${findings[@]}"; do
    IFS='|' read -r status axis zero title detail <<< "$f"
    $first || printf ','
    printf '{"status":"%s","axis":"%s","zero":%d,"title":%s,"detail":%s}' \
      "$status" "$axis" "$zero" "$(printf '%s' "$title" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
      "$(printf '%s' "$detail" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
    first=false
  done
  printf ']}\n'
} > "$SNAPSHOT"

# ─────────────────────────────────────────────────────────────────
# Append to Living Document
# ─────────────────────────────────────────────────────────────────
if ! $DRY_RUN; then
  if [[ ! -f "$LIVING_DOC" ]]; then
    cat > "$LIVING_DOC" <<'HEADER'
# CHEF Recipe #1 — Living Audit Document

> **Living document.** Every run of `iac/audit/pre-sync-gate.sh`
> appends a dated entry below. The newest entry is at the top so the
> current state is always the first thing you see. The detailed
> per-run sections are the audit *trail*; the visual header at the
> top of each entry is the audit *verdict*.
>
> Read the top entry to know whether the household is clean *right
> now*. Scroll down to see how it got here. **An audit that doesn't
> persist is a story; an audit that persists is a witness.**

---

HEADER
  fi
  # Build new entry in a temp, then prepend after the header
  ENTRY="$DIST_DIR/.entry.$$"
  {
    echo "## $TS — verdict: $verdict $badge"
    echo
    echo "| | Pass | Pinned | Warning | Block |"
    echo "|---|---|---|---|---|"
    echo "| count | $pass_count | $pinned_warning | $new_warning | $hard_fail |"
    echo
    echo "### Findings"
    echo
    echo "| Status | Axis | Zero | Title | Detail |"
    echo "|---|---|---|---|---|"
    for f in "${findings[@]}"; do
      IFS='|' read -r status axis zero title detail <<< "$f"
      case "$status" in
        PASS)    icon="$B_PASS PASS" ;;
        PINNED)  icon="$B_PIN PINNED" ;;
        WARNING) icon="$B_WARN WARNING" ;;
        BLOCK)   icon="$B_FAIL BLOCK" ;;
      esac
      detail_md=$(printf '%s' "$detail" | sed 's/|/\\|/g' | tr -d '\n' | cut -c1-120)
      title_md=$(printf '%s' "$title" | sed 's/|/\\|/g')
      echo "| $icon | $axis | $zero | $title_md | $detail_md |"
    done
    echo
    echo "Snapshot: \`iac/audit/dist/$TS_FILE.json\`"
    echo
    echo "---"
    echo
  } > "$ENTRY"

  # Prepend after the header (after the first --- line)
  if grep -q '^---$' "$LIVING_DOC"; then
    awk -v entry="$ENTRY" '
      BEGIN { inserted = 0 }
      /^---$/ && !inserted {
        print
        print ""
        while ((getline line < entry) > 0) print line
        inserted = 1
        next
      }
      { print }
    ' "$LIVING_DOC" > "$LIVING_DOC.new" && mv "$LIVING_DOC.new" "$LIVING_DOC"
  else
    cat "$ENTRY" >> "$LIVING_DOC"
  fi
  rm -f "$ENTRY"
fi

# Exit code
case "$verdict" in
  PASS)    exit 0 ;;
  WARNING) exit 1 ;;
  BLOCK)   exit 1 ;;
esac
