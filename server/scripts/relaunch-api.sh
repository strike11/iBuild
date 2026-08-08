#!/usr/bin/env bash
# Quick relaunch of the iBuild API on the staging VDS.
#
# Install on the server:
#   cp /opt/ibuild/source/server/scripts/relaunch-api.sh ~/ibuild-relaunch.sh
#   chmod +x ~/ibuild-relaunch.sh
#
# Usage:
#   ~/ibuild-relaunch.sh              # restart container, wait for /v1/health
#   ~/ibuild-relaunch.sh --recreate   # force-recreate (picks up new image tag)
#   ~/ibuild-relaunch.sh --status     # health + docker ps
#   ~/ibuild-relaunch.sh --logs       # tail api logs

set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/ibuild/deploy}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:4000/v1/health}"
RESIDENCES_DIR="${RESIDENCES_DIR:-/opt/ibuild/server/residences-images}"
WAIT_SECS="${WAIT_SECS:-120}"

usage() {
  cat <<'EOF'
iBuild API relaunch

  ibuild-relaunch.sh              Restart api container and wait for health
  ibuild-relaunch.sh --recreate   docker compose up -d --force-recreate api
  ibuild-relaunch.sh --sync       Mirror residence images to static web root
  ibuild-relaunch.sh --status     Show container + health + OTP smoke test
  ibuild-relaunch.sh --logs       Follow api logs (Ctrl+C to exit)
  ibuild-relaunch.sh --help       This help

Env overrides: DEPLOY_DIR, HEALTH_URL, WAIT_SECS
EOF
}

log() {
  echo "[$(date -Is)] $*"
}

require_deploy_dir() {
  if [ ! -f "${DEPLOY_DIR}/docker-compose.yml" ]; then
    log "ERROR: ${DEPLOY_DIR}/docker-compose.yml not found"
    exit 1
  fi
  if [ ! -f "${DEPLOY_DIR}/.env" ]; then
    log "ERROR: ${DEPLOY_DIR}/.env missing (IBUILD_IMAGE not pinned)"
    exit 1
  fi
}

wait_healthy() {
  local deadline=$((SECONDS + WAIT_SECS))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if curl -fsS --max-time 5 "$HEALTH_URL" >/dev/null 2>&1; then
      curl -fsS "$HEALTH_URL"
      echo ""
      return 0
    fi
    sleep 2
  done
  log "ERROR: health check timed out at ${HEALTH_URL}"
  cd "$DEPLOY_DIR"
  docker compose logs --tail=80 api || true
  exit 1
}

sync_residences() {
  if [ -x "${DEPLOY_DIR}/sync-residences-images.sh" ] && [ -d "$RESIDENCES_DIR" ]; then
    log "Syncing residence images..."
    bash "${DEPLOY_DIR}/sync-residences-images.sh" "$RESIDENCES_DIR"
  fi
}

show_status() {
  require_deploy_dir
  cd "$DEPLOY_DIR"
  echo "==> IBUILD_IMAGE"
  cat "${DEPLOY_DIR}/.env"
  echo ""
  echo "==> Container"
  docker compose ps || true
  echo ""
  echo "==> Health"
  if curl -fsS --max-time 5 "$HEALTH_URL"; then
    echo ""
  else
    echo "FAILED"
    exit 1
  fi
  echo ""
  echo "==> OTP smoke (staging dev code 123456 when Eskiz unset)"
  curl -fsS -X POST "http://127.0.0.1:4000/v1/auth/otp/send" \
    -H 'Content-Type: application/json' \
    -d '{"phone":"+998901234567"}' || true
  echo ""
}

restart_api() {
  local mode="${1:-restart}"
  require_deploy_dir
  cd "$DEPLOY_DIR"
  # shellcheck disable=SC1091
  source "${DEPLOY_DIR}/.env"
  log "Using image: ${IBUILD_IMAGE:-unknown}"
  if [ "$mode" = "recreate" ]; then
    log "Force-recreating api container..."
    docker compose up -d --force-recreate api
  else
    log "Restarting api container..."
    docker compose restart api
  fi
  sleep 2
  log "Waiting for ${HEALTH_URL} ..."
  wait_healthy
  log "API is up."
}

cmd="${1:---restart}"

case "$cmd" in
  --restart|restart|"")
    restart_api restart
    ;;
  --recreate|recreate)
    restart_api recreate
    ;;
  --sync|sync)
    sync_residences
    ;;
  --status|status)
    show_status
    ;;
  --logs|logs)
    require_deploy_dir
    cd "$DEPLOY_DIR"
    docker compose logs -f api
    ;;
  --help|-h|help)
    usage
    ;;
  *)
    echo "Unknown option: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
