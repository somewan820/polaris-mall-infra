# Dev Topology

## Purpose

This document defines the local runtime topology used during the first MVP build.

## Components

| Component | Source | Port | Responsibility |
| --- | --- | --- | --- |
| gateway | `nginx:1.27-alpine` | `8080` | Entry point and reverse proxy |
| postgres | `postgres:16-alpine` | `5432` | Transactional storage |
| redis | `redis:7-alpine` | `6379` | Session and cache support |
| prometheus | `prom/prometheus` | `9090` | Metrics collection and rules |
| alertmanager | `prom/alertmanager` | `9093` | Alert routing |
| grafana | `grafana/grafana` | `3000` | Dashboard and log explore |
| loki | `grafana/loki` | `3100` | Centralized log store |
| nginx-exporter | `nginx/nginx-prometheus-exporter` | `9113` | Gateway runtime metrics |
| blackbox-exporter | `prom/blackbox-exporter` | `9115` | Synthetic HTTP probing |
| api | local process | `9000` | Auth and domain API service |
| web | local static server | `5173` | Storefront shell |

## Async Runtime (I004)

- Queue runtime uses Redis Streams in dev.
- Streams:
  - `polaris.events.order`
  - `polaris.events.payment`
- Consumer group:
  - `polaris-workers`
- Retention:
  - per stream `MAXLEN ~ 10000`

## Request Paths

- Browser -> `http://127.0.0.1:8080/` -> web (`8s` read timeout)
- Browser -> `http://127.0.0.1:8080/api/v1/*` -> api (`10s` read timeout)
- Browser -> `http://127.0.0.1:8080/api/v1/admin/*` -> api (`15s` read timeout + Authorization forward)
- Payment provider callback -> `http://127.0.0.1:8080/api/v1/payments/callback/mockpay` -> api (`POST only`, `20s` read timeout)
- Prometheus -> `gateway/nginx_status` (gateway health probe)
- Prometheus -> blackbox probe `POST /api/v1/checkout/preview` (critical checkout ingress signal)

## Environment Contract

`.env` must define:

- `POLARIS_DB_*`
- `POLARIS_REDIS_*`
- `POLARIS_GATEWAY_PORT`
- `POLARIS_PROMETHEUS_PORT`
- `POLARIS_ALERTMANAGER_PORT`
- `POLARIS_GRAFANA_PORT`
- `POLARIS_LOKI_PORT`
- `POLARIS_NGINX_EXPORTER_PORT`
- `POLARIS_BLACKBOX_PORT`
- `POLARIS_GRAFANA_ADMIN_*`
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
7. Run observability validation (`scripts/observability_validate_dev.ps1` or `scripts/observability_validate_dev.sh`)
8. Verify:
   - `GET /healthz` from API
   - open homepage through gateway
