# Troubleshooting

Run:

```bash
./validate.sh
docker compose ps
docker compose logs -f
```

## API Not Reachable

Check:

```bash
docker compose logs call_analytics_api
curl -v http://localhost:8080/health
```

## Frontend Not Reachable

Check:

```bash
docker compose logs frontend
curl -v http://localhost:3000/login
```

## Authentication Fails

For simple auth, verify `AUTH_USERS` and `AUTH_JWT_SECRET` in `.env`.

For API calls, pass:

```bash
X-API-Key: YOUR_CALL_API_KEY
```

## Database Problems

Check:

```bash
docker compose logs db
docker compose logs call_analytics_api | grep -i migrat
```

## STT Model Download Problems

Set online model download mode:

```bash
WHISPER_LOCAL_ONLY=0
HF_HUB_OFFLINE=0
```

Then restart:

```bash
docker compose up -d stt_service
```
