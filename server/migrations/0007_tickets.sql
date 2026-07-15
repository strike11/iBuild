-- Support tickets: any authenticated user (buyer/renter, developer/residence
-- admin) can open a ticket; platform (system) admins triage, reply, and
-- resolve them from the B2B "Тикеты" section. Replies are stored as a JSONB
-- array on the ticket row — a ticket's thread is always read/written as a
-- whole, so a normalized child table would add join overhead with no
-- benefit here.
CREATE TABLE IF NOT EXISTS tickets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_name TEXT,
    user_phone TEXT,
    subject TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'other', -- billing | moderation | technical | other
    status TEXT NOT NULL DEFAULT 'open', -- open | in_progress | resolved | closed
    assigned_to_name TEXT,
    replies_json TEXT NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tickets_user ON tickets (user_id);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets (status);

ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tickets_tenant ON tickets;

CREATE POLICY tickets_tenant ON tickets
    FOR ALL
    USING (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR user_id = NULLIF(current_setting('app.user_id', true), '')
    )
    WITH CHECK (
        COALESCE(current_setting('app.role', true), '') IN ('system_admin', 'service')
        OR user_id = NULLIF(current_setting('app.user_id', true), '')
    );
