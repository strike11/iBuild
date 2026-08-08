#!/usr/bin/env bash
# Copy bundled residence photos to the host path mounted into the API container.
# Usage (on VDS): bash /opt/ibuild/deploy/sync-residences-images.sh
set -euo pipefail

SRC="${1:-/opt/ibuild/source/server/residences-images}"
DEST="${2:-/opt/ibuild/server/residences-images}"

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: source directory missing: $SRC" >&2
  exit 1
fi

sudo mkdir -p "$DEST"
sudo rsync -a --delete "$SRC/" "$DEST/"
sudo chown -R 10001:10001 "$DEST"
echo "Synced $(find "$DEST" -type f | wc -l) files to $DEST"
ls -la "$DEST"
