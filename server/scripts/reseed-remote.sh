#!/bin/bash
set -euo pipefail
set -a
. /opt/ibuild/server/.env
set +a
sed -i 's/\r$//' /tmp/reseed-catalogue.sql
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f /tmp/reseed-catalogue.sql
cd /opt/ibuild/deploy
docker compose up -d --force-recreate api
sleep 12
curl -fsS "http://127.0.0.1:4000/v1/projects?limit=1"
