#!/usr/bin/env bash
# Copy bundled residence photos to the host path mounted into the API container.
# Usage (on VDS): bash /opt/ibuild/deploy/sync-residences-images.sh
set -euo pipefail

SRC="${1:-/opt/ibuild/source/server/residences-images}"
DEST="${2:-/opt/ibuild/server/residences-images}"

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: source directory missing: $SRC" >&2
  exit 1
fi

mkdir -p "$DEST"
rsync -a --delete "$SRC/" "$DEST/"
chmod -R a+rX "$DEST"
echo "Synced $(find "$DEST" -type f | wc -l) files to $DEST"
ls -la "$DEST"

# nginx regex for *.png catches /v1/static/residences/* before the API proxy
# unless location ^~ /v1/ is active — mirror files under the B2C web root too.
NGINX_STATIC="/var/www/ibuild/app/v1/static/residences"
if [ -d /var/www/ibuild/app ]; then
  docker run --rm \
    -v "${SRC}:/src:ro" \
    -v /var/www/ibuild/app:/app-root \
    alpine:3.20 \
    sh -c "mkdir -p /app-root/v1/static/residences && rm -rf /app-root/v1/static/residences/* && cp -a /src/* /app-root/v1/static/residences/ && chown -R 33:33 /app-root/v1"
  echo "Mirrored to ${NGINX_STATIC} for nginx static fallback"
  ls -la "${NGINX_STATIC}" 2>/dev/null || true
fi
