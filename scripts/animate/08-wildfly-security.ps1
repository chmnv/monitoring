<#
.SYNOPSIS
  Animate dashboard 08 WildFly Security & Audit.

.DESCRIPTION
  Panel map (via mgmt-activity.ps1):
    Total / Admin / Write / Failed Operations / Audit Rate → jboss-cli read+add+write+remove
    Operations by Access Channel / User / Top Ops / Audit Trail → same CLI rounds
    Security Events (server log)                                 → side-effect of mgmt

.EXAMPLE
  .\scripts\animate\08-wildfly-security.ps1 -DurationSec 60
#>
param(
    [string]$Container = "wildfly",
    [int]$DurationSec = 60,
    [int]$DelayMs = 750
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "08 WildFly Security & Audit" -GrafanaUrl "http://localhost:3000/d/wildfly-security" -DurationSec $DurationSec

$rounds = [Math]::Max(5, [int]($DurationSec / ([Math]::Max(0.5, $DelayMs / 1000.0))))
Write-AnimatePanel "Write Ops / Audit Trail / Top Operations" "mgmt-activity rounds=$rounds"
& "$PSScriptRoot\..\mgmt-activity.ps1" -Container $Container -Rounds $rounds -DelayMs $DelayMs

Write-Host "Done. Open http://localhost:3000/d/wildfly-security"
