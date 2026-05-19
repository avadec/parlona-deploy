# GPU STT

GPU mode requires:

- NVIDIA GPU
- Recent NVIDIA driver
- NVIDIA Container Toolkit installed on the Docker host

Install with:

```bash
./install.sh --with-gpu
```

Or start manually:

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
```

Useful `.env` values:

```bash
STT_ENABLE_GPU=1
FORCE_CPU=0
STT_MODEL_NAME=Systran/faster-whisper-medium
```
