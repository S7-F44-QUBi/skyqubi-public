# iac/intake — The S7 Intake Gate

> **Trust nothing on first pull.**
> `podman pull`, `npm install`, `pip install`, `dnf install` — every one
> of them has shipped malicious code to a "trusted" ecosystem in the
> last five years. event-stream, ua-parser-js, colors.js, node-ipc,
> Lottie Player. npm alone is enough argument.

S7 does not let upstream code touch live storage directly. Every
inbound artifact lands in a **quarantine** area first, passes a
**gate**, and only then is **promoted** into the place where S7
services actually use it. Same shape for containers, npm, pip, rpm,
gem, git submodules. One gate, many adapters.

## Architecture

```
   upstream source
         │
         ▼
  ┌──────────────┐    quarantine area
  │   adapter    │    iac/intake/quarantine/<kind>/
  │  (pull step) │          │
  └──────────────┘          ▼
                    ┌──────────────────┐
                    │   gate checks    │
                    │  1. hash pin     │  ← iac/manifest.yaml intake:
                    │  2. signature    │  ← allowlist in manifest
                    │  3. vuln scan    │  ← optional (trivy, osv)
                    │  4. SBOM diff    │  ← optional (phase 2)
                    └──────────────────┘
                          │
                    pass  │  fail
                     ┌────┴────┐
                     ▼         ▼
              promote to    reject +
              live area     decision log
                     │
                     ▼
              S7 uses it
```

## Contract

Every adapter MUST:

1. **Pull into quarantine, never into live storage.** For containers
   this means `podman --root <quarantine>` or a separate graph root.
   For npm this means a throwaway `node_modules/` directory. For
   Python a temporary venv. The adapter decides HOW, but the
   destination MUST NOT be a path any service consults directly.

2. **Emit an intake descriptor** (JSON one-liner) to stdout on success:
   ```json
   {
     "kind": "container",
     "name": "quay.io/fedora/fedora-minimal:44",
     "quarantine_ref": "localhost/_intake_fedora-minimal:44",
     "sha256": "659eef30e5bf713e98557c1b324738d462a41607bf60ac9d8955d5a9516b9c8e",
     "size_bytes": 83886080,
     "pulled_at": "2026-04-12T22:30:00Z"
   }
   ```

3. **Exit non-zero if the pull itself failed.** Connectivity errors,
   registry 404s, disk-full — those are pull failures, not gate
   failures.

Every gate run MUST:

1. **Read** the intake descriptor and locate the pinned entry in
   `iac/manifest.yaml` under the `intake:` section (by kind + name).

2. **Check** each pinned field against the actual artifact in
   quarantine. Order: cheapest first (hash → signature → scan).

3. **Log** a decision record to `iac/intake/decisions/<iso-date>.ndjson`
   — one JSON line per intake, with kind/name/verdict/reasons. This
   is the audit trail.

4. **Return** exit 0 on pass, exit 1 on fail. The adapter is
   responsible for the promote step on pass and the reject step on
   fail.

## manifest.yaml schema

```yaml
intake:
  containers:
    - name: quay.io/fedora/fedora-minimal:44
      sha256: 659eef30e5bf713e98557c1b324738d462a41607bf60ac9d8955d5a9516b9c8e
      signing_key_fingerprint_prefix: "4F2E 4CD1 6A0F 1E57"
      promote_to: localhost/fedora-minimal:44
  npm:
    - name: react@18.2.0
      sha256: "..."       # from the package's .integrity field
      promote_to: /s7/skyqubi-private/frontend/node_modules_live/react
  pip:
    - name: fastapi==0.110.0
      sha256: "..."
      promote_to: /s7/.local/share/s7-venvs/live/fastapi
```

Unpinned artifacts cannot pass the gate. That is the point.

## Adapters currently in this directory

| File | Kind | Status |
|---|---|---|
| `pull-container.sh` | container | working (uses podman, no skopeo/trivy required) |
| `pull-npm.sh`       | npm       | not yet implemented |
| `pull-pip.sh`       | pip       | not yet implemented |
| `pull-git.sh`       | git       | not yet implemented |
| `gate.sh`           | (shared)  | working |

## Promote strategy (containers, no skopeo)

Quarantine and live storage are separate podman graph roots:

- `iac/intake/quarantine/containers/` — quarantine graph root
- `/s7/.local/share/containers/storage/` — live graph root (the normal one)

Promotion path (airlock — no registry contact after verification):

```
podman --root <quarantine> save <ref> -o /tmp/s7-intake.tar
podman --root <live>       load < /tmp/s7-intake.tar
rm /tmp/s7-intake.tar
podman --root <live> tag   <loaded-ref> <promote_to>
```

This is an on-disk copy that inherits nothing from the upstream
registry beyond what the gate already blessed. No surprises at run
time.

## Decision log

Every gate run appends one line to `iac/intake/decisions/<date>.ndjson`:

```json
{"ts":"2026-04-12T22:30:00Z","kind":"container","name":"quay.io/fedora/fedora-minimal:44","verdict":"pass","sha256_ok":true,"sig_ok":true,"scan_ok":"skipped","size_bytes":83886080}
{"ts":"2026-04-12T22:31:00Z","kind":"container","name":"some/other:image","verdict":"fail","sha256_ok":false,"reason":"sha256 mismatch: expected XXX, got YYY"}
```

`decisions/` is committed to the repo. A bad gate decision stays in
the history — you can always go back and ask "what did we pull, and
why did we trust it?"

## What this does NOT do yet

- **No vulnerability scanner** (trivy/osv/grype) — this is phase 2.
  `scan_ok` in the decision log is currently always `"skipped"`.
- **No SBOM diff** — phase 3. Would require keeping a signed SBOM
  per approved version.
- **No behavior sandbox** — phase 4. Would require running the image
  in a network-less container and inspecting syscalls.
- **No adapters for npm/pip/rpm/git yet** — the contract is in place;
  adapters come next.

Those are not excuses. They are the correct order: lock in the
tampering gate first (hash + signature, which you already have), then
stack the richer checks on top of the same promote path without
breaking anything.
