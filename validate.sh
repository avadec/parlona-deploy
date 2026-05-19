#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

./scripts/preflight.sh

set -a
. ./.env
set +a

docker compose config >/dev/null
docker compose ps

curl -fsS "http://localhost:${API_PORT:-8080}/health" >/dev/null
curl -fsS "http://localhost:${FRONTEND_PORT:-3000}/login" >/dev/null

echo "Validation passed."
