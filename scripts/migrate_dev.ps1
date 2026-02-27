param(
  [switch]$Rollback
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$composeFile = Join-Path $repoRoot 'docker-compose.dev.yml'
$envFile = Join-Path $repoRoot '.env'

if (-not (Test-Path $envFile)) {
  throw "Missing .env. Run scripts/bootstrap_dev.ps1 first."
}

$migrations = @(
  @{
    Version = '0001_initial'
    Up = '/workspace/migrations/0001_initial.sql'
    Down = '/workspace/migrations/rollback/0001_initial.down.sql'
  },
  @{
    Version = '0002_fulfillment_audit'
    Up = '/workspace/migrations/0002_fulfillment_audit.sql'
    Down = '/workspace/migrations/rollback/0002_fulfillment_audit.down.sql'
  }
)

function Invoke-DbQuery {
  param(
    [string]$Query,
    [switch]$Scalar
  )

  $args = @(
    'compose', '-f', $composeFile, '--env-file', $envFile,
    'exec', '-T', 'postgres',
    'psql', '-U', 'polaris', '-d', 'polaris_mall', '-v', 'ON_ERROR_STOP=1'
  )
  if ($Scalar) {
    $args += @('-tA', '-c', $Query)
  } else {
    $args += @('-c', $Query)
  }
  $output = & docker @args
  if ($LASTEXITCODE -ne 0) {
    throw "Database query failed: $Query"
  }
  return ($output | Out-String).Trim()
}

function Invoke-DbFile {
  param(
    [string]$FilePath
  )

  $args = @(
    'compose', '-f', $composeFile, '--env-file', $envFile,
    'exec', '-T', 'postgres',
    'psql', '-U', 'polaris', '-d', 'polaris_mall', '-v', 'ON_ERROR_STOP=1',
    '-f', $FilePath
  )
  & docker @args
  if ($LASTEXITCODE -ne 0) {
    throw "Migration file failed: $FilePath"
  }
}

function Wait-PostgresReady {
  param(
    [int]$Retries = 30,
    [int]$DelaySeconds = 2
  )

  $args = @(
    'compose', '-f', $composeFile, '--env-file', $envFile,
    'exec', '-T', 'postgres',
    'psql', '-U', 'polaris', '-d', 'polaris_mall', '-v', 'ON_ERROR_STOP=1',
    '-tA', '-c', 'SELECT 1;'
  )
  for ($attempt = 1; $attempt -le $Retries; $attempt++) {
    $output = & docker @args 2>$null
    if ($LASTEXITCODE -eq 0 -and (($output | Out-String).Trim() -eq '1')) {
      Write-Host 'Postgres is ready.'
      return
    }
    Start-Sleep -Seconds $DelaySeconds
  }
  throw 'Postgres is not ready after waiting.'
}

Wait-PostgresReady
Invoke-DbQuery -Query 'CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(64) PRIMARY KEY, applied_at TIMESTAMP NOT NULL DEFAULT NOW());'

if ($Rollback) {
  $latestVersion = Invoke-DbQuery -Query 'SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1;' -Scalar
  if ([string]::IsNullOrWhiteSpace($latestVersion)) {
    Write-Host 'No applied migrations to rollback.'
    exit 0
  }

  $targetMigration = $migrations | Where-Object { $_.Version -eq $latestVersion } | Select-Object -First 1
  if ($null -eq $targetMigration) {
    throw "No rollback file found for migration version: $latestVersion"
  }

  Write-Host "Rolling back migration: $latestVersion"
  Invoke-DbFile -FilePath $targetMigration.Down
  Invoke-DbQuery -Query "DELETE FROM schema_migrations WHERE version = '$latestVersion';"
  Write-Host "Rollback completed: $latestVersion"
  exit 0
}

foreach ($migration in $migrations) {
  $version = $migration.Version
  $appliedVersion = Invoke-DbQuery -Query "SELECT version FROM schema_migrations WHERE version = '$version' LIMIT 1;" -Scalar
  if ($appliedVersion -eq $version) {
    Write-Host "Skip migration (already applied): $version"
    continue
  }

  Write-Host "Applying migration: $version"
  Invoke-DbFile -FilePath $migration.Up
  Invoke-DbQuery -Query "INSERT INTO schema_migrations(version) VALUES ('$version') ON CONFLICT (version) DO NOTHING;"
}

Write-Host 'All migrations applied.'
exit 0
