-- engine/sql/s7-appliance-schema.sql
-- S7 QUBi Appliance Fleet Registry
--
-- Every deployed S7 QUBi appliance (home, ministry, business, reference)
-- gets one row in appliance.appliance. The row carries identification,
-- classification, region, and language so that any S7 service on the
-- appliance can introspect "who am I, where am I, who am I serving."
--
-- appliance.snapshot records point-in-time copies of that appliance's
-- repo / container images / SBOMs, so an appliance can always be
-- rebuilt from a known-good state. S7 itself is appliance #1 — the
-- reference deployment, source of truth.
--
-- Lives in DB:    s7_cws
-- Schema:         appliance
-- Prerequisites:  extension "uuid-ossp" (already loaded in s7_cws)

CREATE SCHEMA IF NOT EXISTS appliance;

-- ── appliance.appliance ──
-- One row per physical/virtual QUBi. The serial is the user-facing
-- identity. Soft classification keeps simple strings (not enums) so
-- new tiers can be added without a migration.
CREATE TABLE IF NOT EXISTS appliance.appliance (
    id                    UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    serial                TEXT         NOT NULL UNIQUE,
    classification        TEXT         NOT NULL,    -- 'reference', 'home', 'ministry', 'business', 'dev'
    region                TEXT         NOT NULL,    -- ISO 3166 alpha-2 (+ optional subdivision)
    language              TEXT         NOT NULL,    -- IETF BCP 47 tag (en-US, es-419, ...)
    akashic_seed          TEXT,                     -- per-appliance randomizer seed used by the
                                                    -- Akashic transform layer. End user / business
                                                    -- at origin or destination may choose to alter
                                                    -- characters in Akashic language; these seeded
                                                    -- letters are the randomizer for AI appliance
                                                    -- updates, so no two appliances receive byte-
                                                    -- identical payloads and cross-correlation of
                                                    -- updates between units is mechanically blocked.
    akashic_encoder       JSONB,                    -- the encoder that consumes akashic_seed to
                                                    -- produce a per-appliance character transform
                                                    -- table. Shape:
                                                    --   { "version": "akashic-sub-v1",
                                                    --     "derived_at": "2026-04-12T22:56:46Z",
                                                    --     "charset": "latin-extended",
                                                    --     "reversible": true }
                                                    -- The actual transform table is NOT stored
                                                    -- here — it is recomputed deterministically
                                                    -- from (akashic_seed, version) on demand.
                                                    -- Together seed + encoder bind an appliance
                                                    -- to a unique per-unit Akashic cipher.
    owner_display_name    TEXT,                     -- optional, may be blank for privacy
    covenant_accepted_at  TIMESTAMPTZ,              -- CWS-BSL-1.1 acceptance timestamp
    current_version       TEXT,                     -- e.g. v2026.04.12
    status                TEXT         NOT NULL DEFAULT 'active',  -- 'active', 'dormant', 'retired'
    notes                 TEXT,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE appliance.appliance IS
  'S7 QUBi appliance fleet registry. One row per deployed unit. S7 itself is the reference entry.';

-- Idempotent migration for existing deployments that pre-date the
-- akashic_seed / akashic_encoder fields. Safe to re-run.
ALTER TABLE appliance.appliance
  ADD COLUMN IF NOT EXISTS akashic_seed    TEXT;
ALTER TABLE appliance.appliance
  ADD COLUMN IF NOT EXISTS akashic_encoder JSONB;

-- ── appliance.snapshot ──
-- Many snapshots per appliance (one per significant update). Points
-- at a file path on disk rather than embedding bytes — audit rows
-- stay small and the actual payload lives in a path the gitignore
-- excludes.
CREATE TABLE IF NOT EXISTS appliance.snapshot (
    id            UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    appliance_id  UUID         NOT NULL REFERENCES appliance.appliance(id) ON DELETE CASCADE,
    kind          TEXT         NOT NULL,    -- 'git-bundle', 'git-archive', 'container-image', 'sbom'
    commit_sha    TEXT,                     -- nullable for non-git snapshots
    path          TEXT         NOT NULL,    -- on-disk absolute path
    sha256        TEXT         NOT NULL,
    size_bytes    BIGINT       NOT NULL,
    taken_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    notes         TEXT
);

CREATE INDEX IF NOT EXISTS snapshot_appliance_taken_idx
    ON appliance.snapshot (appliance_id, taken_at DESC);

COMMENT ON TABLE appliance.snapshot IS
  'Point-in-time snapshots (git bundles, tarballs, container images, SBOMs) of a QUBi appliance. Path points at bytes on disk.';

-- ── Seed: S7 reference appliance #1 ──
-- The first row. Appliance #1 is us — Jamie's reference deployment,
-- the source of truth for the whole fleet.
INSERT INTO appliance.appliance (
    serial,
    classification,
    region,
    language,
    owner_display_name,
    covenant_accepted_at,
    current_version,
    status,
    notes
) VALUES (
    'S7-REF-0001',
    'reference',
    'US',
    'en-US',
    '2XR LLC / S7 reference appliance',
    NOW(),
    'v2026.04.12',
    'active',
    'First appliance in the S7 QUBi fleet. Reference deployment. Source of truth.'
) ON CONFLICT (serial) DO NOTHING;
