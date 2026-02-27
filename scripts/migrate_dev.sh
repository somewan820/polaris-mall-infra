#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-up}"

if [[ ! -f "${repo_root}/.env" ]]; then
  echo "missing .env. run scripts/bootstrap_dev.sh first." >&2
  exit 1
fi

if [[ "${mode}" == "down" ]]; then
  echo "applying rollback migration"
  docker compose -f "${repo_root}/docker-compose.dev.yml" --env-file "${repo_root}/.env" exec -T postgres \
    psql -U polaris -d polaris_mall -v ON_ERROR_STOP=1 -f "/workspace/migrations/rollback/0001_initial.down.sql"
  exit 0
fi

echo "applying initial migration"
docker compose -f "${repo_root}/docker-compose.dev.yml" --env-file "${repo_root}/.env" exec -T postgres \
  psql -U polaris -d polaris_mall -v ON_ERROR_STOP=1 -f "/workspace/migrations/0001_initial.sql"

