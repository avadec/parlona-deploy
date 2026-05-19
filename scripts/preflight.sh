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

check_disk_space() {
  local min_gb="${MIN_DOCKER_FREE_GB:-15}"
  local docker_root
  local docker_mount
  local available_kb
  local available_gb

  docker_root="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)"
  if [ -z "$docker_root" ]; then
    return 0
  fi

  docker_mount="$docker_root"
  while [ ! -e "$docker_mount" ] && [ "$docker_mount" != "/" ]; do
    docker_mount="$(dirname "$docker_mount")"
  done

  available_kb="$(df -Pk "$docker_mount" | awk 'NR==2 {print $4}')"
  available_gb="$((available_kb / 1024 / 1024))"

  if [ "$available_gb" -lt "$min_gb" ]; then
    cat >&2 <<EOF
Docker does not have enough free disk space.

Docker root: ${docker_root}
Available:   ${available_gb} GB
Required:    ${min_gb} GB minimum

Free space before installing VoiceCore. Common cleanup commands:
  docker system df
  docker system prune
  docker image prune -a
  docker volume prune

Be careful: prune commands remove unused Docker data. Do not remove volumes
that contain data you still need.

You can override the threshold with:
  MIN_DOCKER_FREE_GB=25 ./install.sh
EOF
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

check_disk_space

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
