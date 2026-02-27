$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envFile = Join-Path $repoRoot '.env'

if (-not (Test-Path $envFile)) {
  throw "Missing .env file: $envFile"
}

function Get-EnvValue {
  param(
    [string]$Key,
    [string]$DefaultValue
  )

  $line = Get-Content -Encoding UTF8 $envFile | Where-Object {
    $_ -match "^\s*$Key\s*="
  } | Select-Object -First 1

  if ($null -eq $line) {
    return $DefaultValue
  }

  $parts = $line.Split('=', 2)
  if ($parts.Count -lt 2) {
    return $DefaultValue
  }
  return $parts[1].Trim()
}

$promPort = Get-EnvValue -Key 'POLARIS_PROMETHEUS_PORT' -DefaultValue '9090'
$grafanaPort = Get-EnvValue -Key 'POLARIS_GRAFANA_PORT' -DefaultValue '3000'
$lokiPort = Get-EnvValue -Key 'POLARIS_LOKI_PORT' -DefaultValue '3100'

function Wait-HttpReady {
  param(
    [string]$Url,
    [int]$MaxAttempts = 30,
    [int]$SleepSeconds = 2
  )

  for ($i = 0; $i -lt $MaxAttempts; $i++) {
    try {
      $response = Invoke-WebRequest -UseBasicParsing -Uri $Url
      if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
        return $true
      }
    } catch {
      # wait and retry
    }
    Start-Sleep -Seconds $SleepSeconds
  }
  return $false
}

Push-Location $repoRoot
try {
  try {
    docker compose -f 'docker-compose.dev.yml' --env-file '.env' down --remove-orphans | Out-Null
  } catch {
    Write-Host 'Pre-clean skipped.'
  }

  docker compose -f 'docker-compose.dev.yml' --env-file '.env' up -d gateway nginx-exporter blackbox-exporter prometheus alertmanager loki promtail grafana | Out-Null
  Start-Sleep -Seconds 12

  if (-not (Wait-HttpReady -Url "http://127.0.0.1:$promPort/-/ready")) {
    throw 'Prometheus ready endpoint timeout.'
  }

  $rules = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$promPort/api/v1/rules"
  $hasCriticalRule = $false
  foreach ($group in $rules.data.groups) {
    foreach ($rule in $group.rules) {
      if ($rule.name -eq 'CriticalCheckoutProbeFailed') {
        $hasCriticalRule = $true
      }
    }
  }
  if (-not $hasCriticalRule) {
    throw 'CriticalCheckoutProbeFailed alert rule not loaded in Prometheus.'
  }

  $targets = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$promPort/api/v1/targets"
  $jobs = @{}
  foreach ($item in $targets.data.activeTargets) {
    $job = $item.labels.job
    if ($null -ne $job -and $job -ne '') {
      $jobs[$job] = $true
    }
  }
  foreach ($required in @('nginx-exporter', 'checkout-probe', 'gateway-health-probe')) {
    if (-not $jobs.ContainsKey($required)) {
      throw "Prometheus target job missing: $required"
    }
  }

  if (-not (Wait-HttpReady -Url "http://127.0.0.1:$grafanaPort/api/health")) {
    throw 'Grafana health endpoint timeout.'
  }
  $grafanaHealth = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$grafanaPort/api/health"
  if ($grafanaHealth.database -ne 'ok') {
    throw 'Grafana health check failed.'
  }

  if (-not (Wait-HttpReady -Url "http://127.0.0.1:$lokiPort/ready")) {
    throw 'Loki ready endpoint timeout.'
  }

  Write-Host 'Observability validation passed.'
}
finally {
  Pop-Location
}
