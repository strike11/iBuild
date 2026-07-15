-- RLS extension (Track A.5): defense in depth for the catalogue/CRM tables,
-- mirroring the policy pattern established in
-- 0004_org_kyc_subscription_rls.sql / 0007_tickets.sql —
--   * service / system_admin: full bypass.
--   * owner: rows reachable from a developer the caller owns
--     (developers.owner_user_id = app.user_id), via projects.developer_id
--     and onward through buildings/units/media/offers/leads.
--   * public read: published + moderation-approved projects (and everything
--     hanging off them) stay visible to anonymous/ordinary-user SELECTs.
--
-- NOTE: because these tables' write-throughs in PgPersistence are
-- fire-and-forget, they now run via the `service`-role transaction helper
-- (`_asService` in lib/src/db/pg_persistence.dart) exactly like the other
-- FORCE-RLS tables already do — otherwise a request's ambient
-- app.role/app.user_id (set per-request by authMiddleware on the shared
-- connection) could have already moved on to a different caller by the time
-- a queued write actually executes.

-- --- projects --------------------------------------------------------------

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS projects_tenant ON projects;

CREATE POLICY projects_tenant ON projects
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR (is_published = TRUE AND moderation_status = 'approved')
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

-- --- buildings ---------------------------------------------------------------

ALTER TABLE buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE buildings FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS buildings_tenant ON buildings;

CREATE POLICY buildings_tenant ON buildings
    FOR ALL
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
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR project_id IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

-- --- units -------------------------------------------------------------------

ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE units FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS units_tenant ON units;

CREATE POLICY units_tenant ON units
    FOR ALL
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
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR project_id IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

-- --- media (owned by exactly one of project_id / unit_id) ---------------------

ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE media FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS media_tenant ON media;

CREATE POLICY media_tenant ON media
    FOR ALL
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
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR COALESCE(project_id, (SELECT u.project_id FROM units u WHERE u.id = media.unit_id)) IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

-- --- offers --------------------------------------------------------------------

ALTER TABLE offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE offers FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS offers_tenant ON offers;

CREATE POLICY offers_tenant ON offers
    FOR ALL
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
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR project_id IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );

-- --- leads (owner: the buyer who created it, or the developer whose project it targets) ---

ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS leads_tenant ON leads;

CREATE POLICY leads_tenant ON leads
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR user_id = NULLIF(current_setting('app.user_id', true), '')
        OR project_id IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR user_id = NULLIF(current_setting('app.user_id', true), '')
        OR project_id IN (
            SELECT p.id FROM projects p
            JOIN developers d ON d.id = p.developer_id
            WHERE d.owner_user_id = NULLIF(current_setting('app.user_id', true), '')
        )
    );
