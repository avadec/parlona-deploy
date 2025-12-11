# ParlonaCore Call Analytics Framework

ParlonaCore is an open-source framework for processing and analyzing voice conversations. It provides a complete pipeline for speech-to-text transcription, conversation summarization, and structured data storage.

## Features

- **Speech-to-Text Transcription**: Powered by Faster-Whisper for accurate transcription with optional speaker diarization
- **Conversation Summarization**: Automatic generation of concise summaries using LLMs
- **Secure Architecture**: Redis with password authentication and protected mode
- **Flexible Deployment**: Pre-built Docker images for easy deployment
- **Multi-Backend LLM Support**: Compatible with OpenAI, vLLM, Groq, and Ollama
- **Database Storage**: PostgreSQL integration for persistent data storage
- **API Key Authentication**: Secure access to protected endpoints with generated API keys

## Quick Start

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` to set your desired configuration, including strong passwords:
   ```bash
   # Change to a strong password
   REDIS_PASSWORD=your_strong_password_here
   
   # Database credentials
   POSTGRES_USER=your_db_user
   POSTGRES_PASSWORD=your_db_password
   POSTGRES_DB=your_db_name
   ```

3. Run the deployment script to generate an API key and start services:
   ```bash
   ./deploy_parlonacore.sh
   ```

4. The deployment script will display your API key. Use this key to authenticate API requests.

## Architecture

The system consists of four main services orchestrated by Docker Compose:

1. **API Service** (`call_analytics_api`): REST API for job submission and result retrieval
2. **STT Service** (`stt_service`): Speech-to-text processing with automatic GPU/CPU detection
3. **Summary Service** (`summary_service`): Conversation summarization using external LLMs
4. **Postprocess Service** (`postprocess_service`): Data persistence to PostgreSQL

Services communicate through Redis queues for asynchronous processing.

## Security Notice

Starting with version 1.0.0, ParlonaCore implements enhanced security measures:

1. **Redis Authentication**: Redis now requires password authentication
2. **Network Isolation**: Services communicate through isolated Docker networks
3. **Protected Mode**: Redis runs in protected mode to prevent unauthorized access
4. **API Key Authentication**: All protected endpoints require a valid API key

**Important**: Always change the default `REDIS_PASSWORD` in your `.env` file to a strong, unique password before deploying.

## API Authentication

After running the deployment script, an API key is automatically generated and added to your `.env` file. This key is required for all protected endpoints:

```bash
# Example API key (automatically generated)
CALL_API_KEY=71c9ea972b799c0b9029cd1fc4cb62d51db11ed1b2ff268de1fa259221d49497
```

To authenticate API requests, include the API key in the `X-API-Key` header:

```bash
curl -H "X-API-Key: YOUR_API_KEY_HERE" http://localhost:8080/v1/calls
```

Example with a file upload:
```bash
curl -H "X-API-Key: YOUR_API_KEY_HERE" \
     -F "file=@audio.wav" \
     http://localhost:8080/v1/jobs/upload
```

Public endpoints (like `/health`) do not require authentication.

## Configuration

The framework is configured through environment variables in the `.env` file:

### Core Settings
- `PARLONACORE_VERSION`: Version of the ParlonaCore images to use
- `REDIS_PASSWORD`: Password for Redis authentication
- `STORAGE_DIR`: Directory for temporary file storage
- `CALL_API_KEY`: Automatically generated API key for endpoint authentication

### Database Settings
- `POSTGRES_USER`: PostgreSQL username
- `POSTGRES_PASSWORD`: PostgreSQL password
- `POSTGRES_DB`: PostgreSQL database name

### STT Settings
- `STT_DIARIZATION_MODE`: Diarization mode (`stereo_channels` or `mono`)
- `STT_STEREO_SPEAKER_MAPPING`: Speaker mapping for stereo diarization
- `WHISPER_MODEL_DIR`: Directory for Whisper model caching
- `WHISPER_LOCAL_ONLY`: Set to "1" for offline operation

### GPU Acceleration for STT
For GPU acceleration of the speech-to-text service:
1. Ensure you have the NVIDIA Container Toolkit installed
2. Set `STT_ENABLE_GPU=1` in your `.env` file:
   ```bash
   # Enable GPU acceleration for STT service
   STT_ENABLE_GPU=1
   ```
3. The STT service will automatically detect GPU availability and configure appropriate models

### LLM Settings
- `LLM_BACKEND`: Backend provider (`openai`, `vllm`, `groq`, `ollama`)
- `LLM_API_KEY`: API key for cloud providers
- `LLM_BASE_URL`: Base URL for self-hosted LLMs
- `LLM_MODEL`: Model name to use for summarization

## API Endpoints

- `POST /v1/jobs/upload`: Submit an audio file for processing (requires API key)
- `GET /v1/jobs`: List all processing jobs (requires API key)
- `GET /v1/jobs/{job_id}`: Get details for a specific job (requires API key)
- `GET /v1/calls`: List processed calls (requires API key)
- `GET /v1/calls/{call_id}`: Get details for a specific call (requires API key)
- `GET /health`: Health check endpoint (public)
- `GET /v1/health`: Health check endpoint (public)

## Development

For development, use the dev compose file:
```bash
docker compose -f docker-compose.dev.yml up --build
```

For GPU-accelerated development, set `STT_ENABLE_GPU=1` in your `.env` file:
```bash
# Enable GPU acceleration
STT_ENABLE_GPU=1
docker compose -f docker-compose.dev.yml up --build
```

## License

APACHE 2.0