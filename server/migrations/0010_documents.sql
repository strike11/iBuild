-- Developer verification docs. All 4 required types must be accepted before org approve.
CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    developer_id TEXT NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
    project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
    type TEXT NOT NULL, -- license | construction_permit | land_rights | project_declaration
    file_url TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- pending | accepted | rejected
    reject_reason TEXT,
    uploaded_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_documents_developer ON documents (developer_id);
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents (status);
