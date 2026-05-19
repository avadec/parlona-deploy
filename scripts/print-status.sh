#!/usr/bin/env bash
set -euo pipefail

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

echo
echo "VoiceCore status"
echo "----------------"
docker compose ps -a
echo
echo "Frontend: ${PUBLIC_FRONTEND_URL:-http://localhost:${FRONTEND_PORT:-3000}}"
echo "API:      ${PUBLIC_API_URL:-http://localhost:${API_PORT:-8080}}"
echo
if [ "${KEYCLOAK_ENABLED:-0}" = "0" ]; then
  echo "Dashboard auth: ${AUTH_USERS:-admin:change-me}"
else
  echo "Dashboard auth: Keycloak SSO"
fi
echo "API key header: X-API-Key: ${CALL_API_KEY:-not-set}"
echo
