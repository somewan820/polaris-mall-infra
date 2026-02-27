$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$composeFile = Join-Path $repoRoot 'docker-compose.dev.yml'
$envFile = Join-Path $repoRoot '.env'
$groupName = 'polaris-workers'
$streamMaxLen = '10000'
$streams = @('polaris.events.order', 'polaris.events.payment')

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

function Wait-RedisReady {
  param(
    [int]$Retries = 30,
    [int]$DelaySeconds = 2
  )

  for ($i = 1; $i -le $Retries; $i++) {
    $pong = Invoke-Redis -RedisArgs @('PING')
    if ($pong -match 'PONG') {
      Write-Host 'Redis is ready.'
      return
    }
    Start-Sleep -Seconds $DelaySeconds
  }
  throw 'Redis is not ready after waiting.'
}

Write-Host 'Ensuring redis runtime is up...'
& docker compose -f $composeFile --env-file $envFile up -d redis | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Failed to start redis service.'
}

Wait-RedisReady

foreach ($stream in $streams) {
  Write-Host "Configuring stream: $stream"
  $null = Invoke-Redis -RedisArgs @('XGROUP', 'CREATE', $stream, $groupName, '$', 'MKSTREAM') -AllowErrorPattern 'BUSYGROUP'
  $trimmed = Invoke-Redis -RedisArgs @('XTRIM', $stream, 'MAXLEN', '~', $streamMaxLen)
  Write-Host "Retention set (MAXLEN~$streamMaxLen), trimmed: $trimmed"
}

Write-Host 'Queue bootstrap completed.'
