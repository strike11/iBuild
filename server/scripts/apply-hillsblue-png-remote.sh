#!/usr/bin/env bash
set -eu

echo "==> Remove hillsblue.jpg (including www-data static)"
docker run --rm -v /var/www/ibuild/app/v1/static/residences:/dest alpine:3.20 \
  sh -c 'rm -f /dest/hillsblue.jpg; ls -la /dest/'
find /opt/ibuild -name 'hillsblue.jpg' -type f -delete 2>/dev/null || true

echo "==> Install hillsblue.png"
mkdir -p /opt/ibuild/server/residences-images
cp -f /tmp/hillsblue.png /opt/ibuild/server/residences-images/hillsblue.png
for d in /opt/ibuild/source/ibuild/server/residences-images /opt/ibuild/source/server/residences-images; do
  mkdir -p "$d"
  cp -f /tmp/hillsblue.png "$d/hillsblue.png"
  rm -f "$d/hillsblue.jpg"
done

echo "==> Update DB media URLs"
sed -i 's/\r$//' /tmp/update-hillsblue-png.sql
set -a && . /opt/ibuild/server/.env && set +a
export PGPASSWORD="$DB_PASSWORD"
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f /tmp/update-hillsblue-png.sql

echo "==> Sync static mirror"
bash /opt/ibuild/deploy/sync-residences-images.sh /opt/ibuild/server/residences-images

echo "==> Relaunch API"
~/ibuild-relaunch.sh --recreate

echo "==> Verify"
ls -la /opt/ibuild/server/residences-images/
ls -la /var/www/ibuild/app/v1/static/residences/
curl -fsSI http://127.0.0.1:4000/v1/static/residences/hillsblue.png | head -1
curl -fsSI http://127.0.0.1/v1/static/residences/hillsblue.png | head -1
curl -fsS "http://127.0.0.1:4000/v1/projects?limit=5" | python3 -c \
  "import sys,json;d=json.load(sys.stdin);\
[p for p in d['data'] if 'Hills' in p.get('name','')] and print('gallery', [p for p in d['data'] if 'Hills' in p.get('name','')][0]['gallery'][0]['url'])"
