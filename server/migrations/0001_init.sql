-- Initial normalized schema for the iBuild PostgreSQL persistence layer.
--
-- Mirrors the nested JSON shape produced by `buildProjectsSeed()` in
-- `lib/src/seed_data.dart` (project -> developer + gallery + buildings ->
-- units -> media, plus offers), normalized so real SQL filtering/
-- pagination (`GET /v1/projects?status=&district=&type=`) and lead lookups
-- (`leads.project_id`) can run as indexed queries instead of in-memory
-- scans. Applied once by `Database.migrate()` and tracked in
-- `schema_migrations`.

CREATE TABLE IF NOT EXISTS developers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    logo_url TEXT,
    rating DOUBLE PRECISION NOT NULL,
    projects_count INTEGER NOT NULL,
    phone TEXT NOT NULL,
    agent_name TEXT NOT NULL,
    agent_phone TEXT NOT NULL,
    agent_avatar_url TEXT
);

CREATE TABLE IF NOT EXISTS projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    status TEXT NOT NULL,
    district TEXT NOT NULL,
    address TEXT NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    developer_id TEXT REFERENCES developers(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    -- Nested-but-not-queried string lists: array column keeps them typed
    -- without inventing a many-to-many join table for pure display data.
    amenities TEXT[] NOT NULL DEFAULT '{}',
    tags TEXT[] NOT NULL DEFAULT '{}',
    price_min DOUBLE PRECISION,
    price_max DOUBLE PRECISION,
    rent_min DOUBLE PRECISION,
    rent_max DOUBLE PRECISION,
    construction_progress INTEGER,
    completion_date TIMESTAMPTZ,
    rating DOUBLE PRECISION NOT NULL,
    available_units INTEGER NOT NULL DEFAULT 0,
    total_units INTEGER NOT NULL DEFAULT 0,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Used by GET /v1/projects?status=&district=&type=
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects (status);
CREATE INDEX IF NOT EXISTS idx_projects_district ON projects (district);
CREATE INDEX IF NOT EXISTS idx_projects_type ON projects (type);

CREATE TABLE IF NOT EXISTS buildings (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    floors INTEGER NOT NULL,
    construction_progress INTEGER,
    completion_date TIMESTAMPTZ,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_buildings_project_id ON buildings (project_id);

CREATE TABLE IF NOT EXISTS units (
    id TEXT PRIMARY KEY,
    building_id TEXT NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
    -- Denormalized from buildings.project_id so unit rows can be filtered
    -- and joined back to a project without hopping through buildings.
    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    number TEXT NOT NULL,
    kind TEXT NOT NULL,
    deal_type TEXT NOT NULL,
    status TEXT NOT NULL,
    floor INTEGER NOT NULL,
    is_offplan BOOLEAN NOT NULL DEFAULT FALSE,
    area_total DOUBLE PRECISION NOT NULL,
    area_living DOUBLE PRECISION,
    rooms INTEGER,
    layout TEXT,
    price DOUBLE PRECISION,
    price_m2 DOUBLE PRECISION,
    rent_monthly DOUBLE PRECISION,
    rent_m2 DOUBLE PRECISION,
    min_lease_months INTEGER,
    finishing TEXT,
    view TEXT,
    plan_column INTEGER,
    plan_row INTEGER,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_units_building_id ON units (building_id);
CREATE INDEX IF NOT EXISTS idx_units_project_id ON units (project_id);
CREATE INDEX IF NOT EXISTS idx_units_status ON units (status);

-- Polymorphic media: attached to exactly one of a project (gallery, in
-- `_project.gallery`) or a unit (photo + floor plan, in
-- `buildBuilding`'s per-unit `media` list) — never both.
CREATE TABLE IF NOT EXISTS media (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    url TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_cover BOOLEAN NOT NULL DEFAULT FALSE,
    project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,
    unit_id TEXT REFERENCES units(id) ON DELETE CASCADE,
    CONSTRAINT media_exactly_one_owner CHECK (
        (project_id IS NOT NULL AND unit_id IS NULL) OR
        (project_id IS NULL AND unit_id IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_media_project_id ON media (project_id);
CREATE INDEX IF NOT EXISTS idx_media_unit_id ON media (unit_id);

CREATE TABLE IF NOT EXISTS offers (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    -- Only meaningful for type = 'installment' (see seed_data.dart _offer);
    -- left NULL for discount/rentPromo offers, same as the in-memory shape.
    down_payment_percent DOUBLE PRECISION,
    term_months INTEGER,
    interest_rate DOUBLE PRECISION
);

CREATE INDEX IF NOT EXISTS idx_offers_project_id ON offers (project_id);

-- No FK to projects: a lead's projectId is only validated loosely by the
-- API layer, matching today's in-memory Store.createLead behavior.
CREATE TABLE IF NOT EXISTS leads (
    id TEXT PRIMARY KEY,
    number TEXT NOT NULL,
    project_id TEXT NOT NULL,
    project_name TEXT,
    unit_id TEXT,
    unit_label TEXT,
    intent TEXT NOT NULL,
    status TEXT NOT NULL,
    contact_phone TEXT,
    message TEXT,
    preferred_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_leads_project_id ON leads (project_id);
CREATE INDEX IF NOT EXISTS idx_leads_status ON leads (status);

-- Phone-OTP users/sessions. Store persists and reloads these when
-- PostgreSQL is configured (see PgPersistence.loadAllUsers / loadAllSessions).
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    phone TEXT NOT NULL UNIQUE,
    name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sessions (
    access_token TEXT PRIMARY KEY,
    refresh_token TEXT,
    phone TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
