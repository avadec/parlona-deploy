#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-default}"

# Defaults
ENV_FILE=".env"
COMPOSE_FILES="-f docker-compose.yml"

echo "[deploy_parlonacore] Profile: $PROFILE"
echo "[deploy_parlonacore] Env file: $ENV_FILE"
echo "[deploy_parlonacore] Compose files: $COMPOSE_FILES"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[deploy_parlonacore] ERROR: Env file '$ENV_FILE' not found."
  exit 1
fi

# -------------------------------------------------------------------
# Generate or reuse API key
# -------------------------------------------------------------------
if grep -q '^CALL_API_KEY=' "$ENV_FILE"; then
  API_KEY=$(grep '^CALL_API_KEY=' "$ENV_FILE" | tail -n1 | cut -d'=' -f2-)
  echo "[deploy_parlonacore] Reusing existing CALL_API_KEY from $ENV_FILE"
else
  # 64 hex chars = 32 bytes of randomness
  API_KEY=$(openssl rand -hex 32)
  # Ensure we're adding to a new line
  if [[ $(tail -c 1 "$ENV_FILE" | wc -l) -eq 0 ]]; then
    echo "" >> "$ENV_FILE"
  fi
  echo "CALL_API_KEY=$API_KEY" >> "$ENV_FILE"
  echo "[deploy_parlonacore] Generated new CALL_API_KEY and appended to $ENV_FILE"
fi

echo
echo "[deploy_parlonacore] === API key for Asterisk / clients ==="
echo
echo "  $API_KEY"
echo
echo "  Use it as:  X-API-Key: $API_KEY"
echo

# -------------------------------------------------------------------
# (Optional) Example: store API key in DB via a migration/command
# You will need to adapt this to your actual DB container / schema.
# -------------------------------------------------------------------
# docker compose $COMPOSE_FILES --env-file "$ENV_FILE" exec -T db \
#   psql -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\" \
#   -c \"INSERT INTO api_keys (key, description, created_at)
#       VALUES ('$API_KEY', 'install default key', NOW())
#       ON CONFLICT DO NOTHING;\"

docker compose $COMPOSE_FILES --env-file "$ENV_FILE" pull
docker compose $COMPOSE_FILES --env-file "$ENV_FILE" up -d

echo "[deploy_parlonacore] Deployment completed."