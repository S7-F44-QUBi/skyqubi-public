-- engine/sql/s7-prism-tier-classifier.sql
-- Principled, declarative CWS tier classification.
--
-- Jamie: 'permanent fix it, move forward we got time, fix now
--         dont add and break it later when we cant afford breakage'
--
-- Replaces the per-row UPDATE hack with:
--   1. A deterministic classifier function that maps any row's
--      content to its proper CWS tier
--   2. A BEFORE INSERT/UPDATE trigger that sets cws_tier
--      automatically — every new row gets the right tier at
--      insert time, every existing row gets the right tier on
--      any future update
--   3. A one-time backfill that runs the classifier over every
--      existing row
--
-- Rules (in evaluation order, first match wins):
--   1. witness_consensus IS NOT NULL AND dissolution_count >= 7
--        → 'anchored'
--   2. witness_consensus IS NOT NULL
--        → 'trusted'
--   3. notes LIKE 'Prism v1.0.1 schema foundation%'
--        → 'trusted' (covenant seed; Door row is ground truth)
--   4. aptitude_delta >= 1
--        → 'probationary' (has content, not yet witness-verified)
--   5. default
--        → 'unset' (no classification data)

CREATE OR REPLACE FUNCTION cws_core.classify_cws_tier(
    p_witness_consensus JSONB,
    p_dissolution_count INTEGER,
    p_notes             TEXT,
    p_aptitude_delta    SMALLINT
)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_witness_consensus IS NOT NULL AND COALESCE(p_dissolution_count, 0) >= 7
            THEN 'anchored'
        WHEN p_witness_consensus IS NOT NULL
            THEN 'trusted'
        WHEN p_notes LIKE 'Prism v1.0.1 schema foundation%'
            THEN 'trusted'
        WHEN COALESCE(p_aptitude_delta, 0) >= 1
            THEN 'probationary'
        ELSE 'unset'
    END
$$;

COMMENT ON FUNCTION cws_core.classify_cws_tier IS
  'Deterministic CWS tier classifier. First-match rules. Used both by the auto-tier trigger (on every INSERT/UPDATE) and by the one-time backfill that initialized tonight''s existing rows.';


-- ── BEFORE INSERT/UPDATE trigger — auto-classify on write ─────────
-- Works alongside cws_tier_auto_promote (which handles the
-- trusted → anchored promotion on dissolution_count >= 7). This
-- one sets the INITIAL tier when the row is first written, and
-- re-runs classification when witness_consensus or aptitude_delta
-- changes.

CREATE OR REPLACE FUNCTION cws_core.auto_classify_tier()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- If the caller explicitly set a non-default tier, trust them
    -- unless the classifier would promote higher
    IF TG_OP = 'UPDATE' AND OLD.cws_tier = NEW.cws_tier THEN
        -- classification fields haven't changed intent; just
        -- reclassify to keep the tier honest
        NEW.cws_tier := cws_core.classify_cws_tier(
            NEW.witness_consensus,
            NEW.dissolution_count,
            NEW.notes,
            NEW.aptitude_delta
        );
    ELSIF TG_OP = 'INSERT' AND NEW.cws_tier = 'unset' THEN
        NEW.cws_tier := cws_core.classify_cws_tier(
            NEW.witness_consensus,
            NEW.dissolution_count,
            NEW.notes,
            NEW.aptitude_delta
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cws_tier_auto_classify ON cws_core.location_id;
CREATE TRIGGER cws_tier_auto_classify
  BEFORE INSERT OR UPDATE OF witness_consensus, aptitude_delta, notes
  ON cws_core.location_id
  FOR EACH ROW
  EXECUTE FUNCTION cws_core.auto_classify_tier();

COMMENT ON FUNCTION cws_core.auto_classify_tier IS
  'BEFORE trigger that auto-applies cws_core.classify_cws_tier on every INSERT and on updates that change classification-relevant fields. Caller overrides are preserved unless the row is being inserted with cws_tier=unset.';


-- ── One-time backfill: reclassify every existing row ──────────────

UPDATE cws_core.location_id
SET cws_tier = cws_core.classify_cws_tier(
    witness_consensus,
    dissolution_count,
    notes,
    aptitude_delta
);

-- ── Verify ────────────────────────────────────────────────────────

SELECT cws_tier, count(*) AS rows
FROM cws_core.location_id
GROUP BY cws_tier
ORDER BY
  CASE cws_tier
    WHEN 'anchored'     THEN 0
    WHEN 'trusted'      THEN 1
    WHEN 'probationary' THEN 2
    WHEN 'untrusted'    THEN 3
    WHEN 'unset'        THEN 4
  END;
