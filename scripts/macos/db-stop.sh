#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=./_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

need_cmd docker
cd "$SERVER_DIR"
if docker compose version >/dev/null 2>&1; then
  docker compose down
else
  docker-compose down
fi
echo "PostgreSQL stopped."
