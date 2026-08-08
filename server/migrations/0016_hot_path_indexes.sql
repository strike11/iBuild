-- Indexes for three query paths that were doing sequential scans.

-- Refresh/logout lookup by refresh_token (UNIQUE; NULLs ok for legacy rows).
CREATE UNIQUE INDEX IF NOT EXISTS uq_sessions_refresh_token
    ON sessions (refresh_token)
    WHERE refresh_token IS NOT NULL;

-- Developer dashboard + publish project-count check.
CREATE INDEX IF NOT EXISTS idx_projects_developer_id
    ON projects (developer_id);

-- Startup loads newest audit entries.
CREATE INDEX IF NOT EXISTS idx_audit_log_created
    ON audit_log (created_at DESC);
