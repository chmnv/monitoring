<#
.SYNOPSIS
  Animate dashboard 03 JVM Overview.

.DESCRIPTION
  Panel map:
    Heap Used / Heap Memory / Memory pools* → registration + list burst (alloc)
    Process CPU / CPU Load                  → concurrent HTTP workers
    Live Threads / Threads                  → parallel Invoke-WebRequest
    Loaded Classes / Class Loading          → hit many endpoints
    GC* / GC Overhead / Avg GC Pause        → alloc pressure via POSTs
    JVM Uptime                              → naturally live

.EXAMPLE
  .\scripts\animate\03-jvm.ps1 -DurationSec 60
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$DurationSec = 60,
    [int]$DelayMs = 50
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "03 JVM Overview" -GrafanaUrl "http://localhost:3000/d/jvm-overview" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 3
    switch ($step) {
        0 {
            Write-AnimatePanel "Heap / Memory pools / GC" "POST register burst"
            1..4 | ForEach-Object { Invoke-AnimateHttpLoad -BaseUrl $BaseUrl -IncludePost | Out-Null }
        }
        1 {
            Write-AnimatePanel "Threads / CPU" "parallel list+search"
            $jobs = 1..4 | ForEach-Object {
                Start-Job -ScriptBlock {
                    param($u)
                    try { Invoke-WebRequest -Uri "$u/rest/members" -UseBasicParsing -TimeoutSec 8 | Out-Null } catch { }
                    try { Invoke-WebRequest -Uri "$u/rest/members/search?q=Load" -UseBasicParsing -TimeoutSec 8 | Out-Null } catch { }
                } -ArgumentList $BaseUrl
            }
            $jobs | Wait-Job | Out-Null
            $jobs | Remove-Job -Force
        }
        2 {
            Write-AnimatePanel "Class Loading / Non-Heap" "HTML + metrics + by-id"
            Invoke-AnimateJson -Uri "$BaseUrl/" | Out-Null
            Invoke-AnimateJson -Uri "$BaseUrl/metrics" | Out-Null
            Invoke-AnimateJson -Uri "$BaseUrl/rest/members/0" | Out-Null
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/jvm-overview"
