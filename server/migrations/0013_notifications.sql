-- Admin notifications inbox: every developer-side change that needs a
-- system admin's attention (new project, project submitted for review,
-- project edited, verification document uploaded, developer application
-- submitted) is recorded here and pushed live over `/v1/ws`
-- (`adminNotification`, admin-only — see `Store.notifyAdmins`). Platform
-- admins mark entries read individually or in bulk via
-- `PATCH /v1/platform/notifications/*`.
CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL, -- project_created | project_submitted | project_updated | document_uploaded | developer_submitted
    title TEXT NOT NULL,
    body TEXT,
    developer_id TEXT REFERENCES developers(id) ON DELETE SET NULL,
    project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
    target_type TEXT,
    target_id TEXT,
    actor_user_id TEXT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications (is_read);
