<#
.SYNOPSIS
  Animate dashboard 11 Search & Discovery.

.DESCRIPTION
  Panel map:
    Searches / sec / Outcomes / Hit Rate     → hit queries (Load, Jane)
    Zero-result / sec                        → zzznofind*
    Refine (short q)                         → q=a
    empty outcome                            → blank q
    Search p95 / Duration / Result Size / DB → all of the above

.EXAMPLE
  .\scripts\animate\11-search-discovery.ps1
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$DurationSec = 60,
    [int]$DelayMs = 100
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "11 Search & Discovery" -GrafanaUrl "http://localhost:3000/d/search-discovery" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0
$rest = "$BaseUrl/rest/members"

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 4
    switch ($step) {
        0 {
            Write-AnimatePanel "Hit Rate / Outcomes hit" "q=Load or Jane"
            $q = if ((Get-Random -Maximum 2) -eq 0) { "Load" } else { "Jane" }
            Invoke-AnimateJson -Uri "$rest/search?q=$([uri]::EscapeDataString($q))" | Out-Null
        }
        1 {
            Write-AnimatePanel "Zero-result / sec" "q=zzznofind"
            Invoke-AnimateJson -Uri "$rest/search?q=zzznofind$n" | Out-Null
        }
        2 {
            Write-AnimatePanel "Refine (short q)" "q=a"
            Invoke-AnimateJson -Uri "$rest/search?q=a" | Out-Null
        }
        3 {
            Write-AnimatePanel "empty outcome / Duration" "blank q"
            Invoke-AnimateJson -Uri "$rest/search" | Out-Null
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/search-discovery"
