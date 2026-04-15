"""systemd-analyze the unit file for syntax + ordering."""
import shutil
import subprocess
from pathlib import Path

UNIT = Path(__file__).parent / "s7-timecapsule-verify.service"


def test_unit_exists():
    assert UNIT.is_file()


def test_systemd_analyze_verify():
    if shutil.which("systemd-analyze") is None:
        import pytest
        pytest.skip("systemd-analyze not installed")
    result = subprocess.run(
        ["systemd-analyze", "verify", str(UNIT)],
        capture_output=True, text=True,
    )
    # Filter to warnings about THIS unit file. Then exclude warnings
    # about the ExecStart path not existing on this box — that's an
    # install-time concern, not a unit-file syntax concern.
    relevant = [
        line for line in result.stderr.splitlines()
        if str(UNIT) in line or "s7-timecapsule-verify" in line
    ]
    bad = [
        line for line in relevant
        if "does not exist" not in line
        and "is not executable" not in line
        and "Failed to load" not in line
    ]
    assert not bad, (
        "systemd-analyze warnings (after filtering install-time noise):\n"
        + "\n".join(bad)
    )


def test_unit_orders_before_podman_socket():
    text = UNIT.read_text()
    assert "Before=podman.socket" in text or "Before=podman.service" in text


def test_unit_runs_the_script():
    text = UNIT.read_text()
    assert "/usr/local/sbin/s7-timecapsule-verify.sh" in text


def test_unit_is_oneshot():
    text = UNIT.read_text()
    assert "Type=oneshot" in text
