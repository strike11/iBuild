-- Wipe catalogue and allow Store.create() to re-seed from buildProjectsSeed().
-- Usage (on server): psql ... -f scripts/reseed-catalogue.sql && docker compose restart api

BEGIN;
SET LOCAL app.role = 'service';
DELETE FROM media;
DELETE FROM offers;
DELETE FROM units;
DELETE FROM buildings;
DELETE FROM leads;
DELETE FROM reviews;
DELETE FROM projects;
DELETE FROM app_meta WHERE key = 'catalogue_seeded';
COMMIT;

SELECT COUNT(*) AS projects FROM projects;
