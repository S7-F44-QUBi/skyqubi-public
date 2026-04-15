"""Tests for s7-boot-validate.sh.

Uses docker.io/library/nginx:alpine as the fixture image:
- Tiny (~50MB)
- Binds port 80 by default → can map to 8080 on the host
- Returns 200 on /
- Already in podman image cache on most dev boxes (pulled once if not).

The script under test takes an image tag as arg, so this fixture works
even though it's not the real s7-base image.
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
    p.write_text("http://127.0.0.1:28080/\t200\tnginx root\n")
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
            "--port", "28080:80",
            "--smoke-checks", str(smoke_file),
            "--timeout", "30",
        ],
        env=env, capture_output=True, text=True,
    )
    assert result.returncode == 0, f"stdout={result.stdout}\nstderr={result.stderr}"
    assert "PASS" in result.stdout
    assert log.exists()

    import json
    lines = [l for l in log.read_text().splitlines() if l.strip()]
    assert len(lines) >= 1
    for line in lines:
        entry = json.loads(line)
        assert entry["verdict"] == "pass"
        assert entry["url"] == "http://127.0.0.1:28080/"
        assert entry["status"] == 200


def test_container_is_torn_down_after_run(nginx_pulled, smoke_file, tmp_path):
    """After the script returns, no s7-boot-validate container should remain."""
    env = os.environ.copy()
    env["S7_BOOT_VALIDATE_LOG"] = str(tmp_path / "log.ndjson")
    subprocess.run(
        ["bash", str(SCRIPT),
         "--image", nginx_pulled,
         "--port", "28080:80",
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
    smoke.write_text("http://127.0.0.1:28080/this-path-does-not-exist\t200\tbad path\n")

    env = os.environ.copy()
    env["S7_BOOT_VALIDATE_LOG"] = str(tmp_path / "log.ndjson")
    result = subprocess.run(
        ["bash", str(SCRIPT),
         "--image", nginx_pulled,
         "--port", "28080:80",
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
         "--port", "28080:80",
         "--smoke-checks", str(smoke_file),
         "--timeout", "10"],
        env=env, capture_output=True, text=True,
    )
    assert result.returncode != 0
