#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="${repo_root}/docker-compose.dev.yml"
env_file="${repo_root}/.env"
topic="${1:-order}"
consumer="${2:-worker-dev-1}"
block_ms="${3:-5000}"
group_name="polaris-workers"

if [[ ! -f "${env_file}" ]]; then
  echo "missing .env. run scripts/bootstrap_dev.sh first." >&2
  exit 1
fi

stream="polaris.events.order"
if [[ "${topic}" == "payment" ]]; then
  stream="polaris.events.payment"
fi

redis_cli() {
  docker compose -f "${compose_file}" --env-file "${env_file}" exec -T redis redis-cli "$@"
}

"${repo_root}/scripts/queue_bootstrap_dev.sh"
redis_cli XGROUP CREATE "${stream}" "${group_name}" '$' MKSTREAM >/dev/null 2>&1 || true

payload="$(
  redis_cli XREADGROUP GROUP "${group_name}" "${consumer}" COUNT 1 BLOCK "${block_ms}" STREAMS "${stream}" '>'
)"

if [[ "${payload}" == "(nil)" || -z "${payload}" ]]; then
  echo "no message consumed from ${stream} within ${block_ms}ms"
  exit 0
fi

echo "consumed payload:"
echo "${payload}"
