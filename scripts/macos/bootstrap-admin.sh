#!/usr/bin/env bash
# Promote a phone to system_admin (dev/demo). Requires API on :4000.
set -euo pipefail
# shellcheck source=./_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

PHONE="${1:-+998901111111}"
SECRET="${BOOTSTRAP_ADMIN_SECRET:-ibuild-local-demo-secret}"

# Outside production, bootstrap is enabled; ensure a non-legacy secret is set
# in .env if you use this script repeatedly.
if ! grep -q '^BOOTSTRAP_ADMIN_SECRET=' "$SERVER_DIR/.env" 2>/dev/null; then
  echo "BOOTSTRAP_ADMIN_SECRET=$SECRET" >>"$SERVER_DIR/.env"
  echo "Appended BOOTSTRAP_ADMIN_SECRET to server/.env — restart API if already running."
fi

# Prefer secret from .env
SECRET="$(grep '^BOOTSTRAP_ADMIN_SECRET=' "$SERVER_DIR/.env" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'")"
SECRET="${SECRET:-ibuild-local-demo-secret}"

need_cmd curl
echo "Bootstrapping system admin $PHONE ..."
RESP="$(curl -sf -X POST "http://localhost:4000/v1/platform/bootstrap-admin" \
  -H "Content-Type: application/json" \
  -d "{\"secret\":\"$SECRET\",\"phone\":\"$PHONE\"}" || true)"

if [[ -z "$RESP" ]]; then
  die "bootstrap failed — is the API running? Check BOOTSTRAP_ADMIN_SECRET (legacy ibuild-dev is rejected)."
fi
echo "$RESP"
echo "Sign in to B2B with $PHONE — OTP in local/dev is 123456"
