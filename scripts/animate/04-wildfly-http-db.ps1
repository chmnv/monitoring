<#
.SYNOPSIS
  Animate dashboard 04 WildFly HTTP & Datasources.

.DESCRIPTION
  Panel map:
    Requests / sec / Request Rate / Throughput / Request Time → HTTP GET/POST
    Listener Error Rate / Listener Errors                     → occasional bad paths + load
    Active Sessions / Session Churn                           → HTML (JSF) + login sessions
    DB Conn In Use / Pool* / Wait / Churn                     → list/search/register (DS)

.EXAMPLE
  .\scripts\animate\04-wildfly-http-db.ps1
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$DurationSec = 60,
    [int]$DelayMs = 80
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "04 WildFly HTTP & Datasources" -GrafanaUrl "http://localhost:3000/d/wildfly-http-db" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0
$auth = "$BaseUrl/rest/auth"

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 4
    switch ($step) {
        0 {
            Write-AnimatePanel "Requests / Throughput / Request Time" "list+html+byid"
            Invoke-AnimateHttpLoad -BaseUrl $BaseUrl | Out-Null
            Invoke-AnimateHttpLoad -BaseUrl $BaseUrl | Out-Null
        }
        1 {
            Write-AnimatePanel "DB Conn / Pool / Wait" "search+register"
            Invoke-AnimateHttpLoad -BaseUrl $BaseUrl -IncludePost | Out-Null
        }
        2 {
            Write-AnimatePanel "Active Sessions / Session Churn" "JSF + app login/logout"
            Invoke-AnimateJson -Uri "$BaseUrl/" | Out-Null
            $s = New-AnimateSession
            Invoke-AnimateJson -Uri "$auth/login" -Method POST -Body @{ email = "john.smith@mailinator.com"; password = "demo" } -Session $s | Out-Null
            if ((Get-Random -Maximum 100) -lt 60) {
                Invoke-AnimateJson -Uri "$auth/logout" -Method POST -Session $s | Out-Null
            }
        }
        3 {
            Write-AnimatePanel "Listener Errors" "404 path + miss id"
            try { Invoke-WebRequest -Uri "$BaseUrl/no-such-page-$n" -UseBasicParsing -TimeoutSec 5 | Out-Null } catch { }
            Invoke-AnimateJson -Uri "$BaseUrl/rest/members/999999" | Out-Null
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/wildfly-http-db"
