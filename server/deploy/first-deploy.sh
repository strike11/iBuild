#!/usr/bin/env bash
# First API deploy on the VDS (run as the deploy user, after setup-docker-server.sh).
#
# Usage:
#   first-deploy.sh build              — build image from /opt/ibuild/source/server
#   first-deploy.sh pull IMAGE_TAG     — pull a GHCR image (after CI build)
#   first-deploy.sh status             — container + health
#
# Examples:
#   ./first-deploy.sh build
#   ./first-deploy.sh pull ghcr.io/strike11/ibuild/api:latest

set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/ibuild/deploy}"
SOURCE_DIR="${SOURCE_DIR:-/opt/ibuild/source/server}"
LOCAL_TAG="${LOCAL_TAG:-ibuild-api:local}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:4000/v1/health}"

cd "$DEPLOY_DIR"

cmd="${1:-}"
arg="${2:-}"

require_env_file() {
  if [ ! -f /opt/ibuild/server/.env ]; then
    echo "ERROR: /opt/ibuild/server/.env missing. Run setup-docker-server.sh first." >&2
    exit 1
  fi
}

write_image_env() {
  local image="$1"
  echo "IBUILD_IMAGE=${image}" > "${DEPLOY_DIR}/.env"
  echo "Pinned IBUILD_IMAGE=${image}"
}

wait_healthy() {
  local     ok=0
    for _ in $(seq 1 90); do
    if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
      ok=1
      break
    fi
    sleep 2
  done
  if [ "$ok" -ne 1 ]; then
    echo "ERROR: health check failed at ${HEALTH_URL}" >&2
    docker compose logs --tail=100 api || true
    exit 1
  fi
  curl -fsS "$HEALTH_URL"
  echo ""
}

case "$cmd" in
  build)
    require_env_file
    if [ ! -f "${SOURCE_DIR}/Dockerfile" ]; then
      echo "ERROR: ${SOURCE_DIR}/Dockerfile not found." >&2
      echo "Clone or rsync the repo to ${SOURCE_DIR} first, e.g.:" >&2
      echo "  sudo mkdir -p /opt/ibuild/source && sudo chown \$USER /opt/ibuild/source" >&2
      echo "  git clone https://github.com/strike11/iBuild.git /opt/ibuild/source" >&2
      exit 1
    fi
    docker build -t "$LOCAL_TAG" "$SOURCE_DIR"
    write_image_env "$LOCAL_TAG"
    docker compose up -d --remove-orphans
    wait_healthy
    echo "API is up (${LOCAL_TAG})."
    ;;

  pull)
    require_env_file
    if [ -z "$arg" ]; then
      echo "Usage: $0 pull ghcr.io/owner/repo/api:tag" >&2
      exit 1
    fi
    docker pull "$arg"
    write_image_env "$arg"
    docker compose up -d --remove-orphans
    wait_healthy
    echo "API is up (${arg})."
    ;;

  status)
    docker compose ps
    curl -fsS "$HEALTH_URL" && echo || echo "health: FAILED"
    ;;

  logs)
    docker compose logs -f api
    ;;

  restart)
    docker compose restart api
    wait_healthy
    ;;

  *)
    echo "Usage: $0 {build|pull IMAGE|status|logs|restart}" >&2
    exit 1
    ;;
esac
