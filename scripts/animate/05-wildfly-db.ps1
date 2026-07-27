<#
.SYNOPSIS
  Animate dashboard 05 Database & Query Timing.

.DESCRIPTION
  Panel map:
    Avg/Max Conn Usage / Get Time / Pool Over Time / Peak Util / Churn → DS via JPA ops
    DB Ops / sec / by Type / Duration p95                              → findAll/findById/search/persist
    Max Used Connections                                               → parallel DB-heavy calls

.EXAMPLE
  .\scripts\animate\05-wildfly-db.ps1
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$DurationSec = 60,
    [int]$DelayMs = 70
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "05 Database & Query Timing" -GrafanaUrl "http://localhost:3000/d/wildfly-db" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0
$rest = "$BaseUrl/rest/members"

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 4
    switch ($step) {
        0 {
            Write-AnimatePanel "DB Ops findAll / Pool usage" "GET /members"
            Invoke-AnimateJson -Uri $rest | Out-Null
        }
        1 {
            Write-AnimatePanel "DB Ops findById" "GET /members/{id}"
            Invoke-AnimateJson -Uri "$rest/$(Get-Random -Minimum 0 -Maximum 3)" | Out-Null
            Invoke-AnimateJson -Uri "$rest/999888" | Out-Null
        }
        2 {
            Write-AnimatePanel "DB Ops search" "GET /members/search"
            Invoke-AnimateJson -Uri "$rest/search?q=Load" | Out-Null
            Invoke-AnimateJson -Uri "$rest/search?q=zzznofind" | Out-Null
        }
        3 {
            Write-AnimatePanel "DB Ops persist / Conn churn" "POST register (+activate)"
            Invoke-AnimateHttpLoad -BaseUrl $BaseUrl -IncludePost | Out-Null
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/wildfly-db"
