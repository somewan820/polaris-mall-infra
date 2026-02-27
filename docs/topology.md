# Dev Topology

## Purpose

This document defines the local runtime topology used during the first MVP build.

## Components

| Component | Source | Port | Responsibility |
| --- | --- | --- | --- |
| gateway | `nginx:1.27-alpine` | `8080` | Entry point and reverse proxy |
| postgres | `postgres:16-alpine` | `5432` | Transactional storage |
| redis | `redis:7-alpine` | `6379` | Session and cache support |
| api | local process | `9000` | Auth and domain API service |
| web | local static server | `5173` | Storefront shell |

## Request Paths

- Browser -> `http://127.0.0.1:8080/` -> web (`8s` read timeout)
- Browser -> `http://127.0.0.1:8080/api/v1/*` -> api (`10s` read timeout)
- Browser -> `http://127.0.0.1:8080/api/v1/admin/*` -> api (`15s` read timeout + Authorization forward)
- Payment provider callback -> `http://127.0.0.1:8080/api/v1/payments/callback/mockpay` -> api (`POST only`, `20s` read timeout)

## Environment Contract

`.env` must define:

- `POLARIS_DB_*`
- `POLARIS_REDIS_*`
- `POLARIS_GATEWAY_PORT`
- `POLARIS_API_ORIGIN`
- `POLARIS_WEB_ORIGIN`
- `POLARIS_API_TOKEN_SECRET`

## Startup Order

1. Run `scripts/bootstrap_dev.ps1` or `scripts/bootstrap_dev.sh`
2. Start containers: `docker compose -f docker-compose.dev.yml --env-file .env up -d`
3. Start API service (`polaris-mall-api`)
4. Start Web static server (`polaris-mall-web`)
5. Apply migration pipeline (`scripts/migrate_dev.ps1` or `scripts/migrate_dev.sh`)
6. Run rollback validation (`scripts/migrate_validate_dev.ps1` or `scripts/migrate_validate_dev.sh`)
7. Verify:
   - `GET /healthz` from API
   - open homepage through gateway
