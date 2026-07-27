<#
.SYNOPSIS
  Animate dashboard 02 Windows Host (no fake Prometheus metrics).

.DESCRIPTION
  Panel map:
    CPU Busy / Per-core / CPU by mode     → CPU burn loop
    RAM Used / Memory Used vs Total       → allocate+release byte arrays
    Disk C: / Disk by volume / Disk I/O   → temp file write/read/delete
    Network* / Processes / Threads / Uptime → real host (windows_exporter); light I/O helps

.EXAMPLE
  .\scripts\animate\02-windows-host.ps1 -DurationSec 45
#>
param(
    [int]$DurationSec = 60,
    [int]$DelayMs = 200
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "02 Windows Host" -GrafanaUrl "http://localhost:3000/d/windows-host" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0
$tmp = Join-Path $env:TEMP "kitchensink-animate-host.bin"

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 3
    switch ($step) {
        0 {
            Write-AnimatePanel "CPU Busy / Per-core" "CPU burn ~150ms"
            $t = [Diagnostics.Stopwatch]::StartNew()
            while ($t.ElapsedMilliseconds -lt 150) {
                [Math]::Sqrt((Get-Random)) | Out-Null
            }
        }
        1 {
            Write-AnimatePanel "RAM Used" "allocate ~32MB briefly"
            $buf = New-Object byte[] (32MB)
            [Array]::Clear($buf, 0, 1)
            Start-Sleep -Milliseconds 50
            $buf = $null
            [GC]::Collect()
        }
        2 {
            Write-AnimatePanel "Disk C: / Disk I/O" "write+read temp file"
            $bytes = New-Object byte[] (1MB)
            (New-Object Random).NextBytes($bytes)
            [IO.File]::WriteAllBytes($tmp, $bytes)
            [IO.File]::ReadAllBytes($tmp) | Out-Null
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/windows-host"
Write-Host "Note: windows_exporter must be up on :9182."
