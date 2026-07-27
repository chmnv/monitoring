<#
.SYNOPSIS
  One command to make EVERY dashboard live: HTTP + DB + business traffic AND
  management/audit activity, running together.

.DESCRIPTION
  Starts load-traffic.ps1 (Undertow, datasources, kitchensink, logs) and
  mgmt-activity.ps1 (Security & Audit read+write ops) in parallel for the same
  window, then waits for both to finish.

  Naturally-live dashboards (no driver needed): Windows Host (real host),
  JVM Overview (moves with traffic/GC), System Health / Platform Overview
  (aggregate the above).

.EXAMPLE
  .\scripts\demo-all.ps1
  .\scripts\demo-all.ps1 -DurationSec 600 -Workers 8
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [string]$Container = "wildfly",
    [int]$DurationSec = 300,
    [int]$DelayMs = 80,
    [int]$Workers = 6
)

$root = $PSScriptRoot
Write-Host "demo-all: driving ALL dashboards for ${DurationSec}s (traffic + mgmt/audit)."
Write-Host "Open Grafana http://localhost:3000 (set range to Last 15 minutes, refresh 10s)."
Write-Host ""

# Management/audit activity: roughly one round per ~1.5s for the whole window.
$rounds = [Math]::Max(5, [int]($DurationSec / 1.5))

$traffic = Start-Process -FilePath "powershell" -PassThru -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$root\load-traffic.ps1",
    "-BaseUrl", $BaseUrl, "-DurationSec", $DurationSec, "-DelayMs", $DelayMs, "-Workers", $Workers, "-Failures"
)
$mgmt = Start-Process -FilePath "powershell" -PassThru -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$root\mgmt-activity.ps1",
    "-Container", $Container, "-Rounds", $rounds, "-DelayMs", 1200
)

Write-Host "Started: traffic (PID $($traffic.Id)) + mgmt-activity (PID $($mgmt.Id)). Waiting..."
$traffic.WaitForExit()
$mgmt.WaitForExit()

Write-Host ""
Write-Host "demo-all done. Dashboards to review:"
Write-Host "  01 http://localhost:3000/d/afsypu2byt8u8b"
Write-Host "  04 http://localhost:3000/d/wildfly-http-db"
Write-Host "  05 http://localhost:3000/d/wildfly-db"
Write-Host "  06 http://localhost:3000/d/kitchensink-app"
Write-Host "  08 http://localhost:3000/d/wildfly-security"
Write-Host "  09 http://localhost:3000/d/system-health"
Write-Host "  10 http://localhost:3000/d/registration-quality"
Write-Host "  11 http://localhost:3000/d/search-discovery"
Write-Host "  12 http://localhost:3000/d/auth-sessions"
Write-Host "  13 http://localhost:3000/d/account-activation"
Write-Host "  14 http://localhost:3000/d/account-recovery"
