# TimeCapsule Registry — Plan A: Foundation + Intake

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the `/s7/timecapsule/registry/` directory layout, the GPG-signed-tar manifest format, the boot-time verifier, the `additionalimagestores` podman wiring, and modify the existing intake adapter to write to TimeCapsule. Outcome: a single tiny test image (`busybox`) can be pulled through the modified intake gate, lands as a signed tar in TimeCapsule, gets loaded into the additional store at boot, and is visible to `podman images` from a normal podman invocation. Nothing migrates yet.

**Architecture:** TimeCapsule is a directory tree on the +1 disk layer. Tars are the shipping format, signed with the existing `skycair-code` GPG key. A boot script verifies sigs and `podman load`s any new tars into a read-only `store/` directory configured as `additionalimagestores` in `/etc/containers/storage.conf`. The intake adapter's promote step is rewritten to save the verified image into TimeCapsule instead of into the live graphroot.

**Tech Stack:** bash, python3 (stdlib only — no new pip deps), pytest (for the python module), gnupg2, podman 5.x, systemd, jq.

**Spec:** `docs/internal/superpowers/specs/2026-04-13-pull-once-save-local-design.md`

**Out of scope for Plan A** (covered by Plans B/C/D): qubi network recreation, service migration, Vivaldi container, s7-launch wrapper, Samuel guardian skill, desktop file edit.

---

## File structure (Plan A)

| Path | Responsibility |
|---|---|
| `iac/timecapsule/README.md` | Directory layout doc, manifest format reference, operator runbook |
| `iac/timecapsule/manifest.schema.json` | JSON schema for `manifest.json` — single source of truth for entry shape |
| `iac/timecapsule/timecapsule_manifest.py` | Python module: load, validate, atomically update `manifest.json`. No external deps. |
| `iac/timecapsule/test_timecapsule_manifest.py` | pytest tests for the module |
| `iac/timecapsule/storage.conf.snippet` | The `[storage.options]` block that goes into `/etc/containers/storage.conf` |
| `iac/timecapsule/s7-timecapsule-verify.sh` | Boot verification: walk manifest, gpg verify each tar, load into store if missing |
| `iac/timecapsule/test_verify.py` | pytest tests that drive the shell script with fixtures |
| `iac/timecapsule/s7-timecapsule-verify.service` | systemd unit, ordered before `podman.socket` |
| `iac/timecapsule/fixtures/` | test GPG keyring + test signed tar (generated at first test run, gitignored) |
| `iac/intake/pull-container.sh` | **Modified.** Promote phase rewritten to save+sign+manifest into TimeCapsule. |
| `iac/intake/test_pull_container_timecapsule.sh` | bash integration test: end-to-end pull of `quay.io/quay/busybox:latest` through the modified adapter |

---

## Task 1: TimeCapsule directory layout + manifest schema

**Files:**
- Create: `iac/timecapsule/README.md`
- Create: `iac/timecapsule/manifest.schema.json`
- Create: `/s7/timecapsule/registry/manifest.json` (initial empty manifest, host-side, NOT in git)
- Create: `/s7/timecapsule/registry/images/.gitkeep` equivalent (host-side directory)
- Create: `/s7/timecapsule/registry/store/.gitkeep` equivalent (host-side directory)
- Create: `/s7/timecapsule/registry/KEY.fingerprint` (host-side, contains `80F0291480E25C0F683E9714E11792E0AD945BE9`)

- [ ] **Step 1: Verify prerequisites exist on the dev box**

```bash
test -d /s7 && \
  gpg --list-secret-keys 80F0291480E25C0F683E9714E11792E0AD945BE9 >/dev/null 2>&1 && \
  echo OK
```

Expected: `OK`. If it fails, the GPG key is missing — stop and fix that first.

- [ ] **Step 2: Create the host-side TimeCapsule directories**

```bash
sudo mkdir -p /s7/timecapsule/registry/images /s7/timecapsule/registry/store
sudo chown -R "$USER:$USER" /s7/timecapsule
echo '80F0291480E25C0F683E9714E11792E0AD945BE9' > /s7/timecapsule/registry/KEY.fingerprint
echo '{"version": 1, "images": []}' > /s7/timecapsule/registry/manifest.json
ls -la /s7/timecapsule/registry/
```

Expected: directory listing showing `images/`, `store/`, `KEY.fingerprint`, `manifest.json`.

- [ ] **Step 3: Write `iac/timecapsule/manifest.schema.json`**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://s7.skyqubi/timecapsule/manifest.schema.json",
  "title": "TimeCapsule Registry Manifest",
  "type": "object",
  "required": ["version", "images"],
  "properties": {
    "version": { "type": "integer", "const": 1 },
    "images": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "version", "tar", "sig", "sha256", "added_at", "upstream"],
        "properties": {
          "name":     { "type": "string", "pattern": "^[a-z0-9][a-z0-9-]*$" },
          "version":  { "type": "string", "minLength": 1 },
          "tar":      { "type": "string", "pattern": "^images/[a-z0-9-]+-[^/]+\\.tar$" },
          "sig":      { "type": "string", "pattern": "^images/[a-z0-9-]+-[^/]+\\.tar\\.sig$" },
          "sha256":   { "type": "string", "pattern": "^[0-9a-f]{64}$" },
          "added_at": { "type": "string", "format": "date-time" },
          "upstream": { "type": "string", "minLength": 1 },
          "promote_to": { "type": "string", "pattern": "^localhost/s7/[a-z0-9-]+:[^/]+$" }
        },
        "additionalProperties": false
      }
    }
  },
  "additionalProperties": false
}
```

- [ ] **Step 4: Write `iac/timecapsule/README.md`**

```markdown
# TimeCapsule Registry

Lives at `/s7/timecapsule/registry/` on the QUBi appliance. Holds every
container image S7 services need to run, as GPG-signed tar files,
indexed by `manifest.json`.

## Layout

```
/s7/timecapsule/registry/
├── KEY.fingerprint     # GPG key fingerprint, 40 hex chars, no spaces
├── manifest.json       # Index of every image, validated against schema
├── images/             # The signed tars themselves
│   ├── <name>-<version>.tar
│   └── <name>-<version>.tar.sig   # detached GPG signature
└── store/              # Read-only podman additional image store
                        # populated by s7-timecapsule-verify.sh at boot
```

## Manifest format

Validated against `manifest.schema.json` in this directory. Each entry has:

- `name`: short name, lowercase, e.g. `cyberchef`
- `version`: pinned version string, e.g. `10.22.1`
- `tar`: relative path to the tar inside the registry
- `sig`: relative path to the detached signature
- `sha256`: hex digest of the tar (64 chars)
- `added_at`: ISO-8601 UTC timestamp
- `upstream`: the upstream ref the tar was pulled from (provenance)
- `promote_to`: the local podman tag (e.g. `localhost/s7/cyberchef:10.22.1`)

## How it gets populated

Only the modified intake adapter (`iac/intake/pull-container.sh`) writes
to this directory. Manual `cp` or `podman save` into `images/` is not
supported and will fail boot verification (no manifest entry).

## How it gets read

The boot script `s7-timecapsule-verify.sh` walks the manifest, GPG-verifies
each tar against the key in `KEY.fingerprint`, and loads any tar whose
image is not yet in `store/`. Podman is configured to read `store/` as
an `additionalimagestores`, so containers can `--pull=never` against the
loaded images.
```

- [ ] **Step 5: Commit**

```bash
cd /s7/skyqubi-private
git add iac/timecapsule/README.md iac/timecapsule/manifest.schema.json
git -c user.email=261467595+skycair-code@users.noreply.github.com \
    -c user.name=skycair-code \
    commit -m "feat(timecapsule): directory layout, manifest schema, readme"
```

---

## Task 2: Python manifest updater module + tests

**Files:**
- Create: `iac/timecapsule/timecapsule_manifest.py`
- Create: `iac/timecapsule/test_timecapsule_manifest.py`

- [ ] **Step 1: Write the failing tests**

Create `iac/timecapsule/test_timecapsule_manifest.py`:

```python
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

    # Patch os.rename to verify it's called (atomic).
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /s7/skyqubi-private
python3 -m pytest iac/timecapsule/test_timecapsule_manifest.py -v
```

Expected: `ModuleNotFoundError: No module named 'iac.timecapsule.timecapsule_manifest'`

- [ ] **Step 3: Implement `timecapsule_manifest.py`**

Create `iac/timecapsule/timecapsule_manifest.py`:

```python
"""TimeCapsule registry manifest — atomic, schema-validated updater.

Loaded by:
- iac/intake/pull-container.sh (during promote, to add a new entry)
- iac/timecapsule/s7-timecapsule-verify.sh (during boot, to read entries)

Responsibility: own manifest.json read, validation, and atomic write.
Nothing else writes to manifest.json.
"""
from __future__ import annotations

import hashlib
import json
import os
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import jsonschema  # already installed (4.26.0)

SCHEMA_PATH = Path(__file__).parent / "manifest.schema.json"


class ManifestError(Exception):
    """Raised on validation failures, duplicate entries, or IO errors."""


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


@dataclass
class Manifest:
    path: Path
    version: int = 1
    images: list[dict[str, Any]] = field(default_factory=list)

    @classmethod
    def load(cls, path: Path) -> "Manifest":
        path = Path(path)
        try:
            data = json.loads(path.read_text())
        except FileNotFoundError:
            return cls(path=path, version=1, images=[])
        except json.JSONDecodeError as e:
            raise ManifestError(f"manifest.json is not valid JSON: {e}") from e

        schema = json.loads(SCHEMA_PATH.read_text())
        try:
            jsonschema.validate(data, schema)
        except jsonschema.ValidationError as e:
            raise ManifestError(f"manifest schema validation failed: {e.message}") from e

        return cls(path=path, version=data["version"], images=list(data["images"]))

    def add_entry(
        self,
        *,
        name: str,
        version: str,
        tar_path: Path,
        sig_path: Path,
        upstream: str,
        promote_to: str,
    ) -> None:
        for entry in self.images:
            if entry["name"] == name and entry["version"] == version:
                raise ManifestError(
                    f"entry for {name}:{version} already exists in manifest"
                )

        sha = sha256_file(tar_path)
        entry = {
            "name": name,
            "version": version,
            "tar": f"images/{tar_path.name}",
            "sig": f"images/{sig_path.name}",
            "sha256": sha,
            "added_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "upstream": upstream,
            "promote_to": promote_to,
        }

        # Validate the single new entry against schema before appending.
        schema = json.loads(SCHEMA_PATH.read_text())
        try:
            jsonschema.validate(
                {"version": self.version, "images": self.images + [entry]},
                schema,
            )
        except jsonschema.ValidationError as e:
            raise ManifestError(f"new entry would invalidate manifest: {e.message}") from e

        self.images.append(entry)

    def save(self) -> None:
        """Atomic write: tmpfile in same dir + os.rename."""
        payload = {"version": self.version, "images": self.images}
        text = json.dumps(payload, indent=2, sort_keys=True) + "\n"

        # Use mkstemp in the same directory so rename is atomic.
        fd, tmp_path = tempfile.mkstemp(
            prefix=".manifest-", suffix=".json.tmp", dir=str(self.path.parent)
        )
        try:
            with os.fdopen(fd, "w") as f:
                f.write(text)
            os.rename(tmp_path, self.path)
        except Exception:
            try:
                os.unlink(tmp_path)
            except FileNotFoundError:
                pass
            raise
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /s7/skyqubi-private
python3 -m pytest iac/timecapsule/test_timecapsule_manifest.py -v
```

Expected: `6 passed`.

- [ ] **Step 5: Commit**

```bash
cd /s7/skyqubi-private
git add iac/timecapsule/timecapsule_manifest.py iac/timecapsule/test_timecapsule_manifest.py
git -c user.email=261467595+skycair-code@users.noreply.github.com \
    -c user.name=skycair-code \
    commit -m "feat(timecapsule): atomic manifest updater module + tests"
```

---

## Task 3: storage.conf snippet for additionalimagestores

**Files:**
- Create: `iac/timecapsule/storage.conf.snippet`
- Create: `iac/timecapsule/test_storage_conf.py`

- [ ] **Step 1: Write the failing test**

Create `iac/timecapsule/test_storage_conf.py`:

```python
"""Test that storage.conf.snippet has the exact additionalimagestores config."""
from pathlib import Path
import re

SNIPPET = Path(__file__).parent / "storage.conf.snippet"


def test_snippet_exists():
    assert SNIPPET.is_file()


def test_snippet_declares_overlay_driver():
    text = SNIPPET.read_text()
    assert re.search(r'^driver\s*=\s*"overlay"', text, re.MULTILINE)


def test_snippet_lists_timecapsule_store():
    text = SNIPPET.read_text()
    # Must list /s7/timecapsule/registry/store as an additional image store.
    assert re.search(
        r'additionalimagestores\s*=\s*\[\s*"/s7/timecapsule/registry/store"\s*\]',
        text,
    )


def test_snippet_uses_s7_graphroot():
    text = SNIPPET.read_text()
    assert re.search(
        r'graphroot\s*=\s*"/s7/\.local/share/containers/storage"',
        text,
    )
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /s7/skyqubi-private
python3 -m pytest iac/timecapsule/test_storage_conf.py -v
```

Expected: 4 failures, all "FileNotFoundError" or "snippet does not exist."

- [ ] **Step 3: Write `iac/timecapsule/storage.conf.snippet`**

```toml
# S7 storage.conf — TimeCapsule registry as additional image store.
#
# Drop this content into /etc/containers/storage.conf on the QUBi
# appliance. Replaces the [storage] and [storage.options] sections;
# leaves any other sections (runroot, etc.) untouched.
#
# Effect:
#   - Writable graphroot stays at /s7/.local/share/containers/storage
#     (runtime layers, volumes, containers — ephemeral S7 state)
#   - Read-only additional store at /s7/timecapsule/registry/store
#     (TimeCapsule images, populated at boot by s7-timecapsule-verify.sh)
#   - Podman searches both when resolving an image reference; runs
#     containers directly out of the additional store with zero copy.

[storage]
driver = "overlay"
graphroot = "/s7/.local/share/containers/storage"
runroot = "/run/containers/storage"

[storage.options]
additionalimagestores = ["/s7/timecapsule/registry/store"]
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /s7/skyqubi-private
python3 -m pytest iac/timecapsule/test_storage_conf.py -v
```

Expected: `4 passed`.

- [ ] **Step 5: Commit**

```bash
cd /s7/skyqubi-private
git add iac/timecapsule/storage.conf.snippet iac/timecapsule/test_storage_conf.py
git -c user.email=261467595+skycair-code@users.noreply.github.com \
    -c user.name=skycair-code \
    commit -m "feat(timecapsule): storage.conf snippet for additionalimagestores"
```

---

## Task 4: Boot verify script — skeleton with mocked GPG

**Files:**
- Create: `iac/timecapsule/s7-timecapsule-verify.sh`
- Create: `iac/timecapsule/test_verify.py`

- [ ] **Step 1: Write the failing tests**

Create `iac/timecapsule/test_verify.py`:

```python
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
                    # sha of b"BUSYBOX FAKE TAR"
                    "sha256": "f53cca7c9b2f37c1c3aa67c2e2cf5b6f8d7d5a3e3e4f7b9c0d1e2f3a4b5c6d7e",
                    "added_at": "2026-04-13T00:00:00Z",
                    "upstream": "quay.io/quay/busybox:latest",
                    "promote_to": "localhost/s7/busybox:1.36",
                }
            ],
        },
        {"busybox-1.36.tar": b"BUSYBOX FAKE TAR"},
    )
    # Pre-compute the actual sha and patch the manifest so we test the verify path,
    # not a typo above.
    import hashlib
    actual_sha = hashlib.sha256(b"BUSYBOX FAKE TAR").hexdigest()
    m = json.loads((reg / "manifest.json").read_text())
    m["images"][0]["sha256"] = actual_sha
    (reg / "manifest.json").write_text(json.dumps(m))

    result, podman_log = run_verify(reg, tmp_path)
    assert result.returncode == 0, f"stdout={result.stdout}\nstderr={result.stderr}"
    assert "verdict: ok" in result.stdout

    # Podman load was called against the additional store.
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
                    "sha256": "0" * 64,  # wrong on purpose
                    "added_at": "2026-04-13T00:00:00Z",
                    "upstream": "x",
                    "promote_to": "localhost/s7/busybox:1.36",
                }
            ],
        },
        {"busybox-1.36.tar": b"BUSYBOX FAKE TAR"},
    )
    result, podman_log = run_verify(reg, tmp_path)
    assert result.returncode == 0  # boot continues
    assert "verdict: fail" in result.stdout
    assert "sha256 mismatch" in result.stdout

    # Podman load was NOT called for the failing image.
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /s7/skyqubi-private
python3 -m pytest iac/timecapsule/test_verify.py -v
```

Expected: 4 failures, all because `s7-timecapsule-verify.sh` does not exist yet.

- [ ] **Step 3: Write `iac/timecapsule/s7-timecapsule-verify.sh`**

```bash
#!/usr/bin/env bash
# s7-timecapsule-verify.sh
# Boot-time TimeCapsule registry verification.
#
# Walks /s7/timecapsule/registry/manifest.json, GPG-verifies each tar
# against KEY.fingerprint, sha256-checks each tar, and `podman load`s
# any tar whose image is not yet in the additional store.
#
# Always exits 0 — broken images are logged but boot continues. Services
# that depend on a broken image will fail loudly when they try to start
# with --pull=never.
#
# Environment variables (for testing):
#   S7_TIMECAPSULE_REGISTRY  — override registry path (default /s7/timecapsule/registry)
#   S7_TIMECAPSULE_LOG       — override log path (default /var/log/s7/timecapsule.log)

set -uo pipefail

REGISTRY="${S7_TIMECAPSULE_REGISTRY:-/s7/timecapsule/registry}"
LOG="${S7_TIMECAPSULE_LOG:-/var/log/s7/timecapsule.log}"
MANIFEST="$REGISTRY/manifest.json"
KEY_FILE="$REGISTRY/KEY.fingerprint"
STORE="$REGISTRY/store"

mkdir -p "$(dirname "$LOG")"

log() { echo "$@" | tee -a "$LOG"; }

[[ -f "$MANIFEST" ]] || { log "no manifest at $MANIFEST — nothing to verify"; exit 0; }
[[ -f "$KEY_FILE" ]] || { log "FAIL: missing $KEY_FILE"; exit 0; }

KEY_FP=$(tr -d ' \n' < "$KEY_FILE")
COUNT=$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))['images']))" "$MANIFEST")

if [[ "$COUNT" == "0" ]]; then
  log "no images to verify"
  exit 0
fi

log "verifying $COUNT image(s) against key $KEY_FP"

# Iterate manifest entries via python (jq isn't guaranteed at boot).
python3 - "$MANIFEST" <<'PYEOF' | while IFS=$'\t' read -r NAME VERSION TAR SIG EXPECTED_SHA PROMOTE_TO; do
import json, sys
data = json.load(open(sys.argv[1]))
for e in data["images"]:
    print("\t".join([
        e["name"], e["version"], e["tar"], e["sig"],
        e["sha256"], e["promote_to"],
    ]))
PYEOF
  TAR_PATH="$REGISTRY/$TAR"
  SIG_PATH="$REGISTRY/$SIG"

  # ── Check 1: GPG verify ──
  if ! gpg --verify "$SIG_PATH" "$TAR_PATH" >/dev/null 2>&1; then
    log "  $NAME:$VERSION  verdict: fail  reason: gpg verification failed"
    continue
  fi

  # ── Check 2: sha256 ──
  ACTUAL_SHA=$(sha256sum "$TAR_PATH" | awk '{print $1}')
  if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
    log "  $NAME:$VERSION  verdict: fail  reason: sha256 mismatch (expected $EXPECTED_SHA got $ACTUAL_SHA)"
    continue
  fi

  # ── Load into additional store if not already present ──
  # We check by trying a no-op `podman --root <store> images <ref>` — exit 0 means present.
  if podman --root "$STORE" images --quiet "$PROMOTE_TO" 2>/dev/null | grep -q .; then
    log "  $NAME:$VERSION  verdict: ok  (already in store)"
  else
    if podman --root "$STORE" load -i "$TAR_PATH" >/dev/null 2>&1; then
      log "  $NAME:$VERSION  verdict: ok  (loaded into store)"
    else
      log "  $NAME:$VERSION  verdict: fail  reason: podman load failed"
    fi
  fi
done

log "verification complete"
exit 0
```

- [ ] **Step 4: Make script executable and run tests**

```bash
chmod +x /s7/skyqubi-private/iac/timecapsule/s7-timecapsule-verify.sh
cd /s7/skyqubi-private
python3 -m pytest iac/timecapsule/test_verify.py -v
```

Expected: `4 passed`. If a test fails, fix the script (not the test) until they all pass.

- [ ] **Step 5: Commit**

```bash
cd /s7/skyqubi-private
git add iac/timecapsule/s7-timecapsule-verify.sh iac/timecapsule/test_verify.py
git -c user.email=261467595+skycair-code@users.noreply.github.com \
    -c user.name=skycair-code \
    commit -m "feat(timecapsule): boot verify script + tests with mocked gpg+podman"
```

---

## Task 5: Real GPG round-trip test (no mocks)

**Files:**
- Modify: `iac/timecapsule/test_verify.py` — add one real-key test using a throwaway test keyring

- [ ] **Step 1: Add the failing test**

Append to `iac/timecapsule/test_verify.py`:

```python
def test_real_gpg_round_trip(tmp_path):
    """Generate a throwaway GPG key, sign a tar, run verify with the real key.

    This is the only test that uses real gpg (no mocks). It catches drift
    between the script's gpg invocation and the real tool's CLI.
    """
    import hashlib
    import json
    import shutil

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
```

- [ ] **Step 2: Run the new test**

```bash
cd /s7/skyqubi-private
python3 -m pytest iac/timecapsule/test_verify.py::test_real_gpg_round_trip -v
```

Expected: `1 passed`. If gpg complains about home permissions, the script's `chmod 0o700` on `gnupg/` should already handle it. If it complains about a missing pinentry, the `%no-protection` line should already handle it.

- [ ] **Step 3: Run the full verify test suite**

```bash
cd /s7/skyqubi-private
python3 -m pytest iac/timecapsule/test_verify.py -v
```

Expected: `5 passed` (4 mocked + 1 real round-trip).

- [ ] **Step 4: Commit**

```bash
cd /s7/skyqubi-private
git add iac/timecapsule/test_verify.py
git -c user.email=261467595+skycair-code@users.noreply.github.com \
    -c user.name=skycair-code \
    commit -m "test(timecapsule): real-gpg round-trip test for verify script"
```

---

## Task 6: systemd unit for the verifier

**Files:**
- Create: `iac/timecapsule/s7-timecapsule-verify.service`
- Create: `iac/timecapsule/test_systemd_unit.py`

- [ ] **Step 1: Write the failing test**

Create `iac/timecapsule/test_systemd_unit.py`:

```python
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
    # systemd-analyze verify exits 0 on success, prints warnings to stderr.
    # We require zero stderr lines that mention the unit file.
    bad = [
        line for line in result.stderr.splitlines()
        if str(UNIT) in line or "s7-timecapsule-verify" in line
    ]
    assert not bad, f"systemd-analyze warnings:\n" + "\n".join(bad)


def test_unit_orders_before_podman_socket():
    text = UNIT.read_text()
    assert "Before=podman.socket" in text or "Before=podman.service" in text


def test_unit_runs_the_script():
    text = UNIT.read_text()
    assert "/usr/local/sbin/s7-timecapsule-verify.sh" in text


def test_unit_is_oneshot():
    text = UNIT.read_text()
    assert "Type=oneshot" in text
```

- [ ] **Step 2: Run the failing test**

```bash
cd /s7/skyqubi-private
python3 -m pytest iac/timecapsule/test_systemd_unit.py -v
```

Expected: 5 failures, all "FileNotFoundError" or similar.

- [ ] **Step 3: Write the unit file**

Create `iac/timecapsule/s7-timecapsule-verify.service`:

```ini
[Unit]
Description=S7 TimeCapsule registry verification
Documentation=file:///s7/skyqubi-private/iac/timecapsule/README.md
DefaultDependencies=yes
After=local-fs.target
Before=podman.socket podman.service
ConditionPathExists=/s7/timecapsule/registry/manifest.json

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/s7-timecapsule-verify.sh
StandardOutput=journal
StandardError=journal
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 4: Run tests**

```bash
cd /s7/skyqubi-private
python3 -m pytest iac/timecapsule/test_systemd_unit.py -v
```

Expected: `5 passed` (or 4 passed + 1 skipped if `systemd-analyze` is absent).

- [ ] **Step 5: Commit**

```bash
cd /s7/skyqubi-private
git add iac/timecapsule/s7-timecapsule-verify.service iac/timecapsule/test_systemd_unit.py
git -c user.email=261467595+skycair-code@users.noreply.github.com \
    -c user.name=skycair-code \
    commit -m "feat(timecapsule): systemd unit + analyze test"
```

---

## Task 7: Modify pull-container.sh — TimeCapsule promote

**Files:**
- Modify: `iac/intake/pull-container.sh:119-138` (the `[3/4] promote` and `[4/4] clean` phases)
- Create: `iac/intake/test_pull_container_timecapsule.sh`

- [ ] **Step 1: Write the failing integration test**

Create `iac/intake/test_pull_container_timecapsule.sh`:

```bash
#!/usr/bin/env bash
# Integration test for pull-container.sh modified to write to TimeCapsule.
#
# Pulls a tiny real upstream image (quay.io/quay/busybox:latest) through
# the modified adapter, verifies the resulting signed tar lands in
# /tmp/test-timecapsule/registry/images/, and that manifest.json gains
# an entry. Cleans up after itself.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_REG="/tmp/test-timecapsule/registry"
ORIG_REG="${S7_TIMECAPSULE_REGISTRY:-}"

cleanup() {
  rm -rf /tmp/test-timecapsule
  podman --root /tmp/test-quarantine rmi --all --force 2>/dev/null || true
  rm -rf /tmp/test-quarantine
}
trap cleanup EXIT

# 1. Stage a fresh empty registry with the real KEY.fingerprint.
mkdir -p "$TEST_REG/images" "$TEST_REG/store"
echo '80F0291480E25C0F683E9714E11792E0AD945BE9' > "$TEST_REG/KEY.fingerprint"
echo '{"version": 1, "images": []}' > "$TEST_REG/manifest.json"

# 2. Pin busybox in a temporary manifest copy (don't touch the real one).
TEST_MANIFEST="/tmp/test-iac-manifest.yaml"
cp "$REPO/iac/manifest.yaml" "$TEST_MANIFEST"
# Need to compute the actual digest first.
DIGEST=$(podman manifest inspect quay.io/quay/busybox:latest \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("config",{}).get("digest","").replace("sha256:",""))' \
  || echo "")
test -n "$DIGEST" || { echo "FAIL: could not get busybox digest"; exit 1; }

python3 - "$TEST_MANIFEST" "$DIGEST" <<'PYEOF'
import sys, yaml
path, digest = sys.argv[1], sys.argv[2]
with open(path) as f: m = yaml.safe_load(f)
m.setdefault("intake", {}).setdefault("containers", []).append({
    "name": "quay.io/quay/busybox:latest",
    "sha256": digest,
    "promote_to": "localhost/s7/busybox:latest",
})
with open(path, "w") as f: yaml.safe_dump(m, f)
PYEOF

# 3. Run the adapter with the test registry + test manifest.
S7_TIMECAPSULE_REGISTRY="$TEST_REG" \
S7_INTAKE_MANIFEST="$TEST_MANIFEST" \
S7_QUARANTINE_ROOT=/tmp/test-quarantine/containers \
"$REPO/iac/intake/pull-container.sh" quay.io/quay/busybox:latest

# 4. Verify the artifacts.
TAR="$TEST_REG/images/busybox-latest.tar"
SIG="$TAR.sig"
test -f "$TAR" || { echo "FAIL: tar not written to $TAR"; exit 1; }
test -f "$SIG" || { echo "FAIL: sig not written to $SIG"; exit 1; }

# Verify the sig against the real key.
gpg --verify "$SIG" "$TAR" || { echo "FAIL: sig does not verify"; exit 1; }

# Verify the manifest entry.
ENTRY=$(python3 -c "
import json
m = json.load(open('$TEST_REG/manifest.json'))
matches = [e for e in m['images'] if e['name']=='busybox' and e['version']=='latest']
assert len(matches) == 1, f'expected 1 entry, got {len(matches)}'
print(json.dumps(matches[0]))
")
echo "$ENTRY" | python3 -m json.tool

echo "PASS: pull-container.sh writes signed tar + manifest entry to TimeCapsule"
```

- [ ] **Step 2: Run the failing test**

```bash
chmod +x /s7/skyqubi-private/iac/intake/test_pull_container_timecapsule.sh
/s7/skyqubi-private/iac/intake/test_pull_container_timecapsule.sh
```

Expected: FAIL — the current `pull-container.sh` does not honor `S7_TIMECAPSULE_REGISTRY` or `S7_INTAKE_MANIFEST`, and its promote phase does `podman load` into the live graphroot, not a tar+sig into TimeCapsule.

- [ ] **Step 3: Modify `iac/intake/pull-container.sh`**

Replace lines 119–147 (the `[3/4] promote` and `[4/4] clean quarantine` phases). The existing file has these phases doing `podman save → podman load → podman tag` into the live graphroot. The new version writes a signed tar + signature file into TimeCapsule and updates the manifest via `timecapsule_manifest.py`.

The new `[3/4]` and `[4/4]` phases:

```bash
# ── Phase 4: promote (save → sign → manifest into TimeCapsule) ──
echo
echo "[3/4] promote → TimeCapsule"
TIMECAPSULE_REG="${S7_TIMECAPSULE_REGISTRY:-/s7/timecapsule/registry}"
KEY_FP=$(tr -d ' \n' < "$TIMECAPSULE_REG/KEY.fingerprint" 2>/dev/null || echo "")
[[ -n "$KEY_FP" ]] || { echo "FAIL: TimeCapsule KEY.fingerprint missing at $TIMECAPSULE_REG/KEY.fingerprint" >&2; exit 2; }

# Derive name+version from PROMOTE_TO (localhost/s7/<name>:<version>)
TC_NAME=$(echo "$PROMOTE_TO" | sed -E 's|^localhost/s7/([^:]+):.*$|\1|')
TC_VERSION=$(echo "$PROMOTE_TO" | sed -E 's|^localhost/s7/[^:]+:(.+)$|\1|')
TC_TAR="$TIMECAPSULE_REG/images/${TC_NAME}-${TC_VERSION}.tar"
TC_SIG="${TC_TAR}.sig"

if $DRY_RUN; then
  echo "  [dry-run] podman --root '$QUARANTINE_ROOT' save '$REF' -o '$TC_TAR'"
  echo "  [dry-run] gpg --detach-sign --armor --local-user '$KEY_FP' -o '$TC_SIG' '$TC_TAR'"
  echo "  [dry-run] timecapsule_manifest add-entry $TC_NAME $TC_VERSION ..."
else
  mkdir -p "$(dirname "$TC_TAR")"
  podman --root "$QUARANTINE_ROOT" save -o "$TC_TAR" "$REF"
  gpg --batch --yes --detach-sign --armor \
      --local-user "$KEY_FP" \
      -o "$TC_SIG" \
      "$TC_TAR"

  PYTHONPATH="$REPO" python3 -m iac.timecapsule.timecapsule_manifest_cli add-entry \
    --manifest "$TIMECAPSULE_REG/manifest.json" \
    --name "$TC_NAME" \
    --version "$TC_VERSION" \
    --tar "$TC_TAR" \
    --sig "$TC_SIG" \
    --upstream "$REF" \
    --promote-to "$PROMOTE_TO"
  echo "  wrote $TC_TAR + .sig + manifest entry"
fi

# ── Phase 5: clean quarantine copy ──
echo
echo "[4/4] clean quarantine"
if $DRY_RUN; then
  echo "  [dry-run] podman --root '$QUARANTINE_ROOT' rmi '$REF'"
else
  podman --root "$QUARANTINE_ROOT" rmi "$REF" >/dev/null 2>&1 || true
fi

echo
echo "═════════════════════════════════════════════════════"
echo "  intake complete: $REF → TimeCapsule:$TC_NAME:$TC_VERSION"
echo "═════════════════════════════════════════════════════"
```

Also: at the top of the script, after the existing `MANIFEST=...` line, add:

```bash
# Allow override for testing.
MANIFEST="${S7_INTAKE_MANIFEST:-$REPO/iac/manifest.yaml}"
```

(replacing the existing unconditional `MANIFEST="$REPO/iac/manifest.yaml"`).

- [ ] **Step 4: Add the CLI shim for the manifest module**

The integration test (and the modified shell script) call `python3 -m iac.timecapsule.timecapsule_manifest_cli`. Create `iac/timecapsule/timecapsule_manifest_cli.py`:

```python
"""CLI shim around timecapsule_manifest.Manifest, used by pull-container.sh.

Usage:
  python3 -m iac.timecapsule.timecapsule_manifest_cli add-entry \\
    --manifest /s7/timecapsule/registry/manifest.json \\
    --name busybox --version latest \\
    --tar /s7/timecapsule/registry/images/busybox-latest.tar \\
    --sig /s7/timecapsule/registry/images/busybox-latest.tar.sig \\
    --upstream quay.io/quay/busybox:latest \\
    --promote-to localhost/s7/busybox:latest
"""
import argparse
import sys
from pathlib import Path

from iac.timecapsule.timecapsule_manifest import Manifest, ManifestError


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    add = sub.add_parser("add-entry")
    add.add_argument("--manifest", type=Path, required=True)
    add.add_argument("--name", required=True)
    add.add_argument("--version", required=True)
    add.add_argument("--tar", type=Path, required=True)
    add.add_argument("--sig", type=Path, required=True)
    add.add_argument("--upstream", required=True)
    add.add_argument("--promote-to", required=True, dest="promote_to")

    args = parser.parse_args()
    if args.cmd == "add-entry":
        try:
            m = Manifest.load(args.manifest)
            m.add_entry(
                name=args.name, version=args.version,
                tar_path=args.tar, sig_path=args.sig,
                upstream=args.upstream, promote_to=args.promote_to,
            )
            m.save()
        except ManifestError as e:
            print(f"FAIL: {e}", file=sys.stderr)
            return 1
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
```

Also create `iac/__init__.py` and `iac/timecapsule/__init__.py` as empty files if they don't already exist, so the `python3 -m iac.timecapsule.timecapsule_manifest_cli` import path works:

```bash
touch /s7/skyqubi-private/iac/__init__.py /s7/skyqubi-private/iac/timecapsule/__init__.py
```

- [ ] **Step 5: Run the integration test**

```bash
/s7/skyqubi-private/iac/intake/test_pull_container_timecapsule.sh
```

Expected: `PASS: pull-container.sh writes signed tar + manifest entry to TimeCapsule`

If it fails on `podman manifest inspect quay.io/quay/busybox:latest` (network or rate limit), substitute any locally available small image: `quay.io/skopeo/stable:latest` or `docker.io/library/hello-world:latest`. The point of the test is the adapter behavior, not the specific image.

- [ ] **Step 6: Run the full test suite to confirm no regressions**

```bash
cd /s7/skyqubi-private
python3 -m pytest iac/timecapsule/ -v
```

Expected: all green (the count from earlier tasks: ~16 tests).

- [ ] **Step 7: Commit**

```bash
cd /s7/skyqubi-private
git add iac/intake/pull-container.sh \
        iac/intake/test_pull_container_timecapsule.sh \
        iac/timecapsule/timecapsule_manifest_cli.py \
        iac/__init__.py \
        iac/timecapsule/__init__.py
git -c user.email=261467595+skycair-code@users.noreply.github.com \
    -c user.name=skycair-code \
    commit -m "feat(intake): promote into TimeCapsule via signed tar + manifest"
```

---

## Task 8: Run the full standard pipeline as the end-of-plan gate

**Goal:** Prove Plan A's commits don't break the existing local→private→public→precheck→lifecycle→postcheck→base-build pipeline. This is the same gate every change to S7 has to pass; Plan A doesn't get a free ride.

**The "boot server" stage is intentionally NOT in Plan A's gate** — Plan A only adds files (TimeCapsule layout, manifest module, verify script, modified intake adapter). No service consumes TimeCapsule yet at the OS-image level, so a real boot would not exercise the new code. The boot-server gate runs in Plan B (where services start consuming TimeCapsule from the bootc image).

**Files:** none new. This task only runs existing scripts in order.

- [ ] **Step 1: Pre-check audit**

```bash
cd /s7/skyqubi-private
bash iac/audit-pre.sh
```

Expected: exit 0, "PASS" lines for every checked invariant. If audit-pre catches a drift, fix the drift before proceeding (do not bypass the audit).

- [ ] **Step 2: Confirm working tree is clean (private)**

```bash
cd /s7/skyqubi-private
git status --short
```

Expected: empty output. If anything is uncommitted, that's a Plan A task that wasn't committed — go back and commit it. Do not bundle.

- [ ] **Step 3: Sync to public repo**

```bash
cd /s7/skyqubi-private
bash s7-sync-public.sh
```

Expected: either "No changes" (if nothing public-facing changed — likely for Plan A, since everything is in `iac/timecapsule/` and `iac/intake/` which may or may not be public-mirrored) or a clean push to skyqubi-public with no errors.

- [ ] **Step 4: Confirm working tree is clean (public)**

```bash
cd /s7/skyqubi-public
git status --short
```

Expected: empty output.

- [ ] **Step 5: Run the lifecycle test suite**

```bash
cd /s7/skyqubi-private
bash s7-lifecycle-test.sh
```

Expected: every numbered test (R01, R02, R03, K01, K02, S01–S06, etc.) prints PASS, and the final line says `N/N PASS — LIFECYCLE VERIFIED`. The script exits 0.

If R01/R02 fail with "private/public repo not clean", that means a previous task left untracked files — go back and commit them as part of the right task, do not add a "cleanup commit."

- [ ] **Step 6: Post-check audit**

```bash
cd /s7/skyqubi-private
bash iac/audit-post.sh
```

Expected: exit 0, every invariant verified.

- [ ] **Step 7: Build the Fedora bootc base image**

```bash
cd /s7/skyqubi-private
bash iac/build-s7-base.sh
```

Expected: build completes, image tagged `localhost/s7-base:<version>`, audit-post inside the build script passes. This proves the new files in `iac/` haven't broken the existing image-build path.

If this build was already cached (recall store hit), the script reports a HIT and exits — that is also a pass.

- [ ] **Step 7b: Lightweight image boot smoke check**

```bash
# Confirm the freshly-built image at least starts. Not a real service boot
# (Plan B0 covers that) — just "does this image execute /bin/true without
# crashing." Proves Plan A didn't break the image's runnability.
LATEST=$(podman images --format '{{.Repository}}:{{.Tag}}' | grep '^localhost/s7-base:' | head -1)
test -n "$LATEST" || { echo "FAIL: no localhost/s7-base image found"; exit 1; }
podman run --rm "$LATEST" /bin/true
echo "smoke check: $LATEST runs /bin/true OK"
```

Expected: `smoke check: localhost/s7-base:<version> runs /bin/true OK`. If podman exits non-zero, the bootc image is broken — fix that before claiming Plan A green.

- [ ] **Step 8: Final lifecycle re-run after the build**

```bash
cd /s7/skyqubi-private
bash s7-lifecycle-test.sh
```

Expected: same as Step 5 — every test still passes after the build. The build should not have left untracked files or modified the working tree.

- [ ] **Step 9: Append the Plan A completion marker to the lifecycle log**

```bash
echo "═══ Plan A — TimeCapsule foundation + intake — COMPLETE $(date -u +%Y-%m-%dT%H:%M:%SZ) ═══" \
  >> /s7/skyqubi-private/docs/internal/superpowers/plans/2026-04-13-timecapsule-registry-plan-a.md
cd /s7/skyqubi-private
git add docs/internal/superpowers/plans/2026-04-13-timecapsule-registry-plan-a.md
git -c user.email=261467595+skycair-code@users.noreply.github.com \
    -c user.name=skycair-code \
    commit -m "chore(plan-a): mark Plan A complete after green pipeline gate"
```

This commit is the only one in Task 8. The pipeline scripts produce no file changes of their own when they pass; the marker line is the auditable record that Plan A finished green.

---

## Verification (end of Plan A)

After all 7 tasks are committed, the following must all be true:

```bash
# 1. All Plan A tests pass.
cd /s7/skyqubi-private && python3 -m pytest iac/timecapsule/ -v
# Expected: ~16 passed.

# 2. The integration test passes (real upstream pull → TimeCapsule).
/s7/skyqubi-private/iac/intake/test_pull_container_timecapsule.sh
# Expected: PASS line at the bottom.

# 3. The TimeCapsule directory exists and has the right shape.
ls -la /s7/timecapsule/registry/
# Expected: KEY.fingerprint, manifest.json, images/, store/

# 4. The systemd unit verifies clean.
systemd-analyze verify /s7/skyqubi-private/iac/timecapsule/s7-timecapsule-verify.service
# Expected: no warnings about the unit file.

# 5. Existing intake gate still works for the original case (Fedora base).
grep -A3 'fedora-minimal' /s7/skyqubi-private/iac/manifest.yaml
# Expected: the existing entry is unchanged.

# 6. No service is migrated yet — the running 6 services are untouched.
podman ps --format '{{.Names}}' | sort
# Expected: same containers as before Plan A.

# 7. Lifecycle tests pass.
cd /s7/skyqubi-private && bash iac/lifecycle.sh
# Expected: all green.
```

---

## What Plan A leaves for Plans B/C/D

- **Plan B**: Recreate the `qubi` podman network at 172.16.7.0/27, run the new intake flow against the 6 real services, update pod YAML + standalone start scripts to point at `localhost/s7/...` with `--pull=never`, retire the upstream-tagged copies.
- **Plan C**: Build the `localhost/s7/vivaldi:<version>` image, run it through the new intake flow, write `/usr/local/bin/s7-launch`, change the `s7.desktop` Exec line.
- **Plan D**: Add the `qubi_service_guardian` skill to Samuel, wire it into his skill registry, add the SPA notifications surface for tier-3 escalation.

Each subsequent plan can begin only after Plan A's verification block is green.
