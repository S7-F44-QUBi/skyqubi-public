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


if __name__ == "__main__":
    sys.exit(main())
