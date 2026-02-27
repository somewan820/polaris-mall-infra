#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

if [[ ! -f ".env" ]]; then
  echo "missing .env file" >&2
  exit 1
fi

set -a
source ".env"
set +a

prom_port="${POLARIS_PROMETHEUS_PORT:-9090}"
grafana_port="${POLARIS_GRAFANA_PORT:-3000}"
loki_port="${POLARIS_LOKI_PORT:-3100}"

docker compose -f "docker-compose.dev.yml" --env-file ".env" down --remove-orphans >/dev/null 2>&1 || true

docker compose -f "docker-compose.dev.yml" --env-file ".env" up -d \
  gateway nginx-exporter blackbox-exporter prometheus alertmanager loki promtail grafana >/dev/null

wait_http() {
  local url="$1"
  local attempts="${2:-30}"
  local delay="${3:-2}"
  local i
  for ((i = 0; i < attempts; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$delay"
  done
  return 1
}

wait_http "http://127.0.0.1:${prom_port}/-/ready"

rules_json="$(curl -fsS "http://127.0.0.1:${prom_port}/api/v1/rules")"
echo "$rules_json" | grep -q "CriticalCheckoutProbeFailed"

targets_json="$(curl -fsS "http://127.0.0.1:${prom_port}/api/v1/targets")"
echo "$targets_json" | grep -q "\"job\":\"nginx-exporter\""
echo "$targets_json" | grep -q "\"job\":\"checkout-probe\""
echo "$targets_json" | grep -q "\"job\":\"gateway-health-probe\""

wait_http "http://127.0.0.1:${grafana_port}/api/health"
grafana_health="$(curl -fsS "http://127.0.0.1:${grafana_port}/api/health")"
echo "$grafana_health" | grep -q "\"database\":\"ok\""

wait_http "http://127.0.0.1:${loki_port}/ready"

echo "Observability validation passed."
