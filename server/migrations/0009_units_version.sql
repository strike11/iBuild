-- Optimistic locking: expectedVersion mismatch -> 409 UNIT_CONFLICT.
ALTER TABLE units
    ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;
