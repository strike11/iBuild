-- Confirmed progress (photo reports) vs promised (`planned_progress` from
-- schedule); gap is the delivery-risk signal on the project card.
ALTER TABLE projects ADD COLUMN IF NOT EXISTS planned_progress INTEGER;

-- severity: routine feed vs critical admin alerts (e.g. schedule deviation).
-- NULL → treat as 'info'.
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS severity TEXT;

CREATE INDEX IF NOT EXISTS idx_notifications_severity
    ON notifications (severity)
    WHERE severity = 'critical';
