#!/usr/bin/env bash
set -euo pipefail

print_docker_install_help() {
  cat >&2 <<'EOF'
Docker was not found on this machine.

Install Docker before running VoiceCore:

Ubuntu/Debian:
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  newgrp docker
  docker --version
  docker compose version

RHEL/CentOS/Rocky:
  Follow Docker's official "Install Docker Engine" guide for your distro,
  then verify:
  docker --version
  docker compose version

macOS/Windows:
  Install Docker Desktop and start it before running ./install.sh.

If Docker is installed but this script cannot find it, make sure the docker
binary is on PATH for the current shell.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    if [ "$1" = "docker" ]; then
      print_docker_install_help
    else
      echo "Missing required command: $1" >&2
    fi
    exit 1
  fi
}

check_port() {
  local port="$1"
  if [ "${SKIP_PORT_CHECK:-0}" = "1" ]; then
    return 0
  fi

  if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Port $port is already in use." >&2
    exit 1
  fi

  if command -v ss >/dev/null 2>&1 && ss -ltn "( sport = :${port} )" | grep -q ":${port}"; then
    echo "Port $port is already in use." >&2
    exit 1
  fi

  if command -v netstat >/dev/null 2>&1 && netstat -ltn 2>/dev/null | grep -q "[.:]${port} "; then
    echo "Port $port is already in use." >&2
    exit 1
  fi
}

require_command docker
require_command openssl

docker compose version >/dev/null
if ! docker info >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Docker is installed, but the Docker daemon is not reachable.

Common fixes:
- Start Docker Desktop on macOS/Windows.
- Start Docker Engine on Linux: sudo systemctl start docker
- Add your user to the docker group, then open a new shell:
  sudo usermod -aG docker "$USER"
  newgrp docker
EOF
  exit 1
fi

if [ ! -f .env ]; then
  echo ".env not found. Run ./install.sh first." >&2
  exit 1
fi

set -a
. ./.env
set +a

: "${CALL_API_KEY:?CALL_API_KEY is required}"
: "${REDIS_PASSWORD:?REDIS_PASSWORD is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${AUTH_JWT_SECRET:?AUTH_JWT_SECRET is required}"

check_port "${API_PORT:-8080}"
check_port "${FRONTEND_PORT:-3000}"

echo "Preflight checks passed."
