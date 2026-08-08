#!/usr/bin/env bash
set -euo pipefail
set -a
. /opt/ibuild/server/.env
set +a

echo "==> Sync residence images"
bash /opt/ibuild/deploy/sync-residences-images.sh "${1:-/tmp/residences-images-staging}"

echo "==> Reseed catalogue (NestOne + Hills Blue)"
sed -i 's/\r$//' /tmp/reseed-catalogue.sql
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f /tmp/reseed-catalogue.sql

echo "==> Restart API"
cd /opt/ibuild/deploy
docker compose up -d --force-recreate api
sleep 18

echo "==> Verify"
curl -fsS 'http://127.0.0.1:4000/v1/projects?limit=10' | python3 -c "import sys,json; d=json.load(sys.stdin); print('projects', d['meta']['total']); [print(' -', p['name'], p.get('gallery',[{}])[0].get('url','')) for p in d['data']]"
curl -fsSI 'http://127.0.0.1:4000/v1/static/residences/nestone.png' | head -1
curl -fsSI 'http://127.0.0.1:4000/v1/static/residences/hillsblue.jpg' | head -1
