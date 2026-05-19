#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ "$#" -ne 1 ]; then
  echo "Usage: ./upgrade.sh VERSION" >&2
  exit 1
fi

VERSION="$1"

if [ ! -f .env ]; then
  echo ".env not found. Run ./install.sh first." >&2
  exit 1
fi

CURRENT_VERSION="$(grep '^VOICECORE_VERSION=' .env | tail -n1 | cut -d= -f2- || true)"
sed -i.bak "s|^VOICECORE_VERSION=.*|VOICECORE_VERSION=${VERSION}|" .env
rm -f .env.bak

echo "Upgrading VoiceCore from ${CURRENT_VERSION:-unknown} to ${VERSION}"
docker compose pull
docker compose up -d
./scripts/wait-health.sh || true
./scripts/print-status.sh

echo "Rollback command: ./upgrade.sh ${CURRENT_VERSION:-previous-version}"
