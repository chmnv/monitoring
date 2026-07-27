<#
.SYNOPSIS
  Stop ALL background animation / load / mgmt traffic started by animate-start.

.EXAMPLE
  .\scripts\animate-stop.ps1
#>
param(
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"
$pidFile = Join-Path $PSScriptRoot ".animate.pids"
$killed = 0

function Stop-AnimateTree {
    param([int]$ProcessId)
    try {
        $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue
        foreach ($c in $children) {
            Stop-AnimateTree -ProcessId ([int]$c.ProcessId)
        }
    } catch { }
    try {
        $proc = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($proc) {
            Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
            $script:killed++
            if (-not $Quiet) { Write-Host "  stopped PID $ProcessId ($($proc.ProcessName))" }
        }
    } catch { }
}

if (-not $Quiet) {
    Write-Host "animate-stop: killing animation traffic..."
}

# 1) PIDs recorded by animate-start
if (Test-Path $pidFile) {
    Get-Content $pidFile | ForEach-Object {
        $id = 0
        if ([int]::TryParse("$_".Trim(), [ref]$id) -and $id -gt 0) {
            Stop-AnimateTree -ProcessId $id
        }
    }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

# 2) Sweep leftovers by command line (in case PID file missing / stale)
$patterns = @(
    'scripts\\animate\\',
    'scripts/animate/',
    'animate-live\.ps1',
    'load-traffic\.ps1',
    'mgmt-activity\.ps1',
    'animate-start\.ps1'
)
try {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        $cmd = $_.CommandLine
        if (-not $cmd) { return }
        foreach ($pat in $patterns) {
            if ($cmd -match $pat) {
                # don't kill THIS stop script's host if somehow matched
                if ($cmd -match 'animate-stop\.ps1') { return }
                Stop-AnimateTree -ProcessId ([int]$_.ProcessId)
                break
            }
        }
    }
} catch { }

if (-not $Quiet) {
    Write-Host "Done. Stopped ~$killed process tree(s)."
    Write-Host "Grafana panels on rate() will settle to 0 after ~1-2 minutes."
}
