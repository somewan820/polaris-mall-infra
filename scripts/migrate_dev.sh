#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-up}"

if [[ ! -f "${repo_root}/.env" ]]; then
  echo "missing .env. run scripts/bootstrap_dev.sh first." >&2
  exit 1
fi

migrations=(
  "0001_initial:/workspace/migrations/0001_initial.sql:/workspace/migrations/rollback/0001_initial.down.sql"
  "0002_fulfillment_audit:/workspace/migrations/0002_fulfillment_audit.sql:/workspace/migrations/rollback/0002_fulfillment_audit.down.sql"
)

compose_exec() {
  docker compose -f "${repo_root}/docker-compose.dev.yml" --env-file "${repo_root}/.env" exec -T postgres "$@"
}

query_scalar() {
  compose_exec psql -U polaris -d polaris_mall -v ON_ERROR_STOP=1 -tA -c "$1" | tr -d '[:space:]'
}

query_exec() {
  compose_exec psql -U polaris -d polaris_mall -v ON_ERROR_STOP=1 -c "$1"
}

run_file() {
  compose_exec psql -U polaris -d polaris_mall -v ON_ERROR_STOP=1 -f "$1"
}

wait_postgres_ready() {
  local retries=30
  local delay_seconds=2
  local attempt
  for ((attempt=1; attempt<=retries; attempt++)); do
    if compose_exec psql -U polaris -d polaris_mall -v ON_ERROR_STOP=1 -tA -c "SELECT 1;" >/dev/null 2>&1; then
      echo "postgres is ready"
      return 0
    fi
    sleep "${delay_seconds}"
  done
  echo "postgres is not ready after waiting" >&2
  exit 1
}

wait_postgres_ready
query_exec "CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(64) PRIMARY KEY, applied_at TIMESTAMP NOT NULL DEFAULT NOW());"

if [[ "${mode}" == "down" ]]; then
  latest_version="$(query_scalar "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1;")"
  if [[ -z "${latest_version}" ]]; then
    echo "no applied migrations to rollback"
    exit 0
  fi

  rollback_file=""
  for item in "${migrations[@]}"; do
    IFS=":" read -r version _ down_file <<< "${item}"
    if [[ "${version}" == "${latest_version}" ]]; then
      rollback_file="${down_file}"
      break
    fi
  done

  if [[ -z "${rollback_file}" ]]; then
    echo "no rollback file for migration ${latest_version}" >&2
    exit 1
  fi

  echo "rolling back migration: ${latest_version}"
  run_file "${rollback_file}"
  query_exec "DELETE FROM schema_migrations WHERE version = '${latest_version}';"
  echo "rollback completed: ${latest_version}"
  exit 0
fi

for item in "${migrations[@]}"; do
  IFS=":" read -r version up_file _ <<< "${item}"
  applied="$(query_scalar "SELECT version FROM schema_migrations WHERE version = '${version}' LIMIT 1;")"
  if [[ "${applied}" == "${version}" ]]; then
    echo "skip migration (already applied): ${version}"
    continue
  fi
  echo "applying migration: ${version}"
  run_file "${up_file}"
  query_exec "INSERT INTO schema_migrations(version) VALUES ('${version}') ON CONFLICT (version) DO NOTHING;"
done

echo "all migrations applied"
