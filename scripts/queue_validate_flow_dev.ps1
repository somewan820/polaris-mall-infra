$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$composeFile = Join-Path $repoRoot 'docker-compose.dev.yml'
$envFile = Join-Path $repoRoot '.env'
$stream = 'polaris.events.order'
$groupName = "polaris-validate-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
$consumer = 'validator-dev-1'

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
$null = Invoke-Redis -RedisArgs @('XGROUP', 'CREATE', $stream, $groupName, '$', 'MKSTREAM')

$traceID = "validate-$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
$orderID = "O-VAL-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
$occurredAt = [DateTime]::UtcNow.ToString('o')

Write-Host 'Publishing sample order event...'
$entryID = Invoke-Redis -RedisArgs @(
  'XADD', $stream, 'MAXLEN', '~', '10000', '*',
  'event_type', 'order.created',
  'trace_id', $traceID,
  'order_id', $orderID,
  'payment_id', 'NA',
  'occurred_at', $occurredAt
)

Write-Host "Reading with worker group=$groupName consumer=$consumer ..."
$payload = Invoke-Redis -RedisArgs @(
  'XREADGROUP', 'GROUP', $groupName, $consumer,
  'COUNT', '1',
  'BLOCK', '5000',
  'STREAMS', $stream, '>'
)

if ($payload -match 'nil') {
  throw 'Validation failed: worker did not consume any event.'
}
if ($payload -notmatch [regex]::Escape($traceID)) {
  throw "Validation failed: consumed payload does not contain trace_id=$traceID"
}
if ($payload -notmatch [regex]::Escape($orderID)) {
  throw "Validation failed: consumed payload does not contain order_id=$orderID"
}

$acked = Invoke-Redis -RedisArgs @('XACK', $stream, $groupName, $entryID)

Write-Host "Validation passed. entry_id=$entryID trace_id=$traceID xack=$acked"
