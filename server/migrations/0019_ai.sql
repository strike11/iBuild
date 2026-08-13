-- AI layer: photo-report verification results, computed lead scoring, and the
-- restart-proof AI quota ledger (the in-memory RateLimiter handed out a fresh
-- budget on every deploy).

-- --- photo_reports: readiness/verification output --------------------------
-- phash is the 64-bit perceptual hash as hex, so duplicate detection is a
-- Hamming distance against prior reports of the same project.
ALTER TABLE photo_reports ADD COLUMN IF NOT EXISTS phash TEXT;
-- confirmed | discrepancy_found | violation_found | requires_manual_review
ALTER TABLE photo_reports ADD COLUMN IF NOT EXISTS verification_status TEXT;
ALTER TABLE photo_reports ADD COLUMN IF NOT EXISTS verification_confidence INTEGER;
-- Full stage_1..stage_7 result, so the b2b stepper can be re-rendered later.
ALTER TABLE photo_reports ADD COLUMN IF NOT EXISTS verification_json JSONB;
-- EXIF DateTimeOriginal / GPS as extracted; NULL when the photo carries none.
ALTER TABLE photo_reports ADD COLUMN IF NOT EXISTS exif_taken_at TIMESTAMPTZ;
ALTER TABLE photo_reports ADD COLUMN IF NOT EXISTS exif_lat DOUBLE PRECISION;
ALTER TABLE photo_reports ADD COLUMN IF NOT EXISTS exif_lng DOUBLE PRECISION;
-- Stage classified from the image vs the stage the developer declared.
ALTER TABLE photo_reports ADD COLUMN IF NOT EXISTS detected_stage TEXT;
ALTER TABLE photo_reports ADD COLUMN IF NOT EXISTS declared_stage TEXT;

-- Duplicate detection scans every prior hash for one project.
CREATE INDEX IF NOT EXISTS idx_photo_reports_project_phash
    ON photo_reports (project_id, phash)
    WHERE phash IS NOT NULL;

-- --- leads: subject + computed AI score ------------------------------------
-- What the buyer enquired about (project | unit | rent | office | mortgage |
-- other); a scoring input, distinct from `intent`.
ALTER TABLE leads ADD COLUMN IF NOT EXISTS subject TEXT;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS ai_score INTEGER;
-- hot | warm | cold, derived from ai_score.
ALTER TABLE leads ADD COLUMN IF NOT EXISTS ai_band TEXT;
-- Reason codes only — the b2b client localizes them.
ALTER TABLE leads ADD COLUMN IF NOT EXISTS ai_reasons TEXT[];
ALTER TABLE leads ADD COLUMN IF NOT EXISTS ai_scored_at TIMESTAMPTZ;

-- "Требуют внимания сегодня" reads the top band first.
CREATE INDEX IF NOT EXISTS idx_leads_ai_score
    ON leads (ai_score DESC NULLS LAST);

-- --- ai_usage: quota ledger ------------------------------------------------
-- ip_hash is sha256(ip + AI_QUOTA_SALT) — a raw IP is never stored. The
-- `user:<id>` and `global` scopes reuse the same table under reserved keys so
-- all three enforcement layers share one counter shape.
CREATE TABLE IF NOT EXISTS ai_usage (
    ip_hash TEXT NOT NULL,
    day DATE NOT NULL,
    kind TEXT NOT NULL, -- chat | search | verify
    count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (ip_hash, day, kind)
);

-- Daily global cap sums one day across all keys.
CREATE INDEX IF NOT EXISTS idx_ai_usage_day_kind ON ai_usage (day, kind);
