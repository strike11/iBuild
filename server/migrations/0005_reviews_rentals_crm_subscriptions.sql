-- Konseptsiya alignment: reviews/trust layer (§9), owner secondary/primary
-- rental listings (§5, §8), lead CRM tags/scoring (§8), and the
-- subscription-tier ladder (§11.A.1) replacing the single $299/mo plan.
--
-- NOTE: as of this migration, `Store` (lib/src/store.dart) keeps these
-- entities in memory only — `PgPersistence` does not yet read/write them.
-- The schema below is forward-looking so a later persistence pass has a
-- stable target; it does not change current runtime behavior when
-- `DB_HOST` is set (existing tables/columns are unaffected).

CREATE TABLE IF NOT EXISTS reviews (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_name TEXT,
    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    developer_id TEXT REFERENCES developers(id) ON DELETE SET NULL,
    rating_overall INTEGER NOT NULL CHECK (rating_overall BETWEEN 1 AND 5),
    rating_location INTEGER CHECK (rating_location BETWEEN 1 AND 5),
    rating_quality INTEGER CHECK (rating_quality BETWEEN 1 AND 5),
    rating_value INTEGER CHECK (rating_value BETWEEN 1 AND 5),
    body TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'published', -- published | flagged | removed
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reviews_project ON reviews (project_id, status);
CREATE INDEX IF NOT EXISTS idx_reviews_developer ON reviews (developer_id, status);

-- Owner-submitted rental listings — deliberately separate from
-- projects/units. `deal_type` is CHECK-constrained to 'rent' only: this
-- table must never carry a secondary-sale listing, enforcing Konseptsiya
-- §5's "никакой купли-продажи вторички" rule at the schema level too.
CREATE TABLE IF NOT EXISTS rental_listings (
    id TEXT PRIMARY KEY,
    owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    district TEXT NOT NULL,
    address TEXT NOT NULL,
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    property_kind TEXT NOT NULL, -- apartment | office | retail
    deal_type TEXT NOT NULL DEFAULT 'rent' CHECK (deal_type = 'rent'),
    area_total DOUBLE PRECISION NOT NULL,
    rooms INTEGER,
    rent_monthly DOUBLE PRECISION NOT NULL,
    min_lease_months INTEGER NOT NULL DEFAULT 12,
    contact_phone TEXT NOT NULL,
    is_secondary BOOLEAN NOT NULL DEFAULT TRUE,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    moderation_status TEXT NOT NULL DEFAULT 'pending', -- pending | approved | rejected
    moderation_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rental_listings_owner ON rental_listings (owner_user_id);
CREATE INDEX IF NOT EXISTS idx_rental_listings_moderation ON rental_listings (moderation_status);
CREATE INDEX IF NOT EXISTS idx_rental_listings_district ON rental_listings (district);

CREATE TABLE IF NOT EXISTS rental_listing_photos (
    id TEXT PRIMARY KEY,
    rental_listing_id TEXT NOT NULL REFERENCES rental_listings(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0
);

-- Lead CRM: tags + hot/warm/cold scoring (Konseptsiya §8).
ALTER TABLE leads
    ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS score TEXT, -- hot | warm | cold
    ADD COLUMN IF NOT EXISTS last_contact_at TIMESTAMPTZ;

-- Subscription tier ladder replacing the single business_monthly plan.
ALTER TABLE subscriptions
    ADD COLUMN IF NOT EXISTS leads_used_this_period INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS subscription_plans (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    price_usd NUMERIC(10, 2) NOT NULL,
    max_projects INTEGER NOT NULL DEFAULT -1, -- -1 = unlimited
    max_units INTEGER NOT NULL DEFAULT -1,
    included_leads_per_month INTEGER NOT NULL DEFAULT 0,
    pay_per_lead_usd NUMERIC(6, 2) NOT NULL DEFAULT 0
);

INSERT INTO subscription_plans (id, name, price_usd, max_projects, max_units, included_leads_per_month, pay_per_lead_usd)
VALUES
    ('start', 'Start', 99.00, 3, 300, 50, 3.00),
    ('growth', 'Growth', 299.00, 10, 2000, 250, 2.50),
    ('corporate', 'Corporate', 799.00, -1, -1, 1000, 2.00)
ON CONFLICT (id) DO NOTHING;

-- Street-retail is a `projects.type` value and `units.kind` value —
-- both columns are free-form TEXT already, so no DDL change is required
-- to add 'street_retail' / 'retail'; application-layer validation is the
-- source of truth (see lib/src/seed_data.dart, lib/src/app.dart).
