-- engine/sql/s7-prism-witness-consensus.sql
-- 7-to-1 witness convergence: embed the full evaluation in
-- a single token.
--
-- Jamie: 'So like 7 models converge for 1 token vs 7 tokens = 0 …
--          the 1 token is embedded with all evaluation and against
--          foundation reducing token and expense of processing same
--          data, that is now RAG worthy embedded.'
--
-- Adds a witness_consensus JSONB column to cws_core.location_id.
-- Each converged token carries its full witness evaluation in this
-- column so repeat queries don't need to re-invoke the witness set.
-- First answer is consensus; second answer is a cache hit.

ALTER TABLE cws_core.location_id
  ADD COLUMN IF NOT EXISTS witness_consensus JSONB;

COMMENT ON COLUMN cws_core.location_id.witness_consensus IS
  'Embedded witness evaluation for 7-to-1 converged tokens. Shape: { "witnesses": N, "threshold_crossed": bool, "per_plane_agreement": {plane: count}, "converged_cell": [d1..d8], "dissent": [...] }. Populated at convergence time; read on every subsequent query for the same semantic cell so witnesses do not need to re-run.';

CREATE INDEX IF NOT EXISTS location_id_has_consensus_idx
  ON cws_core.location_id ((witness_consensus IS NOT NULL))
  WHERE witness_consensus IS NOT NULL;
