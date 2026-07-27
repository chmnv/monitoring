# Shared helpers for scripts/animate/*.ps1
# Dot-source: . "$PSScriptRoot\_common.ps1"

$ErrorActionPreference = "Continue"

function Get-AnimateRandSuffix {
    -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
}

function Write-AnimatePanel {
    param(
        [Parameter(Mandatory)][string]$Panel,
        [Parameter(Mandatory)][string]$Action
    )
    Write-Host ("  [{0}] {1} - {2}" -f (Get-Date -Format "HH:mm:ss"), $Panel, $Action)
}

function Write-AnimateHeader {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$GrafanaUrl,
        [int]$DurationSec = 60
    )
    Write-Host ""
    Write-Host "=== $Title ==="
    Write-Host "Grafana: $GrafanaUrl"
    Write-Host "Duration: ${DurationSec}s  (Ctrl+C to stop)"
    Write-Host ""
}

function Invoke-AnimateJson {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [ValidateSet("GET", "POST")][string]$Method = "GET",
        [hashtable]$Body = $null,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session = $null,
        [int]$TimeoutSec = 10
    )
    $params = @{
        Uri             = $Uri
        Method          = $Method
        UseBasicParsing = $true
        TimeoutSec      = $TimeoutSec
    }
    if ($Session) { $params.WebSession = $Session }
    if ($null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Compress)
        $params.ContentType = "application/json; charset=utf-8"
    }
    try {
        $resp = Invoke-WebRequest @params
        $json = $null
        try { $json = $resp.Content | ConvertFrom-Json } catch { }
        return [pscustomobject]@{
            Ok     = ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300)
            Status = [int]$resp.StatusCode
            Json   = $json
            Raw    = $resp.Content
        }
    } catch {
        $status = 0
        if ($_.Exception.Response) {
            try { $status = [int]$_.Exception.Response.StatusCode.value__ } catch { }
        }
        return [pscustomobject]@{
            Ok     = $false
            Status = $status
            Json   = $null
            Raw    = $_.Exception.Message
        }
    }
}

function New-AnimateSession {
    New-Object Microsoft.PowerShell.Commands.WebRequestSession
}

function Get-AnimateEndTime {
    param([int]$DurationSec)
    return [DateTime]::UtcNow.AddSeconds($DurationSec)
}

function Test-AnimateStillRunning {
    param([DateTime]$End)
    return [DateTime]::UtcNow -lt $End
}

function Invoke-AnimateHttpLoad {
    <#
      Mix of list / HTML / by-id / search / register - feeds Undertow, DS, app metrics.
    #>
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [switch]$IncludePost,
        [switch]$IncludeFailures
    )
    $rest = "$BaseUrl/rest/members"
    $roll = Get-Random -Maximum 100
    if ($roll -lt 30) {
        Invoke-AnimateJson -Uri $rest | Out-Null
        return "list"
    }
    if ($roll -lt 45) {
        Invoke-AnimateJson -Uri "$BaseUrl/" | Out-Null
        return "html"
    }
    if ($roll -lt 60) {
        $id = if ((Get-Random -Maximum 2) -eq 0) { Get-Random -Minimum 0 -Maximum 5 } else { Get-Random -Minimum 900000 -Maximum 999999 }
        Invoke-AnimateJson -Uri "$rest/$id" | Out-Null
        return "byid"
    }
    if ($roll -lt 75) {
        $q = @("Load", "Jane", "a", "zzznofind", "")[(Get-Random -Maximum 5)]
        $uri = if ([string]::IsNullOrEmpty($q)) { "$rest/search" } else { "$rest/search?q=$([uri]::EscapeDataString($q))" }
        Invoke-AnimateJson -Uri $uri | Out-Null
        return "search"
    }
    if ($IncludePost -or $IncludeFailures) {
        $suffix = Get-AnimateRandSuffix
        if ($IncludeFailures -and (Get-Random -Maximum 100) -lt 40) {
            $bodies = @(
                @{ name = "Bad123"; email = "bad-$suffix@example.com"; phoneNumber = "2125551234" },
                @{ name = "Bad Email $suffix"; email = "not-an-email"; phoneNumber = "2125559999" },
                @{ name = "Bad Phone $suffix"; email = "bad-phone-$suffix@example.com"; phoneNumber = "12ab" },
                @{ name = "Jane Doe"; email = "jane.doe@mailinator.com"; phoneNumber = "2125551234" }
            )
            $body = $bodies[(Get-Random -Maximum $bodies.Count)]
            Invoke-AnimateJson -Uri $rest -Method POST -Body $body | Out-Null
            return "fail"
        }
        $body = @{
            name        = "Load User $suffix"
            email       = "load-$suffix-$(Get-Random)@example.com"
            phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
        }
        $r = Invoke-AnimateJson -Uri $rest -Method POST -Body $body
        if ($r.Ok -and $r.Json.activationToken -and ((Get-Random -Maximum 100) -lt 70)) {
            Invoke-AnimateJson -Uri "$BaseUrl/rest/auth/activate" -Method POST -Body @{ token = $r.Json.activationToken } | Out-Null
        }
        return "post"
    }
    Invoke-AnimateJson -Uri $rest | Out-Null
    return "list"
}
