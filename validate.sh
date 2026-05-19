#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SKIP_PORT_CHECK=1 ./scripts/preflight.sh

set -a
. ./.env
set +a

docker compose config >/dev/null

echo "Container state:"
docker compose ps -a

running_count="$(docker compose ps --services --filter status=running | wc -l | tr -d ' ')"
if [ "${running_count:-0}" -eq 0 ]; then
  echo
  echo "No VoiceCore services are running for this compose project."
  echo "Run ./install.sh again, or inspect startup failures with:"
  echo "  docker compose ps -a"
  echo "  docker compose logs --tail=120"
  exit 1
fi

curl -fsS "http://localhost:${API_PORT:-8080}/health" >/dev/null
curl -fsS "http://localhost:${FRONTEND_PORT:-3000}/login" >/dev/null

echo "Validation passed."
