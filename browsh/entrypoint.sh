#!/usr/bin/env bash
set -euo pipefail

BROWSH_PORT="${BROWSH_PORT:-8080}"
BROWSH_WINDOW_SIZE="${BROWSH_WINDOW_SIZE:-1366,768}"

FF_PROFILE="/home/app/.mozilla/firefox/profile.default"
mkdir -p "$FF_PROFILE"

# Browsh runs Firefox in headless mode internally
# Keep args minimal for compatibility; adjust in compose env if needed
exec browsh \
  --http-server=true \
  --http-server-bind-address=0.0.0.0 \
  --http-server-port="${BROWSH_PORT}" \
  --startup-url="about:blank" \
  --firefox.window-size="${BROWSH_WINDOW_SIZE}" \
  --firefox.profile="${FF_PROFILE}"