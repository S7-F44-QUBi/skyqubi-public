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
