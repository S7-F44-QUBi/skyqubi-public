# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 2.x     | Yes       |
| < 2.0   | No        |

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

Please report security issues by emailing:

**omegaanswers@123tech.net**

Include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Response Timeline

| Action | Target |
|--------|--------|
| Acknowledgment | 48 hours |
| Initial assessment | 7 days |
| Fix for critical issues | 14 days |
| Public disclosure | After fix is released |

## Scope

The following are in scope:

- CWS Engine (`engine/`)
- Pod configuration (`skyqubi-pod.yaml`)
- Install scripts (`install/`)
- Systemd service files (`services/`)
- Caddy configuration

The following are out of scope:

- Upstream dependencies (Ollama, PostgreSQL, Redis, Qdrant, N.O.M.A.D)
- Fedora OS vulnerabilities
- Issues requiring physical access to the machine

## Security Design Principles

S7 SkyQUB*i* follows a **zero-trust per-endpoint** model. There is no perimeter security; every endpoint independently authenticates the caller and emits opaque error responses.

- **Endpoint auth:** Every protected endpoint requires its own credential (the CWS Engine bearer token model). No "trusted internal network" assumption.
- **Localhost-only by default:** All services bind to `127.0.0.1` — this is the *second* layer of defense, never the first.
- **No stack trace exposure:** A global FastAPI exception handler returns generic 500 responses; full traces are logged server-side only. Validated by CodeQL.
- **Path validation:** User-supplied file paths are resolved via `os.path.realpath` and validated against an allowlist. No path injection surface.
- **Secret hygiene:** Secrets generated locally with cryptographically secure randomness, stored in mode-600 files, never committed to git.
- **Rootless containers:** Podman runs without a privileged daemon. No root capabilities anywhere.
- **INSERT-only data:** The CWS Engine's molecular bond table is append-only — nothing that entered the system can be made to have never existed.
- **Signed commits:** The public repository requires verified GPG signatures on every commit (`required_signatures: true` on `main`). Contributors sign with keys uploaded to GitHub.
- **No telemetry:** No analytics, no phone-home, no outbound connections beyond what the user explicitly initiates.
- **DNS-layer security:** Production deployments resolve via Quad9 (`9.9.9.9`, `149.112.112.112`) — non-commercial threat-intelligence-blocked, no logs.

## Disclosure Policy

We follow coordinated disclosure. We will:

1. Confirm receipt of your report
2. Investigate and determine impact
3. Develop and test a fix
4. Release the fix before public disclosure
5. Credit you in the release notes (unless you prefer anonymity)

Thank you for helping keep SkyQUBi secure.
