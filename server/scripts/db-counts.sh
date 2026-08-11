#!/bin/bash
set -euo pipefail
set -a
. /opt/ibuild/server/.env
set +a
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" <<'SQL'
SELECT COUNT(*) AS developers FROM developers;
SELECT COUNT(*) AS projects FROM projects;
SELECT COUNT(*) AS units FROM units;
SELECT id, name FROM projects LIMIT 5;
SQL
