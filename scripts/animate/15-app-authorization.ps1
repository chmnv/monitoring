<#
.SYNOPSIS
  Animate dashboard 15 Authorization & Privileged Ops.

.DESCRIPTION
  Panel map:
    Authz / Allow Rate / Outcomes allowed / Duration by Op → admin stats + export
    Denied / sec / Allow-Deny by Operation                 → jane member → stats
    Unauthenticated / sec                                  → stats without session
    set_role allowed / Accounts by Role / Admins           → promote+demote ephemeral
    Outcomes (total) / p95                                 → all of the above

.EXAMPLE
  .\scripts\animate\15-app-authorization.ps1
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$DurationSec = 60,
    [int]$DelayMs = 180
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "15 Authorization & Privileged Ops" -GrafanaUrl "http://localhost:3000/d/app-authorization" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0
$auth = "$BaseUrl/rest/auth"
$admin = "$BaseUrl/rest/admin"
$rest = "$BaseUrl/rest/members"

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 4
    switch ($step) {
        0 {
            Write-AnimatePanel "Allowed stats/export / Allow Rate / Duration" "john admin"
            $s = New-AnimateSession
            Invoke-AnimateJson -Uri "$auth/login" -Method POST -Body @{
                email = "john.smith@mailinator.com"; password = "demo"
            } -Session $s | Out-Null
            if ((Get-Random -Maximum 2) -eq 0) {
                Invoke-AnimateJson -Uri "$admin/stats" -Session $s | Out-Null
            } else {
                Invoke-AnimateJson -Uri "$admin/export" -Session $s | Out-Null
            }
        }
        1 {
            Write-AnimatePanel "Denied / sec" "jane member -> stats"
            $s = New-AnimateSession
            Invoke-AnimateJson -Uri "$auth/login" -Method POST -Body @{
                email = "jane.doe@mailinator.com"; password = "demo"
            } -Session $s | Out-Null
            Invoke-AnimateJson -Uri "$admin/stats" -Session $s | Out-Null
        }
        2 {
            Write-AnimatePanel "Unauthenticated / sec" "stats no session"
            Invoke-AnimateJson -Uri "$admin/stats" | Out-Null
        }
        3 {
            Write-AnimatePanel "set_role / Accounts by Role / Admins" "promote+demote ephemeral"
            $suffix = Get-AnimateRandSuffix
            $email = "authz-$suffix-$(Get-Random)@example.com"
            $r = Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Load User $suffix"; email = $email
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            }
            if ($r.Ok -and $r.Json.activationToken) {
                Invoke-AnimateJson -Uri "$auth/activate" -Method POST -Body @{ token = $r.Json.activationToken } | Out-Null
            }
            $s = New-AnimateSession
            Invoke-AnimateJson -Uri "$auth/login" -Method POST -Body @{
                email = "john.smith@mailinator.com"; password = "demo"
            } -Session $s | Out-Null
            Invoke-AnimateJson -Uri "$admin/role" -Method POST -Body @{ email = $email; role = "admin" } -Session $s | Out-Null
            Invoke-AnimateJson -Uri "$admin/role" -Method POST -Body @{ email = $email; role = "member" } -Session $s | Out-Null
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/app-authorization"
