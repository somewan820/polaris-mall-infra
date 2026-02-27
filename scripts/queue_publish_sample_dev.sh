#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="${repo_root}/docker-compose.dev.yml"
env_file="${repo_root}/.env"
topic="${1:-order}"
order_id="${2:-O-DEMO-0001}"
payment_id="${3:-PAY-DEMO-0001}"

if [[ ! -f "${env_file}" ]]; then
  echo "missing .env. run scripts/bootstrap_dev.sh first." >&2
  exit 1
fi

stream="polaris.events.order"
event_type="order.created"
if [[ "${topic}" == "payment" ]]; then
  stream="polaris.events.payment"
  event_type="payment.succeeded"
fi

redis_cli() {
  docker compose -f "${compose_file}" --env-file "${env_file}" exec -T redis redis-cli "$@"
}

"${repo_root}/scripts/queue_bootstrap_dev.sh"

trace_id="trace-$(date +%s)"
occurred_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
entry_id="$(
  redis_cli XADD "${stream}" MAXLEN '~' 10000 '*' \
    event_type "${event_type}" \
    trace_id "${trace_id}" \
    order_id "${order_id}" \
    payment_id "${payment_id}" \
    occurred_at "${occurred_at}"
)"

echo "published stream=${stream} entry_id=${entry_id} trace_id=${trace_id}"
