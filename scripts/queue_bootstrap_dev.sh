#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="${repo_root}/docker-compose.dev.yml"
env_file="${repo_root}/.env"
group_name="polaris-workers"
stream_maxlen="10000"
streams=("polaris.events.order" "polaris.events.payment")

if [[ ! -f "${env_file}" ]]; then
  echo "missing .env. run scripts/bootstrap_dev.sh first." >&2
  exit 1
fi

redis_cli() {
  docker compose -f "${compose_file}" --env-file "${env_file}" exec -T redis redis-cli "$@"
}

wait_redis_ready() {
  local retries=30
  local delay=2
  local i
  for ((i=1; i<=retries; i++)); do
    if [[ "$(redis_cli PING 2>/dev/null || true)" == "PONG" ]]; then
      echo "redis is ready"
      return 0
    fi
    sleep "${delay}"
  done
  echo "redis is not ready after waiting" >&2
  exit 1
}

echo "ensuring redis runtime is up..."
docker compose -f "${compose_file}" --env-file "${env_file}" up -d redis >/dev/null
wait_redis_ready

for stream in "${streams[@]}"; do
  echo "configuring stream: ${stream}"
  if ! redis_cli XGROUP CREATE "${stream}" "${group_name}" '$' MKSTREAM >/dev/null 2>&1; then
    if ! redis_cli XGROUP CREATE "${stream}" "${group_name}" '$' MKSTREAM 2>&1 | grep -q "BUSYGROUP"; then
      echo "failed to create group for ${stream}" >&2
      exit 1
    fi
  fi
  trimmed="$(redis_cli XTRIM "${stream}" MAXLEN '~' "${stream_maxlen}")"
  echo "retention set (MAXLEN~${stream_maxlen}), trimmed: ${trimmed}"
done

echo "queue bootstrap completed"
