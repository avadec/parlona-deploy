#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

set_env_value() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$ENV_FILE"; then
    local current
    current="$(grep "^${key}=" "$ENV_FILE" | tail -n1 | cut -d= -f2-)"
    if [ -z "$current" ] || [[ "$current" == CHANGE_ME* ]] || [[ "$current" == "change-me" ]]; then
      sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    fi
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

require_command openssl

if [ ! -f "$ENV_FILE" ]; then
  echo "Env file not found: $ENV_FILE" >&2
  exit 1
fi

set_env_value CALL_API_KEY "$(openssl rand -hex 32)"
set_env_value REDIS_PASSWORD "$(openssl rand -base64 32 | tr -d '\n')"
set_env_value POSTGRES_PASSWORD "$(openssl rand -base64 32 | tr -d '\n')"
set_env_value AUTH_JWT_SECRET "$(openssl rand -base64 48 | tr -d '\n')"

if grep -q '^AUTH_USERS=admin:change-me$' "$ENV_FILE"; then
  admin_password="$(openssl rand -base64 18 | tr -d '\n')"
  sed -i.bak "s|^AUTH_USERS=.*|AUTH_USERS=admin:${admin_password}|" "$ENV_FILE"
fi

rm -f "${ENV_FILE}.bak"
echo "Secrets generated in $ENV_FILE"
