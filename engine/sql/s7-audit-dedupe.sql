-- engine/sql/s7-audit-dedupe.sql
-- Add a UNIQUE index on (path, mtime) so the continuous-snapshot
-- ingester can use ON CONFLICT DO NOTHING without the table
-- ballooning into tens of thousands of duplicate rows per run.
--
-- NULL mtime pairs are still allowed (stat errors) because postgres
-- treats NULLs as distinct by default — we accept that edge case.

CREATE UNIQUE INDEX IF NOT EXISTS fch_path_mtime_uniq
  ON audit.file_change_history (path, mtime);
