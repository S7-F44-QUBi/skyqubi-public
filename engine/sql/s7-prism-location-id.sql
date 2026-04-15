-- engine/sql/s7-prism-location-id.sql
-- S7 QBIT Prism v1.0.1 — LocationID matrix
--
-- Extends cws_core.prism_vectors (already present) with the full
-- composite LocationID: 8-plane ternary + Earth address + Cosmic
-- address + Sequential time + Aptitude expansion + Strand tokens +
-- rational subposition.
--
-- The integer cube has 3^8 = 6561 cells. Decimal subpositions let
-- infinite entries live inside a single cell without the cube ever
-- expanding. Truman Show math — growth is inward, the cube stays
-- the same size forever.
--
-- Every entry is INSERT-only. No updates. No deletes. This is a
-- witness log.
--
-- Patent: CWS-005 — QBIT Prism Convergence Vector Decomposition
-- TPP99606 — 123Tech / 2XR, LLC

CREATE SCHEMA IF NOT EXISTS cws_core;  -- may already exist; safe.

-- ── LocationID table ────────────────────────────────────────────────
-- One row per witnessed LocationID. Queryable by any subset of the
-- composite. The 8-plane direction columns are indexed individually
-- and jointly for the fast 'does this cell exist' lookup that
-- Location Detection needs.

CREATE TABLE IF NOT EXISTS cws_core.location_id (
    id                  UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- ── Semantic address (8-plane ternary cube) ──────────────────
    -- Each dir column is one of {-1, 0, +1}. The tuple of 8
    -- directions is the integer cell address — 3^8 = 6561 cells.
    sensory_dir         SMALLINT      NOT NULL CHECK (sensory_dir     IN (-1,0,1)),
    episodic_dir        SMALLINT      NOT NULL CHECK (episodic_dir    IN (-1,0,1)),
    semantic_dir        SMALLINT      NOT NULL CHECK (semantic_dir    IN (-1,0,1)),
    associative_dir     SMALLINT      NOT NULL CHECK (associative_dir IN (-1,0,1)),
    procedural_dir      SMALLINT      NOT NULL CHECK (procedural_dir  IN (-1,0,1)),
    lexical_dir         SMALLINT      NOT NULL CHECK (lexical_dir     IN (-1,0,1)),
    relational_dir      SMALLINT      NOT NULL CHECK (relational_dir  IN (-1,0,1)),
    executive_dir       SMALLINT      NOT NULL CHECK (executive_dir   IN (-1,0,1)),

    -- ── Rational subposition inside the cell ─────────────────────
    -- Two entries can occupy the same integer cell; they are
    -- distinguished by a rational number sub_num / sub_den.
    -- Insertion between two existing subpositions uses the
    -- Stern-Brocot mediant: (a_num + b_num) / (a_den + b_den).
    -- Result is always in lowest terms, unique, and allows
    -- infinite subdivision without precision loss.
    sub_num             BIGINT        NOT NULL DEFAULT 1,
    sub_den             BIGINT        NOT NULL DEFAULT 1 CHECK (sub_den > 0),

    -- ── Earth address ────────────────────────────────────────────
    -- NULL when origin / witness location is genuinely unknown
    -- (Voynich, Rongorongo, etc.) — absence is legitimate.
    long_deg            NUMERIC(9,6),   -- -180.000000 .. +180.000000
    lat_deg             NUMERIC(8,6),   -- -90.000000  .. +90.000000

    -- ── Cosmic address (geometric time) ──────────────────────────
    sun_azimuth_deg     NUMERIC(8,5),   -- 0..360
    sun_elevation_deg   NUMERIC(8,5),   -- -90..+90

    -- ── Sequential time ──────────────────────────────────────────
    -- J2000 Terrestrial Time seconds. Signed so prehistoric
    -- entries (Gilgamesh, Pyramid Texts) are representable.
    time_j2000_s        BIGINT,

    -- ── Aptitude expansion ───────────────────────────────────────
    -- Signed capability-delta this entry adds to the foundation.
    -- Asserted by the witness at ingest; challengeable through
    -- the Reporter.
    aptitude_delta      SMALLINT      NOT NULL DEFAULT 0,

    -- ── Strand tokens ────────────────────────────────────────────
    -- UUIDs pointing at the upstream foundation (RevToken) and the
    -- downstream intent (ForToken). NULL means strand terminus.
    for_token           UUID,
    rev_token           UUID,

    -- ── Covenant flags ───────────────────────────────────────────
    -- A forbidden cell is one the Reporter has marked off-limits
    -- (military, weapons, deception). Any LocationID landing in a
    -- forbidden cell returns verdict VIOLATION.
    forbidden           BOOLEAN       NOT NULL DEFAULT FALSE,

    -- ── Witness metadata ─────────────────────────────────────────
    witness             TEXT,           -- e.g. appliance serial, model name
    source_text_hash    TEXT,           -- sha256 of the underlying payload for audit
    notes               TEXT,

    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
    -- INSERT-only: no updated_at, no deletes expected
);

COMMENT ON TABLE cws_core.location_id IS
  'QBIT Prism v1.0.1 LocationID matrix. Each row is a witnessed address in the 8-plane ternary cube with rational subposition, Earth coordinates, cosmic time, aptitude delta, and strand tokens. Used by detect_location() for Foundation/Frontier/Hallucination/Violation verdicts.';

-- ── Indexes ─────────────────────────────────────────────────────────

-- Fast composite lookup on the 8-plane integer cell. This is the
-- O(1) hot path for Location Detection — "does this cell exist?".
CREATE INDEX IF NOT EXISTS location_id_cell_idx
  ON cws_core.location_id (
    sensory_dir, episodic_dir, semantic_dir, associative_dir,
    procedural_dir, lexical_dir, relational_dir, executive_dir
  );

-- Forbidden cells (covenant violations)
CREATE INDEX IF NOT EXISTS location_id_forbidden_idx
  ON cws_core.location_id (forbidden)
  WHERE forbidden = TRUE;

-- Strand walks
CREATE INDEX IF NOT EXISTS location_id_for_token_idx
  ON cws_core.location_id (for_token)
  WHERE for_token IS NOT NULL;

CREATE INDEX IF NOT EXISTS location_id_rev_token_idx
  ON cws_core.location_id (rev_token)
  WHERE rev_token IS NOT NULL;

-- Temporal walks (for history queries, strand ordering)
CREATE INDEX IF NOT EXISTS location_id_time_idx
  ON cws_core.location_id (time_j2000_s)
  WHERE time_j2000_s IS NOT NULL;

-- Physical-address queries (nearest entries by Long/Lat)
CREATE INDEX IF NOT EXISTS location_id_geo_idx
  ON cws_core.location_id (long_deg, lat_deg)
  WHERE long_deg IS NOT NULL AND lat_deg IS NOT NULL;

-- Aptitude-sorted retrieval (high-pull entries first)
CREATE INDEX IF NOT EXISTS location_id_aptitude_idx
  ON cws_core.location_id (aptitude_delta DESC);


-- ── Seed: S7 reference LocationID ───────────────────────────────────
-- First entry in the matrix — the Prism v1.0.1 schema itself,
-- witnessed by the reference appliance on the night it was built.
-- Semantic address is (0,0,0,0,0,0,0,0) — the Door state, all
-- planes at neutral, representing a structural / foundational
-- declaration rather than a content claim.
INSERT INTO cws_core.location_id (
    sensory_dir, episodic_dir, semantic_dir, associative_dir,
    procedural_dir, lexical_dir, relational_dir, executive_dir,
    sub_num, sub_den,
    aptitude_delta,
    witness, notes
) VALUES (
    0, 0, 0, 0, 0, 0, 0, 0,
    1, 1,
    1,
    'S7-REF-0001',
    'Prism v1.0.1 schema foundation. All 8 planes at Door (0). The reference LocationID from which the strand begins.'
) ON CONFLICT DO NOTHING;
