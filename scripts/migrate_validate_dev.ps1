$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$composeFile = Join-Path $repoRoot 'docker-compose.dev.yml'
$envFile = Join-Path $repoRoot '.env'
$migrateScript = Join-Path $PSScriptRoot 'migrate_dev.ps1'

if (-not (Test-Path $envFile)) {
  throw "Missing .env. Run scripts/bootstrap_dev.ps1 first."
}

function Invoke-Scalar {
  param(
    [string]$Query
  )

  $args = @(
    'compose', '-f', $composeFile, '--env-file', $envFile,
    'exec', '-T', 'postgres',
    'psql', '-U', 'polaris', '-d', 'polaris_mall', '-v', 'ON_ERROR_STOP=1',
    '-tA', '-c', $Query
  )
  $output = & docker @args
  if ($LASTEXITCODE -ne 0) {
    throw "Database query failed: $Query"
  }
  return ($output | Out-String).Trim()
}

Write-Host 'Step 1/4: apply migrations'
& $migrateScript

Write-Host 'Step 2/4: verify key tables after migration'
$tableCount = Invoke-Scalar -Query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('users','products','orders','payments','shipments','refunds','notification_events','audit_logs');"
if ($tableCount -ne '8') {
  throw "Expected 8 key tables after migration, got: $tableCount"
}

Write-Host 'Step 3/4: rollback latest migration and verify removal'
& $migrateScript -Rollback
$auditRegClass = Invoke-Scalar -Query "SELECT to_regclass('public.audit_logs');"
if (-not [string]::IsNullOrWhiteSpace($auditRegClass)) {
  throw "Expected audit_logs to be removed after rollback, got: $auditRegClass"
}

Write-Host 'Step 4/4: re-apply migrations to restore baseline'
& $migrateScript

Write-Host 'Migration validation passed.'
