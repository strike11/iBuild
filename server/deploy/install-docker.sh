#!/usr/bin/env bash
# Install Docker Engine + Compose v2 plugin on Ubuntu 22.04/24.04 (Debian-based).
# Idempotent — safe to re-run.
#
# Usage (as root or via sudo):
#   curl -fsSL .../install-docker.sh | sudo bash
#   sudo ./install-docker.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script targets Debian/Ubuntu (apt-get not found)." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Cloud images sometimes ship a stale cdrom apt entry that breaks apt update.
find /etc/apt -type f -exec sed -i '/cdrom/d' {} + 2>/dev/null || true

apt-get update
apt-get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
fi

. /etc/os-release
CODENAME="${VERSION_CODENAME:-jammy}"
ARCH="$(dpkg --print-architecture)"
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

systemctl enable --now docker

echo ""
docker --version
docker compose version
echo "Docker Engine installed."
