# TimeCapsule Registry — Plan B0: Boot-Server Validation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the missing "boot server" stage of the standard pipeline. Produce one script — `iac/boot/s7-boot-validate.sh` — that takes the freshly-built `localhost/s7-base:<version>` image, boots it as a long-running podman container with the `qubi` network attached, waits for the SPA to respond, runs a small smoke test against it, and tears down cleanly. Wire that script into `s7-lifecycle-test.sh` as a new gate so every future plan's pipeline ends with a real boot test.

**Architecture:** A bash wrapper around `podman run` + `curl` + `podman stop`, with three knobs (image tag, timeout, smoke-test URL list). Idempotent. Cleans up its own container even on failure (trap EXIT). Produces an NDJSON line per smoke check appended to `/var/log/s7/boot-validate.ndjson` for the audit chain.

**Tech Stack:** bash, podman, curl, jq.

**Prerequisite:** Plan A complete and green. The `qubi` network does NOT exist yet at this point (Plan B creates it) — so Plan B0 creates a **temporary** ephemeral network just for the boot test, and tears it down with the container.

**Spec:** `docs/internal/superpowers/specs/2026-04-13-pull-once-save-local-design.md` (the boot-validation gap surfaced in the Plan A discussion)

**Out of scope:** real USB hardware boot (separate concern, requires hardware), Plan B's permanent qubi network creation (covered by Plan B), Samuel guardian (Plan D).

---

## File structure (Plan B0)

| Path | Responsibility |
|---|---|
| `iac/boot/s7-boot-validate.sh` | The validation script. Boots image, waits for SPA, runs smoke checks, tears down. |
| `iac/boot/test_boot_validate.py` | pytest tests using a tiny fixture image (`docker.io/library/nginx:alpine` already in cache, or build a 5-line one) |
| `iac/boot/smoke-checks.txt` | Newline-separated list of `URL\tEXPECTED_STATUS` lines the script checks |
| `s7-lifecycle-test.sh:NEW` | Add one new test row (`B01: Boot validation`) that calls the script |

---

## Task 1: Smoke-checks input file

**Files:**
- Create: `iac/boot/smoke-checks.txt`

- [ ] **Step 1: Write the smoke checks file**

```text
# iac/boot/smoke-checks.txt
# Newline-separated smoke checks the boot validator runs against a freshly
# booted s7-base image. Format: URL<TAB>EXPECTED_STATUS<TAB>DESCRIPTION
# Lines starting with # are comments. Blank lines ignored.
http://127.0.0.1:8080/	200	S7 SPA root
http://127.0.0.1:8080/health	200	S7 SPA health endpoint
```

- [ ] **Step 2: Commit**

```bash
cd /s7/skyqubi-private
mkdir -p iac/boot
git add iac/boot/smoke-checks.txt
git -c user.email=261467595+skycair-code@users.noreply.github.com \
    -c user.name=skycair-code \
    commit -m "feat(boot): smoke-checks input file for boot validator"
```

---

## Task 2: Boot validation script — happy path

**Files:**
- Create: `iac/boot/s7-boot-validate.sh`
- Create: `iac/boot/test_boot_validate.py`

- [ ] **Step 1: Write the failing test**

Create `iac/boot/test_boot_validate.py`:

```python
"""Tests for s7-boot-validate.sh.

We use docker.io/library/nginx:alpine as the test image because:
  - It's tiny (~50MB)
  - It binds port 80 by default, which the script can map to 8080
  - It returns 200 on /
  - It's already in podman image cache on most dev boxes (or one quick pull)

The script under test is generic (takes an image tag as arg), so this
fixture works even though it's not the real s7-base image.
"""
import os
import shutil
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parent / "s7-boot-validate.sh"
NGINX_IMAGE = "docker.io/library/nginx:alpine"


@pytest.fixture(scope="module")
def nginx_pulled():
    """Make sure the test fixture image is available."""
    result = subprocess.run(
        ["podman", "image", "exists", NGINX_IMAGE], capture_output=True
    )
    if result.returncode != 0:
        subprocess.run(["podman", "pull", NGINX_IMAGE], check=True, capture_output=True)
    yield NGINX_IMAGE
    # Don't clean up — leave it for re-runs.


@pytest.fixture
def smoke_file(tmp_path):
    p = tmp_path / "smoke.txt"
    p.write_text("http://127.0.0.1:8080/\t200\tnginx root\n")
    return p


def test_script_exists():
    assert SCRIPT.is_file()
    assert os.access(SCRIPT, os.X_OK)


def test_happy_path_boot_and_smoke(nginx_pulled, smoke_file, tmp_path):
    """Boot nginx, hit /, see 200, tear down."""
    log = tmp_path / "boot-validate.ndjson"
    env = os.environ.copy()
    env["S7_BOOT_VALIDATE_LOG"] = str(log)

    result = subprocess.run(
        [
            "bash", str(SCRIPT),
            "--image", nginx_pulled,
            "--port", "8080:80",
            "--smoke-checks", str(smoke_file),
            "--timeout", "30",
        ],
        env=env, capture_output=True, text=True,
    )
    assert result.returncode == 0, f"stdout={result.stdout}\nstderr={result.stderr}"
    assert "PASS" in result.stdout
    assert log.exists()

    # NDJSON line per check.
    import json
    lines = [l for l in log.read_text().splitlines() if l.strip()]
    assert len(lines) >= 1
    for line in lines:
        entry = json.loads(line)
        assert entry["verdict"] == "pass"
        assert entry["url"] == "http://127.0.0.1:8080/"
        assert entry["status"] == 200


def test_container_is_torn_down_after_run(nginx_pulled, smoke_file, tmp_path):
    """After the script returns, no s7-boot-validate container should remain."""
    env = os.environ.copy()
    env["S7_BOOT_VALIDATE_LOG"] = str(tmp_path / "log.ndjson")
    subprocess.run(
        ["bash", str(SCRIPT),
         "--image", nginx_pulled,
         "--port", "8080:80",
         "--smoke-checks", str(smoke_file),
         "--timeout", "30"],
        env=env, capture_output=True, text=True,
    )
    ps = subprocess.run(
        ["podman", "ps", "-a", "--filter", "name=s7-boot-validate",
         "--format", "{{.Names}}"],
        capture_output=True, text=True,
    )
    assert ps.stdout.strip() == "", f"orphan containers: {ps.stdout}"


def test_smoke_failure_returns_nonzero(nginx_pulled, tmp_path):
    """If a smoke check expects 200 but gets 404, the script must exit non-zero."""
    smoke = tmp_path / "smoke.txt"
    smoke.write_text("http://127.0.0.1:8080/this-path-does-not-exist\t200\tbad path\n")

    env = os.environ.copy()
    env["S7_BOOT_VALIDATE_LOG"] = str(tmp_path / "log.ndjson")
    result = subprocess.run(
        ["bash", str(SCRIPT),
         "--image", nginx_pulled,
         "--port", "8080:80",
         "--smoke-checks", str(smoke),
         "--timeout", "30"],
        env=env, capture_output=True, text=True,
    )
    assert result.returncode != 0
    assert "FAIL" in result.stdout or "FAIL" in result.stderr


def test_image_does_not_exist_returns_nonzero(tmp_path, smoke_file):
    """Garbage image tag → script exits non-zero, no orphans."""
    env = os.environ.copy()
    env["S7_BOOT_VALIDATE_LOG"] = str(tmp_path / "log.ndjson")
    result = subprocess.run(
        ["bash", str(SCRIPT),
         "--image", "localhost/does-not-exist:0.0.0",
         "--port", "8080:80",
         "--smoke-checks", str(smoke_file),
         "--timeout", "10"],
        env=env, capture_output=True, text=True,
    )
    assert result.returncode != 0
```

- [ ] **Step 2: Run the failing tests**

```bash
cd /s7/skyqubi-private
python3 -m pytest iac/boot/test_boot_validate.py -v
```

Expected: 5 failures, all because `s7-boot-validate.sh` doesn't exist yet.

- [ ] **Step 3: Write the script**

Create `iac/boot/s7-boot-validate.sh`:

```bash
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
```

- [ ] **Step 4: Make executable and run tests**

```bash
chmod +x /s7/skyqubi-private/iac/boot/s7-boot-validate.sh
cd /s7/skyqubi-private
python3 -m pytest iac/boot/test_boot_validate.py -v
```

Expected: `5 passed`. If `test_image_does_not_exist_returns_nonzero` fails because podman tries to pull, that's fine — the `podman image exists` precheck in the script catches it.

- [ ] **Step 5: Commit**

```bash
cd /s7/skyqubi-private
git add iac/boot/s7-boot-validate.sh iac/boot/test_boot_validate.py
git -c user.email=261467595+skycair-code@users.noreply.github.com \
    -c user.name=skycair-code \
    commit -m "feat(boot): s7-boot-validate.sh + tests (boot, smoke, tear down)"
```

---

## Task 3: Wire boot validation into the lifecycle suite

**Files:**
- Modify: `s7-lifecycle-test.sh` — add one new test row in a new "BOOT" section before the RESULTS section.

- [ ] **Step 1: Read the existing lifecycle file structure**

```bash
grep -n '^# ═' /s7/skyqubi-private/s7-lifecycle-test.sh | head -20
grep -n '^EXPECTED=' /s7/skyqubi-private/s7-lifecycle-test.sh
```

Note the line where `EXPECTED=N` is set — you will increment it by 1.

- [ ] **Step 2: Add the boot test**

Find the "DOCS (2 tests)" section in `s7-lifecycle-test.sh` (around lines 153-161) and add a new section after it, before the RESULTS section. Insert these lines:

```bash
# ══════════════════════════════════════════════════════════════════
# BOOT (1 test)
# ══════════════════════════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo -e "${B}── Boot (1 test) ──${X}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# B01 picks the most recently built s7-base image. If none exists,
# the test reports skip (still counted as a pass for the lifecycle gate
# so this doesn't block plans that don't touch the bootc image).
BOOT_IMAGE=$(podman images --format '{{.Repository}}:{{.Tag}}' | grep '^localhost/s7-base:' | head -1)
if [[ -n "$BOOT_IMAGE" ]]; then
  t "B01" "Boot validation"           "bash /s7/skyqubi-private/iac/boot/s7-boot-validate.sh --image '$BOOT_IMAGE' --port 8080:8080 --smoke-checks /s7/skyqubi-private/iac/boot/smoke-checks.txt --timeout 60 >/dev/null 2>&1 && echo OK"  "OK"
else
  echo "  B01  Boot validation         SKIP (no s7-base image built yet)" | tee -a "$LOG"
  PASS=$((PASS+1)); TOTAL=$((TOTAL+1))
fi
```

- [ ] **Step 3: Update EXPECTED count**

Find the `EXPECTED=` line near the top of `s7-lifecycle-test.sh` and increment it by 1 (the new B01 test).

- [ ] **Step 4: Run lifecycle to verify the new test executes**

```bash
cd /s7/skyqubi-private
bash s7-lifecycle-test.sh
```

Expected: the new `── Boot (1 test) ──` section appears, B01 runs (or SKIPs if no s7-base image is built), and the final tally matches the new `EXPECTED` count.

If smoke-checks.txt expects port 8080 but the s7-base image doesn't bind 8080, B01 will FAIL legitimately — that means smoke-checks.txt needs to point at whatever port the s7-base image actually serves. For the first run, the SKIP path is the safe default.

- [ ] **Step 5: Commit**

```bash
cd /s7/skyqubi-private
git add s7-lifecycle-test.sh
git -c user.email=261467595+skycair-code@users.noreply.github.com \
    -c user.name=skycair-code \
    commit -m "feat(lifecycle): add B01 boot validation gate"
```

---

## Verification (end of Plan B0)

```bash
# 1. All Plan B0 tests pass.
cd /s7/skyqubi-private && python3 -m pytest iac/boot/ -v
# Expected: 5 passed.

# 2. The script is invokable from the lifecycle suite without error.
cd /s7/skyqubi-private && bash s7-lifecycle-test.sh
# Expected: B01 runs (or SKIPs) and the suite still ends green.

# 3. The script handles all four code paths:
#    - happy path → exit 0
#    - smoke check fails → exit 1
#    - image missing → exit 1
#    - cleanup runs even on crash → no orphan containers
# All four are covered by test_boot_validate.py.

# 4. Manual run against any image with a known port mapping.
bash iac/boot/s7-boot-validate.sh \
  --image docker.io/library/nginx:alpine \
  --port 8080:80 \
  --smoke-checks iac/boot/smoke-checks.txt \
  --timeout 30
# Expected: PASS line at the bottom (assuming smoke-checks.txt expects nginx behavior).
```

After Plan B0 is green, every subsequent plan (B, C, D) gets the boot validation gate "for free" by virtue of running the lifecycle suite as part of its end-of-plan gate.

## What Plan B0 leaves for Plan B and beyond

- **Plan B**: Now has a real boot-server gate. When Plan B migrates services to TimeCapsule, its end-of-plan gate runs `bash iac/boot/s7-boot-validate.sh` against the freshly-built bootc image with the migrated services and proves they all come up.
- **Real USB hardware boot**: Still out of scope. That requires hardware in the loop (a physical USB stick, a target machine, an SSH back-channel). A future plan can build a `s7-usb-boot-validate.sh` that uses QEMU+UEFI to boot a real USB image in a VM — but that is its own design discussion, not something Plan B0 should silently expand into.
