-- Optimistic locking for units: PATCH /v1/admin/units/:uid may pass an
-- `expectedVersion` in the body; if it no longer matches the row's current
-- version, the request is rejected with 409 UNIT_CONFLICT instead of
-- silently clobbering a concurrent edit (see Store.updateUnit and the
-- route handler in admin_routes.dart). Every successful update increments
-- this column and returns the new value on the unit payload.
ALTER TABLE units
    ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;
