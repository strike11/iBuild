#!/usr/bin/env bash
set -euo pipefail

echo "=== sites-enabled ==="
ls -la /etc/nginx/sites-enabled/

echo "=== listening ports ==="
docker run --rm --pid host --privileged alpine:3.20 sh -c 'ss -tlnp' | grep nginx || true

echo "=== web roots ==="
for d in www app admin; do
  echo "-- /var/www/ibuild/$d"
  ls /var/www/ibuild/$d/index.html 2>&1 || echo MISSING
done

echo "=== local HTTPS checks ==="
for host in app.ibuild.uz admin.ibuild.uz api.ibuild.uz www.ibuild.uz; do
  code=$(curl -sS -o /dev/null -w '%{http_code}' --resolve "${host}:443:127.0.0.1" "https://${host}/" 2>/dev/null || echo ERR)
  echo "${host} -> ${code}"
done

code=$(curl -sS -o /dev/null -w '%{http_code}' --resolve 'api.ibuild.uz:443:127.0.0.1' 'https://api.ibuild.uz/v1/health' 2>/dev/null || echo ERR)
echo "api health -> ${code}"

echo "=== public DNS from server ==="
for host in app.ibuild.uz admin.ibuild.uz api.ibuild.uz www.ibuild.uz ibuild.uz; do
  echo -n "${host}: "
  host "${host}" 2>/dev/null | head -1 || echo NXDOMAIN
done
