# iBuild — macOS / Linux scripts

Separate from the Windows PowerShell stack under `scripts/*.ps1`.

## Prerequisites

- Docker Desktop (for Postgres) **or** a local Postgres 13+ on `localhost:5432`
- [Dart SDK](https://dart.dev/get-dart) 3.9+
- [Flutter](https://flutter.dev) stable
- `curl`, `lsof`, `bash`

## Quick start (investor demo)

```bash
cd /path/to/ibuild
chmod +x scripts/macos/*.sh
./scripts/macos/launch-stack.sh
```

This will:

1. Ensure `server/.env` and Flutter `dart_defines.dev.json` exist  
2. Start Postgres via `server/docker-compose.yml`  
3. Start the API (Postgres-backed; demo ticker off; trust staging on)  
4. Start B2C (`:8099`) and B2B (`:8100`) against localhost  

Stop everything:

```bash
./scripts/macos/stop-stack.sh
```

## Individual commands

| Script | Purpose |
|--------|---------|
| `ensure-env.sh` | Copy `.env` / dart_defines examples if missing |
| `db-start.sh` / `db-stop.sh` | Docker Compose Postgres |
| `start-api.sh` | `dart run bin/server.dart` (foreground) |
| `start-b2c.sh` / `start-b2b.sh` | Flutter web clients |
| `launch-stack.sh` | Full stack in separate Terminal tabs/windows |
| `stop-stack.sh` | Kill ports 4000 / 8099 / 8100 + stop Postgres |
| `bootstrap-admin.sh` | Promote a phone to system_admin (once per DB) |
| `reseed-catalogue.sh` | Wipe projects + clear seed guard → next API start re-seeds |

## Demo-safe defaults (`server/.env`)

```env
LIVE_DEMO_TICKER=false   # no random shahmatka flips
DEMO_STAGE_TRUST=true    # Verified badge + Progress photos on showcase project
```

See also: [`DEMO.md`](../../DEMO.md), [`PRESENTATION_READINESS.md`](../../PRESENTATION_READINESS.md).
