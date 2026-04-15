-- ═══════════════════════════════════════════════════════════════
-- CWS Akashic Language Schema
-- S7 SkyQUBi · 123Tech / 2XR, LLC
--
-- Akashic Language: foundational encoding layer for universal
-- model ingestion. Each word maps to a curve_value ∈ [-7, +7]
-- across 7 cognitive planes. The ternary boundary {-1, 0, +1}
-- classifies at ^7.
--
-- INSERT-only covenant: no UPDATE or DELETE on scored data.
-- ═══════════════════════════════════════════════════════════════

CREATE SCHEMA IF NOT EXISTS cws_akashic;

-- ── Language Plans ──────────────────────────────────────────────
-- Named convergence plans with semantic anchor points.
-- A plan is a context for Language Index evaluation.
CREATE TABLE cws_akashic.language_plans (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_name       TEXT NOT NULL UNIQUE,
    description     TEXT,
    plane_count     INT NOT NULL DEFAULT 7,
    curve_min       INT NOT NULL DEFAULT -7,
    curve_max       INT NOT NULL DEFAULT 7,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Plan Points ─────────────────────────────────────────────────
-- Named semantic anchors within a plan (e.g. "convergence",
-- "trust", "boundary", "memory", "inference").
CREATE TABLE cws_akashic.plan_points (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id         UUID NOT NULL REFERENCES cws_akashic.language_plans(id),
    point_name      TEXT NOT NULL,
    description     TEXT,
    base_weight     FLOAT NOT NULL DEFAULT 1.0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (plan_id, point_name)
);

-- ── Language Index ──────────────────────────────────────────────
-- The core Akashic table. Each word maps to a curve value and
-- a plan point. Words can appear in multiple plans with
-- different curve values.
--
-- curve_value:     -7 to +7 (graduated ternary weight)
-- location_weight: positional weight within the plan point space
-- plane_affinity:  which of the 7 planes this word resonates with
CREATE TABLE cws_akashic.language_index (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    word            TEXT NOT NULL,
    word_normalised TEXT NOT NULL,
    plan_id         UUID NOT NULL REFERENCES cws_akashic.language_plans(id),
    plan_point_id   UUID REFERENCES cws_akashic.plan_points(id),
    index_position  INT NOT NULL,
    location_weight FLOAT NOT NULL DEFAULT 0.0,
    curve_value     INT NOT NULL CHECK (curve_value BETWEEN -7 AND 7),
    plane_affinity  INT[] NOT NULL DEFAULT '{}'::INT[],
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (word_normalised, plan_id)
);

CREATE INDEX idx_akashic_word ON cws_akashic.language_index (word_normalised);
CREATE INDEX idx_akashic_plan ON cws_akashic.language_index (plan_id);
CREATE INDEX idx_akashic_curve ON cws_akashic.language_index (curve_value);

-- ── Encoded Responses ───────────────────────────────────────────
-- INSERT-only log of Akashic-encoded Reporter outputs.
-- Each row is one Reporter's response to one query, encoded
-- through the Language Index into a 7-plane curve vector.
CREATE TABLE cws_akashic.encoded_responses (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID,
    witness_id      UUID NOT NULL REFERENCES cws_core.witnesses(id),
    plan_id         UUID NOT NULL REFERENCES cws_akashic.language_plans(id),
    raw_text        TEXT NOT NULL,
    token_count     INT NOT NULL,
    encoded_count   INT NOT NULL,
    unencoded_count INT NOT NULL,
    -- 7-plane curve vector: plane scores from -7 to +7
    plane_curves    FLOAT[7] NOT NULL,
    -- Aggregated ternary classification per plane: {-1, 0, +1}
    plane_ternary   INT[7] NOT NULL,
    total_curve     FLOAT NOT NULL,
    state           TEXT NOT NULL CHECK (state IN ('FERTILE', 'BABEL', 'DOOR')),
    encoded_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_encoded_witness ON cws_akashic.encoded_responses (witness_id);
CREATE INDEX idx_encoded_state ON cws_akashic.encoded_responses (state);

-- ── Reporter Sessions ───────────────────────────────────────────
-- Formalises the 1-model-1-voice Reporter pattern.
-- Each Reporter session = one model answering one query.
CREATE TABLE cws_akashic.reporter_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    consensus_id    UUID REFERENCES cws_core.consensus_sessions(id),
    witness_id      UUID NOT NULL REFERENCES cws_core.witnesses(id),
    plane_index     INT NOT NULL CHECK (plane_index BETWEEN 0 AND 6),
    plane_name      TEXT NOT NULL,
    query_text      TEXT NOT NULL,
    response_text   TEXT,
    encoded_id      UUID REFERENCES cws_akashic.encoded_responses(id),
    fertile_ratio   FLOAT,
    latency_ms      INT,
    reported_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reporter_witness ON cws_akashic.reporter_sessions (witness_id);
CREATE INDEX idx_reporter_consensus ON cws_akashic.reporter_sessions (consensus_id);

-- ── Witness Trust ───────────────────────────────────────────────
-- INSERT-only trust accumulation per model over time.
-- Trust score = fertile_sessions / total_sessions (computed, not stored).
-- Tier is derived from the running total — never mutated.
CREATE TABLE cws_akashic.witness_trust (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    witness_id      UUID NOT NULL REFERENCES cws_core.witnesses(id),
    session_id      UUID,
    was_fertile     BOOLEAN NOT NULL,
    fertile_ratio   FLOAT NOT NULL,
    running_fertile INT NOT NULL,
    running_total   INT NOT NULL,
    trust_score     FLOAT NOT NULL,
    tier            TEXT NOT NULL CHECK (tier IN ('UNTRUSTED', 'PROBATIONARY', 'TRUSTED', 'ANCHORED')),
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_trust_witness ON cws_akashic.witness_trust (witness_id);
CREATE INDEX idx_trust_tier ON cws_akashic.witness_trust (tier);
CREATE INDEX idx_trust_time ON cws_akashic.witness_trust (recorded_at DESC);

-- ── Seed: Default Language Plan ─────────────────────────────────
INSERT INTO cws_akashic.language_plans (plan_name, description, plane_count, curve_min, curve_max)
VALUES ('convergence', 'Default convergence plan — evaluates trust, truth, and semantic alignment', 7, -7, 7);

-- ── Seed: Core Plan Points ──────────────────────────────────────
INSERT INTO cws_akashic.plan_points (plan_id, point_name, description, base_weight)
SELECT lp.id, pp.point_name, pp.description, pp.base_weight
FROM cws_akashic.language_plans lp
CROSS JOIN (VALUES
    ('trust',       'Trust and reliability signals',          1.0),
    ('convergence', 'Agreement and convergence markers',      1.0),
    ('boundary',    'Boundary and threshold language',        0.8),
    ('memory',      'Memory, recall, and storage concepts',   0.7),
    ('inference',   'Reasoning and inference patterns',       0.9),
    ('safety',      'Safety, protection, and covenant terms', 1.0),
    ('identity',    'Identity, self, and origin language',     0.6)
) AS pp(point_name, description, base_weight)
WHERE lp.plan_name = 'convergence';
