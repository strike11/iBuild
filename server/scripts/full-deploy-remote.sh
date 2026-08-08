#!/usr/bin/env bash
# Full stack deploy on the VDS (run after uploading source + web builds).
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/ibuild/deploy}"
SOURCE_DIR="${SOURCE_DIR:-/opt/ibuild/source/server}"
LOCAL_TAG="${LOCAL_TAG:-ibuild-api:local}"
HOST="${HOST:-127.0.0.1}"

echo "==> Sync deploy scripts"
chmod +x "${DEPLOY_DIR}"/*.sh 2>/dev/null || true

echo "==> Sync residence images"
if [ -d /opt/ibuild/server/residences-images ]; then
  bash "${DEPLOY_DIR}/sync-residences-images.sh" /opt/ibuild/server/residences-images
fi

echo "==> Build API image from ${SOURCE_DIR}"
if [ ! -f "${SOURCE_DIR}/Dockerfile" ]; then
  echo "ERROR: ${SOURCE_DIR}/Dockerfile missing" >&2
  exit 1
fi
docker build -t "${LOCAL_TAG}" "${SOURCE_DIR}"
echo "IBUILD_IMAGE=${LOCAL_TAG}" > "${DEPLOY_DIR}/.env"

echo "==> Restart API"
cd "${DEPLOY_DIR}"
docker compose up -d --force-recreate api

ok=0
for _ in $(seq 1 60); do
  if curl -fsS "http://${HOST}:4000/v1/health" >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 2
done
if [ "$ok" -ne 1 ]; then
  echo "ERROR: API health check failed" >&2
  docker compose logs --tail=80 api || true
  exit 1
fi

install_web() {
  local src="$1"
  local dest="$2"
  local root="$src"
  if [ -d "${src}/web" ]; then
    root="${src}/web"
  fi
  if [ ! -f "${root}/index.html" ]; then
    echo "WARN: skip web install — missing ${root}/index.html" >&2
    return 0
  fi
  docker run --rm \
    -v "${root}:/src:ro" \
    -v "${dest}:/dest" \
    alpine:3.20 \
    sh -c 'rm -rf /dest/* && cp -a /src/. /dest/ && chown -R 33:33 /dest'
}

echo "==> Install B2C web"
install_web /tmp/ibuild-app-src /var/www/ibuild/app

echo "==> Install B2B web"
install_web /tmp/ibuild-admin-src /var/www/ibuild/admin
docker run --rm -v /var/www/ibuild/admin:/dest alpine:3.20 \
  rm -f /dest/flutter_service_worker.js 2>/dev/null || true

echo "==> Verify"
curl -fsS "http://${HOST}:4000/v1/projects?limit=5" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print('projects', d['meta']['total']); [print(' -', p['name']) for p in d['data']]"
curl -fsSI "http://${HOST}:4000/v1/static/residences/nestone.png" | head -1
curl -fsSI "http://${HOST}:4000/v1/static/residences/hillsblue.jpg" | head -1
curl -fsSI "http://${HOST}/" | head -1 || true
curl -fsSI "http://${HOST}:8080/" | head -1 || true

echo "Deploy complete (${LOCAL_TAG})."
