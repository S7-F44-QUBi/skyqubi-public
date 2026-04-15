-- engine/sql/s7-prism-weight-split.sql
-- Split context_weight → foundation_weight + learning_weight.
--
-- Jamie's framing: 'chris langdan chris bledsoe Intelligent vs
-- Humble — they parallel CMTU.'
--
-- Langan (CTMU, formal, structural, intelligent) and Bledsoe
-- (experiential, surrender, humble) are two parallel tracks
-- converging on the same covenant. In the Prism geometry they
-- correspond to:
--
--   foundation_weight — structure pole, -1 memory axis,
--                       structure_curve (Father peak at x=-1)
--                       • aptitude_delta contribution
--                       • strand_anchored_by_count (rows that
--                         point INTO this row via for/rev_token)
--                       • cell_density (mass already here)
--
--   learning_weight   — nurture pole, +1 destiny axis,
--                       nurture_curve (Mother peak at x=+1)
--                       • strand_reaches_count (rows this row's
--                         for_token/rev_token points AT)
--                       • same_cell_velocity (rows added to the
--                         same cell AFTER this one — pull signal)
--                       • subposition_distance_from_unit (Stern-
--                         Brocot pull toward unexplored rationals)
--
-- context_weight stays as the sum: foundation_weight + learning_weight.
-- A row with only foundation is calcified; a row with only learning
-- is untethered; covenant requires both.

ALTER TABLE cws_core.location_id
  ADD COLUMN IF NOT EXISTS foundation_weight REAL NOT NULL DEFAULT 0.0;
ALTER TABLE cws_core.location_id
  ADD COLUMN IF NOT EXISTS learning_weight REAL NOT NULL DEFAULT 0.0;

COMMENT ON COLUMN cws_core.location_id.foundation_weight IS
  'Structure-pole weight (Langan / CTMU / force / -1 memory). aptitude_delta + anchored_by_count + same_cell_density.';

COMMENT ON COLUMN cws_core.location_id.learning_weight IS
  'Nurture-pole weight (Bledsoe / surrender / pull / +1 destiny). strand_reach + same_cell_velocity + subposition_frontier.';

CREATE INDEX IF NOT EXISTS location_id_foundation_weight_idx
  ON cws_core.location_id (foundation_weight DESC);

CREATE INDEX IF NOT EXISTS location_id_learning_weight_idx
  ON cws_core.location_id (learning_weight DESC);


-- ── New recompute function: parallel weights + total ──────────────

CREATE OR REPLACE FUNCTION cws_core.recompute_parallel_weights()
RETURNS TABLE (
    rows_updated INT,
    foundation_min REAL, foundation_max REAL, foundation_avg REAL,
    learning_min REAL,   learning_max REAL,   learning_avg REAL,
    context_min REAL,    context_max REAL,    context_avg REAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    n INT;
BEGIN
    WITH
    -- Langan / structure / force side
    anchored_by AS (
        SELECT
            l.id,
            (
                SELECT count(*)::INT
                FROM cws_core.location_id t
                WHERE (t.for_token IS NOT NULL AND t.for_token = l.id)
                   OR (t.rev_token IS NOT NULL AND t.rev_token = l.id)
            ) AS anchored_by_count
        FROM cws_core.location_id l
    ),
    cell_density AS (
        SELECT
            l.id,
            LEAST((
                SELECT count(*) - 1
                FROM cws_core.location_id n
                WHERE n.sensory_dir     = l.sensory_dir
                  AND n.episodic_dir    = l.episodic_dir
                  AND n.semantic_dir    = l.semantic_dir
                  AND n.associative_dir = l.associative_dir
                  AND n.procedural_dir  = l.procedural_dir
                  AND n.lexical_dir     = l.lexical_dir
                  AND n.relational_dir  = l.relational_dir
                  AND n.executive_dir   = l.executive_dir
            ), 10)::INT AS same_cell_count
        FROM cws_core.location_id l
    ),
    -- Bledsoe / nurture / pull side
    strand_reach AS (
        SELECT
            l.id,
            (
                (CASE WHEN l.for_token IS NOT NULL
                      AND EXISTS (SELECT 1 FROM cws_core.location_id x WHERE x.id = l.for_token)
                      THEN 1 ELSE 0 END)
              + (CASE WHEN l.rev_token IS NOT NULL
                      AND EXISTS (SELECT 1 FROM cws_core.location_id x WHERE x.id = l.rev_token)
                      THEN 1 ELSE 0 END)
            )::INT AS strand_reach_count
        FROM cws_core.location_id l
    ),
    same_cell_velocity AS (
        SELECT
            l.id,
            LEAST((
                SELECT count(*)
                FROM cws_core.location_id n
                WHERE n.created_at > l.created_at
                  AND n.sensory_dir     = l.sensory_dir
                  AND n.episodic_dir    = l.episodic_dir
                  AND n.semantic_dir    = l.semantic_dir
                  AND n.associative_dir = l.associative_dir
                  AND n.procedural_dir  = l.procedural_dir
                  AND n.lexical_dir     = l.lexical_dir
                  AND n.relational_dir  = l.relational_dir
                  AND n.executive_dir   = l.executive_dir
            ), 10)::INT AS velocity_count
        FROM cws_core.location_id l
    ),
    subposition_frontier AS (
        -- How far the rational subposition is from the "unit"
        -- position 1/1 — encourages entries that have been
        -- subdivided (Stern-Brocot pull) as a nurture signal.
        SELECT
            l.id,
            CASE
                WHEN l.sub_num = 1 AND l.sub_den = 1 THEN 0.0
                ELSE LEAST(log(GREATEST(l.sub_den, 1))::REAL, 5.0)
            END AS sub_bonus
        FROM cws_core.location_id l
    )
    UPDATE cws_core.location_id lid
    SET
        foundation_weight = (
            COALESCE(lid.aptitude_delta, 0)::REAL
            + COALESCE(ab.anchored_by_count, 0)::REAL
            + COALESCE(cd.same_cell_count, 0)::REAL
        ),
        learning_weight = (
            COALESCE(sr.strand_reach_count, 0)::REAL
            + COALESCE(scv.velocity_count, 0)::REAL
            + COALESCE(sf.sub_bonus, 0)::REAL
        ),
        context_weight = (
            COALESCE(lid.aptitude_delta, 0)::REAL
            + COALESCE(ab.anchored_by_count, 0)::REAL
            + COALESCE(cd.same_cell_count, 0)::REAL
            + COALESCE(sr.strand_reach_count, 0)::REAL
            + COALESCE(scv.velocity_count, 0)::REAL
            + COALESCE(sf.sub_bonus, 0)::REAL
        )
    FROM anchored_by ab, cell_density cd, strand_reach sr, same_cell_velocity scv, subposition_frontier sf
    WHERE ab.id = lid.id AND cd.id = lid.id AND sr.id = lid.id AND scv.id = lid.id AND sf.id = lid.id;

    GET DIAGNOSTICS n = ROW_COUNT;

    RETURN QUERY
        SELECT
            n,
            MIN(foundation_weight)::REAL, MAX(foundation_weight)::REAL, AVG(foundation_weight)::REAL,
            MIN(learning_weight)::REAL,   MAX(learning_weight)::REAL,   AVG(learning_weight)::REAL,
            MIN(context_weight)::REAL,    MAX(context_weight)::REAL,    AVG(context_weight)::REAL
        FROM cws_core.location_id;
END;
$$;

COMMENT ON FUNCTION cws_core.recompute_parallel_weights() IS
  'Recompute foundation_weight + learning_weight + context_weight in one UPDATE pass. Parallel tracks: Langan structure / Bledsoe surrender. UPDATE-only, idempotent, no re-encoding.';

-- Backfill
SELECT * FROM cws_core.recompute_parallel_weights();
