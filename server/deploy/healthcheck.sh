#!/usr/bin/env bash
# Optional watchdog: restart API if /v1/health stops responding.
# Install:
#   sudo cp healthcheck.sh /opt/ibuild/server/deploy/healthcheck.sh
#   sudo chmod +x /opt/ibuild/server/deploy/healthcheck.sh
#   sudo cp ibuild-healthcheck.service ibuild-healthcheck.timer /etc/systemd/system/
#   sudo systemctl daemon-reload
#   sudo systemctl enable --now ibuild-healthcheck.timer
#
# Or cron (every 2 min):
#   */2 * * * * /opt/ibuild/server/deploy/healthcheck.sh

set -euo pipefail

HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:4000/v1/health}"
SERVICE="${SERVICE:-ibuild-api}"

if curl -sf --max-time 10 "$HEALTH_URL" >/dev/null; then
  exit 0
fi

echo "$(date -Is) health check FAILED — restarting $SERVICE" >&2
systemctl restart "$SERVICE"
sleep 3
if curl -sf --max-time 10 "$HEALTH_URL" >/dev/null; then
  echo "$(date -Is) $SERVICE recovered" >&2
  exit 0
fi

echo "$(date -Is) $SERVICE still unhealthy after restart" >&2
exit 1
