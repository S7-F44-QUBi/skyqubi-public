-- ═══════════════════════════════════════════════════════════════════════════════
-- CWS QBIT PRISM EXTENSION
-- 8-Plane Convergence Vector Decomposition + RAG Reasoning
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Licensor:       123Tech / 2XR, LLC
-- Licensed Work:  CWS QBIT Prism Extension, April 10, 2026
-- License:        Business Source License 1.1
-- Change Date:    April 7, 2030
-- Change License: Apache License 2.0
--
-- Contact:        OmegaAnswers@123Tech.net
-- Brand:          UNIFIED LINUX SkyCAIR by S7
--
-- Patent Pending: CWS-005 — QBIT Prism Convergence Vector Decomposition
--
-- WHAT THIS ADDS:
--   cws_core.prism_vectors     — 8-plane convergence vector per entity
--   cws_memory.rag_reasoning   — direction-verified retrieval hop log
--   cws_memory.reasoning_chains — multi-hop reasoning chain audit trail
--
-- Every retrieval is now a testable geometric claim.
-- INSERT-only covenant applies to all new tables.
-- ═══════════════════════════════════════════════════════════════════════════════


-- ─── QBIT PRISM: 8-PLANE CONVERGENCE VECTORS ─────────────────────────────────

-- Stores the full QBIT Prism decomposition for any entity or memory entry.
-- Each plane gets: convergence_x (position on axis) + direction (ternary)
-- This is the vector quantity: magnitude (door_distance from x=0) + direction.

CREATE TABLE IF NOT EXISTS cws_core.prism_vectors (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id       UUID REFERENCES cws_core.entities(id),
    memory_entry_id UUID REFERENCES cws_memory.entries(id),
    -- Sensory plane: raw input, perception
    sensory_x       NUMERIC(10,6) NOT NULL DEFAULT 0,
    sensory_dir     SMALLINT NOT NULL DEFAULT 0 CHECK (sensory_dir IN (-1,0,1)),
    sensory_mag     NUMERIC(10,6) NOT NULL DEFAULT 0,
    -- Episodic plane: temporal sequences, events
    episodic_x      NUMERIC(10,6) NOT NULL DEFAULT 0,
    episodic_dir    SMALLINT NOT NULL DEFAULT 0 CHECK (episodic_dir IN (-1,0,1)),
    episodic_mag    NUMERIC(10,6) NOT NULL DEFAULT 0,
    -- Semantic plane: meaning, concepts
    semantic_x      NUMERIC(10,6) NOT NULL DEFAULT 0,
    semantic_dir    SMALLINT NOT NULL DEFAULT 0 CHECK (semantic_dir IN (-1,0,1)),
    semantic_mag    NUMERIC(10,6) NOT NULL DEFAULT 0,
    -- Associative plane: relationships, connections
    associative_x   NUMERIC(10,6) NOT NULL DEFAULT 0,
    associative_dir SMALLINT NOT NULL DEFAULT 0 CHECK (associative_dir IN (-1,0,1)),
    associative_mag NUMERIC(10,6) NOT NULL DEFAULT 0,
    -- Procedural plane: action patterns, how-to
    procedural_x    NUMERIC(10,6) NOT NULL DEFAULT 0,
    procedural_dir  SMALLINT NOT NULL DEFAULT 0 CHECK (procedural_dir IN (-1,0,1)),
    procedural_mag  NUMERIC(10,6) NOT NULL DEFAULT 0,
    -- Lexical plane: vocabulary, token forms
    lexical_x       NUMERIC(10,6) NOT NULL DEFAULT 0,
    lexical_dir     SMALLINT NOT NULL DEFAULT 0 CHECK (lexical_dir IN (-1,0,1)),
    lexical_mag     NUMERIC(10,6) NOT NULL DEFAULT 0,
    -- Relational plane: hierarchies, structure
    relational_x    NUMERIC(10,6) NOT NULL DEFAULT 0,
    relational_dir  SMALLINT NOT NULL DEFAULT 0 CHECK (relational_dir IN (-1,0,1)),
    relational_mag  NUMERIC(10,6) NOT NULL DEFAULT 0,
    -- Executive plane: decisions, goals, control
    executive_x     NUMERIC(10,6) NOT NULL DEFAULT 0,
    executive_dir   SMALLINT NOT NULL DEFAULT 0 CHECK (executive_dir IN (-1,0,1)),
    executive_mag   NUMERIC(10,6) NOT NULL DEFAULT 0,
    -- Metadata
    computed_at     TIMESTAMPTZ DEFAULT NOW()
    -- INSERT-only: no updated_at
);

CREATE INDEX IF NOT EXISTS idx_prism_entity  ON cws_core.prism_vectors (entity_id);
CREATE INDEX IF NOT EXISTS idx_prism_entry   ON cws_core.prism_vectors (memory_entry_id);
-- Direction indexes for fast direction-matching retrieval
CREATE INDEX IF NOT EXISTS idx_prism_semantic_dir  ON cws_core.prism_vectors (semantic_dir);
CREATE INDEX IF NOT EXISTS idx_prism_episodic_dir  ON cws_core.prism_vectors (episodic_dir);
CREATE INDEX IF NOT EXISTS idx_prism_executive_dir ON cws_core.prism_vectors (executive_dir);


-- ─── RAG REASONING: DIRECTION-VERIFIED RETRIEVAL LOG ─────────────────────────

-- Every retrieval hop in a RAG Reasoning chain is logged here.
-- query_prism_id: the QBIT Prism decomposition of the current reasoning step
-- retrieved_entry: the memory entry that was retrieved
-- agreement_score: fraction of planes where directions agreed
-- result: FERTILE (used in chain) or BABEL (rejected)
-- hop_index: position in the multi-hop reasoning chain (0 = first retrieval)

CREATE TABLE IF NOT EXISTS cws_memory.rag_reasoning (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id          UUID REFERENCES cws_inference.sessions(id),
    chain_id            UUID,   -- FK to reasoning_chains, set after that table exists
    query_prism_id      UUID REFERENCES cws_core.prism_vectors(id),
    retrieved_entry_id  UUID REFERENCES cws_memory.entries(id),
    -- Agreement metrics
    agreement_score     NUMERIC(6,4) NOT NULL,
    fertile_planes      SMALLINT NOT NULL DEFAULT 0,
    total_planes        SMALLINT NOT NULL DEFAULT 8,
    -- Per-plane direction match flags (bitmask: bit i = plane i fertile)
    plane_mask          SMALLINT DEFAULT 0,
    -- Primary planes consulted for this hop
    primary_planes      TEXT[],
    -- Result
    result              cws_core.discernment NOT NULL,
    hop_index           SMALLINT NOT NULL DEFAULT 0,
    retrieved_at        TIMESTAMPTZ DEFAULT NOW()
    -- INSERT-only: no updated_at
);

CREATE INDEX IF NOT EXISTS idx_rag_session  ON cws_memory.rag_reasoning (session_id, hop_index);
CREATE INDEX IF NOT EXISTS idx_rag_fertile  ON cws_memory.rag_reasoning (result) WHERE result = 'FERTILE';
CREATE INDEX IF NOT EXISTS idx_rag_chain    ON cws_memory.rag_reasoning (chain_id, hop_index);


-- ─── REASONING CHAINS: MULTI-HOP AUDIT TRAIL ─────────────────────────────────

-- A reasoning chain is a sequence of FERTILE retrieval hops that collectively
-- produce a verified answer. Each hop builds on the previous.
-- The chain is complete when the circuit breaker is not triggered and the
-- executive plane reaches convergence (direction stabilizes).
--
-- This is the INSERT-only audit trail of the reasoning process itself.

CREATE TABLE IF NOT EXISTS cws_memory.reasoning_chains (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID REFERENCES cws_inference.sessions(id),
    query_text      TEXT NOT NULL,
    query_hash      VARCHAR(64) NOT NULL,
    -- Chain statistics
    total_hops      SMALLINT NOT NULL DEFAULT 0,
    fertile_hops    SMALLINT NOT NULL DEFAULT 0,
    babel_hops      SMALLINT NOT NULL DEFAULT 0,
    -- Final convergence
    final_direction SMALLINT CHECK (final_direction IN (-1,0,1)),
    final_plane     TEXT,
    converged       BOOLEAN DEFAULT FALSE,
    -- Circuit breaker
    babel_ratio     NUMERIC(6,4),
    circuit_tripped BOOLEAN DEFAULT FALSE,
    -- Timing
    started_at      TIMESTAMPTZ DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
    -- INSERT-only: no updated_at
);

CREATE INDEX IF NOT EXISTS idx_chain_session ON cws_memory.reasoning_chains (session_id);
CREATE INDEX IF NOT EXISTS idx_chain_hash    ON cws_memory.reasoning_chains (query_hash);

-- Add FK from rag_reasoning to reasoning_chains
ALTER TABLE cws_memory.rag_reasoning
    ADD CONSTRAINT fk_rag_chain
    FOREIGN KEY (chain_id) REFERENCES cws_memory.reasoning_chains(id)
    DEFERRABLE INITIALLY DEFERRED;


-- ─── PRISM SUMMARY VIEW ──────────────────────────────────────────────────────

CREATE OR REPLACE VIEW cws_core.prism_summary AS
SELECT
    p.id,
    p.entity_id,
    p.memory_entry_id,
    -- Direction summary: one char per plane (-/0/+)
    CONCAT(
        CASE sensory_dir     WHEN -1 THEN '-' WHEN 1 THEN '+' ELSE '0' END,
        CASE episodic_dir    WHEN -1 THEN '-' WHEN 1 THEN '+' ELSE '0' END,
        CASE semantic_dir    WHEN -1 THEN '-' WHEN 1 THEN '+' ELSE '0' END,
        CASE associative_dir WHEN -1 THEN '-' WHEN 1 THEN '+' ELSE '0' END,
        CASE procedural_dir  WHEN -1 THEN '-' WHEN 1 THEN '+' ELSE '0' END,
        CASE lexical_dir     WHEN -1 THEN '-' WHEN 1 THEN '+' ELSE '0' END,
        CASE relational_dir  WHEN -1 THEN '-' WHEN 1 THEN '+' ELSE '0' END,
        CASE executive_dir   WHEN -1 THEN '-' WHEN 1 THEN '+' ELSE '0' END
    ) AS direction_signature,
    -- Zero count: how many planes are at the Door
    (
        (CASE WHEN sensory_dir     = 0 THEN 1 ELSE 0 END) +
        (CASE WHEN episodic_dir    = 0 THEN 1 ELSE 0 END) +
        (CASE WHEN semantic_dir    = 0 THEN 1 ELSE 0 END) +
        (CASE WHEN associative_dir = 0 THEN 1 ELSE 0 END) +
        (CASE WHEN procedural_dir  = 0 THEN 1 ELSE 0 END) +
        (CASE WHEN lexical_dir     = 0 THEN 1 ELSE 0 END) +
        (CASE WHEN relational_dir  = 0 THEN 1 ELSE 0 END) +
        (CASE WHEN executive_dir   = 0 THEN 1 ELSE 0 END)
    ) AS door_planes,
    p.computed_at
FROM cws_core.prism_vectors p;


-- ─── RAG REASONING PIPELINE VIEW ─────────────────────────────────────────────

CREATE OR REPLACE VIEW cws_memory.rag_pipeline AS
SELECT
    rc.id              AS chain_id,
    rc.query_text,
    rc.total_hops,
    rc.fertile_hops,
    rc.babel_hops,
    rc.babel_ratio,
    rc.converged,
    rc.circuit_tripped,
    rc.final_direction,
    rc.final_plane,
    r.hop_index,
    r.agreement_score,
    r.result           AS hop_result,
    r.primary_planes,
    r.retrieved_at,
    EXTRACT(EPOCH FROM (rc.completed_at - rc.started_at)) * 1000 AS chain_ms
FROM cws_memory.reasoning_chains rc
LEFT JOIN cws_memory.rag_reasoning r ON r.chain_id = rc.id
ORDER BY rc.started_at DESC, r.hop_index ASC;


-- ─── CONFIRMATION ────────────────────────────────────────────────────────────

DO $$ BEGIN
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE 'CWS QBIT Prism Extension — Loaded';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE 'New tables:';
    RAISE NOTICE '  cws_core.prism_vectors      — 8-plane convergence vectors';
    RAISE NOTICE '  cws_memory.rag_reasoning    — direction-verified retrieval log';
    RAISE NOTICE '  cws_memory.reasoning_chains — multi-hop chain audit trail';
    RAISE NOTICE 'New views:';
    RAISE NOTICE '  cws_core.prism_summary      — direction signature per entity';
    RAISE NOTICE '  cws_memory.rag_pipeline     — full chain lifecycle view';
    RAISE NOTICE '';
    RAISE NOTICE 'Retrieval is now a testable geometric claim.';
    RAISE NOTICE 'Direction {-1,0,+1} = vector quantity. Cosine = scalar.';
    RAISE NOTICE 'Patent Pending: CWS-005';
    RAISE NOTICE 'INSERT-only covenant active.';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
END $$;
