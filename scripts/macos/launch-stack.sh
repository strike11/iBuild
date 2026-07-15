#!/usr/bin/env bash
# Full local stack for macOS/Linux demos.
set -euo pipefail
# shellcheck source=./_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

SKIP_DB=0
SKIP_B2C=0
SKIP_B2B=0
for arg in "$@"; do
  case "$arg" in
    --skip-db) SKIP_DB=1 ;;
    --skip-b2c) SKIP_B2C=1 ;;
    --skip-b2b) SKIP_B2B=1 ;;
    -h|--help)
      echo "Usage: $0 [--skip-db] [--skip-b2c] [--skip-b2b]"
      exit 0
      ;;
  esac
done

need_cmd dart
need_cmd flutter

"$ROOT/scripts/macos/ensure-env.sh"

if [[ "$SKIP_DB" -eq 0 ]]; then
  "$ROOT/scripts/macos/db-start.sh"
else
  echo "Skipping Postgres (--skip-db)"
fi

echo "Launching API..."
open_tab "iBuild API" "'$ROOT/scripts/macos/start-api.sh'"
sleep 4

if [[ "$SKIP_B2C" -eq 0 ]]; then
  echo "Launching B2C..."
  open_tab "iBuild B2C" "'$ROOT/scripts/macos/start-b2c.sh'"
fi

if [[ "$SKIP_B2B" -eq 0 ]]; then
  echo "Launching B2B..."
  open_tab "iBuild B2B" "'$ROOT/scripts/macos/start-b2b.sh'"
fi

cat <<EOF

Stack launch requested.
  API:  http://localhost:4000/v1
  B2C:  http://localhost:8099
  B2B:  http://localhost:8100

Confirm API log shows: Persistence: PostgreSQL
Confirm: Live unit ticker OFF
Confirm: DEMO_STAGE_TRUST staged Verified docs (if catalogue present)

Bootstrap admin (once):  ./scripts/macos/bootstrap-admin.sh
Stop stack:              ./scripts/macos/stop-stack.sh
EOF
