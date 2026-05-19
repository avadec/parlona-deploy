#!/usr/bin/env bash
set -euo pipefail

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

check_port() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Port $port is already in use." >&2
    exit 1
  fi
}

require_command docker
require_command openssl

docker compose version >/dev/null
docker info >/dev/null

if [ ! -f .env ]; then
  echo ".env not found. Run ./install.sh first." >&2
  exit 1
fi

set -a
. ./.env
set +a

: "${CALL_API_KEY:?CALL_API_KEY is required}"
: "${REDIS_PASSWORD:?REDIS_PASSWORD is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${AUTH_JWT_SECRET:?AUTH_JWT_SECRET is required}"

check_port "${API_PORT:-8080}"
check_port "${FRONTEND_PORT:-3000}"

echo "Preflight checks passed."
