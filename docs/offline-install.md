# Offline Install

On an internet-connected machine:

```bash
docker compose pull
docker save \
  parlona/voicecore-api:${VOICECORE_VERSION} \
  parlona/voicecore-stt:${VOICECORE_VERSION} \
  parlona/voicecore-summary:${VOICECORE_VERSION} \
  parlona/voicecore-postprocess:${VOICECORE_VERSION} \
  parlona/voicecore-frontend:${VOICECORE_VERSION} \
  redis:7-alpine \
  postgres:16 \
  -o voicecore-images-${VOICECORE_VERSION}.tar
```

Copy this deployment folder and the image tar to the target machine.

On the offline machine:

```bash
docker load -i voicecore-images-1.3.0.tar
./install.sh --skip-pull
```

If using Whisper offline mode, pre-populate the `whisper_cache` volume or run one warmup on an internet-connected host first.
