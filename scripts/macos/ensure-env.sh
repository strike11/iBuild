#!/usr/bin/env bash
# Create local env files from templates if missing (no overwrite).
set -euo pipefail
# shellcheck source=./_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

copy_if_missing() {
  local src="$1"
  local dst="$2"
  if [[ -f "$dst" ]]; then
    echo "  ok  $dst"
    return 0
  fi
  [[ -f "$src" ]] || die "missing template: $src"
  cp "$src" "$dst"
  echo "  created $dst"
}

echo "Ensuring env files..."
copy_if_missing "$SERVER_DIR/.env.example" "$SERVER_DIR/.env"
copy_if_missing "$B2C_DIR/dart_defines.dev.json.example" "$B2C_DIR/dart_defines.dev.json"
copy_if_missing "$B2B_DIR/dart_defines.dev.json.example" "$B2B_DIR/dart_defines.dev.json"

# Force demo-safe keys in .env if absent (do not clobber explicit values).
ensure_env_key() {
  local key="$1"
  local value="$2"
  local file="$SERVER_DIR/.env"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    return 0
  fi
  printf '\n%s=%s\n' "$key" "$value" >>"$file"
  echo "  appended $key=$value"
}

ensure_env_key "LIVE_DEMO_TICKER" "false"
ensure_env_key "DEMO_STAGE_TRUST" "true"
ensure_env_key "APP_ENV" "development"
ensure_env_key "BOOTSTRAP_ADMIN_SECRET" "ibuild-local-demo-secret"

echo "Done."
