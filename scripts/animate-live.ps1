<#
.SYNOPSIS
  Keep multiple dashboards alive in parallel (demo / mentor walkthrough).

.DESCRIPTION
  Starts selected animate scripts as background processes so rate() panels move
  at the same time (sequential animate-all only feeds one board at a time).

.EXAMPLE
  .\scripts\animate-live.ps1
  .\scripts\animate-live.ps1 -DurationSec 600 -Dashboards 4,5,7,8,11,12,13,14,15
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [string]$Container = "wildfly",
    [int]$DurationSec = 300,
    [int]$DelayMs = 80,
    [string[]]$Dashboards = @("04", "05", "07", "08", "11", "12", "13", "14", "15")
)

$ErrorActionPreference = "Continue"
$root = Join-Path $PSScriptRoot "animate"

$map = @{
    "01" = "01-platform.ps1"; "02" = "02-windows-host.ps1"; "03" = "03-jvm.ps1"
    "04" = "04-wildfly-http-db.ps1"; "05" = "05-wildfly-db.ps1"; "06" = "06-kitchensink-app.ps1"
    "07" = "07-wildfly-logs.ps1"; "08" = "08-wildfly-security.ps1"; "09" = "09-system-health.ps1"
    "10" = "10-registration-quality.ps1"; "11" = "11-search-discovery.ps1"; "12" = "12-auth-sessions.ps1"
    "13" = "13-account-activation.ps1"; "14" = "14-account-recovery.ps1"; "15" = "15-app-authorization.ps1"
}

Write-Host "animate-live: parallel boards for ${DurationSec}s"
Write-Host "Grafana: http://localhost:3000  (Last 15 minutes, refresh 10s)"
Write-Host ""

$procs = @()
foreach ($raw in $Dashboards) {
    $key = if ("$raw" -match '^\d+$') { "{0:D2}" -f [int]$raw } else { "$raw" }
    if (-not $map.ContainsKey($key)) {
        Write-Warning "Skip unknown board: $raw"
        continue
    }
    $file = Join-Path $root $map[$key]
    $argList = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $file,
        "-DurationSec", "$DurationSec"
    )
    if ($key -notin @("02", "08")) {
        $argList += @("-BaseUrl", $BaseUrl, "-DelayMs", "$DelayMs")
    } elseif ($key -eq "02") {
        $argList += @("-DelayMs", "$([Math]::Max(150, $DelayMs))")
    } else {
        $argList += @("-Container", $Container, "-DelayMs", "700")
    }
    if ($key -eq "07") {
        $argList += @("-Container", $Container)
    }
    $p = Start-Process -FilePath "powershell" -PassThru -WindowStyle Minimized -ArgumentList $argList
    $procs += $p
    Write-Host "  started $($map[$key]) PID=$($p.Id)"
}

# Also continuous mixed traffic + mgmt for undertow/ds/audit coverage
$traffic = Start-Process -FilePath "powershell" -PassThru -WindowStyle Minimized -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "load-traffic.ps1"),
    "-BaseUrl", $BaseUrl, "-DurationSec", "$DurationSec", "-DelayMs", "$DelayMs", "-Workers", "4", "-Failures"
)
$rounds = [Math]::Max(8, [int]($DurationSec / 2))
$mgmt = Start-Process -FilePath "powershell" -PassThru -WindowStyle Minimized -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "mgmt-activity.ps1"),
    "-Container", $Container, "-Rounds", "$rounds", "-DelayMs", "1500"
)
$procs += @($traffic, $mgmt)
Write-Host "  started load-traffic PID=$($traffic.Id)"
Write-Host "  started mgmt-activity PID=$($mgmt.Id)"
Write-Host ""
Write-Host "Waiting for all ($($procs.Count) processes)..."
$procs | Wait-Process
Write-Host "animate-live done."
