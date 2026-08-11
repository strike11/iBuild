#!/usr/bin/env bash
set -euo pipefail
docker run --rm --pid host --privileged -v /run:/run alpine:3.20 \
  sh -c 'kill -HUP "$(cat /run/nginx.pid)"'
