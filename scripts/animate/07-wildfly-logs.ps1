<#
.SYNOPSIS
  Animate dashboard 07 WildFly Logs.

.DESCRIPTION
  Panel map:
    Total Lines / Ingest Rate / Log Volume by Level / Live Logs → app traffic (INFO)
    Warnings / Warnings & Errors                                → jboss-cli noise + 404s
    Errors                                                      → failed ops / bad requests (when present)
    Top Loggers / Info / Debug                                  → volume from Undertow + app

.EXAMPLE
  .\scripts\animate\07-wildfly-logs.ps1
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [string]$Container = "wildfly",
    [int]$DurationSec = 60,
    [int]$DelayMs = 120
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "07 WildFly Logs" -GrafanaUrl "http://localhost:3000/d/wildfly-logs" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0
$cli = "/opt/jboss/wildfly/bin/jboss-cli.sh"

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 3
    switch ($step) {
        0 {
            Write-AnimatePanel "Total Lines / Info / Live Logs" "HTTP traffic"
            Invoke-AnimateHttpLoad -BaseUrl $BaseUrl -IncludePost | Out-Null
        }
        1 {
            Write-AnimatePanel "Warnings / Errors volume" "404 + miss id"
            try { Invoke-WebRequest -Uri "$BaseUrl/missing-$n.html" -UseBasicParsing -TimeoutSec 5 | Out-Null } catch { }
            Invoke-AnimateJson -Uri "$BaseUrl/rest/members/888777" | Out-Null
        }
        2 {
            Write-AnimatePanel "Top Loggers / mgmt noise" "jboss-cli read-attribute"
            try {
                docker exec $Container $cli --connect --command=":read-attribute(name=server-state)" 2>&1 | Out-Null
            } catch { }
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/wildfly-logs"
