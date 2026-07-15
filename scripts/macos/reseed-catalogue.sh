#!/usr/bin/env bash
# Clear catalogue + seed guard so the next API start re-seeds demo projects.
# Requires Docker Postgres matching server/.env (ibuild/changeme by default).
set -euo pipefail
# shellcheck source=./_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

need_cmd docker
cd "$SERVER_DIR"

echo "This DELETES all projects (and cascaded inventory) in the local Docker DB."
read -r -p "Type YES to continue: " confirm
[[ "$confirm" == "YES" ]] || die "aborted"

COMPOSE=(docker compose)
if ! docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
fi

"${COMPOSE[@]}" exec -T postgres psql -U ibuild -d ibuild <<'SQL'
DELETE FROM projects;
DELETE FROM app_meta WHERE key = 'catalogue_seeded';
SQL

echo "Catalogue cleared. Restart the API — it will re-seed and (if DEMO_STAGE_TRUST=true) stage Verified docs + photos."
echo "  ./scripts/macos/stop-stack.sh --skip-db"
echo "  ./scripts/macos/start-api.sh"
