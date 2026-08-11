#!/usr/bin/env bash
set -euo pipefail

docker run --rm \
  -v /etc/letsencrypt:/etc/letsencrypt \
  -v /var/www/ibuild/www:/var/www/ibuild/www \
  -v /var/www/ibuild/app:/var/www/ibuild/app \
  -v /var/www/ibuild/admin:/var/www/ibuild/admin \
  -v /var/www/certbot:/var/www/certbot \
  certbot/certbot:latest renew --quiet

bash /opt/ibuild/deploy/reload-nginx.sh
