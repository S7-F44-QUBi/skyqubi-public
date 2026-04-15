# Ribbon-Gated Cloud of AI Chat — Design

**Date:** 2026-04-13
**Author:** Claude (with Jamie)
**Status:** Draft, awaiting review
**Source:** Jamie, 2026-04-13: *"Measured against FIPS / CIS / HIPPA Security Boot Chain successful 1st Place Ribbon from Website the Cloud can be a chat windows"*

## The reframe

The persona chat (Carli / Elias / Samuel with avatars and emojis) is **not a feature to add to the existing `/chat` page**. It is the **reward** for the appliance having measurably earned its sovereignty.

```
FIPS check passes
+ CIS benchmark passes
+ HIPAA technical safeguards pass
+ Secure Boot Chain verified (TimeCapsule + GPG + boot-verify + Quadlet)
        ↓
S7 1st Place Ribbon awarded
        ↓
"Cloud of AI Happy to Evolve" UNLOCKS
        ↓
The Cloud IS a chat window — the persona chat with avatars
```

When the ribbon is held the cloud is open. When **any** measurement breaks the cloud closes immediately and the personas disappear until the measurements come back green. The covenant is binary: no proof of safety → no AI talking to the family.

## Goal

Build a measurement → ledger → unlock → UI chain so that:

1. The S7 appliance can run a unified `iac/compliance/ribbon-measure.sh` that exercises every measurement the covenant requires, computes a single verdict, and writes a hash-chained row to a `ribbons` ledger
2. The current ribbon state (HELD or REVOKED) is queryable from one place
3. The persona chat UI consults that state on every page load — open if HELD, closed with a "X measurements failing" message if REVOKED
4. When open, the chat shows three personas (Carli / Elias / Samuel) with their model, emoji, and an avatar that can be dropped in via drag-drop and persists across sessions

**Out of scope for this design** (deliberately):

- Mobile app version
- Per-family-member persona customization
- Voice synthesis / audio personas
- Cross-appliance ribbon synchronization
- The actual FIPS / CIS / HIPAA compliance scripts themselves (Phase 1 of the implementation builds the framework; the per-standard scripts are their own follow-up work)

## Architecture

### The four stages, in dependency order

```
Stage 1 — Measurement Framework
    iac/compliance/{fips,cis,hipaa,secure-boot-chain}-check.sh
    iac/compliance/ribbon-measure.sh   (orchestrator)
                  ↓
Stage 2 — Ribbon Ledger
    engine/sql/s7-ribbons.sql
    ribbons.measurements table        (INSERT-only, hash-chained)
    ribbons.current_state view        (latest row → HELD or REVOKED)
                  ↓
Stage 3 — Cloud API
    /api/cloud/status                 (reads ribbons.current_state)
    /api/personas                     (only when cloud open)
    /api/personas/:slug/avatar        (multipart upload)
                  ↓
Stage 4 — Cloud UI
    The existing /chat page becomes ribbon-aware
    Cloud closed → "X measurements failing" page
    Cloud open → persona switcher with avatars, drag-drop upload
```

Each stage tests the previous one. None of them get built in isolation.

### Stage 1 — Measurement Framework

A new directory `iac/compliance/` containing one script per standard plus an orchestrator:

| Script | What it checks | Source of truth |
|---|---|---|
| `fips-check.sh` | Kernel FIPS mode (`/proc/sys/crypto/fips_enabled`), openssl FIPS provider, libgcrypt FIPS mode | NIST SP 800-140 |
| `cis-check.sh` | CIS Distribution Independent Linux Benchmark — the subset that applies to a Fedora 44 appliance: filesystem hardening, services, network, logging, access control, password policy | CIS DIL Benchmark v3.x |
| `hipaa-check.sh` | HIPAA technical safeguards: encryption at rest (LUKS root + signed TimeCapsule), audit log retention (`audit.file_change_history` not truncated), access controls (locked root, nologin shell, mode 0750 on /etc/s7), automatic logoff (idle policy), unique user identification (UID 1000) | 45 CFR § 164.312 |
| `secure-boot-chain-check.sh` | Wraps existing checks: TimeCapsule manifest verifies cleanly, every signed tar's GPG verifies against the known key, boot-verify systemd unit ran successfully on this boot, Quadlet container images all match the additionalimagestores entries | Existing TimeCapsule + GPG + Quadlet machinery |
| `ribbon-measure.sh` | Orchestrator: runs all four, captures pass/fail for each, computes `all_green`, writes a ledger row | Internal |

Each per-standard script:
- Exit code 0 = pass, 1 = fail, 2 = skipped (e.g., HIPAA skipped on a non-medical deployment)
- Standard JSON output to stdout: `{"standard":"fips","verdict":"pass","checks_run":N,"failures":[...],"ts":"..."}`
- Logs to `/var/log/s7/compliance/<standard>-<date>.log` (rootless: `~/.local/state/s7/compliance/...`)

The orchestrator `ribbon-measure.sh`:
- Runs the four scripts (parallel where safe, sequential where stateful)
- Reads each script's JSON output
- Computes the verdict: `all_green = fips_ok && cis_ok && hipaa_ok && sbc_ok`
- INSERTs a row into `ribbons.measurements` (see Stage 2)
- Echoes a one-line summary

The four per-standard scripts can be implemented **incrementally**. Stage 1 ships the orchestrator + stub scripts that each return a "PASS — placeholder" verdict, so the rest of the architecture can be built and tested. The real compliance scripts get implemented one at a time, in their own follow-up plans, as the standards demand.

### Stage 2 — Ribbon Ledger

A new SQL schema in postgres (the cube DB):

```sql
CREATE SCHEMA IF NOT EXISTS ribbons;

CREATE TABLE ribbons.measurements (
    id              BIGSERIAL PRIMARY KEY,
    ts              TIMESTAMPTZ NOT NULL DEFAULT now(),
    fips_ok         BOOLEAN NOT NULL,
    cis_ok          BOOLEAN NOT NULL,
    hipaa_ok        BOOLEAN NOT NULL,
    sbc_ok          BOOLEAN NOT NULL,
    all_green       BOOLEAN GENERATED ALWAYS AS
                        (fips_ok AND cis_ok AND hipaa_ok AND sbc_ok) STORED,
    failure_summary TEXT,
    measured_by     TEXT NOT NULL,            -- script that wrote the row
    prev_row_hash   TEXT,                     -- hash chain
    row_hash        TEXT NOT NULL             -- sha256(canonical(this row))
);

CREATE INDEX ribbons_measurements_ts ON ribbons.measurements (ts DESC);

CREATE OR REPLACE VIEW ribbons.current_state AS
SELECT
    id,
    ts,
    all_green,
    CASE WHEN all_green THEN 'HELD' ELSE 'REVOKED' END AS ribbon_state,
    failure_summary,
    fips_ok, cis_ok, hipaa_ok, sbc_ok
FROM ribbons.measurements
ORDER BY ts DESC
LIMIT 1;
```

INSERT-only, hash-chained like `audit.file_change_history`. The `current_state` view is a single-row read that any consumer can use to ask "is the ribbon held right now?"

The hash chain matters: nobody can fake a ribbon by editing a row, because the row_hash includes the prev_row_hash and any tampering breaks the chain.

### Stage 3 — Cloud API

Three new endpoints in the SPA's AdonisJS backend:

```
GET  /api/cloud/status
     → 200 {"open": true,  "ribbon_state": "HELD",     "ts": "...", "measured_by": "..."}
     → 200 {"open": false, "ribbon_state": "REVOKED",  "ts": "...", "failures": [...]}

GET  /api/personas
     → 200 [{"slug":"carli","name":"Carli","model":"s7-carli:0.6b","emoji":"🌊","avatar_url":"..."},
            {"slug":"elias","name":"Elias","model":"s7-elias:1.3b","emoji":"🛡️","avatar_url":"..."},
            {"slug":"samuel","name":"Samuel","model":"qwen2.5:3b","emoji":"⚙️","avatar_url":"..."}]
     → 403 if cloud is closed (ribbon REVOKED)

POST /api/personas/:slug/avatar
     Content-Type: multipart/form-data
     → 200 {"slug":"carli","avatar_url":"/personas/carli.png","saved_at":"..."}
     → 403 if cloud is closed
     → 400 if file is not an image / too large / wrong dimensions
```

Avatar files saved to `/s7/.local/share/s7-personas/avatars/<slug>.png`, served as static files by Caddy mounted under `/personas/<slug>.png`.

A new `personas` table in mysql (the SPA DB) with the seed rows:

```sql
CREATE TABLE personas (
    id              INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    slug            VARCHAR(64) NOT NULL UNIQUE,
    name            VARCHAR(128) NOT NULL,
    model           VARCHAR(128) NOT NULL,
    emoji           VARCHAR(16) NOT NULL,
    avatar_path     VARCHAR(512),
    voice_description TEXT,
    plane           SMALLINT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO personas (slug, name, model, emoji, voice_description, plane) VALUES
    ('carli',  'Carli',  's7-carli:0.6b',  '🌊', 'The free one. Warm, sharp, direct. Primary witness.', 1),
    ('elias',  'Elias',  's7-elias:1.3b',  '🛡️', 'Sharp, protective, methodical. Second witness.', 2),
    ('samuel', 'Samuel', 'qwen2.5:3b',     '⚙️', 'System voice. Sysadmin persona. Operates the appliance.', 0);
```

### Stage 4 — Cloud UI

Modify the existing `/chat` page in the SPA to be ribbon-aware:

- On page load, fetch `GET /api/cloud/status`
- If `open: false`: render a "🔒 Cloud is closed" page with the failure summary, a list of which measurements failed, and a "Re-measure" button that POSTs to `/api/cloud/remeasure` (which kicks off `ribbon-measure.sh` in the background)
- If `open: true`: fetch `GET /api/personas` and render the chat with a persona switcher above the input. Each persona card shows: emoji, name, avatar (or a default placeholder), model badge. Drag a photo onto a persona card and it uploads via `POST /api/personas/:slug/avatar`. Click a persona card to start a chat session with that persona (sets `chat_sessions.model` and `chat_sessions.persona_id`).

The chat conversation flow stays the same as today (`POST /api/ollama/chat` with the persona's model). The only added concept is the **persona** wrapping the model — same Ollama call, but with a friendly face on top.

When the ribbon transitions HELD → REVOKED while a chat is open, the next user message gets an interrupt: the cloud closes, the chat is archived (not deleted), the user sees the closed-cloud page. When the ribbon comes back HELD, the archived chat is recoverable.

## File structure

| Path | Stage | Responsibility |
|---|---|---|
| `iac/compliance/README.md` | 1 | Doc — what the compliance framework does, how scripts are structured |
| `iac/compliance/fips-check.sh` | 1 | FIPS measurement (stub initially) |
| `iac/compliance/cis-check.sh` | 1 | CIS measurement (stub initially) |
| `iac/compliance/hipaa-check.sh` | 1 | HIPAA measurement (stub initially) |
| `iac/compliance/secure-boot-chain-check.sh` | 1 | SBC measurement (real on day one — wraps existing tools) |
| `iac/compliance/ribbon-measure.sh` | 1 | Orchestrator |
| `engine/sql/s7-ribbons.sql` | 2 | postgres schema + view |
| `engine/sql/test-ribbons.sql` | 2 | smoke test for the schema |
| `iac/admin/migrations/personas.sql` | 3 | mysql migration adding the personas table + seed rows |
| `engine/cloud_api.py` | 3 | Tiny FastAPI app exposing /api/cloud/status, /api/personas, avatar upload — runs as a separate systemd USER unit on its own port, proxied via Caddy |
| `iac/host-state/cloud-page/index.html` | 4 | Standalone /cloud page (Stage 4 minimal — full SPA integration is later) |
| `iac/host-state/systemd-user/s7-cloud-api.service` | 3 | systemd USER unit for the cloud_api service |
| `iac/host-state/caddy/Caddyfile.d/cloud.conf` | 3 | Caddy snippet routing /cloud → the cloud-api service |

## Phasing — three sub-plans

This is too large for a single plan. Three sequential sub-plans:

### Plan R1 — Measurement Framework + Ribbon Ledger
- Build `iac/compliance/` directory with stub scripts
- Build `secure-boot-chain-check.sh` for real (it just wraps existing TimeCapsule verify + GPG check + Quadlet container image audit)
- Build `ribbon-measure.sh` orchestrator
- Build `engine/sql/s7-ribbons.sql` schema in postgres
- Build the test that runs the orchestrator and verifies a row lands in the ledger with the right verdict
- **Outcome**: `bash iac/compliance/ribbon-measure.sh` writes a row. `psql -c 'SELECT * FROM ribbons.current_state;'` shows HELD or REVOKED.

### Plan R2 — Cloud API + Personas Schema
- mysql migration: `personas` table + 3 seed rows
- Build `engine/cloud_api.py` — small FastAPI service on port 57078 with the three endpoints
- systemd USER unit for the service
- Caddy snippet routing `/cloud` and `/api/cloud/*` to the new service
- Avatar storage directory `/s7/.local/share/s7-personas/avatars/` with default placeholder PNGs
- **Outcome**: `curl http://127.0.0.1:8080/api/cloud/status` returns the right HELD/REVOKED state. `curl http://127.0.0.1:8080/api/personas` returns 3 rows (or 403 if cloud is closed). Drag-drop upload works via `POST /api/personas/carli/avatar -F file=@photo.jpg`.

### Plan R3 — Cloud UI integration
- Standalone `/cloud` HTML page that talks to the API directly (no SPA framework — single-file vanilla JS, drag-drop via HTML5 File API, fetch() for everything)
- Eventually: integrate into the SPA's existing chat page (deferred, requires SPA source)
- **Outcome**: visiting `http://127.0.0.1:8080/cloud` shows either the closed-cloud page or the open-cloud page with persona cards and drag-drop avatar upload, all gated by ribbon state.

Each sub-plan has its own gate (lifecycle test green, audit-pre/post green, builds clean) and its own promotion to main.

## What this design does NOT do

- It does not modify the existing compiled SPA chat bundle. The Cloud is an additional surface, not a replacement.
- It does not implement the FIPS / CIS / HIPAA scripts themselves — only the framework. Each per-standard script is its own follow-up plan, sized to the actual compliance work.
- It does not gate the ribbon on Trivy scan results (yet). The current TimeCapsule scan reports show HIGH/CRITICAL CVEs in upstream images; until the image-hardening plan replaces those, gating on scan would keep the ribbon REVOKED forever. Plan R1 SBC check leaves Trivy out of the verdict initially; Plan B's image-hardening work feeds it back in.
- It does not store avatar photos in the DB. They live on the host filesystem at `/s7/.local/share/s7-personas/avatars/<slug>.png`, served as static files. The DB only stores the path.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| The compliance scripts say PASS when they shouldn't (false negatives) | The hash chain on the ledger means a tampered row breaks verification; periodic external audits of the chain catch it. |
| The ribbon state flips HELD→REVOKED→HELD rapidly (flapping) and the cloud opens/closes constantly | `ribbon-measure.sh` is rate-limited to once per N minutes; the SPA caches the current state for 30s before re-querying. |
| A failing measurement is misattributed to the wrong standard | Each per-standard script writes to its own log; `failure_summary` in the ledger row identifies which standards failed. |
| Avatar upload accepts malicious files (XSS, oversized images, exotic formats) | Server-side validation: only PNG/JPEG/WebP, max 2MB, max 1024×1024, re-encode with Pillow before saving. |
| Operator manually disables FIPS mode and the ribbon doesn't notice for hours | `ribbon-measure.sh` runs as a systemd USER timer every 15 minutes. Detection latency ≤ 15 min. |
| The Cloud chat flooding Ollama with persona requests when many family members log in at once | Per-persona rate limit at the cloud_api level; reject if > N concurrent chats per persona. |

## Success criterion

After R1+R2+R3 are complete, the following sequence works end-to-end:

```bash
# 1. Run the measurement
bash iac/compliance/ribbon-measure.sh
# Expected: writes a row to ribbons.measurements, prints the verdict

# 2. Query the ribbon state
PGPASSWORD="$(cat /s7/.config/s7/pg-password)" psql -h 127.0.0.1 -p 57090 -U s7 -d s7_cws -c 'SELECT ribbon_state FROM ribbons.current_state;'
# Expected: HELD (or REVOKED with a clear failure summary)

# 3. Query the cloud API
curl -s http://127.0.0.1:8080/api/cloud/status | python3 -m json.tool
# Expected: {"open": true, "ribbon_state": "HELD", ...}

# 4. List personas
curl -s http://127.0.0.1:8080/api/personas | python3 -m json.tool
# Expected: 3 rows (Carli/Elias/Samuel) with their model + emoji + avatar_url

# 5. Visit the cloud page in a browser
xdg-open http://127.0.0.1:8080/cloud
# Expected: persona cards visible, drag-drop avatar slots, click to chat

# 6. Drag a photo onto Carli's card
# Expected: upload succeeds, page refreshes with new avatar, file at /s7/.local/share/s7-personas/avatars/carli.png

# 7. Force a measurement failure (e.g., disable FIPS mode)
# Re-run ribbon-measure.sh → ribbon goes REVOKED → /api/cloud/status returns open:false
# Refresh /cloud → "Cloud is closed" page with the failure listed
```

The covenant in code: when the appliance can prove it's safe, the personas appear. When it can't, they go away.
