-- engine/sql/s7-prism-cws-tier.sql
-- CWS QUANTi Tiering on converged tokens.
--
-- Jamie: 'CWS QUANTi Tiering'  + 'Mirror is MemPalace'.
--
-- The 4-tier ladder is already defined in engine/s7_akashic.py as
-- the TIER_THRESHOLDS constant — Phase 5 Akashic:
--
--   UNTRUSTED     (<0.50 agreement) — rejected, no row
--   PROBATIONARY  (0.50..0.77)      — tentative, low weight
--   TRUSTED       (>=0.77, = TRUST_THRESHOLD 7/9) — full emerge
--   ANCHORED      (TRUSTED + dissolution_count >= 7) — foundation
--
-- A tier is assigned at convergence time. It graduates over time
-- via the dissolution counter — every mirror event on a TRUSTED
-- row is one more witness confirming the existing truth; after
-- ANCHORED_MIN_SESSIONS = 7 dissolutions, the row is promoted
-- from TRUSTED to ANCHORED (covenant-grade foundation).

ALTER TABLE cws_core.location_id
  ADD COLUMN IF NOT EXISTS cws_tier TEXT NOT NULL DEFAULT 'unset'
    CHECK (cws_tier IN ('unset', 'untrusted', 'probationary', 'trusted', 'anchored'));

COMMENT ON COLUMN cws_core.location_id.cws_tier IS
  'CWS QUANTi trust tier — unset (non-consensus row), untrusted (<50%), probationary (50-77%), trusted (>=77% = 7/9), anchored (trusted + >=7 dissolutions). Promoted automatically by dissolution_count events.';

CREATE INDEX IF NOT EXISTS location_id_cws_tier_idx
  ON cws_core.location_id (cws_tier, dissolution_count DESC)
  WHERE cws_tier IN ('trusted', 'anchored');


-- ── Promote trusted → anchored when dissolutions cross threshold ──
-- Triggered on UPDATE of dissolution_count. When a trusted row's
-- dissolution_count hits 7 (ANCHORED_MIN_SESSIONS), promote it.

CREATE OR REPLACE FUNCTION cws_core.auto_promote_tier()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.cws_tier = 'trusted'
       AND NEW.dissolution_count >= 7
       AND (OLD.dissolution_count IS NULL OR OLD.dissolution_count < 7) THEN
        NEW.cws_tier := 'anchored';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cws_tier_auto_promote ON cws_core.location_id;
CREATE TRIGGER cws_tier_auto_promote
  BEFORE UPDATE OF dissolution_count ON cws_core.location_id
  FOR EACH ROW
  EXECUTE FUNCTION cws_core.auto_promote_tier();

COMMENT ON FUNCTION cws_core.auto_promote_tier() IS
  'Automatic CWS tier promotion: trusted → anchored when dissolution_count crosses 7 (ANCHORED_MIN_SESSIONS). Fires on UPDATE of dissolution_count via cws_tier_auto_promote trigger.';
