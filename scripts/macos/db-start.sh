#!/usr/bin/env bash
# Start local PostgreSQL via Docker Compose (server/docker-compose.yml).
set -euo pipefail
# shellcheck source=./_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

need_cmd docker
"$ROOT/scripts/macos/ensure-env.sh"

cd "$SERVER_DIR"
# Prefer `docker compose` (v2); fall back to docker-compose.
if docker compose version >/dev/null 2>&1; then
  docker compose up -d
else
  need_cmd docker-compose
  docker-compose up -d
fi

echo "Waiting for Postgres..."
for _ in $(seq 1 30); do
  if docker compose exec -T postgres pg_isready -U ibuild -d ibuild >/dev/null 2>&1 \
    || docker-compose exec -T postgres pg_isready -U ibuild -d ibuild >/dev/null 2>&1; then
    echo "PostgreSQL is ready on localhost:5432"
    exit 0
  fi
  sleep 1
done
die "Postgres did not become ready in time"
