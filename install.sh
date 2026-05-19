#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --version VERSION       VoiceCore image tag to deploy
  --hostname HOST         Public hostname or IP for generated URLs
  --with-gpu             Enable NVIDIA GPU overlay for STT
  --with-keycloak        Start bundled development Keycloak
  --skip-pull            Do not run docker compose pull
  -h, --help             Show this help
EOF
}

VERSION=""
HOSTNAME_VALUE=""
WITH_GPU=0
WITH_KEYCLOAK=0
SKIP_PULL=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="${2:?Missing value for --version}"
      shift 2
      ;;
    --hostname)
      HOSTNAME_VALUE="${2:?Missing value for --hostname}"
      shift 2
      ;;
    --with-gpu)
      WITH_GPU=1
      shift
      ;;
    --with-keycloak)
      WITH_KEYCLOAK=1
      shift
      ;;
    --skip-pull)
      SKIP_PULL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example"
fi

./scripts/generate-secrets.sh .env

if [ -n "$VERSION" ]; then
  sed -i.bak "s|^VOICECORE_VERSION=.*|VOICECORE_VERSION=${VERSION}|" .env
  rm -f .env.bak
fi

if [ -n "$HOSTNAME_VALUE" ]; then
  sed -i.bak "s|^PUBLIC_FRONTEND_URL=.*|PUBLIC_FRONTEND_URL=http://${HOSTNAME_VALUE}:3000|" .env
  sed -i.bak "s|^PUBLIC_API_URL=.*|PUBLIC_API_URL=http://${HOSTNAME_VALUE}:8080|" .env
  sed -i.bak "s|^NEXT_PUBLIC_API_URL=.*|NEXT_PUBLIC_API_URL=http://${HOSTNAME_VALUE}:8080|" .env
  rm -f .env.bak
fi

if [ "$WITH_KEYCLOAK" -eq 1 ]; then
  sed -i.bak "s|^KEYCLOAK_ENABLED=.*|KEYCLOAK_ENABLED=1|" .env
  rm -f .env.bak
fi

set -a
. ./.env
set +a

COMPOSE_FILES=(-f docker-compose.yml)
if [ "$WITH_GPU" -eq 1 ]; then
  COMPOSE_FILES+=(-f docker-compose.gpu.yml)
fi
if [ "$WITH_KEYCLOAK" -eq 1 ]; then
  COMPOSE_FILES+=(-f docker-compose.keycloak.yml)
fi

./scripts/preflight.sh

if [ "$SKIP_PULL" -eq 0 ]; then
  docker compose "${COMPOSE_FILES[@]}" pull
fi

docker compose "${COMPOSE_FILES[@]}" up -d

API_PORT="${API_PORT:-8080}" FRONTEND_PORT="${FRONTEND_PORT:-3000}" ./scripts/wait-health.sh || true
./scripts/print-status.sh
