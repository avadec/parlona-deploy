#!/usr/bin/env bash
set -euo pipefail

API_PORT="${API_PORT:-8080}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-180}"

wait_url() {
  local name="$1"
  local url="$2"
  local start
  start="$(date +%s)"

  printf 'Waiting for %s at %s' "$name" "$url"
  while true; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      printf '\n%s is reachable.\n' "$name"
      return 0
    fi

    if [ $(( "$(date +%s)" - start )) -ge "$TIMEOUT_SECONDS" ]; then
      printf '\nTimed out waiting for %s.\n' "$name" >&2
      return 1
    fi

    printf '.'
    sleep 3
  done
}

wait_url "API" "http://localhost:${API_PORT}/health"
wait_url "frontend" "http://localhost:${FRONTEND_PORT}/login"
