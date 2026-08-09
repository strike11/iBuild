#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/ibuild/deploy}"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

install_site() {
  local file="$1"
  local name="$2"
  local src="${DEPLOY_DIR}/${file}"
  if [ ! -f "$src" ]; then
    echo "ERROR: missing ${src}" >&2
    exit 1
  fi
  sudo cp -f "$src" "${NGINX_AVAILABLE}/${name}"
  sudo ln -sf "${NGINX_AVAILABLE}/${name}" "${NGINX_ENABLED}/${name}"
}

sudo mkdir -p /var/www/ibuild/www
sudo chown -R www-data:www-data /var/www/ibuild

install_site "nginx-ibuild.uz.conf" "ibuild.uz"
install_site "nginx-app.ibuild.uz.conf" "app.ibuild.uz"
install_site "nginx-api.ibuild.uz.conf" "api.ibuild.uz"
install_site "nginx-admin.ibuild.uz.conf" "admin.ibuild.uz"

sudo rm -f "${NGINX_ENABLED}/ibuild-staging" "${NGINX_ENABLED}/default"

sudo nginx -t
sudo systemctl reload nginx

echo "Production nginx sites enabled. Issue TLS certs if needed:"
echo "  sudo certbot --nginx -d ibuild.uz -d www.ibuild.uz"
echo "  sudo certbot --nginx -d app.ibuild.uz"
echo "  sudo certbot --nginx -d api.ibuild.uz"
echo "  sudo certbot --nginx -d admin.ibuild.uz"
