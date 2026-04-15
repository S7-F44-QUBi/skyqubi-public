-- engine/sql/s7-ribbons.sql
-- S7 Ribbons ledger — measurement → verdict → ribbon state.
--
-- The 1st Place Ribbon is HELD when every measurement comes back green
-- (FIPS, CIS, HIPAA, Secure Boot Chain). It is REVOKED the moment any
-- measurement fails. The Cloud of AI Happy to Evolve (the persona chat)
-- is gated on this ribbon: HELD → cloud open, REVOKED → cloud closed.
--
-- Schema design:
--   - INSERT-only ledger (ribbons.measurements)
--   - Hash-chained rows (each row's row_hash includes prev_row_hash,
--     so any tampering breaks verification — same pattern as
--     audit.file_change_history)
--   - A current_state view that reads only the latest row
--   - all_green is a generated column so a corrupted writer can't lie

CREATE SCHEMA IF NOT EXISTS ribbons;

CREATE TABLE IF NOT EXISTS ribbons.measurements (
    id              BIGSERIAL PRIMARY KEY,
    ts              TIMESTAMPTZ NOT NULL DEFAULT now(),
    fips_ok         BOOLEAN NOT NULL,
    cis_ok          BOOLEAN NOT NULL,
    hipaa_ok        BOOLEAN NOT NULL,
    sbc_ok          BOOLEAN NOT NULL,
    all_green       BOOLEAN GENERATED ALWAYS AS
                        (fips_ok AND cis_ok AND hipaa_ok AND sbc_ok) STORED,
    failure_summary TEXT,
    measured_by     TEXT NOT NULL,
    prev_row_hash   TEXT,
    row_hash        TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS ribbons_measurements_ts_idx
    ON ribbons.measurements (ts DESC);

-- Latest measurement → current ribbon state. One row, always.
CREATE OR REPLACE VIEW ribbons.current_state AS
SELECT
    id,
    ts,
    all_green,
    CASE WHEN all_green THEN 'HELD' ELSE 'REVOKED' END AS ribbon_state,
    failure_summary,
    fips_ok,
    cis_ok,
    hipaa_ok,
    sbc_ok,
    measured_by
FROM ribbons.measurements
ORDER BY ts DESC
LIMIT 1;

-- Helper: compute a canonical row_hash for an INSERT.
-- The hash includes prev_row_hash, so any tampering with an earlier
-- row breaks the chain when verify_chain() walks it.
CREATE OR REPLACE FUNCTION ribbons.compute_row_hash(
    p_ts            TIMESTAMPTZ,
    p_fips_ok       BOOLEAN,
    p_cis_ok        BOOLEAN,
    p_hipaa_ok      BOOLEAN,
    p_sbc_ok        BOOLEAN,
    p_failure       TEXT,
    p_measured_by   TEXT,
    p_prev_hash     TEXT
) RETURNS TEXT AS $$
    SELECT encode(
        digest(
            COALESCE(p_prev_hash, '') || '|' ||
            p_ts::TEXT || '|' ||
            p_fips_ok::TEXT || '|' ||
            p_cis_ok::TEXT || '|' ||
            p_hipaa_ok::TEXT || '|' ||
            p_sbc_ok::TEXT || '|' ||
            COALESCE(p_failure, '') || '|' ||
            p_measured_by,
            'sha256'
        ),
        'hex'
    );
$$ LANGUAGE SQL STABLE;

-- Walk the chain top-to-bottom, return any row where row_hash doesn't
-- match the recomputed hash. Empty result = chain intact.
CREATE OR REPLACE FUNCTION ribbons.verify_chain()
RETURNS TABLE(broken_id BIGINT, expected TEXT, actual TEXT) AS $$
DECLARE
    r RECORD;
    expected_hash TEXT;
BEGIN
    FOR r IN SELECT * FROM ribbons.measurements ORDER BY id ASC LOOP
        expected_hash := ribbons.compute_row_hash(
            r.ts, r.fips_ok, r.cis_ok, r.hipaa_ok, r.sbc_ok,
            r.failure_summary, r.measured_by, r.prev_row_hash
        );
        IF expected_hash IS DISTINCT FROM r.row_hash THEN
            broken_id := r.id;
            expected := expected_hash;
            actual := r.row_hash;
            RETURN NEXT;
        END IF;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql STABLE;
