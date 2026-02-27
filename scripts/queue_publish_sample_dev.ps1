param(
  [ValidateSet('order', 'payment')]
  [string]$Topic = 'order',
  [string]$OrderID = 'O-DEMO-0001',
  [string]$PaymentID = 'PAY-DEMO-0001'
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$composeFile = Join-Path $repoRoot 'docker-compose.dev.yml'
$envFile = Join-Path $repoRoot '.env'
$streamMap = @{
  order = 'polaris.events.order'
  payment = 'polaris.events.payment'
}
$eventTypeMap = @{
  order = 'order.created'
  payment = 'payment.succeeded'
}

if (-not (Test-Path $envFile)) {
  throw "Missing .env. Run scripts/bootstrap_dev.ps1 first."
}

function Invoke-Redis {
  param([string[]]$RedisArgs)
  $args = @(
    'compose', '-f', $composeFile, '--env-file', $envFile,
    'exec', '-T', 'redis',
    'redis-cli'
  ) + $RedisArgs
  $output = & docker @args 2>&1
  $text = ($output | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) {
    throw "Redis command failed: redis-cli $($RedisArgs -join ' ')`n$text"
  }
  return $text
}

& "$PSScriptRoot/queue_bootstrap_dev.ps1"

$stream = $streamMap[$Topic]
$eventType = $eventTypeMap[$Topic]
$traceID = "trace-$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
$occurredAt = [DateTime]::UtcNow.ToString('o')

$entryID = Invoke-Redis -RedisArgs @(
  'XADD', $stream, 'MAXLEN', '~', '10000', '*',
  'event_type', $eventType,
  'trace_id', $traceID,
  'order_id', $OrderID,
  'payment_id', $PaymentID,
  'occurred_at', $occurredAt
)

Write-Host "Published stream=$stream entry_id=$entryID trace_id=$traceID"
