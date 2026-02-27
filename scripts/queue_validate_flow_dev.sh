#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="${repo_root}/docker-compose.dev.yml"
env_file="${repo_root}/.env"
stream="polaris.events.order"
group_name="polaris-validate-$(date +%s)"
consumer="validator-dev-1"

if [[ ! -f "${env_file}" ]]; then
  echo "missing .env. run scripts/bootstrap_dev.sh first." >&2
  exit 1
fi

redis_cli() {
  docker compose -f "${compose_file}" --env-file "${env_file}" exec -T redis redis-cli "$@"
}

"${repo_root}/scripts/queue_bootstrap_dev.sh"
redis_cli XGROUP CREATE "${stream}" "${group_name}" '$' MKSTREAM >/dev/null

trace_id="validate-$(date +%s)"
order_id="O-VAL-$(date +%s)"
occurred_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "publishing sample order event..."
entry_id="$(
  redis_cli XADD "${stream}" MAXLEN '~' 10000 '*' \
    event_type order.created \
    trace_id "${trace_id}" \
    order_id "${order_id}" \
    payment_id NA \
    occurred_at "${occurred_at}"
)"

echo "reading with worker group=${group_name} consumer=${consumer} ..."
payload="$(
  redis_cli XREADGROUP GROUP "${group_name}" "${consumer}" COUNT 1 BLOCK 5000 STREAMS "${stream}" '>'
)"

if [[ "${payload}" == "(nil)" || -z "${payload}" ]]; then
  echo "validation failed: worker did not consume any event" >&2
  exit 1
fi
if [[ "${payload}" != *"${trace_id}"* ]]; then
  echo "validation failed: payload missing trace_id=${trace_id}" >&2
  exit 1
fi
if [[ "${payload}" != *"${order_id}"* ]]; then
  echo "validation failed: payload missing order_id=${order_id}" >&2
  exit 1
fi

acked="$(redis_cli XACK "${stream}" "${group_name}" "${entry_id}")"
echo "validation passed. entry_id=${entry_id} trace_id=${trace_id} xack=${acked}"
