<#
.SYNOPSIS
  Start ALL dashboard animation traffic in the background (one command).

.DESCRIPTION
  Launches animate scripts for boards 01-15 plus load-traffic and mgmt-activity,
  writes PIDs to scripts/.animate.pids, then returns immediately.
  Stop with: .\scripts\animate-stop.ps1

.EXAMPLE
  .\scripts\animate-start.ps1
  .\scripts\animate-start.ps1 -DurationSec 1800
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [string]$Container = "wildfly",
    # Long default: stop manually with animate-stop.ps1
    [int]$DurationSec = 86400,
    [int]$DelayMs = 80,
    [string[]]$Dashboards = @(
        "01", "02", "03", "04", "05", "06", "07", "08", "09",
        "10", "11", "12", "13", "14", "15"
    )
)

$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$animateRoot = Join-Path $root "animate"
$pidFile = Join-Path $root ".animate.pids"

# Stop any previous run first (clean restart)
& (Join-Path $root "animate-stop.ps1") -Quiet

$map = @{
    "01" = "01-platform.ps1"; "02" = "02-windows-host.ps1"; "03" = "03-jvm.ps1"
    "04" = "04-wildfly-http-db.ps1"; "05" = "05-wildfly-db.ps1"; "06" = "06-kitchensink-app.ps1"
    "07" = "07-wildfly-logs.ps1"; "08" = "08-wildfly-security.ps1"; "09" = "09-system-health.ps1"
    "10" = "10-registration-quality.ps1"; "11" = "11-search-discovery.ps1"; "12" = "12-auth-sessions.ps1"
    "13" = "13-account-activation.ps1"; "14" = "14-account-recovery.ps1"; "15" = "15-app-authorization.ps1"
}

$pids = New-Object System.Collections.Generic.List[int]

function Start-AnimateProc {
    param([string[]]$ArgumentList, [string]$Label)
    $p = Start-Process -FilePath "powershell.exe" -PassThru -WindowStyle Minimized -ArgumentList $ArgumentList
    $pids.Add([int]$p.Id)
    Write-Host ("  [{0}] {1}" -f $p.Id, $Label)
}

Write-Host "animate-start: launching background traffic (DurationSec=$DurationSec)"
Write-Host "Grafana: http://localhost:3000  (Last 15m, refresh 10s)"
Write-Host "Stop:    .\scripts\animate-stop.ps1"
Write-Host ""

foreach ($raw in $Dashboards) {
    $key = if ("$raw" -match '^\d+$') { "{0:D2}" -f [int]$raw } else { "$raw" }
    if (-not $map.ContainsKey($key)) {
        Write-Warning "Skip unknown board: $raw"
        continue
    }
    $file = Join-Path $animateRoot $map[$key]
    $argList = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $file,
        "-DurationSec", "$DurationSec"
    )
    if ($key -eq "02") {
        $argList += @("-DelayMs", "$([Math]::Max(150, $DelayMs))")
    } elseif ($key -eq "08") {
        $argList += @("-Container", $Container, "-DelayMs", "700")
    } else {
        $argList += @("-BaseUrl", $BaseUrl, "-DelayMs", "$DelayMs")
        if ($key -eq "07") { $argList += @("-Container", $Container) }
    }
    Start-AnimateProc -ArgumentList $argList -Label $map[$key]
}

Start-AnimateProc -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $root "load-traffic.ps1"),
    "-BaseUrl", $BaseUrl, "-DurationSec", "$DurationSec",
    "-DelayMs", "$DelayMs", "-Workers", "4", "-Failures"
) -Label "load-traffic.ps1"

$rounds = [Math]::Max(20, [int]($DurationSec / 2))
if ($rounds -gt 50000) { $rounds = 50000 }
Start-AnimateProc -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $root "mgmt-activity.ps1"),
    "-Container", $Container, "-Rounds", "$rounds", "-DelayMs", "1500"
) -Label "mgmt-activity.ps1"

$pids | Set-Content -Path $pidFile -Encoding ascii
Write-Host ""
Write-Host "Started $($pids.Count) processes. PID file: $pidFile"
Write-Host "Running in background - close this window is OK."
