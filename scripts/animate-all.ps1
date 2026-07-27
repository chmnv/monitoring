<#
.SYNOPSIS
  Run dashboard animation scripts sequentially (one board at a time).

.DESCRIPTION
  Default: all 01–15. Use -Dashboards to pick a subset (numbers or names).

.EXAMPLE
  .\scripts\animate-all.ps1
  .\scripts\animate-all.ps1 -DurationSec 45
  .\scripts\animate-all.ps1 -Dashboards 10,12,15 -DurationSec 60
  .\scripts\animate-all.ps1 -Dashboards auth,activation,recovery
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [string]$Container = "wildfly",
    [int]$DurationSec = 45,
    [int]$DelayMs = 100,
    [string[]]$Dashboards = @()
)

$ErrorActionPreference = "Continue"
$root = Join-Path $PSScriptRoot "animate"

$catalog = [ordered]@{
    "01" = @{ File = "01-platform.ps1";              Name = "platform";      Extra = @{} }
    "02" = @{ File = "02-windows-host.ps1";           Name = "windows";       Extra = @{} }
    "03" = @{ File = "03-jvm.ps1";                    Name = "jvm";           Extra = @{} }
    "04" = @{ File = "04-wildfly-http-db.ps1";        Name = "http";          Extra = @{} }
    "05" = @{ File = "05-wildfly-db.ps1";             Name = "db";            Extra = @{} }
    "06" = @{ File = "06-kitchensink-app.ps1";        Name = "business";      Extra = @{} }
    "07" = @{ File = "07-wildfly-logs.ps1";           Name = "logs";          Extra = @{ Container = $Container } }
    "08" = @{ File = "08-wildfly-security.ps1";       Name = "security";      Extra = @{ Container = $Container } }
    "09" = @{ File = "09-system-health.ps1";          Name = "health";        Extra = @{} }
    "10" = @{ File = "10-registration-quality.ps1";   Name = "registration";  Extra = @{} }
    "11" = @{ File = "11-search-discovery.ps1";       Name = "search";        Extra = @{} }
    "12" = @{ File = "12-auth-sessions.ps1";          Name = "auth";          Extra = @{} }
    "13" = @{ File = "13-account-activation.ps1";     Name = "activation";    Extra = @{} }
    "14" = @{ File = "14-account-recovery.ps1";       Name = "recovery";      Extra = @{} }
    "15" = @{ File = "15-app-authorization.ps1";      Name = "authorization"; Extra = @{} }
}

function Resolve-DashboardKeys {
    param([string[]]$Wanted)
    if (-not $Wanted -or $Wanted.Count -eq 0) {
        return @($catalog.Keys)
    }
    $keys = New-Object System.Collections.Generic.List[string]
    foreach ($w in $Wanted) {
        $token = "$w".Trim().ToLowerInvariant()
        if ($token -match '^\d+$') {
            $num = "{0:D2}" -f [int]$token
            if ($catalog.Contains($num)) { $keys.Add($num); continue }
        }
        $hit = $false
        foreach ($k in $catalog.Keys) {
            if ($catalog[$k].Name -eq $token -or $catalog[$k].File -like "*$token*") {
                $keys.Add($k)
                $hit = $true
                break
            }
        }
        if (-not $hit) {
            Write-Warning "Unknown dashboard selector: $w"
        }
    }
    return @($keys | Select-Object -Unique)
}

$selected = Resolve-DashboardKeys -Wanted $Dashboards
Write-Host "animate-all: $($selected.Count) dashboard(s), DurationSec=$DurationSec each"
Write-Host "Open Grafana http://localhost:3000 (Last 15m, refresh 10s)."
Write-Host ""

foreach ($key in $selected) {
    $entry = $catalog[$key]
    $scriptPath = Join-Path $root $entry.File
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Missing $scriptPath"
        continue
    }
    Write-Host "-------- $key $($entry.Name) --------"
    $args = @{
        DurationSec = $DurationSec
    }
    # Scripts that take BaseUrl
    $needsBase = $entry.File -notmatch '02-windows|08-wildfly-security'
    if ($needsBase) {
        # 08 has no BaseUrl; 02 neither. 07 has BaseUrl+Container.
        if ($entry.File -ne "08-wildfly-security.ps1" -and $entry.File -ne "02-windows-host.ps1") {
            $args.BaseUrl = $BaseUrl
        }
    }
    if ($entry.File -ne "08-wildfly-security.ps1" -and $entry.File -ne "02-windows-host.ps1") {
        $args.DelayMs = $DelayMs
    } elseif ($entry.File -eq "02-windows-host.ps1") {
        $args.DelayMs = [Math]::Max($DelayMs, 150)
    } else {
        $args.DelayMs = [Math]::Max($DelayMs, 500)
    }
    if ($entry.Extra.ContainsKey("Container")) {
        $args.Container = $entry.Extra.Container
    }

    & $scriptPath @args
    Write-Host ""
}

Write-Host "animate-all done."
