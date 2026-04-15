-- engine/sql/s7-skymmip-modality.sql
-- SkyMMIP™ — Sky Multi-Modal IP Convergence.
--
-- Adds a modality column to cws_core.location_id so every
-- LocationID carries the modality it was projected from. The same
-- 8-plane trinity cube holds text, code, image, audio, sensor,
-- and anything else we teach a projector for.
--
-- Jamie: 'SkyMMIP shows IP in the name, safe secure, MmIP.'
-- The name carries the protection signal — IP is in the name on
-- purpose. Algorithm is public (CWS-BSL-1.1 → Apache at the change
-- date), per-appliance keys and the trademark are not.
--
-- Architecture:
--   text    → s7_akashic Phase 5 encoder → 8-plane prism → cell
--   code    → s7_skymmc CodeProjector    → 8-plane prism → cell
--   image   → s7_skymmc ImageProjector   → 8-plane prism → cell  (stub)
--   audio   → s7_skymmc AudioProjector   → 8-plane prism → cell  (stub)
--   sensor  → s7_skymmc SensorProjector  → 8-plane prism → cell  (stub)
--
-- All modalities produce LocationIDs in the same table with the
-- same semantics. The existing Prism detect / ingest / context-
-- weight paths work unchanged; they just see a new column.

ALTER TABLE cws_core.location_id
  ADD COLUMN IF NOT EXISTS modality TEXT NOT NULL DEFAULT 'text'
    CHECK (modality IN ('text', 'code', 'image', 'audio', 'sensor', 'mixed'));

COMMENT ON COLUMN cws_core.location_id.modality IS
  'SkyMMC modality tag. Every LocationID carries the modality its 8-plane projection came from. Existing rows default to text.';

CREATE INDEX IF NOT EXISTS location_id_modality_idx
  ON cws_core.location_id (modality, created_at DESC);
