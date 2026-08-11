#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="/opt/ibuild/deploy"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-admin@ibuild.uz}"

install_nginx_file() {
  local src="$1"
  local dest="$2"
  docker run --rm \
    -v "${DEPLOY_DIR}:/deploy:ro" \
    -v /etc/nginx:/etc/nginx \
    alpine:3.20 \
    sh -c "cp -f /deploy/${src} /etc/nginx/${dest}"
}

link_site() {
  local name="$1"
  docker run --rm -v /etc/nginx:/etc/nginx alpine:3.20 \
    sh -c "ln -sf /etc/nginx/sites-available/${name} /etc/nginx/sites-enabled/${name}"
}

unlink_site() {
  local name="$1"
  docker run --rm -v /etc/nginx:/etc/nginx alpine:3.20 \
    rm -f "/etc/nginx/sites-enabled/${name}"
}

if ! docker run --rm -v /etc/letsencrypt:/etc/letsencrypt:ro alpine:3.20 \
  test -f /etc/letsencrypt/live/api.ibuild.uz/fullchain.pem; then
  echo "==> Issue certificate: api.ibuild.uz"
  docker run --rm \
    -v /etc/letsencrypt:/etc/letsencrypt \
    -v /var/www/certbot:/var/www/certbot \
    certbot/certbot:latest certonly --webroot \
    -w /var/www/certbot \
    --cert-name api.ibuild.uz \
    -d api.ibuild.uz \
    --email "${CERTBOT_EMAIL}" \
    --agree-tos --non-interactive --no-eff-email
fi

echo "==> Enable production HTTPS nginx sites"
for pair in \
  "nginx-ibuild.uz.conf:ibuild.uz" \
  "nginx-app.ibuild.uz.conf:app.ibuild.uz" \
  "nginx-api.ibuild.uz.conf:api.ibuild.uz" \
  "nginx-admin.ibuild.uz.conf:admin.ibuild.uz"
do
  file="${pair%%:*}"
  name="${pair##*:}"
  install_nginx_file "${file}" "sites-available/${name}"
  link_site "${name}"
done

unlink_site "ibuild-bootstrap"
docker run --rm --pid host \
  -v /etc/nginx:/etc/nginx:ro \
  -v /etc/letsencrypt:/etc/letsencrypt:ro \
  -v /var/log/nginx:/var/log/nginx \
  -v /var/www:/var/www:ro \
  nginx:1.27-bookworm nginx -t
bash /opt/ibuild/deploy/reload-nginx.sh

echo "==> Verify HTTPS"
for url in \
  "https://www.ibuild.uz/" \
  "https://app.ibuild.uz/" \
  "https://admin.ibuild.uz/" \
  "https://api.ibuild.uz/v1/health"
do
  code="$(curl -fsSI -o /dev/null -w '%{http_code}' "${url}" || echo FAIL)"
  echo "  ${url} -> ${code}"
done

echo "Done."
