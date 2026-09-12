-- The A/B verify job's AI result (verdict, structured report, flags) and its
-- safe export used to live only in the running API process's memory —
-- `site_photo_cycles` never had a column for it. Every restart/redeploy
-- silently wiped the analysis for every cycle sitting in
-- analyzing/inspector/confirmed/rejected, leaving inspectors staring at a
-- generic "Submitted for review." fallback with no actual findings.

ALTER TABLE site_photo_cycles
    ADD COLUMN IF NOT EXISTS last_result JSONB,
    ADD COLUMN IF NOT EXISTS verify_export JSONB;
