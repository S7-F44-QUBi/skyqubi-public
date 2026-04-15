-- engine/sql/s7-audit-hash-chain.sql
-- Add hash-chain tamper-evidence to audit.file_change_history.
--
-- Jamie's research brief item #1: prev_row_hash column turns the
-- audit log into a hash chain. Every new row references the
-- previous row's hash; breaking the chain is detectable by
-- recomputing from any known-good row forward.
--
-- Canonical serialization (stable across rows):
--   path|mtime|size_bytes|foundation|stack|authored_by|touched_by|why|tracked_in_git|importance
--
-- Row hash:
--   row_hash = encode(digest(canonical_serialization, 'sha256'), 'hex')
--
-- Chain link:
--   prev_row_hash = previous row's row_hash
--                   (first row's prev_row_hash = '' — the genesis)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE audit.file_change_history
  ADD COLUMN IF NOT EXISTS row_hash TEXT;
ALTER TABLE audit.file_change_history
  ADD COLUMN IF NOT EXISTS prev_row_hash TEXT;

COMMENT ON COLUMN audit.file_change_history.row_hash IS
  'SHA-256 of canonical serialization of this row. Computed at insert. NEVER updated after that — if a row is modified, the chain breaks.';

COMMENT ON COLUMN audit.file_change_history.prev_row_hash IS
  'row_hash of the row that came immediately before this one in observation order. First row has prev_row_hash = genesis empty string. Any gap or mismatch detectable by audit.verify_chain().';


-- ── Helper function: canonical serialization ──────────────────────

CREATE OR REPLACE FUNCTION audit.canonical_row_text(
    p_path          TEXT,
    p_mtime         TIMESTAMPTZ,
    p_size_bytes    BIGINT,
    p_foundation    SMALLINT,
    p_stack         TEXT,
    p_authored_by   TEXT,
    p_touched_by    TEXT,
    p_why           TEXT,
    p_tracked_in_git BOOLEAN,
    p_importance    SMALLINT
) RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT
        COALESCE(p_path, '') || '|' ||
        COALESCE(to_char(p_mtime AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'), '') || '|' ||
        COALESCE(p_size_bytes::TEXT, '') || '|' ||
        COALESCE(p_foundation::TEXT, '') || '|' ||
        COALESCE(p_stack, '') || '|' ||
        COALESCE(p_authored_by, '') || '|' ||
        COALESCE(p_touched_by, '') || '|' ||
        COALESCE(p_why, '') || '|' ||
        COALESCE(p_tracked_in_git::TEXT, '') || '|' ||
        COALESCE(p_importance::TEXT, '')
$$;


-- ── Helper function: hash the canonical serialization ────────────

CREATE OR REPLACE FUNCTION audit.compute_row_hash(
    p_path          TEXT,
    p_mtime         TIMESTAMPTZ,
    p_size_bytes    BIGINT,
    p_foundation    SMALLINT,
    p_stack         TEXT,
    p_authored_by   TEXT,
    p_touched_by    TEXT,
    p_why           TEXT,
    p_tracked_in_git BOOLEAN,
    p_importance    SMALLINT
) RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT encode(
        digest(
            audit.canonical_row_text(
                p_path, p_mtime, p_size_bytes, p_foundation, p_stack,
                p_authored_by, p_touched_by, p_why, p_tracked_in_git, p_importance
            ),
            'sha256'
        ),
        'hex'
    )
$$;


-- ── Backfill: walk every existing row in observation order ───────
-- For each row, compute row_hash; set prev_row_hash to the row_hash
-- of the row that came just before it. First row's prev_row_hash
-- is the empty string (genesis marker).
--
-- Uses a window-function CTE to compute all hashes in one pass,
-- then UPDATE each row from the CTE. Postgres handles 30k+ rows
-- in well under a second this way.

WITH ordered AS (
    SELECT
        id,
        row_number() OVER (ORDER BY observed_at ASC, id ASC) AS rn,
        audit.compute_row_hash(
            path, mtime, size_bytes, foundation, stack,
            authored_by, touched_by, why, tracked_in_git, importance
        ) AS my_hash
    FROM audit.file_change_history
),
linked AS (
    SELECT
        id,
        rn,
        my_hash,
        LAG(my_hash, 1, '') OVER (ORDER BY rn) AS prev_hash
    FROM ordered
)
UPDATE audit.file_change_history lid
SET
    row_hash      = linked.my_hash,
    prev_row_hash = linked.prev_hash
FROM linked
WHERE linked.id = lid.id;


-- ── Verification function: walk the chain and find the first break ──

CREATE OR REPLACE FUNCTION audit.verify_chain()
RETURNS TABLE (
    status      TEXT,
    checked     BIGINT,
    broken_at   UUID,
    broken_path TEXT,
    expected    TEXT,
    actual      TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    expected_prev TEXT := '';
    n BIGINT := 0;
BEGIN
    FOR rec IN
        SELECT
            id, path, row_hash, prev_row_hash,
            audit.compute_row_hash(
                path, mtime, size_bytes, foundation, stack,
                authored_by, touched_by, why, tracked_in_git, importance
            ) AS recomputed
        FROM audit.file_change_history
        ORDER BY observed_at ASC, id ASC
    LOOP
        n := n + 1;
        IF rec.prev_row_hash <> expected_prev THEN
            RETURN QUERY SELECT 'BROKEN_PREV'::TEXT, n, rec.id, rec.path, expected_prev, rec.prev_row_hash;
            RETURN;
        END IF;
        IF rec.row_hash <> rec.recomputed THEN
            RETURN QUERY SELECT 'BROKEN_ROW'::TEXT, n, rec.id, rec.path, rec.recomputed, rec.row_hash;
            RETURN;
        END IF;
        expected_prev := rec.row_hash;
    END LOOP;
    RETURN QUERY SELECT 'OK'::TEXT, n, NULL::UUID, NULL::TEXT, NULL::TEXT, NULL::TEXT;
END;
$$;

COMMENT ON FUNCTION audit.verify_chain() IS
  'Walk audit.file_change_history in observation order, recomputing each row_hash and verifying prev_row_hash matches the previous row. Returns OK on success or the first break with row id, path, expected, and actual.';


-- ── Run verification now to prove the backfill worked ────────────

SELECT * FROM audit.verify_chain();
