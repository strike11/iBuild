#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=./_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

need_cmd flutter
"$ROOT/scripts/macos/ensure-env.sh"
cd "$B2B_DIR"
DEFINES="$B2B_DIR/dart_defines.dev.json"
echo "Starting B2B on :8100..."
exec flutter run -d chrome --web-port=8100 --dart-define-from-file="$DEFINES"
