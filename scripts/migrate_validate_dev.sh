#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
migrate_script="${repo_root}/scripts/migrate_dev.sh"

if [[ ! -f "${repo_root}/.env" ]]; then
  echo "missing .env. run scripts/bootstrap_dev.sh first." >&2
  exit 1
fi

compose_exec() {
  docker compose -f "${repo_root}/docker-compose.dev.yml" --env-file "${repo_root}/.env" exec -T postgres "$@"
}

query_scalar() {
  compose_exec psql -U polaris -d polaris_mall -v ON_ERROR_STOP=1 -tA -c "$1" | tr -d '[:space:]'
}

echo "step 1/4: apply migrations"
"${migrate_script}"

echo "step 2/4: verify key tables after migration"
table_count="$(query_scalar "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('users','products','orders','payments','shipments','refunds','notification_events','audit_logs');")"
if [[ "${table_count}" != "8" ]]; then
  echo "expected 8 key tables after migration, got: ${table_count}" >&2
  exit 1
fi

echo "step 3/4: rollback latest migration and verify removal"
"${migrate_script}" down
audit_regclass="$(query_scalar "SELECT to_regclass('public.audit_logs');")"
if [[ -n "${audit_regclass}" ]]; then
  echo "expected audit_logs to be removed after rollback, got: ${audit_regclass}" >&2
  exit 1
fi

echo "step 4/4: re-apply migrations to restore baseline"
"${migrate_script}"

echo "migration validation passed"
