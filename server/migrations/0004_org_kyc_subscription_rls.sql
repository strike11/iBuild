-- Org KYC (Uzbekistan), unique INN, subscriptions, and RLS.
-- Legal-entity fields align with state registration practice (STIR/INN,
-- legal name/address, director + PINFL, UBO acknowledgement) under
-- Law on Limited Liability Companies, personal-data (ZRU-547), and AML UBO rules.

-- --- Developers: KYC / public profile ------------------------------------

ALTER TABLE developers
    ADD COLUMN IF NOT EXISTS account_kind TEXT,
    ADD COLUMN IF NOT EXISTS legal_form TEXT,
    ADD COLUMN IF NOT EXISTS registration_number TEXT,
    ADD COLUMN IF NOT EXISTS oked_code TEXT,
    ADD COLUMN IF NOT EXISTS legal_address TEXT,
    ADD COLUMN IF NOT EXISTS office_address TEXT,
    ADD COLUMN IF NOT EXISTS region TEXT,
    ADD COLUMN IF NOT EXISTS email TEXT,
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS brand_color TEXT,
    ADD COLUMN IF NOT EXISTS cover_image_url TEXT,
    ADD COLUMN IF NOT EXISTS director_full_name TEXT,
    ADD COLUMN IF NOT EXISTS director_pinfl TEXT,
    ADD COLUMN IF NOT EXISTS director_passport TEXT,
    ADD COLUMN IF NOT EXISTS director_phone TEXT,
    ADD COLUMN IF NOT EXISTS director_email TEXT,
    ADD COLUMN IF NOT EXISTS ubo_declared BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS ubo_full_name TEXT,
    ADD COLUMN IF NOT EXISTS construction_license TEXT,
    ADD COLUMN IF NOT EXISTS profile_complete BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Unique INN among non-empty values (STIR for legal entities: 9 digits).
CREATE UNIQUE INDEX IF NOT EXISTS uq_developers_inn
    ON developers (inn)
    WHERE inn IS NOT NULL AND btrim(inn) <> '';

CREATE INDEX IF NOT EXISTS idx_developers_owner
    ON developers (owner_user_id);

-- --- Subscriptions ($299/mo publish gate) --------------------------------

CREATE TABLE IF NOT EXISTS subscriptions (
    id TEXT PRIMARY KEY,
    developer_id TEXT NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
    plan_id TEXT NOT NULL DEFAULT 'business_monthly',
    amount_usd NUMERIC(10, 2) NOT NULL DEFAULT 299.00,
    currency TEXT NOT NULL DEFAULT 'USD',
    status TEXT NOT NULL DEFAULT 'none',
    -- none | pending_payment | active | past_due | canceled
    provider TEXT NOT NULL DEFAULT 'manual',
    provider_ref TEXT,
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    last_payment_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_subscriptions_developer
    ON subscriptions (developer_id);

CREATE INDEX IF NOT EXISTS idx_subscriptions_status
    ON subscriptions (status);

-- --- Request context helpers for RLS -------------------------------------
-- App sets these per request via parameterized set_config (never PgPersistence).

-- --- Row Level Security (defense in depth; app RBAC remains primary) -----

ALTER TABLE developers ENABLE ROW LEVEL SECURITY;
ALTER TABLE developers FORCE ROW LEVEL SECURITY;

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions FORCE ROW LEVEL SECURITY;

ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions FORCE ROW LEVEL SECURITY;

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites FORCE ROW LEVEL SECURITY;

ALTER TABLE saved_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_searches FORCE ROW LEVEL SECURITY;

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log FORCE ROW LEVEL SECURITY;

-- Drop policies if re-running manually (CREATE POLICY is not IF NOT EXISTS on older PG).
DROP POLICY IF EXISTS developers_tenant ON developers;
DROP POLICY IF EXISTS subscriptions_tenant ON subscriptions;
DROP POLICY IF EXISTS sessions_tenant ON sessions;
DROP POLICY IF EXISTS users_tenant ON users;
DROP POLICY IF EXISTS favorites_tenant ON favorites;
DROP POLICY IF EXISTS saved_searches_tenant ON saved_searches;
DROP POLICY IF EXISTS audit_log_admin ON audit_log;

-- service / system_admin: full access. Owners: own row only.
CREATE POLICY developers_tenant ON developers
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR owner_user_id = NULLIF(current_setting('app.user_id', true), '')
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR owner_user_id = NULLIF(current_setting('app.user_id', true), '')
    );

CREATE POLICY subscriptions_tenant ON subscriptions
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR developer_id IN (
            SELECT d.id FROM developers d
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR developer_id IN (
            SELECT d.id FROM developers d
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

CREATE POLICY sessions_tenant ON sessions
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR phone IN (
            SELECT u.phone FROM users u
            WHERE u.id = NULLIF(current_setting('app.user_id', true), '')
        )
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR phone IN (
            SELECT u.phone FROM users u
            WHERE u.id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

CREATE POLICY users_tenant ON users
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR id = NULLIF(current_setting('app.user_id', true), '')
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR id = NULLIF(current_setting('app.user_id', true), '')
    );

CREATE POLICY favorites_tenant ON favorites
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR user_id = NULLIF(current_setting('app.user_id', true), '')
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR user_id = NULLIF(current_setting('app.user_id', true), '')
    );

CREATE POLICY saved_searches_tenant ON saved_searches
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR user_id = NULLIF(current_setting('app.user_id', true), '')
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR user_id = NULLIF(current_setting('app.user_id', true), '')
    );

CREATE POLICY audit_log_admin ON audit_log
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
    );
