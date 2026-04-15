"""Drive s7-timecapsule-verify.sh with fixture manifests + tars."""
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parent / "s7-timecapsule-verify.sh"


def make_registry(tmp_path: Path, manifest_data: dict, tars: dict[str, bytes]):
    """Build a fake registry directory with the given manifest + tar contents."""
    reg = tmp_path / "registry"
    (reg / "images").mkdir(parents=True)
    (reg / "store").mkdir()
    (reg / "KEY.fingerprint").write_text("0000000000000000000000000000000000000000\n")
    (reg / "manifest.json").write_text(json.dumps(manifest_data))
    for filename, content in tars.items():
        (reg / "images" / filename).write_bytes(content)
        (reg / "images" / (filename + ".sig")).write_bytes(b"FAKE SIG")
    return reg


def run_verify(registry_dir: Path, log_dir: Path, fake_gpg_result: int = 0):
    """Run the verify script with PATH-injected fake gpg + podman."""
    bin_dir = log_dir / "fake-bin"
    bin_dir.mkdir()
    # Fake gpg: always exits with fake_gpg_result.
    (bin_dir / "gpg").write_text(f"#!/bin/sh\nexit {fake_gpg_result}\n")
    (bin_dir / "gpg").chmod(0o755)
    # Fake podman: records calls to a logfile, always exits 0.
    podman_log = log_dir / "podman.log"
    (bin_dir / "podman").write_text(
        f'#!/bin/sh\necho "$@" >> "{podman_log}"\nexit 0\n'
    )
    (bin_dir / "podman").chmod(0o755)

    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["S7_TIMECAPSULE_REGISTRY"] = str(registry_dir)
    env["S7_TIMECAPSULE_LOG"] = str(log_dir / "verify.log")

    result = subprocess.run(
        ["bash", str(SCRIPT)], env=env, capture_output=True, text=True
    )
    return result, podman_log


def test_empty_manifest_exits_zero(tmp_path):
    reg = make_registry(tmp_path, {"version": 1, "images": []}, {})
    result, _ = run_verify(reg, tmp_path)
    assert result.returncode == 0
    assert "no images to verify" in result.stdout.lower()


def test_one_entry_verifies_and_loads(tmp_path):
    reg = make_registry(
        tmp_path,
        {
            "version": 1,
            "images": [
                {
                    "name": "busybox",
                    "version": "1.36",
                    "tar": "images/busybox-1.36.tar",
                    "sig": "images/busybox-1.36.tar.sig",
                    "sha256": "PLACEHOLDER",
                    "added_at": "2026-04-13T00:00:00Z",
                    "upstream": "quay.io/quay/busybox:latest",
                    "promote_to": "localhost/s7/busybox:1.36",
                }
            ],
        },
        {"busybox-1.36.tar": b"BUSYBOX FAKE TAR"},
    )
    import hashlib
    actual_sha = hashlib.sha256(b"BUSYBOX FAKE TAR").hexdigest()
    m = json.loads((reg / "manifest.json").read_text())
    m["images"][0]["sha256"] = actual_sha
    (reg / "manifest.json").write_text(json.dumps(m))

    result, podman_log = run_verify(reg, tmp_path)
    assert result.returncode == 0, f"stdout={result.stdout}\nstderr={result.stderr}"
    assert "verdict: ok" in result.stdout

    log = podman_log.read_text()
    assert "load" in log
    assert "/registry/store" in log


def test_bad_sha_fails_loudly_but_exits_zero(tmp_path):
    reg = make_registry(
        tmp_path,
        {
            "version": 1,
            "images": [
                {
                    "name": "busybox",
                    "version": "1.36",
                    "tar": "images/busybox-1.36.tar",
                    "sig": "images/busybox-1.36.tar.sig",
                    "sha256": "0" * 64,
                    "added_at": "2026-04-13T00:00:00Z",
                    "upstream": "x",
                    "promote_to": "localhost/s7/busybox:1.36",
                }
            ],
        },
        {"busybox-1.36.tar": b"BUSYBOX FAKE TAR"},
    )
    result, podman_log = run_verify(reg, tmp_path)
    assert result.returncode == 0
    assert "verdict: fail" in result.stdout
    assert "sha256 mismatch" in result.stdout

    log = podman_log.read_text() if podman_log.exists() else ""
    assert "load" not in log


def test_bad_gpg_fails_loudly_but_exits_zero(tmp_path):
    reg = make_registry(
        tmp_path,
        {
            "version": 1,
            "images": [
                {
                    "name": "busybox",
                    "version": "1.36",
                    "tar": "images/busybox-1.36.tar",
                    "sig": "images/busybox-1.36.tar.sig",
                    "sha256": "0" * 64,
                    "added_at": "2026-04-13T00:00:00Z",
                    "upstream": "x",
                    "promote_to": "localhost/s7/busybox:1.36",
                }
            ],
        },
        {"busybox-1.36.tar": b"BUSYBOX FAKE TAR"},
    )
    import hashlib
    actual_sha = hashlib.sha256(b"BUSYBOX FAKE TAR").hexdigest()
    m = json.loads((reg / "manifest.json").read_text())
    m["images"][0]["sha256"] = actual_sha
    (reg / "manifest.json").write_text(json.dumps(m))

    result, podman_log = run_verify(reg, tmp_path, fake_gpg_result=1)
    assert result.returncode == 0
    assert "verdict: fail" in result.stdout
    assert "gpg verification failed" in result.stdout.lower()


def test_real_gpg_round_trip(tmp_path):
    """Generate a throwaway GPG key, sign a tar, run verify with the real key.

    This is the only test that uses real gpg (no mocks). It catches drift
    between the script's gpg invocation and the real tool's CLI.
    """
    import hashlib
    import json

    gnupg_home = tmp_path / "gnupg"
    gnupg_home.mkdir(mode=0o700)

    # 1. Generate an unattended throwaway key.
    batch = tmp_path / "batch.gpg"
    batch.write_text(
        "%no-protection\n"
        "Key-Type: EDDSA\n"
        "Key-Curve: ed25519\n"
        "Name-Real: TimeCapsule Test\n"
        "Name-Email: test@s7.local\n"
        "Expire-Date: 0\n"
        "%commit\n"
    )
    subprocess.run(
        ["gpg", "--homedir", str(gnupg_home), "--batch", "--gen-key", str(batch)],
        check=True, capture_output=True,
    )
    fp_out = subprocess.run(
        ["gpg", "--homedir", str(gnupg_home), "--list-secret-keys",
         "--with-colons", "--fingerprint"],
        check=True, capture_output=True, text=True,
    )
    fingerprint = next(
        line.split(":")[9] for line in fp_out.stdout.splitlines() if line.startswith("fpr:")
    )

    # 2. Build a registry with a real signed tar.
    reg = tmp_path / "registry"
    (reg / "images").mkdir(parents=True)
    (reg / "store").mkdir()
    (reg / "KEY.fingerprint").write_text(fingerprint + "\n")

    tar_path = reg / "images" / "busybox-1.36.tar"
    tar_path.write_bytes(b"REAL ROUND TRIP TAR")
    subprocess.run(
        ["gpg", "--homedir", str(gnupg_home), "--batch", "--yes",
         "--detach-sign", "--armor", "--local-user", fingerprint,
         "-o", str(tar_path) + ".sig", str(tar_path)],
        check=True, capture_output=True,
    )

    sha = hashlib.sha256(b"REAL ROUND TRIP TAR").hexdigest()
    (reg / "manifest.json").write_text(json.dumps({
        "version": 1,
        "images": [{
            "name": "busybox", "version": "1.36",
            "tar": "images/busybox-1.36.tar",
            "sig": "images/busybox-1.36.tar.sig",
            "sha256": sha,
            "added_at": "2026-04-13T00:00:00Z",
            "upstream": "x",
            "promote_to": "localhost/s7/busybox:1.36",
        }],
    }))

    # 3. Run verify with the real GPG (no PATH injection of a fake gpg).
    bin_dir = tmp_path / "real-bin"
    bin_dir.mkdir()
    podman_log = tmp_path / "podman.log"
    (bin_dir / "podman").write_text(
        f'#!/bin/sh\necho "$@" >> "{podman_log}"\nexit 0\n'
    )
    (bin_dir / "podman").chmod(0o755)

    env = os.environ.copy()
    # Real gpg from system PATH, fake podman from bin_dir.
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["GNUPGHOME"] = str(gnupg_home)
    env["S7_TIMECAPSULE_REGISTRY"] = str(reg)
    env["S7_TIMECAPSULE_LOG"] = str(tmp_path / "verify.log")

    result = subprocess.run(
        ["bash", str(SCRIPT)], env=env, capture_output=True, text=True
    )
    assert result.returncode == 0, f"stdout={result.stdout}\nstderr={result.stderr}"
    assert "verdict: ok" in result.stdout
