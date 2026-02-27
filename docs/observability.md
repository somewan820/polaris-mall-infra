# Observability Baseline (I006)

## Scope

This baseline adds shared logging, metrics, tracing context propagation, dashboard provisioning, and one critical alert.

## Components

- Prometheus (`:9090`)
- Alertmanager (`:9093`)
- Grafana (`:3000`)
- Loki (`:3100`)
- Promtail (log shipping)
- Nginx Prometheus Exporter (`:9113`)
- Blackbox Exporter (`:9115`)

## Logging and Correlation

Gateway writes JSON access logs to `/var/log/nginx/access.log` with:

- `request_id`
- `trace_id`
- `correlation_id`
- method/uri/status/request time/upstream time

Propagation rules:

- `X-Trace-Id`: keep incoming value, fallback to Nginx `$request_id`
- `X-Correlation-Id`: keep incoming value, fallback to Nginx `$request_id`
- `X-Request-Id`: always forwarded as Nginx `$request_id`

Promtail ships gateway logs to Loki with labels:

- `job`
- `trace_id`
- `correlation_id`
- `request_id`
- `method`
- `status`

## Metrics and Probes

Prometheus collects:

- gateway runtime metrics from `nginx-exporter`
- gateway and checkout synthetic probes from `blackbox-exporter`

Probe targets:

- gateway status: `http://gateway/nginx_status`
- checkout ingress: `POST http://gateway/api/v1/checkout/preview`
  - expected status in probe: `400` or `401` (API reachable without auth token)

## Alert Rules

Defined in `observability/prometheus/alert.rules.yml`:

- `CriticalCheckoutProbeFailed` (`severity=critical`)
  - trigger: checkout probe fails for 2 minutes
- `GatewayHealthProbeFailed` (`severity=warning`)
  - trigger: gateway status probe fails for 2 minutes

## Dashboard

Provisioned dashboard:

- `observability/grafana/dashboards/polaris-infra-overview.json`

Includes:

- checkout probe success stat
- gateway request rate trend
- gateway access log stream (Loki)

## Validation

PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\observability_validate_dev.ps1"
```

Shell:

```bash
bash scripts/observability_validate_dev.sh
```

Validation checks:

- Prometheus ready endpoint
- critical alert rule loaded
- key scrape jobs discoverable
- Grafana health endpoint
- Loki ready endpoint
