-- Session expiry: opaque access/refresh tokens previously never expired,
-- so a leaked or stale token could be replayed forever. Add absolute expiry
-- timestamps enforced by Store.userForAccessToken / refreshSession (see
-- lib/src/store.dart), with the refresh flow rotating both tokens and
-- re-issuing fresh TTLs.

ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS refresh_expires_at TIMESTAMPTZ;

-- Backfill any pre-existing rows off their creation time so upgrading does
-- not resurrect never-expiring tokens (access: 12h, refresh: 30d — mirrors
-- the TTLs in store.dart).
UPDATE sessions
    SET expires_at = created_at + INTERVAL '12 hours'
    WHERE expires_at IS NULL;

UPDATE sessions
    SET refresh_expires_at = created_at + INTERVAL '30 days'
    WHERE refresh_expires_at IS NULL;

-- Lets a future cleanup job prune expired sessions efficiently.
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions (expires_at);
