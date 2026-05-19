#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

BACKUP_DIR="${1:-}"
if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
  echo "Usage: ./restore.sh BACKUP_DIR" >&2
  exit 1
fi

if [ -f "${BACKUP_DIR}/env.backup" ] && [ ! -f .env ]; then
  cp "${BACKUP_DIR}/env.backup" .env
fi

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

docker compose up -d db
docker compose exec -T db psql -U "${POSTGRES_USER:-parlonacore}" -d "${POSTGRES_DB:-parlonacore}" < "${BACKUP_DIR}/postgres.sql"

if [ -f "${BACKUP_DIR}/audio_storage.tar.gz" ]; then
  docker run --rm -v voicecore_audio_storage:/data -v "$(pwd)/${BACKUP_DIR}:/backup" alpine sh -c "cd /data && tar xzf /backup/audio_storage.tar.gz"
fi

docker compose up -d
echo "Restore completed from ${BACKUP_DIR}"
