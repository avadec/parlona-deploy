# VoiceCore Deploy

Customer deployment bundle for VoiceCore Docker images.

This repository contains configuration, Docker Compose files, and operational scripts only. It does not build VoiceCore images and does not contain application source code.

## Quick Start

```bash
git clone https://github.com/parlona/voicecore-deploy.git
cd voicecore-deploy
./install.sh --version 1.3.0 --hostname YOUR_SERVER_IP
```

After installation, the script prints the dashboard URL, API URL, dashboard credentials, and API key.

## Requirements

- Linux server or VM
- Docker Engine
- Docker Compose v2
- `openssl`
- Internet access to Docker Hub and the selected LLM/STT model providers

Install Docker first if `./install.sh` reports that `docker` is missing.

Ubuntu/Debian:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
newgrp docker
docker --version
docker compose version
```

macOS/Windows: install Docker Desktop and start it before running `./install.sh`.

For private Docker Hub repositories, log in first:

```bash
docker login
```

## Main Files

- `docker-compose.yml` - standard single-machine deployment using prebuilt Docker images.
- `docker-compose.gpu.yml` - optional NVIDIA GPU overlay for STT.
- `docker-compose.keycloak.yml` - optional bundled development Keycloak.
- `.env.example` - customer configuration template.
- `install.sh` - first-time installer.
- `upgrade.sh` - version upgrade helper.
- `validate.sh` - support/health diagnostics.
- `backup.sh` and `restore.sh` - basic database and audio storage backup helpers.

## Common Commands

```bash
# Install with defaults
./install.sh

# Install a specific version
./install.sh --version 1.3.0

# Install with GPU STT support
./install.sh --with-gpu

# Upgrade
./upgrade.sh 1.4.0

# Validate
./validate.sh

# View logs
docker compose logs -f

# Stop
docker compose down
```

## Configuration

Edit `.env` after running `./install.sh` if needed. Important values:

- `VOICECORE_VERSION` - Docker image tag for all VoiceCore services.
- `PUBLIC_FRONTEND_URL` - dashboard URL users open in a browser.
- `PUBLIC_API_URL` / `NEXT_PUBLIC_API_URL` - API URL exposed to integrations/browser code.
- `AUTH_USERS` - simple dashboard users when `KEYCLOAK_ENABLED=0`.
- `CALL_API_KEY` - API key for machine-to-machine API access.
- `LLM_BACKEND` and provider-specific values - summary model configuration.

Prefer pinned image tags such as `1.3.0`; avoid production deployments based on `latest`.

## Services

- `call_analytics_api` - REST API on port `8080` by default.
- `stt_service` - speech-to-text worker.
- `summary_service` - LLM summarization worker.
- `postprocess_service` - database persistence worker.
- `frontend` - dashboard on port `3000` by default.
- `redis` and `db` - bundled Redis/PostgreSQL for single-machine deployments.

## Notes

The frontend image may bake some browser-facing `NEXT_PUBLIC_*` values at build time depending on the app version. For customer-specific public URLs or SSO settings, verify the released image supports runtime configuration before publishing it as a generic image.
