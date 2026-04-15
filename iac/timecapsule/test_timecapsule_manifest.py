"""Tests for timecapsule_manifest.py — the atomic manifest updater."""
import json
import hashlib
import os
import tempfile
from pathlib import Path

import pytest

from iac.timecapsule.timecapsule_manifest import (
    Manifest,
    ManifestError,
    sha256_file,
)

SCHEMA_PATH = Path(__file__).parent / "manifest.schema.json"


@pytest.fixture
def tmp_manifest(tmp_path):
    p = tmp_path / "manifest.json"
    p.write_text('{"version": 1, "images": []}')
    return p


@pytest.fixture
def tmp_tar(tmp_path):
    """Create a tiny 'tar' file (just bytes — we don't need a real tar)."""
    p = tmp_path / "images" / "busybox-1.36.tar"
    p.parent.mkdir()
    p.write_bytes(b"FAKE TAR CONTENT FOR TESTING")
    return p


def test_load_empty_manifest(tmp_manifest):
    m = Manifest.load(tmp_manifest)
    assert m.version == 1
    assert m.images == []


def test_add_entry_appends(tmp_manifest, tmp_tar):
    m = Manifest.load(tmp_manifest)
    m.add_entry(
        name="busybox",
        version="1.36",
        tar_path=tmp_tar,
        sig_path=tmp_tar.with_suffix(".tar.sig"),
        upstream="quay.io/quay/busybox:latest",
        promote_to="localhost/s7/busybox:1.36",
    )
    m.save()

    loaded = json.loads(tmp_manifest.read_text())
    assert len(loaded["images"]) == 1
    entry = loaded["images"][0]
    assert entry["name"] == "busybox"
    assert entry["version"] == "1.36"
    assert entry["tar"] == "images/busybox-1.36.tar"
    assert entry["sig"] == "images/busybox-1.36.tar.sig"
    assert entry["sha256"] == hashlib.sha256(b"FAKE TAR CONTENT FOR TESTING").hexdigest()
    assert entry["upstream"] == "quay.io/quay/busybox:latest"
    assert entry["promote_to"] == "localhost/s7/busybox:1.36"
    assert "added_at" in entry


def test_add_entry_rejects_duplicate_name_version(tmp_manifest, tmp_tar):
    m = Manifest.load(tmp_manifest)
    m.add_entry(
        name="busybox", version="1.36",
        tar_path=tmp_tar, sig_path=tmp_tar.with_suffix(".tar.sig"),
        upstream="x", promote_to="localhost/s7/busybox:1.36",
    )
    m.save()

    m2 = Manifest.load(tmp_manifest)
    with pytest.raises(ManifestError, match="already exists"):
        m2.add_entry(
            name="busybox", version="1.36",
            tar_path=tmp_tar, sig_path=tmp_tar.with_suffix(".tar.sig"),
            upstream="x", promote_to="localhost/s7/busybox:1.36",
        )


def test_atomic_write(tmp_manifest, tmp_tar, monkeypatch):
    """Verify save() uses tmpfile + rename, not in-place write."""
    m = Manifest.load(tmp_manifest)
    m.add_entry(
        name="busybox", version="1.36",
        tar_path=tmp_tar, sig_path=tmp_tar.with_suffix(".tar.sig"),
        upstream="x", promote_to="localhost/s7/busybox:1.36",
    )

    rename_called = []
    real_rename = os.rename
    def fake_rename(src, dst):
        rename_called.append((src, dst))
        real_rename(src, dst)
    monkeypatch.setattr(os, "rename", fake_rename)

    m.save()
    assert len(rename_called) == 1
    src, dst = rename_called[0]
    assert str(dst) == str(tmp_manifest)
    assert str(src) != str(tmp_manifest)


def test_load_rejects_bad_schema(tmp_path):
    bad = tmp_path / "bad.json"
    bad.write_text('{"version": 99, "images": []}')
    with pytest.raises(ManifestError, match="schema"):
        Manifest.load(bad)


def test_sha256_file(tmp_tar):
    expected = hashlib.sha256(b"FAKE TAR CONTENT FOR TESTING").hexdigest()
    assert sha256_file(tmp_tar) == expected
