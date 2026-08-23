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

echo "=== landing certificate SAN (must include apex + www) ==="
docker run --rm -v /etc/letsencrypt:/etc/letsencrypt:ro alpine:3.20 \
  sh -c 'apk add --no-cache openssl >/dev/null && openssl x509 -in /etc/letsencrypt/live/ibuild.uz/fullchain.pem -noout -subject -ext subjectAltName' \
  || echo "MISSING landing cert"
san="$(docker run --rm -v /etc/letsencrypt:/etc/letsencrypt:ro alpine:3.20 \
  sh -c 'apk add --no-cache openssl >/dev/null && openssl x509 -in /etc/letsencrypt/live/ibuild.uz/fullchain.pem -noout -ext subjectAltName' 2>/dev/null || true)"
if ! echo "${san}" | grep -q 'DNS:ibuild.uz'; then
  echo "WARN: landing cert SAN missing DNS:ibuild.uz — apex HTTPS will fail browser verify"
fi
if ! echo "${san}" | grep -q 'DNS:www.ibuild.uz'; then
  echo "WARN: landing cert SAN missing DNS:www.ibuild.uz"
fi

echo "=== local HTTPS checks ==="
for host in ibuild.uz www.ibuild.uz app.ibuild.uz admin.ibuild.uz api.ibuild.uz; do
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

echo "=== NS SPOF check (dns1/dns2 should not share one IP) ==="
ns1="$(getent ahostsv4 dns1.airnet.uz 2>/dev/null | awk '{print $1; exit}' || true)"
ns2="$(getent ahostsv4 dns2.airnet.uz 2>/dev/null | awk '{print $1; exit}' || true)"
echo "dns1.airnet.uz -> ${ns1:-<none>}"
echo "dns2.airnet.uz -> ${ns2:-<none>}"
if [ -n "${ns1}" ] && [ "${ns1}" = "${ns2}" ]; then
  echo "WARN: both authoritative NS resolve to the same IP (${ns1})."
  echo "      This is a single point of failure and can cause intermittent ERR_NAME_NOT_RESOLVED."
  echo "      Ask Airnet for distinct NS addresses or move DNS to a dual-NS provider."
fi
