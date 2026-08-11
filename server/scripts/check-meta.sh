#!/bin/bash
set -euo pipefail
set -a
. /opt/ibuild/server/.env
set +a
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM app_meta;"
