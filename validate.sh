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

container_count="$(docker compose ps -a -q | wc -l | tr -d ' ')"
if [ "${container_count:-0}" -eq 0 ]; then
  echo
  echo "No VoiceCore containers exist for this compose project."
  echo "This means ./install.sh did not reach or complete 'docker compose up -d' for this directory."
  echo
  echo "Run:"
  echo "  ./install.sh"
  echo
  echo "If install fails, capture the full install output. You can also run:"
  echo "  docker compose config --services"
  echo "  docker compose up -d"
  echo "  docker compose ps -a"
  echo "  docker compose logs --tail=120"
  exit 1
fi

running_count="$(docker compose ps -q | wc -l | tr -d ' ')"
if [ "${running_count:-0}" -eq 0 ]; then
  echo
  echo "VoiceCore containers exist, but none are running."
  echo "Inspect failures with:"
  echo "  docker compose ps -a"
  echo "  docker compose logs --tail=120"
  exit 1
fi

if ! curl -fsS "http://localhost:${API_PORT:-8080}/health" >/dev/null; then
  echo
  echo "API health check failed at http://localhost:${API_PORT:-8080}/health"
  echo "Container state:"
  docker compose ps -a
  echo
  echo "Recent API logs:"
  docker compose logs --tail=120 call_analytics_api || true
  exit 1
fi

if ! curl -fsS "http://localhost:${FRONTEND_PORT:-3000}/login" >/dev/null; then
  echo
  echo "Frontend health check failed at http://localhost:${FRONTEND_PORT:-3000}/login"
  echo "Container state:"
  docker compose ps -a
  echo
  echo "Recent frontend logs:"
  docker compose logs --tail=120 frontend || true
  exit 1
fi

echo "Validation passed."
