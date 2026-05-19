#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

REMOVE_VOLUMES=0
if [ "${1:-}" = "--volumes" ]; then
  REMOVE_VOLUMES=1
fi

if [ "$REMOVE_VOLUMES" -eq 1 ]; then
  echo "This will remove containers and persistent volumes."
  printf "Type 'delete data' to continue: "
  read -r answer
  if [ "$answer" != "delete data" ]; then
    echo "Aborted."
    exit 1
  fi
  docker compose down -v
else
  docker compose down
fi

echo "VoiceCore stopped."
