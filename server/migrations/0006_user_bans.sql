-- Platform trust & safety: let a system admin freeze an account with a
-- reason and their own name, surfaced back on the banned account itself
-- (see `Store.banUser` / `banGuardMiddleware` in lib/src).

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS banned BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS ban_reason TEXT,
    ADD COLUMN IF NOT EXISTS banned_by_name TEXT,
    ADD COLUMN IF NOT EXISTS banned_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_users_banned ON users (banned) WHERE banned;
