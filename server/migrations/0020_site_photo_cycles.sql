-- One A→B site-photo cycle per project, vendor-call audit, inspector queue.

CREATE TABLE IF NOT EXISTS site_photo_cycles (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL UNIQUE REFERENCES projects(id) ON DELETE CASCADE,
    interval_days INTEGER NOT NULL DEFAULT 14,
    grace_days INTEGER NOT NULL DEFAULT 3,
    status TEXT NOT NULL DEFAULT 'awaiting_a'
        CHECK (status IN (
            'awaiting_a', 'waiting', 'awaiting_b', 'analyzing',
            'confirmed', 'rejected', 'inspector'
        )),
    photo_a_id TEXT,
    photo_b_id TEXT,
    due_at TIMESTAMPTZ,
    window_end_at TIMESTAMPTZ,
    prompt_version TEXT,
    vendor_job_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_site_photo_cycles_status
    ON site_photo_cycles (status);

ALTER TABLE photo_reports
    ADD COLUMN IF NOT EXISTS cycle_id TEXT REFERENCES site_photo_cycles(id) ON DELETE SET NULL;
ALTER TABLE photo_reports
    ADD COLUMN IF NOT EXISTS role TEXT
        CHECK (role IS NULL OR role IN ('baseline_a', 'followup_b'));

CREATE INDEX IF NOT EXISTS idx_photo_reports_cycle ON photo_reports (cycle_id);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'site_photo_cycles_photo_a_id_fkey'
    ) THEN
        ALTER TABLE site_photo_cycles
            ADD CONSTRAINT site_photo_cycles_photo_a_id_fkey
            FOREIGN KEY (photo_a_id) REFERENCES photo_reports(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'site_photo_cycles_photo_b_id_fkey'
    ) THEN
        ALTER TABLE site_photo_cycles
            ADD CONSTRAINT site_photo_cycles_photo_b_id_fkey
            FOREIGN KEY (photo_b_id) REFERENCES photo_reports(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS vendor_ai_calls (
    id TEXT PRIMARY KEY,
    actor_user_id TEXT,
    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    cycle_id TEXT REFERENCES site_photo_cycles(id) ON DELETE SET NULL,
    photo_a_id TEXT,
    photo_b_id TEXT,
    prompt_id TEXT NOT NULL,
    prompt_sha256 TEXT NOT NULL,
    model TEXT,
    request_sha256 TEXT NOT NULL,
    response_sha256 TEXT,
    http_status INTEGER NOT NULL DEFAULT 0,
    latency_ms INTEGER,
    verdict TEXT NOT NULL
        CHECK (verdict IN ('confirm', 'reject', 'needs_review', 'stub')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vendor_ai_calls_cycle
    ON vendor_ai_calls (cycle_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vendor_ai_calls_project
    ON vendor_ai_calls (project_id, created_at DESC);

CREATE TABLE IF NOT EXISTS inspector_reviews (
    id TEXT PRIMARY KEY,
    cycle_id TEXT NOT NULL UNIQUE REFERENCES site_photo_cycles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'confirmed', 'overturned')),
    assigned_to TEXT,
    gov_notified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: residence admin sees own project's cycle; vendor/inspector rows are
-- service + system_admin only (developers read a filtered cycle GET).
ALTER TABLE site_photo_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_photo_cycles FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS site_photo_cycles_select ON site_photo_cycles;
DROP POLICY IF EXISTS site_photo_cycles_write ON site_photo_cycles;

CREATE POLICY site_photo_cycles_select ON site_photo_cycles
    FOR SELECT
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR project_id IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

CREATE POLICY site_photo_cycles_write ON site_photo_cycles
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR project_id IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR project_id IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

ALTER TABLE vendor_ai_calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_ai_calls FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS vendor_ai_calls_admin ON vendor_ai_calls;
CREATE POLICY vendor_ai_calls_admin ON vendor_ai_calls
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
    );

ALTER TABLE inspector_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspector_reviews FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS inspector_reviews_admin ON inspector_reviews;
CREATE POLICY inspector_reviews_admin ON inspector_reviews
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
    );
