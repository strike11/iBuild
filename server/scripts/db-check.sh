#!/bin/bash
set -euo pipefail
set -a
. /opt/ibuild/server/.env
set +a
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" <<'SQL'
SELECT key, value FROM app_meta;
SELECT COUNT(*) AS projects FROM projects;
SQL
