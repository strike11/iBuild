-- Construction photo reports; optional progressPercent updates project progress.
CREATE TABLE IF NOT EXISTS photo_reports (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    building_id TEXT REFERENCES buildings(id) ON DELETE SET NULL,
    photo_url TEXT NOT NULL,
    taken_at DATE NOT NULL,
    taken_at_is_manual BOOLEAN NOT NULL DEFAULT FALSE,
    progress_percent INTEGER,
    uploaded_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_photo_reports_project ON photo_reports (project_id, taken_at DESC);
