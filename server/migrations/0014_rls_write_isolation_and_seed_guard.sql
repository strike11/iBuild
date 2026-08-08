-- Split catalogue RLS SELECT vs write; `app_meta.catalogue_seeded` stops reseed after wipe.

-- --- Seed guard -------------------------------------------------------------

CREATE TABLE IF NOT EXISTS app_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Mark already-populated DBs as seeded.
INSERT INTO app_meta (key, value)
SELECT 'catalogue_seeded', 'true'
WHERE EXISTS (SELECT 1 FROM projects LIMIT 1)
   OR EXISTS (SELECT 1 FROM developers LIMIT 1)
ON CONFLICT (key) DO NOTHING;

-- Favorites never had an FK; orphan rows survived project deletes. Cascade
-- so hard-deleting a project also clears B2C favorites for it.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'favorites_project_id_fkey'
    ) THEN
        -- Drop orphans that would block adding the FK.
        DELETE FROM favorites f
        WHERE NOT EXISTS (SELECT 1 FROM projects p WHERE p.id = f.project_id);

        ALTER TABLE favorites
            ADD CONSTRAINT favorites_project_id_fkey
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Add leads.project_id FK + CASCADE; drop orphans first.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'leads_project_id_fkey'
    ) THEN
        DELETE FROM leads l
        WHERE NOT EXISTS (SELECT 1 FROM projects p WHERE p.id = l.project_id);

        ALTER TABLE leads
            ADD CONSTRAINT leads_project_id_fkey
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;
    END IF;
END $$;

-- --- projects ---------------------------------------------------------------

DROP POLICY IF EXISTS projects_tenant ON projects;
DROP POLICY IF EXISTS projects_select ON projects;
DROP POLICY IF EXISTS projects_write ON projects;

CREATE POLICY projects_select ON projects
    FOR SELECT
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR (is_published = TRUE AND moderation_status = 'approved')
        OR developer_id IN (
            SELECT d.id FROM developers d
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

CREATE POLICY projects_write ON projects
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

-- --- buildings --------------------------------------------------------------

DROP POLICY IF EXISTS buildings_tenant ON buildings;
DROP POLICY IF EXISTS buildings_select ON buildings;
DROP POLICY IF EXISTS buildings_write ON buildings;

CREATE POLICY buildings_select ON buildings
    FOR SELECT
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR project_id IN (
            SELECT p.id FROM projects p
            WHERE p.is_published = TRUE AND p.moderation_status = 'approved'
        )
        OR project_id IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

CREATE POLICY buildings_write ON buildings
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

-- --- units ------------------------------------------------------------------

DROP POLICY IF EXISTS units_tenant ON units;
DROP POLICY IF EXISTS units_select ON units;
DROP POLICY IF EXISTS units_write ON units;

CREATE POLICY units_select ON units
    FOR SELECT
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR project_id IN (
            SELECT p.id FROM projects p
            WHERE p.is_published = TRUE AND p.moderation_status = 'approved'
        )
        OR project_id IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

CREATE POLICY units_write ON units
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

-- --- media ------------------------------------------------------------------

DROP POLICY IF EXISTS media_tenant ON media;
DROP POLICY IF EXISTS media_select ON media;
DROP POLICY IF EXISTS media_write ON media;

CREATE POLICY media_select ON media
    FOR SELECT
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR COALESCE(project_id, (SELECT u.project_id FROM units u WHERE u.id = media.unit_id)) IN (
            SELECT p.id FROM projects p
            WHERE p.is_published = TRUE AND p.moderation_status = 'approved'
        )
        OR COALESCE(project_id, (SELECT u.project_id FROM units u WHERE u.id = media.unit_id)) IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

CREATE POLICY media_write ON media
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR COALESCE(project_id, (SELECT u.project_id FROM units u WHERE u.id = media.unit_id)) IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR COALESCE(project_id, (SELECT u.project_id FROM units u WHERE u.id = media.unit_id)) IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

-- --- offers -----------------------------------------------------------------

DROP POLICY IF EXISTS offers_tenant ON offers;
DROP POLICY IF EXISTS offers_select ON offers;
DROP POLICY IF EXISTS offers_write ON offers;

CREATE POLICY offers_select ON offers
    FOR SELECT
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR project_id IN (
            SELECT p.id FROM projects p
            WHERE p.is_published = TRUE AND p.moderation_status = 'approved'
        )
        OR project_id IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

CREATE POLICY offers_write ON offers
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
