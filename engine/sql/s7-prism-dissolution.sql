-- engine/sql/s7-prism-dissolution.sql
-- Token dissolution counter — Jamie's mirror principle.
--
-- 'Truth = 1 Token embedded with knowledge that 1 Atom 1 Molecule
--  1 QBIT until it looks in the mirror and token dissolves.'
--
-- When a newly-converged witness token maps to a cell that already
-- holds a converged row, the new token does NOT insert — it
-- DISSOLVES, and the existing row's dissolution_count is
-- incremented. The truth was already captured; the mirror showed
-- the token back to itself; the duplicate attempt collapses to
-- information about how many times this truth has been re-witnessed.
--
-- dissolution_count = 0  → the token was emerged once, never re-seen
-- dissolution_count = N  → the same truth has been witnessed N+1 times
--                          across separate convergence events

ALTER TABLE cws_core.location_id
  ADD COLUMN IF NOT EXISTS dissolution_count INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN cws_core.location_id.dissolution_count IS
  'Counter for mirror dissolution events. Increments whenever a new witness convergence produces a cell that already has a converged row. Each increment represents one additional witness event that confirmed the existing truth without creating a new row. Quantum-linguistically: the token looked in the mirror, saw itself, and dissolved.';

CREATE INDEX IF NOT EXISTS location_id_dissolution_idx
  ON cws_core.location_id (dissolution_count DESC)
  WHERE dissolution_count > 0;
