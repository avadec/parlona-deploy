# ParlonaCore

This repository contains ParlonaCore – an open-source voice intelligence stack built to analyze call audio, transcribe with Whisper, diarize agent/customer, and store structured dialogues in Postgres. It's self-hosted via Docker.

## Overview

Services included in this step:

1. **call_analytics_api** – FastAPI service exposing HTTP endpoints to create jobs, list jobs, and fetch job status.
2. **stt_service** – Real faster-whisper speech-to-text worker (supports stereo-channel diarisation) that writes transcripts into Redis and forwards jobs to the summary queue.
3. **summary_service** – Worker that simulates summarization and tagging, forwarding jobs to post-processing.
4. **postprocess_service** – Worker that simulates delivering final analytics to an external system.
5. **Redis** – Serves as both temporary storage for job metadata and a message broker via Redis lists.

Each worker logs its activity and updates job status. STT results are persisted in the Redis job hash (`stt_text`, `stt_segments`, `stt_language`, metadata, etc.) for downstream services to consume.

## Running the stack

### For end-users / customers (prebuilt images):

```bash
cp .env.example .env
docker compose pull
docker compose up -d
```

This command will start Redis and all service containers. The API becomes available at `http://localhost:8080`.

### For developers (build from source):

```bash
cp .env.example .env
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

## Example usage

Create a new job:

```bash
curl -X POST http://localhost:8080/v1/jobs \
  -H "Content-Type: application/json" \
  -d '{"audio_path": "/tmp/call1.wav"}'
```

Upload a local file via multipart (metadata optional):

```bash
curl -X POST http://localhost:8080/v1/jobs/upload \
  -F "file=@/path/to/dialogue.wav" \
  -F 'metadata={"agent_id":"6001"};type=application/json'
```

Sample response:

```json
{
  "job_id": "<uuid>",
  "status": "queued",
  "audio_path": "/tmp/call1.wav"
}
```

Fetch job status:

```bash
curl http://localhost:8080/v1/jobs/<job_id>
```

List recent jobs:

```bash
curl http://localhost:8080/v1/jobs
```

Observe worker logs in the Docker Compose output to verify the pipeline flow:
- STT worker consumes `queue:stt_jobs`, performs real faster-whisper transcription, and writes transcripts/segments/metadata to the job hash.
- Summary worker consumes `queue:summary_jobs` and writes dummy summaries/tags.
- Postprocess worker consumes `queue:postprocess_jobs` and marks jobs as `done`.

## STT configuration & diarisation

Environment variables (set in `.env` or Compose service) control STT behavior:

| Variable | Default | Description |
| --- | --- | --- |
| `STT_ENGINE` | `faster_whisper` | STT backend identifier. |
| `STT_MODEL_NAME` | `small` | faster-whisper model to load (e.g. `base`, `medium`...). |
| `STT_DEVICE` | `auto` | `cuda`, `cpu`, or `auto` (auto uses CUDA if available). |
| `STT_COMPUTE_TYPE` | `float16` | faster-whisper compute type (`float16`, `int8`, etc.). |
| `STT_DIARIZATION_MODE` | `none` | `none` for standard transcription, `stereo_channels` to split L/R channels. |
| `STT_STEREO_SPEAKER_MAPPING` | `0:speaker_1,1:speaker_2` | Mapping of channel index to label (e.g. `0:agent,1:customer`). |
| `STT_LANGUAGE`, `STT_TASK`, `STT_BEAM_SIZE`, etc. | (see `backend/stt_service/app/config.py`) | Advanced faster-whisper knobs. |

In stereo diarisation mode the worker splits each channel into a mono file, transcribes them independently, labels segments with the configured speaker names, and merges them on the shared timeline. Segment data is stored as JSON in `stt_segments`.

When you upload a file, it is stored under `/app/storage/<job_id>/` inside the containers, and the STT worker uses that shared volume automatically. For remote URLs submitted via JSON, ensure the path is reachable from within the containers.

### Mapping host audio paths inside containers

Containers cannot access host paths directly. Either:
1. Mount the directory containing your audio into the `stt_service` container, e.g.:

```yaml
  stt_service:
    volumes:
      - /Users/you/Audio:/data/audio
```

2. And/or configure `STT_AUDIO_PATH_MAPPINGS` so host-style paths get rewritten inside the worker. Example:

```env
STT_AUDIO_PATH_MAPPINGS=/Users/you/Audio=/data/audio
```

Multiple mappings can be separated with semicolons, or defined as JSON `[["/host/path","/container/path"], ...]`. The worker tries each mapping and falls back to the original path. Jobs will fail with a helpful error if none of the mapped paths exist.

## Next steps

Future iterations will replace dummy logic with real STT/LLM models, introduce persistent storage (Postgres), and add a UI dashboard.

## Deploying ParlonaCore on a GPU Host with vLLM

This setup is intended for environments where:

- You have **one or more NVIDIA GPUs**.
- You run **vLLM** as an OpenAI-compatible API (either inside the same Docker stack or on a separate machine).
- You want **Faster-Whisper STT** to use GPU as well.

### 1. Prerequisites

1. **NVIDIA drivers** installed on the host.
2. **NVIDIA Container Toolkit** installed so Docker containers can access the GPUs.  
   See NVIDIA’s docs for installation instructions.
3. `docker` and `docker compose` installed.

### 2. Files involved

In the project root you should have:

- `docker-compose.yml` – base stack (4 core services).
- `docker-compose.vllm.yml` – GPU/vLLM overlay (added vLLM service + GPU for STT).
- `.env.vllm.example` – example configuration for GPU + vLLM host.
- `deploy_parlonacore.sh` – deployment helper script.

### 3. Create and edit `.env.vllm`

Copy the example and edit it:

```bash
cp .env.vllm.example .env.vllm