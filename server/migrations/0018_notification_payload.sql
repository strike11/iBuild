-- Structured fields for client-side localization of admin notifications.
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS payload JSONB;
