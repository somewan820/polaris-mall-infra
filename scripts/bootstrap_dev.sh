#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_env="${repo_root}/env/.env.dev.example"
target_env="${repo_root}/.env"

if [[ ! -f "${source_env}" ]]; then
  echo "missing source env template: ${source_env}" >&2
  exit 1
fi

if [[ ! -f "${target_env}" ]]; then
  cp "${source_env}" "${target_env}"
  echo "created dev env file: ${target_env}"
else
  echo "env file already exists: ${target_env}"
fi

for file in \
  "${repo_root}/docker-compose.dev.yml" \
  "${repo_root}/gateway/nginx.dev.conf" \
  "${repo_root}/docs/topology.md" \
  "${repo_root}/docs/async-events.md" \
  "${repo_root}/migrations/0001_initial.sql" \
  "${repo_root}/migrations/rollback/0001_initial.down.sql" \
  "${repo_root}/migrations/0002_fulfillment_audit.sql" \
  "${repo_root}/migrations/rollback/0002_fulfillment_audit.down.sql" \
  "${repo_root}/scripts/migrate_dev.sh" \
  "${repo_root}/scripts/migrate_validate_dev.sh" \
  "${repo_root}/scripts/queue_bootstrap_dev.sh" \
  "${repo_root}/scripts/queue_publish_sample_dev.sh" \
  "${repo_root}/scripts/queue_worker_once_dev.sh" \
  "${repo_root}/scripts/queue_validate_flow_dev.sh"
do
  if [[ ! -f "${file}" ]]; then
    echo "missing required file: ${file}" >&2
    exit 1
  fi
done

echo
echo "bootstrap checks passed."
echo "next commands:"
echo "1) cd ${repo_root}"
echo "2) docker compose -f docker-compose.dev.yml --env-file .env up -d"
