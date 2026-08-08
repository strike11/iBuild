-- Absolute access/refresh expiry (enforced in Store; refresh rotates both).

ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS refresh_expires_at TIMESTAMPTZ;

-- Backfill existing rows (access 12h, refresh 30d — same TTLs as store.dart).
UPDATE sessions
    SET expires_at = created_at + INTERVAL '12 hours'
    WHERE expires_at IS NULL;

UPDATE sessions
    SET refresh_expires_at = created_at + INTERVAL '30 days'
    WHERE refresh_expires_at IS NULL;

-- Lets a future cleanup job prune expired sessions efficiently.
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions (expires_at);
