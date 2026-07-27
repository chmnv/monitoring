<#
.SYNOPSIS
  Animate dashboard 09 System Health & SLA.

.DESCRIPTION
  Panel map:
    Platform SLA* / Error Budget / Targets Down / Service Status / Availability* → up{} + traffic
    Undertow OK / Listener Error Rate vs SLO / Latency vs SLO                    → HTTP load + 404s
    App Success (lifetime)                                                       → successful registers
    Host Resource Pressure / Component Uptime / Scrape Duration                  → host + scrape alive

.EXAMPLE
  .\scripts\animate\09-system-health.ps1
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [string]$PrometheusUrl = "http://localhost:9090",
    [int]$DurationSec = 60,
    [int]$DelayMs = 100
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "09 System Health & SLA" -GrafanaUrl "http://localhost:3000/d/system-health" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 4
    switch ($step) {
        0 {
            Write-AnimatePanel "Undertow OK / Latency vs SLO" "HTTP list+html"
            Invoke-AnimateHttpLoad -BaseUrl $BaseUrl | Out-Null
        }
        1 {
            Write-AnimatePanel "App Success / Error Budget context" "successful register"
            Invoke-AnimateHttpLoad -BaseUrl $BaseUrl -IncludePost | Out-Null
        }
        2 {
            Write-AnimatePanel "Listener Error Rate vs SLO" "404 miss"
            try { Invoke-WebRequest -Uri "$BaseUrl/health-miss-$n" -UseBasicParsing -TimeoutSec 5 | Out-Null } catch { }
        }
        3 {
            Write-AnimatePanel "Targets / Scrape Duration" "Prometheus targets API"
            try {
                Invoke-WebRequest -Uri "$PrometheusUrl/api/v1/targets" -UseBasicParsing -TimeoutSec 5 | Out-Null
            } catch { }
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/system-health"
