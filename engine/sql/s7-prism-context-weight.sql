-- engine/sql/s7-prism-context-weight.sql
-- S7 QBIT Prism — Context Weight column + recompute.
--
-- Jamie's framing: 'there is a weight missing — context model
-- selection index merge append reconsider judgement after expanding
-- aptitude plane to models synchronize or asymmetry … Context Weight
-- = encoded reference expands aptitude without token because
-- compressed tokens hold history.'
--
-- The insight that unlocks this: every LocationID already carries
-- its full history in compressed form (the 8-plane cell + the
-- Stern-Brocot subposition + the strand tokens). When the aptitude
-- plane expands — new universals land, new forbidden concepts land,
-- new foundations land — past entries do NOT need to be re-
-- tokenised or re-encoded. Their compressed form is sufficient to
-- re-weight them in place with a single UPDATE.
--
-- context_weight is the scalar that captures this. It is:
--   - Initialised to aptitude_delta at ingest time
--   - Recomputed by a sweep function (UPDATE only, no re-encode)
--     whenever the matrix expands enough to justify it
--   - UPDATE-only in the INSERT-only covenant: weight is a
--     recomputable derivative, not a new claim. Modifying it does
--     not violate the audit property of the underlying row.
--
-- The recompute formula is intentionally simple for tonight:
--
--   context_weight = aptitude_delta
--                  + strand_foundation_bonus
--                  + cell_density_bonus
--
-- where:
--   strand_foundation_bonus  = count of foundation rows reachable
--                              from this row's for_token + rev_token
--   cell_density_bonus       = count of other rows in the same
--                              integer cell (excluding self), capped
--                              at 10 to prevent runaway
--
-- Richer formulas (time decay, witness-specific weight, per-model
-- asymmetry) land in phase 2. Tonight's version ships the column
-- and proves the UPDATE-only recompute path works.

ALTER TABLE cws_core.location_id
  ADD COLUMN IF NOT EXISTS context_weight REAL NOT NULL DEFAULT 0.0;

COMMENT ON COLUMN cws_core.location_id.context_weight IS
  'Per-row scalar derived from aptitude_delta + strand_foundation_bonus + cell_density_bonus. UPDATE-only recomputable derivative. Expands with the aptitude plane without re-tokenising the source text — compressed tokens already hold history.';

CREATE INDEX IF NOT EXISTS location_id_context_weight_idx
  ON cws_core.location_id (context_weight DESC);

-- ── Recompute function ─────────────────────────────────────────────
-- Pure SQL, no re-encoding, one UPDATE pass. Can be called at any
-- time. Idempotent. Jamie: 'encoded reference expands aptitude
-- without token because compressed tokens hold history.'

CREATE OR REPLACE FUNCTION cws_core.recompute_context_weight()
RETURNS TABLE (rows_updated INT, min_weight REAL, max_weight REAL, avg_weight REAL)
LANGUAGE plpgsql
AS $$
DECLARE
    n INT;
BEGIN
    WITH strand_bonus AS (
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
    cell_bonus AS (
        SELECT
            l.id,
            LEAST(
                (
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
                ),
                10
            )::INT AS same_cell_count
        FROM cws_core.location_id l
    )
    UPDATE cws_core.location_id lid
    SET context_weight = (
        COALESCE(lid.aptitude_delta, 0)::REAL
        + COALESCE(sb.anchored_by_count, 0)::REAL
        + COALESCE(cb.same_cell_count, 0)::REAL
    )
    FROM strand_bonus sb, cell_bonus cb
    WHERE sb.id = lid.id AND cb.id = lid.id;

    GET DIAGNOSTICS n = ROW_COUNT;

    RETURN QUERY
        SELECT
            n,
            MIN(context_weight)::REAL,
            MAX(context_weight)::REAL,
            AVG(context_weight)::REAL
        FROM cws_core.location_id;
END;
$$;

COMMENT ON FUNCTION cws_core.recompute_context_weight() IS
  'Recompute context_weight for every row in cws_core.location_id using strand anchoring + cell density. Single UPDATE pass, no re-encoding, idempotent. Call on aptitude plane expansion events.';

-- Run once to backfill the new column for all existing rows.
SELECT * FROM cws_core.recompute_context_weight();
