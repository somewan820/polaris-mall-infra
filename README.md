# Polaris Mall Infra

`polaris-mall-infra` provides the infrastructure baseline for local and shared environments.

## Implemented In This Step (I001)

- environment contract templates:
  - `env/.env.dev.example`
  - `env/.env.stage.example`
  - `env/.env.prod.example`
- local runtime topology:
  - `docker-compose.dev.yml`
  - `gateway/nginx.dev.conf`
- bootstrap scripts:
  - `scripts/bootstrap_dev.ps1`
  - `scripts/bootstrap_dev.sh`
- topology documentation:
  - `docs/topology.md`

## Local Bootstrap

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\bootstrap_dev.ps1"
```

After `.env` is generated, start infra services:

```powershell
docker compose -f .\docker-compose.dev.yml --env-file .\.env up -d
```

## Services (Dev)

- Postgres: `127.0.0.1:5432`
- Redis: `127.0.0.1:6379`
- Gateway: `127.0.0.1:8080`

Gateway routes:

- `/api/*` -> `http://host.docker.internal:9000`
- `/` -> `http://host.docker.internal:5173`

## Migration Baseline (I002 start)

SQL files:

- `migrations/0001_initial.sql`
- `migrations/rollback/0001_initial.down.sql`

Apply migration after infra containers are running:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\migrate_dev.ps1"
```

Rollback:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\migrate_dev.ps1" -Rollback
```
