param(
  [ValidateSet('order', 'payment')]
  [string]$Topic = 'order',
  [string]$Consumer = 'worker-dev-1',
  [int]$BlockMs = 5000
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$composeFile = Join-Path $repoRoot 'docker-compose.dev.yml'
$envFile = Join-Path $repoRoot '.env'
$groupName = 'polaris-workers'
$streamMap = @{
  order = 'polaris.events.order'
  payment = 'polaris.events.payment'
}

if (-not (Test-Path $envFile)) {
  throw "Missing .env. Run scripts/bootstrap_dev.ps1 first."
}

function Invoke-Redis {
  param(
    [string[]]$RedisArgs,
    [string]$AllowErrorPattern = ''
  )
  $args = @(
    'compose', '-f', $composeFile, '--env-file', $envFile,
    'exec', '-T', 'redis',
    'redis-cli'
  ) + $RedisArgs
  $output = & docker @args 2>&1
  $text = ($output | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) {
    if ($AllowErrorPattern -and $text -match $AllowErrorPattern) {
      return $text
    }
    throw "Redis command failed: redis-cli $($RedisArgs -join ' ')`n$text"
  }
  return $text
}

& "$PSScriptRoot/queue_bootstrap_dev.ps1"

$stream = $streamMap[$Topic]
$null = Invoke-Redis -RedisArgs @('XGROUP', 'CREATE', $stream, $groupName, '$', 'MKSTREAM') -AllowErrorPattern 'BUSYGROUP'

$payload = Invoke-Redis -RedisArgs @(
  'XREADGROUP', 'GROUP', $groupName, $Consumer,
  'COUNT', '1',
  'BLOCK', "$BlockMs",
  'STREAMS', $stream, '>'
)

if ($payload -match 'nil') {
  Write-Host "No message consumed from $stream within ${BlockMs}ms."
  exit 0
}

Write-Host 'Consumed payload:'
Write-Host $payload
