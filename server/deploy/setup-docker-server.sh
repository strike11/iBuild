#!/usr/bin/env bash
# One-time VDS bootstrap: Docker, PostgreSQL, directory layout, nginx (IP staging).
#
# Tested on Ubuntu 22.04. Run as root on a fresh VDS:
#   SERVER_IP=203.0.113.10 DEPLOY_USER=deploy ./setup-docker-server.sh
#
# Options (environment):
#   SERVER_IP      — public IPv4/hostname for CORS and docs (required)
#   DEPLOY_USER    — UNIX user for SSH deploy + docker (default: deploy)
#   ADMIN_PHONE    — seeded as system_admin, e.g. +998901234567 (optional)
#   SKIP_POSTGRES  — set to 1 if PostgreSQL is already configured
#   SKIP_NGINX     — set to 1 to skip nginx install/config
#   SKIP_UFW       — set to 1 to skip firewall rules

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVER_IP="${SERVER_IP:-}"
DEPLOY_USER="${DEPLOY_USER:-deploy}"
ADMIN_PHONE="${ADMIN_PHONE:-}"
DB_PASSWORD="${DB_PASSWORD:-}"

usage() {
  sed -n '2,12p' "$0"
  echo ""
  echo "Required: SERVER_IP=your.public.ip"
  exit 1
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo SERVER_IP=x.x.x.x $0" >&2
  exit 1
fi

if [ -z "$SERVER_IP" ]; then
  usage
fi

if [ -z "$DB_PASSWORD" ]; then
  DB_PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)"
  echo "Generated DB_PASSWORD (save it): ${DB_PASSWORD}"
fi

export DEBIAN_FRONTEND=noninteractive

find /etc/apt -type f -exec sed -i '/cdrom/d' {} + 2>/dev/null || true

echo "==> Installing Docker Engine"
bash "${SCRIPT_DIR}/install-docker.sh"

echo "==> Base packages (nginx, PostgreSQL, tools)"
apt-get update
apt-get install -y nginx postgresql postgresql-contrib rsync curl ufw openssl

if [ "${SKIP_UFW:-0}" != "1" ]; then
  echo "==> Firewall (SSH + HTTP only)"
  ufw allow OpenSSH
  ufw allow 80/tcp
  ufw allow 8080/tcp
  ufw allow 443/tcp
  ufw --force enable
fi

if [ "${SKIP_POSTGRES:-0}" != "1" ]; then
  echo "==> PostgreSQL role + database"
  systemctl enable --now postgresql
  sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'ibuild') THEN
    CREATE ROLE ibuild LOGIN PASSWORD '${DB_PASSWORD}';
  ELSE
    ALTER ROLE ibuild WITH PASSWORD '${DB_PASSWORD}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ibuild OWNER ibuild'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ibuild')\gexec
SQL
  # Loopback only — never expose 5432 to the internet.
  PG_CONF="$(find /etc/postgresql -name postgresql.conf 2>/dev/null | head -1)"
  if [ -n "$PG_CONF" ] && grep -q "^listen_addresses" "$PG_CONF"; then
    sed -i "s/^listen_addresses.*/listen_addresses = 'localhost'/" "$PG_CONF"
  fi
  systemctl restart postgresql
fi

echo "==> Deploy user: ${DEPLOY_USER}"
if ! id "$DEPLOY_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
  usermod -aG sudo "$DEPLOY_USER"
fi
usermod -aG docker "$DEPLOY_USER"

echo "==> Directory layout under /opt/ibuild and /var/www/ibuild"
mkdir -p \
  /opt/ibuild/deploy \
  /opt/ibuild/server/uploads/private \
  /opt/ibuild/source \
  /var/www/ibuild/app \
  /var/www/ibuild/admin \
  /var/www/ibuild/www

chown -R "${DEPLOY_USER}:${DEPLOY_USER}" /opt/ibuild/deploy /opt/ibuild/source
mkdir -p /opt/ibuild/server
chown "${DEPLOY_USER}:${DEPLOY_USER}" /opt/ibuild/server
chown -R 10001:10001 /opt/ibuild/server/uploads
chmod 700 /opt/ibuild/server/uploads/private
chown -R www-data:www-data /var/www/ibuild

echo "==> Staging application env: /opt/ibuild/server/.env"
ORIGINS="http://${SERVER_IP},http://${SERVER_IP}:8080,http://${SERVER_IP}:8081"
STAGING_ENV="/opt/ibuild/server/.env"
if [ ! -f "$STAGING_ENV" ]; then
  cat > "$STAGING_ENV" <<ENV
# Staging — IP access, no SMS provider yet. OTP is always 123456 (see docker logs).
# Switch to APP_ENV=production + Eskiz when going live on ibuild.uz domains.

APP_ENV=staging

DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=ibuild
DB_USER=ibuild
DB_PASSWORD=${DB_PASSWORD}
DB_SSL=false

TRUST_PROXY=true
ALLOWED_ORIGINS=${ORIGINS}

BOOTSTRAP_ADMIN_ENABLED=true
BOOTSTRAP_ADMIN_SECRET=$(openssl rand -hex 32)
ALLOW_DEV_CHECKOUT=false
LIVE_DEMO_TICKER=false
DEMO_STAGE_TRUST=false
ENV
  if [ -n "$ADMIN_PHONE" ]; then
    echo "SYSTEM_ADMIN_PHONES=${ADMIN_PHONE}" >> "$STAGING_ENV"
  fi
  chmod 600 "$STAGING_ENV"
  chown "${DEPLOY_USER}:${DEPLOY_USER}" "$STAGING_ENV"
else
  echo "    (skipped — $STAGING_ENV already exists)"
fi

echo "==> Deploy compose env: /opt/ibuild/deploy/.env"
DEPLOY_ENV="/opt/ibuild/deploy/.env"
if [ ! -f "$DEPLOY_ENV" ]; then
  cat > "$DEPLOY_ENV" <<ENV
# Set by CI or first-deploy.sh. Example:
# IBUILD_IMAGE=ghcr.io/strike11/ibuild/api:sha-abc123
IBUILD_IMAGE=
ENV
  chown "${DEPLOY_USER}:${DEPLOY_USER}" "$DEPLOY_ENV"
fi

cp -f "${SCRIPT_DIR}/docker-compose.yml" /opt/ibuild/deploy/docker-compose.yml
cp -f "${SCRIPT_DIR}/first-deploy.sh" /opt/ibuild/deploy/first-deploy.sh
cp -f "${SCRIPT_DIR}/healthcheck-docker.sh" /opt/ibuild/deploy/healthcheck-docker.sh
chmod +x /opt/ibuild/deploy/first-deploy.sh /opt/ibuild/deploy/healthcheck-docker.sh
chown "${DEPLOY_USER}:${DEPLOY_USER}" \
  /opt/ibuild/deploy/docker-compose.yml \
  /opt/ibuild/deploy/first-deploy.sh \
  /opt/ibuild/deploy/healthcheck-docker.sh

if [ "${SKIP_NGINX:-0}" != "1" ]; then
  echo "==> nginx — IP staging (HTTP)"
  cp -f "${SCRIPT_DIR}/nginx-staging-ip.conf" /etc/nginx/sites-available/ibuild-staging
  ln -sf /etc/nginx/sites-available/ibuild-staging /etc/nginx/sites-enabled/ibuild-staging
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl enable --now nginx
  systemctl reload nginx
fi

echo "==> Docker health watchdog (optional systemd timer)"
cp -f "${SCRIPT_DIR}/ibuild-healthcheck-docker.service" /etc/systemd/system/
cp -f "${SCRIPT_DIR}/ibuild-healthcheck-docker.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now ibuild-healthcheck-docker.timer

echo ""
echo "=============================================="
echo " Bootstrap complete."
echo "=============================================="
echo " Deploy user:     ${DEPLOY_USER}  (in group docker)"
echo " API (local):     curl http://127.0.0.1:4000/v1/health  (after first deploy)"
echo " API (public):    http://${SERVER_IP}/v1/health"
echo " Landing:         http://${SERVER_IP}/"
echo " B2C app:         http://${SERVER_IP}:8081/"
echo " B2B admin:       http://${SERVER_IP}:8080/"
echo " Secrets file:    ${STAGING_ENV}"
echo ""
echo " Next steps:"
echo "  1. Copy SSH key for ${DEPLOY_USER} (or run: ssh-copy-id ${DEPLOY_USER}@\$(hostname -I | awk '{print \$1}'))"
echo "  2. On server as ${DEPLOY_USER}: /opt/ibuild/deploy/first-deploy.sh build"
echo "     — or set GitHub secrets AIRNET_* and push to main"
echo "  3. Build Flutter web apps locally and rsync to /var/www/ibuild/{app,admin}"
echo "=============================================="
