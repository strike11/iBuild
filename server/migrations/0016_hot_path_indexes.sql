-- Indexes for three query paths that were doing sequential scans.

-- Every token refresh looks a session up by refresh_token, and logout now
-- deletes by it too. Without an index that is a full scan of `sessions` on the
-- hottest authenticated path. UNIQUE also enforces what the code already
-- assumes: a refresh token identifies exactly one session. NULLs do not
-- conflict, so rows predating refresh tokens are unaffected.
CREATE UNIQUE INDEX IF NOT EXISTS uq_sessions_refresh_token
    ON sessions (refresh_token)
    WHERE refresh_token IS NOT NULL;

-- "Projects belonging to this developer" backs the developer dashboard and the
-- subscription project-count check run on every publish. projects is indexed
-- on status/district/type/moderation but never on its owning developer.
CREATE INDEX IF NOT EXISTS idx_projects_developer_id
    ON projects (developer_id);

-- Startup reads the newest 1000 audit entries; without this the whole table is
-- sorted on every boot, which gets steadily worse as the log grows.
CREATE INDEX IF NOT EXISTS idx_audit_log_created
    ON audit_log (created_at DESC);
