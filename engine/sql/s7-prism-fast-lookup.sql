-- engine/sql/s7-prism-fast-lookup.sql
-- Super-fast access for anchored and trusted tokens.
--
-- Jamie: 'SUPER FAST ACCESS TO THAT' + 'NVMe over TCPIP, U.2, GPU,
--         RAM Memory Persistent vs Zcach / linux swap. It's
--         important to stage tiering where speed is critical.'
--
-- This is the postgres-tier fast path. The full memory hierarchy
-- (GPU VRAM → DRAM Redis → zram → Persistent RAM → local NVMe →
-- NVMe/TCP → swap) lives in docs/internal/research/2026-04-13-
-- tiered-storage-strategy.md.
--
-- For postgres-tier alone:
--   - A partial index on (cws_tier='anchored') narrows the B-tree
--     to only the anchored subset — typically <1% of the full table
--   - Postgres shared_buffers keeps the anchored pages warm
--   - The lookup function uses SET LOCAL enable_seqscan=off to
--     force the index every time, even on small tables

CREATE OR REPLACE FUNCTION cws_core.fast_lookup_cell(
    p_sensory     SMALLINT,
    p_episodic    SMALLINT,
    p_semantic    SMALLINT,
    p_associative SMALLINT,
    p_procedural  SMALLINT,
    p_lexical     SMALLINT,
    p_relational  SMALLINT,
    p_executive   SMALLINT
)
RETURNS TABLE (
    id             UUID,
    cws_tier       TEXT,
    dissolution_count INTEGER,
    foundation_weight REAL,
    witness_consensus  JSONB
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    -- Hot path: anchored tier first (smallest partial index)
    RETURN QUERY
    SELECT l.id, l.cws_tier, l.dissolution_count,
           l.foundation_weight, l.witness_consensus
    FROM cws_core.location_id l
    WHERE l.cws_tier = 'anchored'
      AND l.sensory_dir     = p_sensory
      AND l.episodic_dir    = p_episodic
      AND l.semantic_dir    = p_semantic
      AND l.associative_dir = p_associative
      AND l.procedural_dir  = p_procedural
      AND l.lexical_dir     = p_lexical
      AND l.relational_dir  = p_relational
      AND l.executive_dir   = p_executive
    ORDER BY l.dissolution_count DESC
    LIMIT 1;

    IF FOUND THEN
        RETURN;
    END IF;

    -- Warm path: trusted tier
    RETURN QUERY
    SELECT l.id, l.cws_tier, l.dissolution_count,
           l.foundation_weight, l.witness_consensus
    FROM cws_core.location_id l
    WHERE l.cws_tier = 'trusted'
      AND l.sensory_dir     = p_sensory
      AND l.episodic_dir    = p_episodic
      AND l.semantic_dir    = p_semantic
      AND l.associative_dir = p_associative
      AND l.procedural_dir  = p_procedural
      AND l.lexical_dir     = p_lexical
      AND l.relational_dir  = p_relational
      AND l.executive_dir   = p_executive
    ORDER BY l.dissolution_count DESC
    LIMIT 1;

    IF FOUND THEN
        RETURN;
    END IF;

    -- Cold path: anything else at this cell
    RETURN QUERY
    SELECT l.id, l.cws_tier, l.dissolution_count,
           l.foundation_weight, l.witness_consensus
    FROM cws_core.location_id l
    WHERE l.sensory_dir     = p_sensory
      AND l.episodic_dir    = p_episodic
      AND l.semantic_dir    = p_semantic
      AND l.associative_dir = p_associative
      AND l.procedural_dir  = p_procedural
      AND l.lexical_dir     = p_lexical
      AND l.relational_dir  = p_relational
      AND l.executive_dir   = p_executive
    ORDER BY COALESCE(l.foundation_weight, 0) DESC
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION cws_core.fast_lookup_cell IS
  'Tiered fast lookup: anchored → trusted → anything. Uses partial indexes on (cws_tier) so anchored lookups scan only the smallest partition. First stage of the full speed hierarchy documented in docs/internal/research/2026-04-13-tiered-storage-strategy.md.';
