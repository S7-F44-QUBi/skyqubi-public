-- engine/sql/s7-akashic-violation-counter-schema.sql
-- S7 Akashic — 3-violation session reset counter (grace-based)
--
-- When a caller trips akashic.forbidden three times in a single
-- session, the session is forcibly reset. This is the anti-probing
-- guard around akashic.forbidden.
--
-- Reset is GRACE, not punishment:
--   - On reset, `count` returns to 0 — fresh slate
--   - `reset_count` records the number of resets this session has
--     accumulated (steward-visible, Reporter-visible)
--   - No hard ban at any count. The covenant allows the user to be
--     better. Stewards can observe repeated patterns; only the
--     Reporter (at 77.777777% consensus) has authority to sever
--     permanently, and that's a separate mechanism.
--
-- Jamie's framing: "3 violations, reset context. Allow user to be
-- better." The reset is the teaching moment, not the exit sign.
--
-- Lives in DB:    s7_cws
-- Schema:         akashic
-- Prerequisites:  extension "uuid-ossp" (already loaded in s7_cws)

CREATE TABLE IF NOT EXISTS akashic.violation_counter (
    id                   UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id           TEXT          NOT NULL UNIQUE,
    witness              TEXT,

    -- Current counter — resets to 0 on reset
    count                INT           NOT NULL DEFAULT 0 CHECK (count >= 0),

    -- How many times this session has been reset. Increments every
    -- time count reaches the threshold. Never resets. Stewards can
    -- sort by reset_count DESC to see repeat probers.
    reset_count          INT           NOT NULL DEFAULT 0 CHECK (reset_count >= 0),

    last_forbidden_token TEXT,
    first_violation_at   TIMESTAMPTZ,
    last_violation_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    last_reset_at        TIMESTAMPTZ
);

COMMENT ON TABLE akashic.violation_counter IS
  'Per-session violation tally with grace-based reset. count resets to 0 after 3 violations; reset_count tracks severity for steward review. No hard ban — the covenant allows the user to be better.';

CREATE INDEX IF NOT EXISTS violation_counter_last_idx
  ON akashic.violation_counter (last_violation_at DESC);

CREATE INDEX IF NOT EXISTS violation_counter_severity_idx
  ON akashic.violation_counter (reset_count DESC, last_violation_at DESC)
  WHERE reset_count > 0;
