#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=./_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

need_cmd flutter
"$ROOT/scripts/macos/ensure-env.sh"
cd "$B2C_DIR"
DEFINES="$B2C_DIR/dart_defines.dev.json"
echo "Starting B2C on :8099..."
exec flutter run -d chrome --web-port=8099 --dart-define-from-file="$DEFINES"
