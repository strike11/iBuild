#!/usr/bin/env bash
# Restart ibuild-api container if /v1/health stops responding.
# Used by ibuild-healthcheck-docker.timer (Docker deployments).

set -euo pipefail

HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:4000/v1/health}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/ibuild/deploy}"

if curl -sf --max-time 10 "$HEALTH_URL" >/dev/null; then
  exit 0
fi

echo "$(date -Is) health check FAILED — restarting Docker api" >&2
cd "$DEPLOY_DIR"
docker compose restart api
sleep 5

if curl -sf --max-time 10 "$HEALTH_URL" >/dev/null; then
  echo "$(date -Is) api container recovered" >&2
  exit 0
fi

echo "$(date -Is) api still unhealthy after restart" >&2
docker compose logs --tail=80 api >&2 || true
exit 1
