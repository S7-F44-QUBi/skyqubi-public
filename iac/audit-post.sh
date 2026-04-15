#!/usr/bin/env bash
# iac/audit-post.sh
# S7 Fedora Base — post-build verification against manifest.yaml.
#
# Runs a throwaway container derived from a just-built image and
# verifies every rule in manifest.yaml:
#   - packages.must_include      all present (rpm -qa)
#   - packages.must_exclude      none present
#   - users.must_include         exist with correct uid/gid/home/shell
#   - users.root_must_be_locked  passwd -S root shows L or LK
#   - users.root_shell_must_be   getent passwd root shows expected shell
#   - directories.must_exist     stat owner/group/mode
#   - files.must_exist           stat + must_contain grep
#   - network.exposed_ports_max  inspect Config.ExposedPorts count
#   - default_user               inspect Config.User
#
# Exit 0 = image passes, safe to pack.
# Exit 1 = image fails one or more checks, refuse to pack.
#
# Usage:
#   ./audit-post.sh                         # uses localhost/s7-fedora-base:latest
#   ./audit-post.sh --image IMG[:TAG]       # audit a specific image
#   ./audit-post.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.yaml"
LOG="$SCRIPT_DIR/dist/audit-post.log"
mkdir -p "$(dirname "$LOG")"

IMAGE="localhost/s7-fedora-base:latest"
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --help|-h)
      sed -n '2,22p' "$0" | sed 's|^# \?||'
      exit 0 ;;
    --image)
      j=$((i+1))
      IMAGE="${!j}"
      ;;
  esac
done

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log()       { printf '%s  %s\n' "$(timestamp)" "$*" | tee -a "$LOG"; }
fail_count=0
check_pass() { log "  [PASS] $*"; }
check_fail() { log "  [FAIL] $*"; fail_count=$((fail_count + 1)); }

log "=== audit-post.sh start ==="
log "image: $IMAGE"
log "manifest: $MANIFEST"

# Confirm image exists
if ! podman image exists "$IMAGE" 2>/dev/null; then
  log "FATAL: image $IMAGE not found in local podman storage"
  exit 1
fi

# Helper: run a command inside a throwaway container derived from the image
in_image() {
  podman run --rm --user 0:0 --entrypoint /bin/sh "$IMAGE" -c "$1" 2>/dev/null
}

# --- Packages check ---
log "[1/8] packages.must_include / must_exclude"
INSTALLED=$(in_image "rpm -qa --qf '%{NAME}\n' | sort -u" | sort -u)

while IFS= read -r pkg; do
  if echo "$INSTALLED" | grep -qxF "$pkg"; then
    check_pass "must_include: $pkg"
  else
    check_fail "must_include MISSING: $pkg"
  fi
done < <(python3 -c "import yaml; print('\n'.join(yaml.safe_load(open('$MANIFEST'))['packages']['must_include']))")

while IFS= read -r pkg; do
  if echo "$INSTALLED" | grep -qxF "$pkg"; then
    check_fail "must_exclude PRESENT: $pkg"
  else
    check_pass "must_exclude absent: $pkg"
  fi
done < <(python3 -c "import yaml; print('\n'.join(yaml.safe_load(open('$MANIFEST'))['packages']['must_exclude']))")

# --- Users check ---
log "[2/8] users.must_include"
while IFS='|' read -r name uid gid home shell; do
  ENTRY=$(in_image "getent passwd $name" || true)
  if [[ -z "$ENTRY" ]]; then
    check_fail "user $name MISSING"
    continue
  fi
  ACTUAL_UID=$(echo "$ENTRY" | cut -d: -f3)
  ACTUAL_GID=$(echo "$ENTRY" | cut -d: -f4)
  ACTUAL_HOME=$(echo "$ENTRY" | cut -d: -f6)
  ACTUAL_SHELL=$(echo "$ENTRY" | cut -d: -f7)
  [[ "$ACTUAL_UID"   == "$uid"   ]] && check_pass "user $name uid=$uid"     || check_fail "user $name uid expected=$uid actual=$ACTUAL_UID"
  [[ "$ACTUAL_GID"   == "$gid"   ]] && check_pass "user $name gid=$gid"     || check_fail "user $name gid expected=$gid actual=$ACTUAL_GID"
  [[ "$ACTUAL_HOME"  == "$home"  ]] && check_pass "user $name home=$home"   || check_fail "user $name home expected=$home actual=$ACTUAL_HOME"
  [[ "$ACTUAL_SHELL" == "$shell" ]] && check_pass "user $name shell=$shell" || check_fail "user $name shell expected=$shell actual=$ACTUAL_SHELL"
done < <(python3 -c "
import yaml
m = yaml.safe_load(open('$MANIFEST'))
for u in m['users']['must_include']:
    print('{}|{}|{}|{}|{}'.format(u['name'], u['uid'], u['gid'], u['home'], u['shell']))
")

# --- Root lock check ---
log "[3/8] users.root_must_be_locked"
ROOT_STATUS=$(in_image "passwd -S root 2>/dev/null | awk '{print \$2}'" || true)
if [[ "$ROOT_STATUS" == "L" || "$ROOT_STATUS" == "LK" ]]; then
  check_pass "root password locked (status=$ROOT_STATUS)"
else
  check_fail "root password NOT locked (status=${ROOT_STATUS:-unknown})"
fi

# --- Root shell check ---
log "[4/8] users.root_shell_must_be"
EXPECTED_ROOT_SHELL=$(python3 -c "import yaml; print(yaml.safe_load(open('$MANIFEST'))['users']['root_shell_must_be'])")
ROOT_SHELL=$(in_image "getent passwd root | cut -d: -f7")
[[ "$ROOT_SHELL" == "$EXPECTED_ROOT_SHELL" ]] \
  && check_pass "root shell=$ROOT_SHELL" \
  || check_fail "root shell expected=$EXPECTED_ROOT_SHELL actual=$ROOT_SHELL"

# --- Directories check ---
log "[5/8] directories.must_exist"
while IFS='|' read -r path owner group mode; do
  STAT=$(in_image "stat -c '%U|%G|%a' '$path' 2>/dev/null" || true)
  if [[ -z "$STAT" ]]; then
    check_fail "dir $path MISSING"
    continue
  fi
  ACTUAL_OWNER=$(echo "$STAT" | cut -d'|' -f1)
  ACTUAL_GROUP=$(echo "$STAT" | cut -d'|' -f2)
  ACTUAL_MODE=$(echo "$STAT" | cut -d'|' -f3)
  EXPECTED_MODE="${mode##0}"
  [[ "$ACTUAL_OWNER" == "$owner"         ]] && check_pass "dir $path owner=$owner" || check_fail "dir $path owner expected=$owner actual=$ACTUAL_OWNER"
  [[ "$ACTUAL_GROUP" == "$group"         ]] && check_pass "dir $path group=$group" || check_fail "dir $path group expected=$group actual=$ACTUAL_GROUP"
  [[ "$ACTUAL_MODE"  == "$EXPECTED_MODE" ]] && check_pass "dir $path mode=$mode"   || check_fail "dir $path mode expected=$EXPECTED_MODE actual=$ACTUAL_MODE"
done < <(python3 -c "
import yaml
m = yaml.safe_load(open('$MANIFEST'))
for d in m['directories']['must_exist']:
    print('{}|{}|{}|{}'.format(d['path'], d['owner'], d['group'], d['mode']))
")

# --- Files check ---
log "[6/8] files.must_exist"
while IFS='|' read -r path mode must_contain; do
  EXISTS=$(in_image "test -f '$path' && echo yes || echo no")
  if [[ "$EXISTS" != "yes" ]]; then
    check_fail "file $path MISSING"
    continue
  fi
  ACTUAL_MODE=$(in_image "stat -c '%a' '$path'")
  EXPECTED_MODE="${mode##0}"
  [[ "$ACTUAL_MODE" == "$EXPECTED_MODE" ]] \
    && check_pass "file $path mode=$mode" \
    || check_fail "file $path mode expected=$EXPECTED_MODE actual=$ACTUAL_MODE"
  if [[ -n "$must_contain" ]]; then
    in_image "grep -qF '$must_contain' '$path'" \
      && check_pass "file $path contains '$must_contain'" \
      || check_fail "file $path missing content '$must_contain'"
  fi
done < <(python3 -c "
import yaml
m = yaml.safe_load(open('$MANIFEST'))
for f in m['files']['must_exist']:
    print('{}|{}|{}'.format(f['path'], f['mode'], f.get('must_contain', '')))
")

# --- Exposed ports check ---
log "[7/8] network.exposed_ports_max"
EXPOSED_JSON=$(podman image inspect "$IMAGE" --format '{{json .Config.ExposedPorts}}' 2>/dev/null || echo "null")
EXPOSED_COUNT=$(echo "$EXPOSED_JSON" | python3 -c "import json, sys; d = json.load(sys.stdin); print(0 if d is None else len(d))")
MAX_PORTS=$(python3 -c "import yaml; print(yaml.safe_load(open('$MANIFEST'))['network']['exposed_ports_max'])")
[[ "$EXPOSED_COUNT" -le "$MAX_PORTS" ]] \
  && check_pass "exposed ports count $EXPOSED_COUNT <= max $MAX_PORTS" \
  || check_fail "exposed ports count $EXPOSED_COUNT > max $MAX_PORTS"

# --- Default user check ---
log "[8/8] default_user"
DEFAULT_USER=$(podman image inspect "$IMAGE" --format '{{.Config.User}}' 2>/dev/null)
EXPECTED_USER=$(python3 -c "import yaml; d=yaml.safe_load(open('$MANIFEST'))['default_user']; print(str(d['uid']) + ':' + str(d['uid']))")
EXPECTED_USER_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('$MANIFEST'))['default_user']['name'])")
if [[ "$DEFAULT_USER" == "$EXPECTED_USER" || "$DEFAULT_USER" == "$EXPECTED_USER_NAME:$EXPECTED_USER_NAME" || "$DEFAULT_USER" == "$EXPECTED_USER_NAME" ]]; then
  check_pass "default user=$DEFAULT_USER"
else
  check_fail "default user expected=$EXPECTED_USER_NAME or $EXPECTED_USER, actual=$DEFAULT_USER"
fi

# --- Verdict ---
log "=== audit-post.sh summary ==="
if [[ "$fail_count" -eq 0 ]]; then
  log "VERDICT: PASS (0 failures)"
  exit 0
else
  log "VERDICT: FAIL ($fail_count check failures)"
  exit 1
fi
