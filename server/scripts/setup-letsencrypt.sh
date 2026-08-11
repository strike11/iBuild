#!/usr/bin/env bash
# Issue Let's Encrypt certs and switch nginx from IP staging to production TLS.
# Runs without sudo when the deploy user is in the docker group.
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/ibuild/deploy}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-admin@ibuild.uz}"
SERVER_IP="${SERVER_IP:-46.8.176.254}"

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

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

link_site() {
  local name="$1"
  docker run --rm -v /etc/nginx:/etc/nginx alpine:3.20 \
    sh -c "ln -sf ${NGINX_AVAILABLE}/${name} ${NGINX_ENABLED}/${name}"
}

unlink_site() {
  local name="$1"
  docker run --rm -v /etc/nginx:/etc/nginx alpine:3.20 \
    rm -f "${NGINX_ENABLED}/${name}"
}

certbot_webroot() {
  local webroot="$1"
  shift
  docker run --rm \
    -v /etc/letsencrypt:/etc/letsencrypt \
    -v "${webroot}:${webroot}" \
    certbot/certbot:latest certonly --webroot \
    -w "${webroot}" \
    "$@" \
    --email "${CERTBOT_EMAIL}" \
    --agree-tos --non-interactive --no-eff-email
}

domain_points_here() {
  local domain="$1"
  host "${domain}" 2>/dev/null | grep -q "${SERVER_IP}"
}

echo "==> Prepare web roots"
docker run --rm -v /var/www:/var/www alpine:3.20 \
  sh -c 'mkdir -p /var/www/certbot /var/www/ibuild/www /var/www/ibuild/app /var/www/ibuild/admin && chown -R 33:33 /var/www/ibuild /var/www/certbot'

echo "==> Install HTTP bootstrap nginx (for ACME)"
install_nginx_file "nginx-production-http-bootstrap.conf" "sites-available/ibuild-bootstrap"
unlink_site "ibuild-staging"
unlink_site "default"
link_site "ibuild-bootstrap"
nginx_exec -t
nginx_reload

landing_domains=( -d www.ibuild.uz )
if domain_points_here "ibuild.uz"; then
  landing_domains=( -d ibuild.uz -d www.ibuild.uz )
  echo "==> ibuild.uz apex resolves — including in landing certificate"
else
  echo "WARN: ibuild.uz has no A record yet — cert will cover www.ibuild.uz only" >&2
fi

echo "==> Issue certificate: landing"
certbot_webroot /var/www/ibuild/www --cert-name ibuild.uz "${landing_domains[@]}"

echo "==> Issue certificate: app.ibuild.uz"
certbot_webroot /var/www/ibuild/app --cert-name app.ibuild.uz -d app.ibuild.uz

echo "==> Issue certificate: admin.ibuild.uz"
certbot_webroot /var/www/ibuild/admin --cert-name admin.ibuild.uz -d admin.ibuild.uz

echo "==> Issue certificate: api.ibuild.uz"
certbot_webroot /var/www/certbot --cert-name api.ibuild.uz -d api.ibuild.uz

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
nginx_exec -t
nginx_reload

echo "==> Install certbot renew timer (docker)"
RENEW_SCRIPT="/opt/ibuild/deploy/renew-letsencrypt.sh"
cat > /tmp/renew-letsencrypt.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
docker run --rm \
  -v /etc/letsencrypt:/etc/letsencrypt \
  -v /var/www/ibuild/www:/var/www/ibuild/www \
  -v /var/www/ibuild/app:/var/www/ibuild/app \
  -v /var/www/ibuild/admin:/var/www/ibuild/admin \
  -v /var/www/certbot:/var/www/certbot \
  certbot/certbot:latest renew --quiet
docker run --rm --pid host alpine:3.20 sh -c 'kill -HUP "$(cat /run/nginx.pid)"'
EOF
docker run --rm -v /opt/ibuild/deploy:/dest -v /tmp:/tmp alpine:3.20 \
  sh -c 'cp /tmp/renew-letsencrypt.sh /dest/renew-letsencrypt.sh && chmod +x /dest/renew-letsencrypt.sh'

(docker run --rm -v /etc:/etc alpine:3.20 sh -c 'grep -q renew-letsencrypt /etc/crontab' || \
  docker run --rm -v /etc:/etc alpine:3.20 \
    sh -c 'echo "0 3 * * * root /opt/ibuild/deploy/renew-letsencrypt.sh >> /var/log/ibuild-certbot-renew.log 2>&1" >> /etc/crontab') || true

echo "==> Verify HTTPS endpoints"
for url in \
  "https://www.ibuild.uz/" \
  "https://app.ibuild.uz/" \
  "https://admin.ibuild.uz/" \
  "https://api.ibuild.uz/v1/health"
do
  code="$(curl -fsSI -o /dev/null -w '%{http_code}' "${url}" || echo FAIL)"
  echo "  ${url} -> ${code}"
done

echo "Done. Production TLS is live."
