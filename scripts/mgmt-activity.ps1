<#
.SYNOPSIS
  Generate WildFly management activity so the Security & Audit dashboard is not static.

.DESCRIPTION
  Prometheus scraping :9990 only produces read-only audit events. This script runs
  real management operations via jboss-cli inside the container, including WRITE ops
  (add/remove a harmless system property), so these audit panels move:
    - Write Operations  ("r/o": false)
    - Top Management Operations (add / remove / write-attribute / read-*)
    - Audit Rate / Audit Trail / Operations by Access Channel
  All changes are reversible (the demo system property is removed each round).

.EXAMPLE
  .\scripts\mgmt-activity.ps1
  .\scripts\mgmt-activity.ps1 -Rounds 40 -DelayMs 500
#>
param(
    [string]$Container = "wildfly",
    [int]$Rounds = 20,
    [int]$DelayMs = 750
)

$ErrorActionPreference = "Continue"
$cli = "/opt/jboss/wildfly/bin/jboss-cli.sh"

Write-Host "Management activity -> container '$Container'  rounds=$Rounds  delay=${DelayMs}ms"
Write-Host "Drives the Security & Audit dashboard (read + write mgmt ops). Ctrl+C to stop."
Write-Host ""

for ($i = 1; $i -le $Rounds; $i++) {
    $prop = "demo.metric.$i"
    # A batch of read + write + read + remove ops in one CLI session (one connect).
    $commands = @(
        ":read-attribute(name=server-state)",
        "/system-property=$prop`:add(value=$i)",
        "/system-property=$prop`:read-resource",
        "/system-property=$prop`:write-attribute(name=value,value=$($i * 10))",
        "/system-property=$prop`:remove"
    ) -join ","

    docker exec $Container $cli --connect --commands="$commands" 2>&1 | Out-Null

    if ($i % 5 -eq 0) {
        Write-Host ("[{0}] round {1}/{2} (read+add+write+remove)" -f (Get-Date -Format "HH:mm:ss"), $i, $Rounds)
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host ""
Write-Host "Done. Check: http://localhost:3000/d/wildfly-security"
