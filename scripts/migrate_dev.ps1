param(
  [switch]$Rollback
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$migrationFile = Join-Path $repoRoot 'migrations/0001_initial.sql'
$rollbackFile = Join-Path $repoRoot 'migrations/rollback/0001_initial.down.sql'

if (-not (Test-Path (Join-Path $repoRoot '.env'))) {
  throw "Missing .env. Run scripts/bootstrap_dev.ps1 first."
}

if ($Rollback) {
  Write-Host "Applying rollback migration: $rollbackFile"
  docker compose -f "$repoRoot/docker-compose.dev.yml" --env-file "$repoRoot/.env" exec -T postgres `
    psql -U polaris -d polaris_mall -v ON_ERROR_STOP=1 -f "/workspace/migrations/rollback/0001_initial.down.sql"
  exit $LASTEXITCODE
}

Write-Host "Applying migration: $migrationFile"
docker compose -f "$repoRoot/docker-compose.dev.yml" --env-file "$repoRoot/.env" exec -T postgres `
  psql -U polaris -d polaris_mall -v ON_ERROR_STOP=1 -f "/workspace/migrations/0001_initial.sql"
exit $LASTEXITCODE
