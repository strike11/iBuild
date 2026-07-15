#!/usr/bin/env bash
# Run the iBuild API (foreground). Loads server/.env automatically.
set -euo pipefail
# shellcheck source=./_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

need_cmd dart
"$ROOT/scripts/macos/ensure-env.sh"
cd "$SERVER_DIR"
echo "Starting API on :4000 (cwd=$SERVER_DIR)..."
exec dart run bin/server.dart
