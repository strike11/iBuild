-- B2C accounts are tagged `ordinary_user`; B2B will add system_admin and
-- residence_admin later without reshaping the auth response envelope.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'ordinary_user';
