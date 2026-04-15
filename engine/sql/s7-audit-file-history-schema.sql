-- engine/sql/s7-audit-file-history-schema.sql
-- S7 Audit — file change history, the data dictionary of every
-- touched line on the laptop.
--
-- Jamie: 'sort the files and then you have a datadictionary for
-- the entire change history — build everything important, everything
-- tracked, and every line audited for S7.'
--
-- This is not a text file. It is a postgres table in the same DB
-- as cws_core.location_id, with the same INSERT-only audit
-- semantics. Every file touch is a row; every row carries its
-- covenant-shape classification so the audit is queryable by
-- Foundation axis (-1/0/+1), by Stack, by author, by reason.
--
-- Populated by engine/s7_audit_file_ingest.py which reads a file
-- list (default /tmp/s7-audit-33h.txt) and classifies each path
-- via simple rules before inserting.

CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS audit.file_change_history (
    id             UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),

    path           TEXT          NOT NULL,
    mtime          TIMESTAMPTZ,                  -- file's mtime at observation
    size_bytes     BIGINT,                       -- size in bytes (may be null)

    -- Covenant classification
    foundation     SMALLINT      NOT NULL CHECK (foundation IN (-1, 0, 1)),
    -- -1 = ROCK   (foundation, what you stand on — system, immutable, kernel)
    --  0 = DOOR   (present, what you work at — repo, memory, session, config)
    -- +1 = REST   (destiny, what goes out — build outputs, caches, state)

    stack          TEXT          NOT NULL,
    -- e.g. 'system-etc', 'system-usr', 'system-var',
    --      's7-repo-code', 's7-repo-git', 's7-memory',
    --      's7-mempalace', 's7-config-secret', 's7-config-app',
    --      's7-desktop-apps', 's7-autostart',
    --      'build-output', 'container-cow', 'browser-cache',
    --      'shell-state', 'other'

    authored_by    TEXT          NOT NULL,
    -- 'distro-package', 'jamie', 'claude', 'podman', 'systemd',
    -- 'git', 'browser', 'mempalace', 'dnf5', 'mixed', 'unknown'

    touched_by     TEXT          NOT NULL,
    -- 'edit-tool', 'write-tool', 'git-commit', 'dnf-transaction',
    -- 'podman-exec', 'podman-run', 'systemd-daemon', 'browser-runtime',
    -- 'mempalace-mine', 'mksquashfs', 'sed-refactor', 'mixed'

    why            TEXT,                         -- free-text rationale

    tracked_in_git BOOLEAN       NOT NULL DEFAULT FALSE,
    importance     SMALLINT      NOT NULL DEFAULT 0
                   CHECK (importance BETWEEN 0 AND 5),
    -- 0 = noise (container COW, browser cache)
    -- 1 = routine system state (timers, upower history)
    -- 2 = config drift (dconf, kitty, mimeinfo)
    -- 3 = notable (memory, autostart, polkit rules, mempalace)
    -- 4 = high (repo code changes, secrets, identity, SELinux)
    -- 5 = critical (/etc/passwd, /etc/shadow, build outputs signed + shipped)

    observed_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE audit.file_change_history IS
  'Data dictionary for the entire S7 laptop change history. Every touched file gets a row classified by covenant Foundation (-1/0/+1), Stack, authored_by, touched_by, why, importance. INSERT-only audit trail; INSERT covers the 33h initial snapshot and going-forward auditd-driven rows.';

CREATE INDEX IF NOT EXISTS fch_foundation_idx
  ON audit.file_change_history (foundation, importance DESC, mtime DESC);

CREATE INDEX IF NOT EXISTS fch_stack_idx
  ON audit.file_change_history (stack, mtime DESC);

CREATE INDEX IF NOT EXISTS fch_mtime_idx
  ON audit.file_change_history (mtime DESC);

CREATE INDEX IF NOT EXISTS fch_path_idx
  ON audit.file_change_history (path);

CREATE INDEX IF NOT EXISTS fch_importance_idx
  ON audit.file_change_history (importance DESC)
  WHERE importance >= 3;

-- ── Public-safe view mirroring the covenant's 'public for a reason' pattern ──
-- Exposes counts and summaries without leaking individual paths
CREATE OR REPLACE VIEW audit.file_change_summary AS
SELECT
    foundation,
    stack,
    count(*) AS rows,
    count(*) FILTER (WHERE importance >= 3) AS notable,
    min(mtime) AS earliest,
    max(mtime) AS latest
FROM audit.file_change_history
GROUP BY foundation, stack
ORDER BY foundation, rows DESC;

COMMENT ON VIEW audit.file_change_summary IS
  'Aggregate file-change summary by Foundation + Stack. Public-safe (no individual paths, no sensitive content).';
