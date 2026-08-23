#!/usr/bin/env bash
# Expand / re-issue the landing cert so SAN covers both apex and www.
# Safe to re-run. Uses docker (no sudo) like the other deploy scripts.
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/ibuild/deploy}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-admin@ibuild.uz}"
SERVER_IP="${SERVER_IP:-46.8.176.254}"

nginx_exec() {
  docker run --rm --pid host \
    -v /etc/nginx:/etc/nginx:ro \
    -v /etc/letsencrypt:/etc/letsencrypt:ro \
    -v /var/log/nginx:/var/log/nginx \
    -v /var/www:/var/www:ro \
    nginx:1.27-bookworm nginx "$@"
}

nginx_reload() {
  bash /opt/ibuild/deploy/reload-nginx.sh
}

install_nginx_file() {
  local src="$1"
  local dest="$2"
  docker run --rm \
    -v "${DEPLOY_DIR}:/deploy:ro" \
    -v /etc/nginx:/etc/nginx \
    alpine:3.20 \
    sh -c "cp -f /deploy/${src} /etc/nginx/${dest}"
}

echo "==> Current landing certificate SAN"
docker run --rm -v /etc/letsencrypt:/etc/letsencrypt:ro alpine:3.20 \
  sh -c 'apk add --no-cache openssl >/dev/null && openssl x509 -in /etc/letsencrypt/live/ibuild.uz/fullchain.pem -noout -subject -ext subjectAltName'

echo "==> Ensure apex DNS points at ${SERVER_IP}"
apex_ip="$(getent ahostsv4 ibuild.uz 2>/dev/null | awk '{print $1; exit}' || true)"
if [ "${apex_ip}" != "${SERVER_IP}" ]; then
  echo "ERROR: ibuild.uz resolves to '${apex_ip:-<none>}', expected ${SERVER_IP}" >&2
  exit 1
fi

echo "==> Install nginx vhosts with ACME locations on :80"
for pair in \
  "nginx-ibuild.uz.conf:ibuild.uz" \
  "nginx-app.ibuild.uz.conf:app.ibuild.uz" \
  "nginx-api.ibuild.uz.conf:api.ibuild.uz" \
  "nginx-admin.ibuild.uz.conf:admin.ibuild.uz"
do
  file="${pair%%:*}"
  name="${pair##*:}"
  install_nginx_file "${file}" "sites-available/${name}"
done
nginx_exec -t
nginx_reload

echo "==> Probe ACME webroot on :80"
token="ibuild-acme-probe-$$"
docker run --rm -v /var/www/ibuild/www:/var/www/ibuild/www alpine:3.20 \
  sh -c "mkdir -p /var/www/ibuild/www/.well-known/acme-challenge && printf 'ok\n' > /var/www/ibuild/www/.well-known/acme-challenge/${token}"
code="$(curl -fsS -o /tmp/acme-probe.out -w '%{http_code}' \
  -H 'Host: ibuild.uz' \
  "http://127.0.0.1/.well-known/acme-challenge/${token}" || true)"
body="$(cat /tmp/acme-probe.out 2>/dev/null || true)"
docker run --rm -v /var/www/ibuild/www:/var/www/ibuild/www alpine:3.20 \
  rm -f "/var/www/ibuild/www/.well-known/acme-challenge/${token}"
if [ "${code}" != "200" ] || [ "${body}" != "ok" ]; then
  echo "ERROR: ACME probe failed (HTTP ${code}, body='${body}')" >&2
  exit 1
fi
echo "ACME probe OK"

echo "==> Re-issue landing cert: ibuild.uz + www.ibuild.uz"
docker run --rm \
  -v /etc/letsencrypt:/etc/letsencrypt \
  -v /var/www/ibuild/www:/var/www/ibuild/www \
  certbot/certbot:latest certonly --webroot \
  -w /var/www/ibuild/www \
  --cert-name ibuild.uz \
  -d ibuild.uz -d www.ibuild.uz \
  --email "${CERTBOT_EMAIL}" \
  --agree-tos --non-interactive --no-eff-email \
  --force-renewal

nginx_reload

echo "==> New landing certificate SAN"
docker run --rm -v /etc/letsencrypt:/etc/letsencrypt:ro alpine:3.20 \
  sh -c 'apk add --no-cache openssl >/dev/null && openssl x509 -in /etc/letsencrypt/live/ibuild.uz/fullchain.pem -noout -subject -ext subjectAltName'

echo "==> Verify HTTPS (must include apex)"
fail=0
for url in \
  "https://ibuild.uz/" \
  "https://www.ibuild.uz/" \
  "https://app.ibuild.uz/" \
  "https://admin.ibuild.uz/" \
  "https://api.ibuild.uz/v1/health"
do
  code="$(curl -fsSI -o /dev/null -w '%{http_code}' "${url}" || echo FAIL)"
  echo "  ${url} -> ${code}"
  if [ "${code}" != "200" ]; then
    fail=1
  fi
done
if [ "${fail}" -ne 0 ]; then
  echo "ERROR: one or more HTTPS checks failed" >&2
  exit 1
fi

echo "Done. Landing cert covers ibuild.uz and www.ibuild.uz."
