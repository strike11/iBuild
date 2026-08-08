#!/usr/bin/env bash
set -euo pipefail

sed -i 's/\r$//' /tmp/nginx-staging-ip.conf /tmp/sync-residences-images.sh
cp /tmp/sync-residences-images.sh /opt/ibuild/deploy/sync-residences-images.sh
chmod +x /opt/ibuild/deploy/sync-residences-images.sh

docker run --rm \
  -v /tmp/nginx-staging-ip.conf:/src:ro \
  -v /etc/nginx/sites-available:/etc/nginx/sites-available \
  alpine:3.20 cp /src /etc/nginx/sites-available/ibuild-staging

docker run --rm --pid=host alpine:3.20 sh -c 'kill -HUP "$(cat /run/nginx.pid)"'

bash /opt/ibuild/deploy/sync-residences-images.sh /opt/ibuild/server/residences-images

echo "==> Verify via nginx"
curl -fsSI http://127.0.0.1/v1/static/residences/nestone.png | head -3
curl -fsSI http://127.0.0.1/v1/static/residences/hillsblue.png | head -3
