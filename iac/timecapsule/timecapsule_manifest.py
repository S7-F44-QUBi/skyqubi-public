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

import jsonschema

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
