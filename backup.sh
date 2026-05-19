#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

BACKUP_DIR="${1:-backups/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$BACKUP_DIR"

docker compose exec -T db pg_dump -U "${POSTGRES_USER:-parlonacore}" "${POSTGRES_DB:-parlonacore}" > "${BACKUP_DIR}/postgres.sql"
docker run --rm -v voicecore_audio_storage:/data -v "$(pwd)/${BACKUP_DIR}:/backup" alpine tar czf /backup/audio_storage.tar.gz -C /data .
cp .env "${BACKUP_DIR}/env.backup"

echo "Backup written to ${BACKUP_DIR}"
