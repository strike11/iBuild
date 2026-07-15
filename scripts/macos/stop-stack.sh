#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=./_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

SKIP_DB=0
for arg in "$@"; do
  case "$arg" in
    --skip-db) SKIP_DB=1 ;;
  esac
done

echo "Stopping iBuild stack..."
kill_port 8099 "B2C"
kill_port 8100 "B2B"
kill_port 4000 "API"

if [[ "$SKIP_DB" -eq 0 ]]; then
  if command -v docker >/dev/null 2>&1; then
    "$ROOT/scripts/macos/db-stop.sh" || true
  else
    echo "  docker not found — left Postgres alone"
  fi
else
  echo "  left Postgres running (--skip-db)"
fi

echo "Done."
