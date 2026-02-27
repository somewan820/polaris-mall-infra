# Polaris Mall Infra

Language: English | [中文](README.zh-CN.md)

`polaris-mall-infra` provides the infrastructure baseline for local and shared environments.

## Implemented In This Step

- I001 baseline:
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
- I002 baseline:
  - versioned migration pipeline:
    - `scripts/migrate_dev.ps1`
    - `scripts/migrate_dev.sh`
  - rollback support for latest applied migration
  - migration validation scripts:
    - `scripts/migrate_validate_dev.ps1`
    - `scripts/migrate_validate_dev.sh`
  - schema files:
    - `migrations/0001_initial.sql`
    - `migrations/0002_fulfillment_audit.sql`
    - `migrations/rollback/0001_initial.down.sql`
    - `migrations/rollback/0002_fulfillment_audit.down.sql`
- I003 baseline:
  - gateway route split for `admin`, `user api`, and `payment callback`
  - Authorization forwarding for `/api/v1/*` and `/api/v1/admin/*`
  - callback ingress rule: `POST /api/v1/payments/callback/mockpay`
  - route-level timeout policies for web/api/callback traffic

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

- `/api/v1/admin/*` -> `http://host.docker.internal:9000` (Authorization forwarded, `15s` timeout)
- `/api/v1/payments/callback/mockpay` -> `http://host.docker.internal:9000` (`POST` only, `20s` timeout)
- `/api/v1/*` -> `http://host.docker.internal:9000` (`10s` timeout)
- `/api/*` -> `http://host.docker.internal:9000` (fallback)
- `/` -> `http://host.docker.internal:5173`

## Migration Baseline (I002)

SQL files:

- `migrations/0001_initial.sql`
- `migrations/0002_fulfillment_audit.sql`
- `migrations/rollback/0001_initial.down.sql`
- `migrations/rollback/0002_fulfillment_audit.down.sql`

Apply all pending migrations after infra containers are running:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\migrate_dev.ps1"
```

Rollback latest applied migration:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\migrate_dev.ps1" -Rollback
```

Validate migration + rollback in disposable runtime:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\migrate_validate_dev.ps1"
```
