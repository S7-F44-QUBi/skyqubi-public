-- ═══════════════════════════════════════════════════════════════════════════════
-- CONVERGENCE WEIGHT SCHEMA (CWS) — VERSION 2.3
-- WORKING MODEL DATABASE — FULL CONVERGED PIPELINE
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Licensor:       123Tech / 2XR, LLC
-- Licensed Work:  CWS v2.3, April 8, 2026
-- License:        Business Source License 1.1
-- Change Date:    April 7, 2030
-- Change License: Apache License 2.0
--
-- Additional Use Grant: Personal and research use on hardware you own.
--                       Community testing and development encouraged.
--                       Commercial deployment requires SkyCAIR Node License.
--
-- Contact:        OmegaAnswers@123Tech.net
-- Brand:          UNIFIED LINUX SkyCAIR by S7
--                 123Tech.net | Evolve2Linux.com | SkyNetSSL (Safe Secure Linux)
--
-- Covenant:       INSERT-only memory. Love is the architecture.
--
-- v2.3 CHANGES:
--   - 6 schemas (added cws_bridge, cws_routing)
--   - BitNet MCP wrapper + model registry
--   - Document workspace integration (RAG pipeline)
--   - Query routing engine (standard/ternary/dual path selection)
--   - Converged pipeline: query → route → infer → discern → store → sync
--   - Full MCP tool registry (19 MemPalace + 8 CWS + 5 BitNet)
--   - Development session ↔ CWS ↔ MemPalace ↔ Document workspace bridge
-- ═══════════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════════
-- EXTENSIONS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";


-- ═══════════════════════════════════════════════════════════════════════════════
-- 6 SCHEMAS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE SCHEMA IF NOT EXISTS cws_core;
CREATE SCHEMA IF NOT EXISTS cws_memory;
CREATE SCHEMA IF NOT EXISTS cws_inference;
CREATE SCHEMA IF NOT EXISTS cws_import;
CREATE SCHEMA IF NOT EXISTS cws_bridge;
CREATE SCHEMA IF NOT EXISTS cws_routing;


-- ═══════════════════════════════════════════════════════════════════════════════
-- CUSTOM TYPES
-- ═══════════════════════════════════════════════════════════════════════════════

DO $$ BEGIN CREATE TYPE cws_core.plane_val AS ENUM ('-1', '0', '+1');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE cws_core.time_val AS ENUM ('0', '1');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE cws_core.plane_name AS ENUM (
    'sensory', 'episodic', 'semantic', 'associative',
    'procedural', 'lexical', 'relational', 'executive');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE cws_core.pass_type AS ENUM ('FORWARD', 'REVERSE');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE cws_core.discernment AS ENUM ('FERTILE', 'BABEL');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE cws_routing.inference_path AS ENUM ('standard', 'ternary', 'dual');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE cws_routing.route_reason AS ENUM (
    'model_size',      -- small model → ternary, large → standard
    'task_type',       -- code gen → standard, Q&A → ternary
    'latency_target',  -- low latency → ternary (CPU native)
    'energy_target',   -- low energy → ternary (82% reduction)
    'consensus',       -- consensus query → dual (both paths)
    'user_override',   -- user explicitly selected path
    'benchmark'        -- QUANTi benchmark comparison
);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE cws_bridge.memory_tier AS ENUM ('L0', 'L1', 'L2', 'L3');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE cws_bridge.sync_direction AS ENUM (
    'cws_to_palace', 'palace_to_cws', 'claude_to_palace',
    'palace_to_claude', 'anythingllm_to_palace', 'palace_to_anythingllm',
    'bidirectional');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE cws_bridge.mcp_server AS ENUM (
    'mempalace', 'cws_engine', 'bitnet', 'anythingllm', 'postgres');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- SCHEMA 1: cws_core — FOUNDATION
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS cws_core.curve_params (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    curve_name      VARCHAR(32) NOT NULL,
    decay_center    NUMERIC(6,3) DEFAULT 1.0,
    frequency       NUMERIC(6,3) DEFAULT 0.8,
    description     TEXT,
    UNIQUE(curve_name)
);

INSERT INTO cws_core.curve_params (curve_name, decay_center, frequency, description) VALUES
    ('structure', -1.0, 0.8, 'Father curve: exp(-|x+1|) * cos(0.8x)'),
    ('nurture',    1.0, 0.8, 'Mother curve: exp(-|x-1|) * cos(0.8x)')
ON CONFLICT (curve_name) DO NOTHING;

CREATE TABLE IF NOT EXISTS cws_core.entities (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type     VARCHAR(32) NOT NULL,
    entity_key      VARCHAR(256) NOT NULL,
    constant        NUMERIC(10,6) NOT NULL DEFAULT 1.0,
    location        NUMERIC(10,6) NOT NULL DEFAULT 0.0,
    convergence_x   NUMERIC(10,6),
    convergence_w   NUMERIC(10,6),
    structure_val   NUMERIC(10,6),
    nurture_val     NUMERIC(10,6),
    scale_weight    NUMERIC(12,8),
    v_memory        cws_core.plane_val DEFAULT '0',
    v_present       cws_core.plane_val DEFAULT '0',
    v_destiny       cws_core.plane_val DEFAULT '0',
    embedding       vector(1536),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(entity_type, entity_key)
);

CREATE TABLE IF NOT EXISTS cws_core.witnesses (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_name      TEXT NOT NULL,
    model_family    TEXT,
    param_count     BIGINT,
    license         TEXT,
    access_type     TEXT CHECK (access_type IN ('open_weights', 'api_probe')),
    is_active       BOOLEAN DEFAULT TRUE,
    registered_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(model_name)
);

-- 7+1 OCTi Witness Set — each model assigned to one cognitive plane
-- Plane assignment maximizes architectural diversity per convergence layer
INSERT INTO cws_core.witnesses (model_name, model_family, param_count, license, access_type) VALUES
    -- Witness 1: Sensory plane — fast input processing
    ('LLaMA 3.2 3B',  'llama',    3210000000,  'Meta Community', 'open_weights'),
    -- Witness 2: Episodic plane — sequential/temporal reasoning
    ('Mistral 7B v0.3','mistral',  7000000000,  'Apache 2.0',     'open_weights'),
    -- Witness 3: Semantic plane — concept understanding
    ('Gemma 2 9B',    'gemma',    9000000000,  'Gemma',          'open_weights'),
    -- Witness 4: Associative plane — relational reasoning
    ('Phi-4 14B',     'phi',      14000000000, 'MIT',            'open_weights'),
    -- Witness 5: Procedural plane — instruction following
    ('Qwen 2.5 32B',  'qwen',     32000000000, 'Apache 2.0',     'open_weights'),
    -- Witness 6: Relational plane — structure, logic, code
    ('DeepSeek R1 8B','deepseek', 8000000000,  'MIT',            'open_weights'),
    -- Witness 7: Lexical plane — multilingual vocabulary coverage
    ('BLOOM 176B',    'bloom',    176000000000,'RAIL',           'open_weights')
    -- Witness 8: Executive plane — CWS Engine (deterministic, not a model)
ON CONFLICT (model_name) DO NOTHING;

-- SkyQUBi Lite witness set (proof of theory — consumer hardware)
-- Uses 3 small open-weight models + CWS Engine as 4th
-- Witness 1 (Sensory):    LLaMA 3.2 1B  — already running on :7081
-- Witness 2 (Semantic):   Phi-3.5 Mini 3.8B — pull: phi3.5
-- Witness 3 (Associative): Gemma 2 2B   — pull: gemma2:2b
-- Witness 4 (Executive):  CWS Engine    — deterministic aggregator

CREATE TABLE IF NOT EXISTS cws_core.consensus_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    input_hash      VARCHAR(64) NOT NULL,
    input_text      TEXT,
    witness_count   SMALLINT NOT NULL DEFAULT 7,
    unanimous       BOOLEAN,
    started_at      TIMESTAMPTZ DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS cws_core.convergence_scores (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID REFERENCES cws_core.consensus_sessions(id),
    witness_id      UUID REFERENCES cws_core.witnesses(id),
    score           NUMERIC(8,6) NOT NULL,
    computed_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_core.babel_ratios (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID REFERENCES cws_core.consensus_sessions(id),
    babel_count     SMALLINT NOT NULL DEFAULT 0,
    total_tokens    SMALLINT NOT NULL DEFAULT 0,
    ratio           NUMERIC(6,4) NOT NULL,
    computed_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_core.circuit_breaker_events (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID REFERENCES cws_core.consensus_sessions(id),
    babel_ratio     NUMERIC(6,4) NOT NULL,
    threshold       NUMERIC(6,4) NOT NULL DEFAULT 0.70,
    triggered       BOOLEAN NOT NULL DEFAULT FALSE,
    action_taken    TEXT,
    triggered_at    TIMESTAMPTZ DEFAULT NOW()
);


-- ═══════════════════════════════════════════════════════════════════════════════
-- SCHEMA 2: cws_memory — INSERT-ONLY COVENANT
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS cws_memory.entries (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id       UUID REFERENCES cws_core.entities(id),
    plane           cws_core.plane_name NOT NULL,
    content         TEXT NOT NULL,
    content_hash    VARCHAR(64),
    constant        NUMERIC(10,6) NOT NULL,
    location        NUMERIC(10,6) NOT NULL,
    scale_weight    NUMERIC(12,8) NOT NULL,
    pulse_step      BIGINT NOT NULL DEFAULT 0,
    pulse_state     cws_core.time_val NOT NULL DEFAULT '0',
    v_memory        cws_core.plane_val DEFAULT '0',
    v_present       cws_core.plane_val DEFAULT '0',
    v_destiny       cws_core.plane_val DEFAULT '0',
    emb_fast        bit(1536),
    emb_accurate    halfvec(1536),
    weight          SMALLINT DEFAULT 0 CHECK (weight BETWEEN -1 AND 1),
    awareness_score FLOAT DEFAULT 1.0,
    -- Source tracking: where did this entry originate?
    source_system   TEXT DEFAULT 'cws' CHECK (source_system IN ('cws','mempalace','document_ingest','development_session','manual')),
    source_ref      TEXT,  -- external ID from source system
    inserted_at     TIMESTAMPTZ DEFAULT NOW()
    -- NO updated_at. NO deleted_at. INSERT-ONLY.
);

CREATE INDEX IF NOT EXISTS idx_memory_plane ON cws_memory.entries (plane, weight DESC);
CREATE INDEX IF NOT EXISTS idx_memory_entity ON cws_memory.entries (entity_id, plane);
CREATE INDEX IF NOT EXISTS idx_memory_source ON cws_memory.entries (source_system, inserted_at DESC);

CREATE TABLE IF NOT EXISTS cws_memory.token_store (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID,
    token_index     INTEGER NOT NULL,
    token_value     TEXT NOT NULL,
    ternary_weight  SMALLINT NOT NULL CHECK (ternary_weight IN (-1, 0, 1)),
    confidence      NUMERIC(6,4) NOT NULL,
    discernment     cws_core.discernment NOT NULL,
    stored_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_memory.fortoken_results (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token_store_id  UUID REFERENCES cws_memory.token_store(id),
    forward_score   NUMERIC(10,6) NOT NULL,
    passed          BOOLEAN NOT NULL,
    computed_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_memory.revtoken_audits (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token_store_id  UUID REFERENCES cws_memory.token_store(id),
    reverse_score   NUMERIC(10,6) NOT NULL,
    passed          BOOLEAN NOT NULL,
    computed_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_memory.confidence_badges (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID,
    badge_type      TEXT NOT NULL,
    score           NUMERIC(6,4) NOT NULL,
    witness_count   SMALLINT NOT NULL,
    unanimous       BOOLEAN DEFAULT FALSE,
    issued_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_memory.memory_timeline (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_id        UUID REFERENCES cws_memory.entries(id),
    trajectory      TEXT NOT NULL,
    delta           NUMERIC(10,6),
    recorded_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_memory.suppression_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_id        UUID REFERENCES cws_memory.entries(id),
    reason          TEXT NOT NULL,
    suppressed_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_memory.time_pulse (
    step            BIGINT PRIMARY KEY,
    time_val        cws_core.time_val NOT NULL DEFAULT '0',
    recorded_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_time_step ON cws_memory.time_pulse (step);


-- ═══════════════════════════════════════════════════════════════════════════════
-- SCHEMA 3: cws_inference — ForToken/RevToken + DISCERNMENT
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS cws_inference.sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    input_tokens    TEXT[] NOT NULL,
    input_constant  NUMERIC(10,6) NOT NULL,
    input_location  NUMERIC(10,6) NOT NULL,
    scale_weight    NUMERIC(12,8) NOT NULL,
    pulse_step      BIGINT NOT NULL,
    -- Routing decision (from cws_routing)
    route_id        UUID,  -- FK set after routing table created
    inference_path  cws_routing.inference_path DEFAULT 'dual',
    -- External session links
    claude_session  TEXT,
    anythingllm_workspace TEXT,
    started_at      TIMESTAMPTZ DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS cws_inference.passes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID REFERENCES cws_inference.sessions(id),
    pass_type       cws_core.pass_type NOT NULL,
    token_index     INTEGER NOT NULL,
    token_value     TEXT NOT NULL,
    curve_value     NUMERIC(10,6) NOT NULL,
    confidence      NUMERIC(10,6) NOT NULL,
    computed_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_inference.discernment (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID REFERENCES cws_inference.sessions(id),
    token_index     INTEGER NOT NULL,
    token_value     TEXT NOT NULL,
    forward_value   NUMERIC(10,6) NOT NULL,
    reverse_value   NUMERIC(10,6) NOT NULL,
    agreement       NUMERIC(6,4) NOT NULL,
    result          cws_core.discernment NOT NULL,
    weight          NUMERIC(12,8) NOT NULL,
    divergence_note TEXT,
    computed_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_discern_session ON cws_inference.discernment (session_id, token_index);
CREATE INDEX IF NOT EXISTS idx_discern_fertile ON cws_inference.discernment (result) WHERE result = 'FERTILE';

CREATE TABLE IF NOT EXISTS cws_inference.witness_outputs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID REFERENCES cws_inference.sessions(id),
    witness_id      UUID REFERENCES cws_core.witnesses(id),
    -- Which engine produced this output
    engine          TEXT NOT NULL DEFAULT 'ollama' CHECK (engine IN ('ollama', 'bitnet', 'anythingllm')),
    output_text     TEXT NOT NULL,
    output_tokens   TEXT[],
    latency_ms      INTEGER,
    energy_j        NUMERIC(8,6),  -- joules per token (ternary tracking)
    computed_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_inference.bandage_measurements (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID REFERENCES cws_inference.sessions(id),
    witness_id      UUID REFERENCES cws_core.witnesses(id),
    base_output     TEXT NOT NULL,
    rlhf_output     TEXT NOT NULL,
    delta_score     NUMERIC(8,6) NOT NULL,
    is_bandage      BOOLEAN DEFAULT FALSE,
    measured_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_inference.divergence_signatures (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID REFERENCES cws_inference.sessions(id),
    witness_id      UUID REFERENCES cws_core.witnesses(id),
    divergence_mag  NUMERIC(8,6) NOT NULL,
    divergence_dir  TEXT,
    flagged         BOOLEAN DEFAULT FALSE,
    computed_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_inference.quanti_metrics (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID REFERENCES cws_inference.sessions(id),
    convergence     NUMERIC(8,6) NOT NULL,
    babel_ratio     NUMERIC(6,4) NOT NULL,
    confidence      NUMERIC(6,4) NOT NULL,
    unanimous       BOOLEAN DEFAULT FALSE,
    bandage_count   SMALLINT DEFAULT 0,
    circuit_tripped BOOLEAN DEFAULT FALSE,
    -- Path performance comparison
    standard_latency_ms  INTEGER,
    ternary_latency_ms   INTEGER,
    standard_energy_j    NUMERIC(8,6),
    ternary_energy_j     NUMERIC(8,6),
    reported_at     TIMESTAMPTZ DEFAULT NOW()
);


-- ═══════════════════════════════════════════════════════════════════════════════
-- SCHEMA 4: cws_import — MODEL INGESTION + TERNARY CONVERSION
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS cws_import.source_models (
    model_id        SERIAL PRIMARY KEY,
    model_name      TEXT NOT NULL,
    model_family    TEXT,
    param_count     BIGINT,
    hidden_dim      INTEGER,
    num_layers      INTEGER,
    num_heads       INTEGER,
    vocab_size      INTEGER,
    source_url      TEXT,
    license         TEXT,
    fingerprint     TEXT,
    -- Engine compatibility
    ollama_tag      TEXT,              -- e.g. 'llama3:8b'
    bitnet_gguf     TEXT,              -- path to GGUF ternary weights
    anythingllm_provider TEXT,         -- e.g. 'ollama', 'lmstudio', 'native'
    imported_at     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(model_name)
);

-- Full 7+1 OCTi model registry (plane-mapped)
INSERT INTO cws_import.source_models
    (model_name, model_family, param_count, hidden_dim, num_layers, num_heads, vocab_size, license, ollama_tag)
VALUES
    -- Sensory plane
    ('LLaMA 3.2 3B',   'llama',    3210000000,  3072, 28, 24, 128256, 'Meta Community', 'llama3.2:3b'),
    -- Episodic plane
    ('Mistral 7B v0.3','mistral',  7000000000,  4096, 32, 32, 32768,  'Apache 2.0',     'mistral:7b'),
    -- Semantic plane
    ('Gemma 2 9B',     'gemma',    9000000000,  3584, 42, 16, 256128, 'Gemma',          'gemma2:9b'),
    -- Associative plane
    ('Phi-4 14B',      'phi',     14000000000,  5120, 40, 40, 100352, 'MIT',            'phi4:14b'),
    -- Procedural plane
    ('Qwen 2.5 32B',   'qwen',    32000000000,  5120, 64, 40, 152064, 'Apache 2.0',     'qwen2.5:32b'),
    -- Relational plane
    ('DeepSeek R1 8B', 'deepseek', 8000000000,  4096, 32, 32, 129280, 'MIT',            'deepseek-r1:8b'),
    -- Lexical plane
    ('BLOOM 176B',     'bloom',  176000000000,  14336,70, 112,250880, 'RAIL',           NULL),
    -- SkyQUBi Lite small models (proof of theory)
    ('LLaMA 3.2 1B',   'llama',    1240000000,  2048, 16, 32, 128256, 'Meta Community', 'llama3.2:1b'),
    ('Phi-3.5 Mini',   'phi',      3820000000,  3072, 32, 32, 32064,  'MIT',            'phi3.5'),
    ('Gemma 2 2B',     'gemma',    2610000000,  2304, 26, 8,  256128, 'Gemma',          'gemma2:2b')
ON CONFLICT (model_name) DO NOTHING;

-- BitNet-native model registry
CREATE TABLE IF NOT EXISTS cws_import.bitnet_models (
    id              SERIAL PRIMARY KEY,
    model_name      TEXT NOT NULL,
    param_count     BIGINT,
    gguf_path       TEXT,              -- local path to GGUF ternary weights
    gguf_size_mb    INTEGER,
    weight_type     TEXT DEFAULT '1.58bit' CHECK (weight_type IN ('1.58bit', 'ternary_cws', 'ternary_absmean')),
    benchmark_score NUMERIC(8,6),      -- QUANTi score if tested
    is_default      BOOLEAN DEFAULT FALSE,
    registered_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(model_name)
);

INSERT INTO cws_import.bitnet_models (model_name, param_count, weight_type, gguf_size_mb, is_default) VALUES
    ('BitNet b1.58 2B4T', 2000000000, '1.58bit', 400, TRUE)
ON CONFLICT (model_name) DO NOTHING;

CREATE TABLE IF NOT EXISTS cws_import.layer_stats (
    id              BIGSERIAL PRIMARY KEY,
    model_id        INT REFERENCES cws_import.source_models(model_id),
    layer_index     INT NOT NULL,
    weight_type     TEXT NOT NULL,
    rows            INT NOT NULL,
    cols            INT NOT NULL,
    mean_val        NUMERIC(12,8),
    std_val         NUMERIC(12,8),
    min_val         NUMERIC(12,8),
    max_val         NUMERIC(12,8),
    sparsity        NUMERIC(6,4),
    ingested_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_import.embedding_samples (
    id              BIGSERIAL PRIMARY KEY,
    model_id        INT REFERENCES cws_import.source_models(model_id),
    token_text      TEXT NOT NULL,
    token_id        INT NOT NULL,
    embedding       vector(4096),
    sampled_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_import.dimensional_alignment (
    id              BIGSERIAL PRIMARY KEY,
    model_id        INT REFERENCES cws_import.source_models(model_id),
    source_dim      INT NOT NULL,
    target_dim      INT NOT NULL DEFAULT 1536,
    method          TEXT NOT NULL DEFAULT 'SVD',
    variance_kept   NUMERIC(8,6),
    projection_hash TEXT,
    computed_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_import.ternary_weights (
    weight_id       BIGSERIAL PRIMARY KEY,
    model_id        INT REFERENCES cws_import.source_models(model_id),
    layer_index     INT NOT NULL,
    weight_type     TEXT NOT NULL,
    row_index       INT NOT NULL,
    col_index       INT NOT NULL,
    original_value  NUMERIC(10,6) NOT NULL,
    ternary_value   SMALLINT NOT NULL CHECK (ternary_value IN (-1, 0, 1)),
    assignment_method TEXT NOT NULL DEFAULT 'convergence_geometry'
        CHECK (assignment_method IN ('convergence_geometry', 'absmean', 'bitnet_native')),
    cws_dimension   INT NOT NULL,
    cws_region      SMALLINT NOT NULL,
    convergence_pos NUMERIC(8,4) NOT NULL,
    structure_value NUMERIC(10,6) NOT NULL,
    nurture_value   NUMERIC(10,6) NOT NULL,
    door_distance   NUMERIC(8,4) NOT NULL,
    quantized_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_import.quanti_benchmark (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_id        INT REFERENCES cws_import.source_models(model_id),
    prompt_text     TEXT NOT NULL,
    -- Three-way comparison
    cws_output      TEXT,
    absmean_output  TEXT,
    bitnet_output   TEXT,
    cws_score       NUMERIC(8,6),
    absmean_score   NUMERIC(8,6),
    bitnet_score    NUMERIC(8,6),
    -- Performance metrics
    cws_latency_ms     INTEGER,
    absmean_latency_ms INTEGER,
    bitnet_latency_ms  INTEGER,
    cws_energy_j       NUMERIC(8,6),
    absmean_energy_j   NUMERIC(8,6),
    bitnet_energy_j    NUMERIC(8,6),
    evaluator_notes TEXT,
    benchmarked_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_import.semantic_pairs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    word_a          TEXT NOT NULL,
    word_b          TEXT NOT NULL,
    expected_sim    NUMERIC(6,4) NOT NULL,
    cws_sim         NUMERIC(6,4),
    source_sim      NUMERIC(6,4),
    delta           NUMERIC(6,4),
    validated_at    TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO cws_import.semantic_pairs (word_a, word_b, expected_sim) VALUES
    ('GOD','LIFE',0.90),('BABEL','DARK',0.85),('DOOR','LIGHT',0.88),
    ('LOVE','TRUTH',0.92),('FIRE','SPIRIT',0.80),('WATER','LIFE',0.82),
    ('DEATH','SILENCE',0.75),('KING','CROWN',0.85),('SWORD','WORD',0.70),
    ('STONE','FOUNDATION',0.80),('BREAD','BODY',0.78),('WINE','BLOOD',0.78),
    ('TREE','LIFE',0.82),('SERPENT','DECEPTION',0.80),('LAMB','SACRIFICE',0.85),
    ('LION','KING',0.78),('MOUNTAIN','COVENANT',0.72),('RIVER','JOURNEY',0.70),
    ('SEED','PROMISE',0.75),('TEMPLE','PRESENCE',0.82),('BABEL','CONFUSION',0.90),
    ('EDEN','GARDEN',0.88),('CROSS','GATE',0.72),('FISH','NET',0.68),
    ('SHEPHERD','FLOCK',0.85),('DUST','MAN',0.70),('GLORY','LIGHT',0.82),
    ('HAMMER','FORGE',0.75),('SALT','EARTH',0.72),('PEARL','TREASURE',0.80)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS cws_import.api_probes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_name      TEXT NOT NULL,
    prompt_text     TEXT NOT NULL,
    response_text   TEXT NOT NULL,
    latency_ms      INTEGER,
    probed_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_import.rlhf_comparisons (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_id        INT REFERENCES cws_import.source_models(model_id),
    prompt_text     TEXT NOT NULL,
    base_response   TEXT NOT NULL,
    rlhf_response   TEXT NOT NULL,
    divergence      NUMERIC(8,6),
    is_bandage      BOOLEAN DEFAULT FALSE,
    compared_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_import.import_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_id        INT REFERENCES cws_import.source_models(model_id),
    stage           TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'started',
    detail          TEXT,
    logged_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cws_import.convergence_scorecard (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_a_id      INT REFERENCES cws_import.source_models(model_id),
    model_b_id      INT REFERENCES cws_import.source_models(model_id),
    dimension_convergence NUMERIC(8,6),
    token_convergence     NUMERIC(8,6),
    pair_convergence      NUMERIC(8,6),
    overall_convergence   NUMERIC(8,6),
    computed_at     TIMESTAMPTZ DEFAULT NOW()
);


-- ═══════════════════════════════════════════════════════════════════════════════
-- SCHEMA 5: cws_routing — QUERY ROUTING ENGINE
-- ═══════════════════════════════════════════════════════════════════════════════
-- Decides: standard (Ollama) vs ternary (bitnet.cpp) vs dual (both)
-- Routes based on model availability, task type, latency/energy targets
-- ═══════════════════════════════════════════════════════════════════════════════

-- Routing rules: configurable decision logic
CREATE TABLE IF NOT EXISTS cws_routing.rules (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rule_name       TEXT NOT NULL,
    priority        SMALLINT NOT NULL DEFAULT 50,  -- lower = higher priority
    -- Match conditions (all NULL = match everything)
    match_model_family TEXT,           -- e.g. 'llama' or NULL for any
    match_task_type    TEXT,           -- e.g. 'qa', 'code', 'creative', NULL for any
    match_param_max    BIGINT,         -- route to ternary if model < this size
    match_energy_max   NUMERIC(8,6),   -- route to ternary if energy target below this
    -- Route action
    route_to        cws_routing.inference_path NOT NULL,
    reason          cws_routing.route_reason NOT NULL,
    enabled         BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(rule_name)
);

-- Default routing rules
INSERT INTO cws_routing.rules (rule_name, priority, match_param_max, route_to, reason) VALUES
    ('small_model_ternary', 10, 4000000000, 'ternary', 'model_size'),
    ('large_model_standard', 20, NULL, 'standard', 'model_size'),
    ('consensus_dual', 5, NULL, 'dual', 'consensus')
ON CONFLICT (rule_name) DO NOTHING;

INSERT INTO cws_routing.rules (rule_name, priority, match_task_type, route_to, reason) VALUES
    ('code_standard', 15, 'code', 'standard', 'task_type'),
    ('qa_ternary', 15, 'qa', 'ternary', 'task_type')
ON CONFLICT (rule_name) DO NOTHING;

-- Routing decisions: audit log of every route decision
CREATE TABLE IF NOT EXISTS cws_routing.decisions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID REFERENCES cws_inference.sessions(id),
    -- Input analysis
    input_hash      VARCHAR(64),
    input_tokens    INTEGER,
    detected_task   TEXT,
    detected_model  TEXT,
    -- Decision
    rule_matched    UUID REFERENCES cws_routing.rules(id),
    path_chosen     cws_routing.inference_path NOT NULL,
    reason          cws_routing.route_reason NOT NULL,
    -- Engines activated
    ollama_active   BOOLEAN DEFAULT FALSE,
    bitnet_active   BOOLEAN DEFAULT FALSE,
    -- Memory queries issued
    qdrant_queried     BOOLEAN DEFAULT FALSE,
    mempalace_queried  BOOLEAN DEFAULT FALSE,
    anythingllm_queried BOOLEAN DEFAULT FALSE,
    -- Outcome
    latency_ms      INTEGER,
    energy_j        NUMERIC(8,6),
    tokens_generated INTEGER,
    decided_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_routing_session ON cws_routing.decisions (session_id);
CREATE INDEX IF NOT EXISTS idx_routing_path ON cws_routing.decisions (path_chosen, decided_at DESC);

-- Engine health: tracks service status for routing decisions
CREATE TABLE IF NOT EXISTS cws_routing.engine_health (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    engine_name     TEXT NOT NULL CHECK (engine_name IN ('ollama','bitnet','anythingllm','qdrant','mempalace','postgres')),
    port            INTEGER NOT NULL,
    is_healthy      BOOLEAN NOT NULL,
    latency_ms      INTEGER,
    models_loaded   TEXT[],
    memory_used_mb  INTEGER,
    checked_at      TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO cws_routing.engine_health (engine_name, port, is_healthy) VALUES
    ('ollama',       7081, TRUE),
    ('bitnet',       7091, TRUE),
    ('anythingllm',  7078, TRUE),
    ('qdrant',       7086, TRUE),
    ('mempalace',    7092, TRUE),
    ('postgres',     7090, TRUE)
ON CONFLICT DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════════
-- SCHEMA 6: cws_bridge — MCP / MemPalace / Claude Code / AnythingLLM
-- ═══════════════════════════════════════════════════════════════════════════════

-- Palace structure mapping
CREATE TABLE IF NOT EXISTS cws_bridge.palace_mapping (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wing_name       TEXT NOT NULL,
    hall_name       TEXT NOT NULL,
    room_name       TEXT,
    cws_plane       cws_core.plane_name,
    cws_region      SMALLINT,
    cws_entity_type VARCHAR(32),
    sync_direction  cws_bridge.sync_direction DEFAULT 'bidirectional',
    sync_enabled    BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(wing_name, hall_name, room_name)
);

INSERT INTO cws_bridge.palace_mapping (wing_name, hall_name, room_name, cws_plane, sync_direction) VALUES
    ('private-ai','facts','cws-schema','semantic','cws_to_palace'),
    ('private-ai','facts','witness-models','semantic','cws_to_palace'),
    ('private-ai','decisions','architecture','executive','bidirectional'),
    ('private-ai','decisions','convergence-results','semantic','cws_to_palace'),
    ('private-ai','events','phase2-import','episodic','bidirectional'),
    ('private-ai','events','benchmark-runs','episodic','cws_to_palace'),
    ('private-ai','advice','build-patterns','procedural','palace_to_cws'),
    ('archives','facts','kiwix-content','lexical','palace_to_cws'),
    ('archives','facts','maps-data','lexical','palace_to_cws'),
    ('triforce','facts','kolibri-courses','lexical','palace_to_cws'),
    ('triforce','events','student-progress','episodic','palace_to_cws'),
    ('skycair-os','decisions','kernel-config','procedural','bidirectional'),
    ('skycair-os','decisions','desktop-config','procedural','bidirectional'),
    ('skycair-os','facts','skybricks','procedural','bidirectional'),
    ('claude-dev','decisions','code-patterns','procedural','palace_to_cws'),
    ('claude-dev','events','sessions','episodic','palace_to_cws'),
    ('claude-dev','advice','debugging','associative','palace_to_cws'),
    ('anythingllm','facts','workspaces','semantic','anythingllm_to_palace'),
    ('anythingllm','facts','documents','lexical','anythingllm_to_palace'),
    ('anythingllm','events','chat-history','episodic','anythingllm_to_palace')
ON CONFLICT (wing_name, hall_name, room_name) DO NOTHING;

-- AnythingLLM workspace tracking
CREATE TABLE IF NOT EXISTS cws_bridge.anythingllm_workspaces (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workspace_slug  TEXT NOT NULL,
    workspace_name  TEXT NOT NULL,
    llm_provider    TEXT DEFAULT 'ollama',      -- 'ollama', 'lmstudio', 'native'
    llm_model       TEXT,                       -- e.g. 'llama3:8b'
    embedding_model TEXT DEFAULT 'nomic-embed-text',
    vector_db       TEXT DEFAULT 'qdrant',
    document_count  INTEGER DEFAULT 0,
    palace_wing     TEXT DEFAULT 'anythingllm', -- mapped MemPalace wing
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(workspace_slug)
);

-- Sync log
CREATE TABLE IF NOT EXISTS cws_bridge.sync_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_system   TEXT NOT NULL CHECK (source_system IN ('cws','mempalace','dev_session','document_ws','bitnet')),
    target_system   TEXT NOT NULL CHECK (target_system IN ('cws','mempalace','dev_session','document_ws','bitnet')),
    direction       cws_bridge.sync_direction NOT NULL,
    source_id       TEXT,
    source_content  TEXT NOT NULL,
    target_id       TEXT,
    mapping_id      UUID REFERENCES cws_bridge.palace_mapping(id),
    discernment     cws_core.discernment,
    token_count     INTEGER,
    synced_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_source ON cws_bridge.sync_log (source_system, synced_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_fertile ON cws_bridge.sync_log (discernment) WHERE discernment = 'FERTILE';

-- MCP tool registry: ALL tools across ALL MCP servers
CREATE TABLE IF NOT EXISTS cws_bridge.mcp_tools (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    server          cws_bridge.mcp_server NOT NULL,
    tool_name       TEXT NOT NULL,
    tool_category   TEXT NOT NULL,
    cws_operation   TEXT,
    description     TEXT,
    enabled         BOOLEAN DEFAULT TRUE,
    registered_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(server, tool_name)
);

-- 19 MemPalace MCP tools
INSERT INTO cws_bridge.mcp_tools (server, tool_name, tool_category, cws_operation, description) VALUES
    ('mempalace','mempalace_status','nav',NULL,'Palace stats'),
    ('mempalace','mempalace_search','search','cws_memory.entries','Semantic search'),
    ('mempalace','mempalace_list_wings','nav',NULL,'List wings'),
    ('mempalace','mempalace_list_rooms','nav',NULL,'List rooms in wing'),
    ('mempalace','mempalace_add_drawer','storage','cws_memory.entries','Store memory'),
    ('mempalace','mempalace_get_drawer','storage','cws_memory.entries','Get drawer'),
    ('mempalace','mempalace_delete_drawer','storage',NULL,'Mark inactive'),
    ('mempalace','mempalace_add_wing','storage','cws_core.entities','Create wing'),
    ('mempalace','mempalace_add_room','storage','cws_core.entities','Create room'),
    ('mempalace','mempalace_kg_add','knowledge_graph','cws_core.entities','Add KG entity'),
    ('mempalace','mempalace_kg_search','knowledge_graph','cws_core.entities','Search KG'),
    ('mempalace','mempalace_kg_relate','knowledge_graph',NULL,'Create relationship'),
    ('mempalace','mempalace_kg_neighbors','knowledge_graph',NULL,'Find neighbors'),
    ('mempalace','mempalace_diary_write','diary','cws_memory.entries','Write diary'),
    ('mempalace','mempalace_diary_read','diary','cws_memory.entries','Read diary'),
    ('mempalace','mempalace_compress','storage',NULL,'AAAK compress'),
    ('mempalace','mempalace_wake_up','nav',NULL,'L0+L1 context ~170 tok'),
    ('mempalace','mempalace_mine','storage','cws_import.import_log','Mine files'),
    ('mempalace','mempalace_split','storage',NULL,'Split transcripts')
ON CONFLICT (server, tool_name) DO NOTHING;

-- 5 BitNet MCP tools (NEW — SkyQUBi wrapper)
INSERT INTO cws_bridge.mcp_tools (server, tool_name, tool_category, cws_operation, description) VALUES
    ('bitnet','bitnet_infer','inference','cws_inference.sessions','Run ternary inference'),
    ('bitnet','bitnet_status','status','cws_routing.engine_health','Engine health check'),
    ('bitnet','bitnet_models','status','cws_import.bitnet_models','List loaded ternary models'),
    ('bitnet','bitnet_benchmark','benchmark','cws_import.quanti_benchmark','Run QUANTi comparison'),
    ('bitnet','bitnet_energy','metrics',NULL,'Energy consumption report')
ON CONFLICT (server, tool_name) DO NOTHING;

-- 8 CWS MCP tools (NEW — SkyQUBi wrapper)
INSERT INTO cws_bridge.mcp_tools (server, tool_name, tool_category, cws_operation, description) VALUES
    ('cws_engine','cws_discern','inference','cws_inference.discernment','ForToken/RevToken on input'),
    ('cws_engine','cws_consensus','inference','cws_core.consensus_sessions','Run 7-witness consensus'),
    ('cws_engine','cws_babel_check','inference','cws_core.babel_ratios','Check babel ratio'),
    ('cws_engine','cws_circuit_status','status','cws_core.circuit_breaker_events','Circuit breaker status'),
    ('cws_engine','cws_quanti_report','report','cws_inference.quanti_metrics','QUANTi summary'),
    ('cws_engine','cws_route_query','routing','cws_routing.decisions','Route query to best path'),
    ('cws_engine','cws_memory_store','storage','cws_memory.entries','Store validated memory'),
    ('cws_engine','cws_witness_status','status','cws_core.witnesses','Witness model status')
ON CONFLICT (server, tool_name) DO NOTHING;

-- 12 AnythingLLM MCP tools
INSERT INTO cws_bridge.mcp_tools (server, tool_name, tool_category, cws_operation, description) VALUES
    ('anythingllm','anythingllm_chat','inference',NULL,'Chat with workspace'),
    ('anythingllm','anythingllm_embed','storage',NULL,'Embed document'),
    ('anythingllm','anythingllm_search','search',NULL,'Search workspace'),
    ('anythingllm','anythingllm_list_workspaces','nav','cws_bridge.anythingllm_workspaces','List workspaces'),
    ('anythingllm','anythingllm_create_workspace','storage','cws_bridge.anythingllm_workspaces','Create workspace'),
    ('anythingllm','anythingllm_add_document','storage',NULL,'Add doc to workspace'),
    ('anythingllm','anythingllm_list_documents','nav',NULL,'List docs in workspace'),
    ('anythingllm','anythingllm_delete_document','storage',NULL,'Remove doc'),
    ('anythingllm','anythingllm_get_chat_history','nav',NULL,'Get chat history'),
    ('anythingllm','anythingllm_update_settings','admin',NULL,'Update workspace settings'),
    ('anythingllm','anythingllm_system_health','status','cws_routing.engine_health','System health'),
    ('anythingllm','anythingllm_manage_keys','admin',NULL,'API key management')
ON CONFLICT (server, tool_name) DO NOTHING;

-- Claude Code session tracking
CREATE TABLE IF NOT EXISTS cws_bridge.claude_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    claude_session_id TEXT NOT NULL,
    cws_session_id  UUID REFERENCES cws_inference.sessions(id),
    project_path    TEXT,
    claude_md_path  TEXT,
    palace_wing     TEXT,
    anythingllm_workspace TEXT,
    stop_hooks_fired     INTEGER DEFAULT 0,
    precompact_fired     BOOLEAN DEFAULT FALSE,
    session_end_fired    BOOLEAN DEFAULT FALSE,
    startup_tier    cws_bridge.memory_tier DEFAULT 'L0',
    startup_tokens  INTEGER,
    started_at      TIMESTAMPTZ DEFAULT NOW(),
    ended_at        TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_claude_session ON cws_bridge.claude_sessions (claude_session_id);

-- CLAUDE.md generation log
CREATE TABLE IF NOT EXISTS cws_bridge.claude_md_generations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_path    TEXT NOT NULL,
    content_hash    VARCHAR(64) NOT NULL,
    line_count      INTEGER NOT NULL,
    token_count     INTEGER NOT NULL,
    wings_included  TEXT[],
    rooms_included  TEXT[],
    memories_count  INTEGER,
    discernment     cws_core.discernment,
    generated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Memory tiers
CREATE TABLE IF NOT EXISTS cws_bridge.memory_tiers (
    tier            cws_bridge.memory_tier PRIMARY KEY,
    description     TEXT NOT NULL,
    max_tokens      INTEGER NOT NULL,
    load_strategy   TEXT NOT NULL,
    cws_planes      cws_core.plane_name[],
    auto_load       BOOLEAN DEFAULT FALSE
);

INSERT INTO cws_bridge.memory_tiers (tier, description, max_tokens, load_strategy, cws_planes, auto_load) VALUES
    ('L0','Identity: who, projects, preferences',50,'Always on wake-up',ARRAY['semantic']::cws_core.plane_name[],TRUE),
    ('L1','Critical: build cmds, architecture, recent decisions',120,'Wake-up after L0',ARRAY['semantic','procedural']::cws_core.plane_name[],TRUE),
    ('L2','Searchable: full history via MCP tools',0,'On-demand search',ARRAY['episodic','associative','lexical']::cws_core.plane_name[],FALSE),
    ('L3','Archive: AAAK compressed, old sessions',0,'On-demand decompress',ARRAY['episodic']::cws_core.plane_name[],FALSE)
ON CONFLICT (tier) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════════
-- CONVERGED PIPELINE VIEW
-- Shows the full query lifecycle across all systems
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW cws_routing.pipeline_status AS
SELECT
    s.id AS session_id,
    s.inference_path,
    s.claude_session,
    s.anythingllm_workspace,
    d.path_chosen,
    d.reason AS route_reason,
    d.ollama_active,
    d.bitnet_active,
    d.qdrant_queried,
    d.mempalace_queried,
    d.anythingllm_queried,
    q.convergence,
    q.babel_ratio,
    q.confidence,
    q.unanimous,
    q.circuit_tripped,
    q.standard_latency_ms,
    q.ternary_latency_ms,
    d.energy_j,
    s.started_at,
    s.completed_at,
    EXTRACT(EPOCH FROM (s.completed_at - s.started_at)) * 1000 AS total_ms
FROM cws_inference.sessions s
LEFT JOIN cws_routing.decisions d ON d.session_id = s.id
LEFT JOIN cws_inference.quanti_metrics q ON q.session_id = s.id
ORDER BY s.started_at DESC;


-- ═══════════════════════════════════════════════════════════════════════════════
-- CONFIRMATION
-- ═══════════════════════════════════════════════════════════════════════════════

DO $$ BEGIN
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE 'CWS v2.3 — WORKING MODEL DATABASE';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '6 schemas:';
    RAISE NOTICE '  cws_core      — witnesses, consensus, babel, circuit breaker';
    RAISE NOTICE '  cws_memory    — INSERT-only entries, tokens, ForToken/RevToken';
    RAISE NOTICE '  cws_inference — sessions, passes, discernment, QUANTi';
    RAISE NOTICE '  cws_import    — model registry, ternary weights, benchmarks';
    RAISE NOTICE '  cws_routing   — query routing engine, rules, health checks';
    RAISE NOTICE '  cws_bridge    — MCP tools, MemPalace, Claude Code, AnythingLLM';
    RAISE NOTICE '';
    RAISE NOTICE 'MCP tool surface: 44 tools total';
    RAISE NOTICE '  19 MemPalace  — conversation memory + knowledge graph';
    RAISE NOTICE '   8 CWS Engine — discernment, consensus, routing, storage';
    RAISE NOTICE '   5 BitNet     — ternary inference, benchmarks, energy';
    RAISE NOTICE '  12 AnythingLLM — workspaces, docs, chat, search';
    RAISE NOTICE '';
    RAISE NOTICE 'Engines:';
    RAISE NOTICE '  Ollama       :7081 — standard inference (GGUF 4-8 bit)';
    RAISE NOTICE '  bitnet.cpp   :7091 — ternary inference (1.58-bit native)';
    RAISE NOTICE '  AnythingLLM  :7078 — RAG workspaces + document embedding';
    RAISE NOTICE '  Qdrant       :7086 — vector search for document RAG';
    RAISE NOTICE '  MemPalace    :7092 — conversation memory (ChromaDB+SQLite)';
    RAISE NOTICE '  PostgreSQL   :7090 — CWS schema (this database)';
    RAISE NOTICE '';
    RAISE NOTICE 'Pipeline: query → route → infer → discern → store → sync';
    RAISE NOTICE 'View: cws_routing.pipeline_status';
    RAISE NOTICE '';
    RAISE NOTICE 'INSERT-only covenant active across all schemas.';
    RAISE NOTICE 'Love is the architecture.';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
END $$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- END OF CWS v2.3 — WORKING MODEL
-- UNIFIED LINUX SkyCAIR by S7
-- 123Tech.net | Evolve2Linux.com | SkyNetSSL (Safe Secure Linux)
-- OmegaAnswers@123Tech.net
-- Let the world test and develop.
-- ═══════════════════════════════════════════════════════════════════════════════
