$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceEnv = Join-Path $repoRoot 'env/.env.dev.example'
$targetEnv = Join-Path $repoRoot '.env'

if (-not (Test-Path $sourceEnv)) {
  throw "Missing source env template: $sourceEnv"
}

if (-not (Test-Path $targetEnv)) {
  Copy-Item -Path $sourceEnv -Destination $targetEnv -Force
  Write-Host "Created dev env file: $targetEnv"
} else {
  Write-Host "Env file already exists: $targetEnv"
}

$requiredFiles = @(
  (Join-Path $repoRoot 'docker-compose.dev.yml'),
  (Join-Path $repoRoot 'gateway/nginx.dev.conf'),
  (Join-Path $repoRoot 'docs/topology.md'),
  (Join-Path $repoRoot 'migrations/0001_initial.sql'),
  (Join-Path $repoRoot 'migrations/rollback/0001_initial.down.sql'),
  (Join-Path $repoRoot 'migrations/0002_fulfillment_audit.sql'),
  (Join-Path $repoRoot 'migrations/rollback/0002_fulfillment_audit.down.sql'),
  (Join-Path $repoRoot 'scripts/migrate_dev.ps1'),
  (Join-Path $repoRoot 'scripts/migrate_validate_dev.ps1')
)

foreach ($file in $requiredFiles) {
  if (-not (Test-Path $file)) {
    throw "Missing required file: $file"
  }
}

Write-Host ''
Write-Host 'Bootstrap checks passed.'
Write-Host 'Next commands:'
Write-Host "1) cd '$repoRoot'"
Write-Host "2) docker compose -f docker-compose.dev.yml --env-file .env up -d"
