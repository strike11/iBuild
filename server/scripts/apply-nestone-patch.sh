#!/bin/bash
set -euo pipefail
set -a
. /opt/ibuild/server/.env
set +a
sed -i 's/\r$//' /tmp/update-nestone.sql
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f /tmp/update-nestone.sql
cd /opt/ibuild/deploy
docker compose restart api
sleep 15
curl -fsS 'http://127.0.0.1:4000/v1/projects/prj-nestone' | python3 -m json.tool | grep -E 'status|district|constructionProgress|tags' | head -10
