# Upgrading

Use pinned image versions.

```bash
./upgrade.sh 1.4.0
```

The script updates `VOICECORE_VERSION`, pulls images, restarts services, and prints the previous version for rollback.

Rollback:

```bash
./upgrade.sh 1.3.0
```

Before major upgrades, create a backup:

```bash
./backup.sh
```
