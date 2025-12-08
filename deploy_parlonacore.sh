#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-default}"

# Defaults
ENV_FILE=".env"
COMPOSE_FILES="-f docker-compose.yml"

if [[ "$PROFILE" == "vllm" ]]; then
  ENV_FILE=".env.vllm"
  COMPOSE_FILES="-f docker-compose.yml -f docker-compose.vllm.yml"
fi

echo "[deploy_parlonacore] Profile: $PROFILE"
echo "[deploy_parlonacore] Env file: $ENV_FILE"
echo "[deploy_parlonacore] Compose files: $COMPOSE_FILES"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[deploy_parlonacore] ERROR: Env file '$ENV_FILE' not found."
  exit 1
fi

docker compose $COMPOSE_FILES --env-file "$ENV_FILE" pull
docker compose $COMPOSE_FILES --env-file "$ENV_FILE" up -d

echo "[deploy_parlonacore] Deployment completed."