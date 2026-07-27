<#
.SYNOPSIS
  Animate dashboard 01 Platform Overview.

.DESCRIPTION
  Panel map:
    Platform Status / Targets Down / Service Status / Availability*  → Prometheus up{} (scrape alive)
    WildFly Uptime / JVM Heap* / Memory pools                       → light HTTP → JVM metrics move
    CPU Host vs WildFly / Memory Host vs Heap / Disk                 → host exporter + WildFly process
    Platform Errors (listener + logs) / Platform Traffic             → HTTP load + list/get

.EXAMPLE
  .\scripts\animate\01-platform.ps1
  .\scripts\animate\01-platform.ps1 -DurationSec 90
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [string]$PrometheusUrl = "http://localhost:9090",
    [int]$DurationSec = 60,
    [int]$DelayMs = 100
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "01 Platform Overview" -GrafanaUrl "http://localhost:3000/d/afsypu2byt8u8b" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 4
    switch ($step) {
        0 {
            Write-AnimatePanel "Platform Traffic / Errors" "HTTP list + HTML"
            Invoke-AnimateHttpLoad -BaseUrl $BaseUrl | Out-Null
        }
        1 {
            Write-AnimatePanel "JVM Heap / Memory pools" "register+list burst"
            Invoke-AnimateHttpLoad -BaseUrl $BaseUrl -IncludePost | Out-Null
            Invoke-AnimateHttpLoad -BaseUrl $BaseUrl | Out-Null
        }
        2 {
            Write-AnimatePanel "Targets / Service Status" "Prometheus /api/v1/targets"
            try {
                Invoke-WebRequest -Uri "$PrometheusUrl/api/v1/targets" -UseBasicParsing -TimeoutSec 5 | Out-Null
            } catch { }
        }
        3 {
            Write-AnimatePanel "CPU/Memory Host vs WildFly" "mixed load"
            1..3 | ForEach-Object { Invoke-AnimateHttpLoad -BaseUrl $BaseUrl -IncludePost | Out-Null }
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/afsypu2byt8u8b"
