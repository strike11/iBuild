#!/usr/bin/env bash
# Confirms the OpenAI construction-verify pipeline is actually wired end to
# end — not just that the API process answers /v1/health.
#
# Why this exists: on 2026-09-12 the A→B site-photo verify pipeline silently
# never called OpenAI for weeks after a deploy. Two independent switches were
# both off on the server (missing OPENAI_API_KEY/AI_VISION_ENABLED, and the
# construction-verify prompt file not mounted into the container — the
# runtime image only ships the committed PROMPT_NOT_SHIPPED placeholder,
# see Dockerfile). Every cycle just quietly landed on `needs_review` with a
# `vision_disabled`/`prompt_not_shipped` flag. `vendor_ai_calls` stayed at
# zero rows the entire time and /v1/health kept returning 200, so nothing
# ever paged anyone.
#
# This script hits the diagnostic route added for exactly this
# (`GET /v1/platform/ai/status`, server/lib/src/ai/ai_routes.dart) and makes
# the breakage loud instead of silent. It is advisory-only: unlike
# healthcheck-docker.sh, it NEVER restarts the container — a restart cannot
# fix a missing secret or an unmounted file, so retrying would just hide the
# same alert behind a "recovered" line.
#
# Auth: on staging, demo login is enabled, so this logs in as the
# `b2b_platform` demo profile (systemAdmin role) to get a token for free.
# In production, demo login is off — set AI_STATUS_TOKEN to a real
# system-admin bearer token instead (e.g. from a service account) and this
# script will use it unmodified.
set -uo pipefail

BASE_URL="${AI_STATUS_BASE_URL:-http://127.0.0.1:4000/v1}"

login_with_demo() {
  curl -sf -m 10 -X POST "$BASE_URL/auth/demo" \
    -H 'Content-Type: application/json' \
    -d '{"profile":"b2b_platform"}' \
    2>/dev/null \
  | grep -o '"accessToken":"[^"]*"' | head -1 | cut -d'"' -f4
}

TOKEN="${AI_STATUS_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  TOKEN="$(login_with_demo)"
fi

if [ -z "$TOKEN" ]; then
  echo "$(date -Is) [ai-healthcheck] WARN: no system-admin token available (demo login disabled/API down) — set AI_STATUS_TOKEN to check in production; skipping" >&2
  exit 0
fi

STATUS_JSON="$(curl -sf -m 10 "$BASE_URL/platform/ai/status" -H "Authorization: Bearer $TOKEN" 2>/dev/null)"
if [ -z "$STATUS_JSON" ]; then
  echo "$(date -Is) [ai-healthcheck] WARN: GET /v1/platform/ai/status did not respond — cannot confirm AI wiring" >&2
  exit 0
fi

READY=$(echo "$STATUS_JSON" | grep -o '"constructionVerifyReady":[a-z]*' | cut -d':' -f2)

if [ "$READY" != "true" ]; then
  echo "$(date -Is) [ai-healthcheck] ALERT: construction-verify AI is NOT fully wired up: $STATUS_JSON" >&2
  exit 1
fi

echo "$(date -Is) [ai-healthcheck] OK: $STATUS_JSON"
exit 0
