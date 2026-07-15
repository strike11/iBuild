#!/usr/bin/env bash
# Shared helpers for scripts/macos/*.sh
set -euo pipefail

_MACOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$_MACOS_DIR/../.." && pwd)"
SERVER_DIR="$ROOT/server"
B2C_DIR="$ROOT/b2c"
B2B_DIR="$ROOT/b2b"

export ROOT SERVER_DIR B2C_DIR B2B_DIR

die() { echo "error: $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

port_pids() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null || true
}

kill_port() {
  local port="$1"
  local label="${2:-port $port}"
  local pids
  pids="$(port_pids "$port")"
  if [[ -z "$pids" ]]; then
    echo "  $label ($port): not running"
    return 0
  fi
  # shellcheck disable=SC2086
  kill $pids 2>/dev/null || true
  sleep 0.5
  pids="$(port_pids "$port")"
  if [[ -n "$pids" ]]; then
    # shellcheck disable=SC2086
    kill -9 $pids 2>/dev/null || true
  fi
  echo "  stopped $label ($port)"
}

open_tab() {
  # Opens a new Terminal.app tab (macOS) running the given command.
  # Falls back to background nohup on Linux.
  local title="$1"
  local cmd="$2"
  if [[ "$(uname -s)" == "Darwin" ]] && command -v osascript >/dev/null 2>&1; then
    osascript <<EOF
tell application "Terminal"
  activate
  do script "printf '\\\\e]0;${title}\\\\a'; cd '${ROOT}'; ${cmd}"
end tell
EOF
  else
    echo "Starting in background: $title"
    nohup bash -lc "cd '$ROOT'; $cmd" >/tmp/ibuild-"${title// /-}"'.log" 2>&1 &
    echo "  log: /tmp/ibuild-${title// /-}.log"
  fi
}
