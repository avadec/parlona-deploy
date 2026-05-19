# Configuration

VoiceCore uses `.env` for customer-specific settings. Run `./install.sh` to create it from `.env.example` and generate secrets.

## Required Settings

- `VOICECORE_VERSION` - release tag for all VoiceCore images.
- `CALL_API_KEY` - API key required for protected backend endpoints.
- `REDIS_PASSWORD` - Redis password.
- `POSTGRES_PASSWORD` - PostgreSQL password.
- `AUTH_JWT_SECRET` - dashboard session signing secret when simple auth is enabled.
- `AUTH_USERS` - comma-separated `username:password` pairs when `KEYCLOAK_ENABLED=0`.

## Public URLs

Set these to URLs reachable by users and integrations:

```bash
PUBLIC_FRONTEND_URL=https://voicecore.example.com
PUBLIC_API_URL=https://voicecore-api.example.com
NEXT_PUBLIC_API_URL=https://voicecore-api.example.com
```

For a local or direct-IP install:

```bash
PUBLIC_FRONTEND_URL=http://SERVER_IP:3000
PUBLIC_API_URL=http://SERVER_IP:8080
NEXT_PUBLIC_API_URL=http://SERVER_IP:8080
```

## LLM Backend

Default:

```bash
LLM_BACKEND=openai
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o-mini
```

OpenAI-compatible self-hosted options can use `VLLM_BASE_URL` or `OLLAMA_BASE_URL`.

## STT

CPU default:

```bash
STT_ENABLE_GPU=0
FORCE_CPU=1
STT_MODEL_NAME=Systran/faster-whisper-small
```

GPU mode:

```bash
./install.sh --with-gpu
```
