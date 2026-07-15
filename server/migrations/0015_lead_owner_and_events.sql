-- Lead CRM ownership (FK to users) + audit trail for assign/transfer/status.

ALTER TABLE leads
    ADD COLUMN IF NOT EXISTS owner_user_id TEXT REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_leads_owner_user_id ON leads (owner_user_id);
CREATE INDEX IF NOT EXISTS idx_leads_project_owner ON leads (project_id, owner_user_id);

CREATE TABLE IF NOT EXISTS lead_events (
    id TEXT PRIMARY KEY,
    lead_id TEXT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    actor_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    type TEXT NOT NULL,
    from_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    to_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    detail TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lead_events_lead_id ON lead_events (lead_id, created_at DESC);

-- Backfill owner from legacy free-text assigned_manager when it matches a user name/phone.
UPDATE leads l
SET owner_user_id = u.id
FROM users u
WHERE l.owner_user_id IS NULL
  AND l.assigned_manager IS NOT NULL
  AND (
    lower(trim(l.assigned_manager)) = lower(trim(coalesce(u.name, '')))
    OR trim(l.assigned_manager) = trim(u.phone)
  );
