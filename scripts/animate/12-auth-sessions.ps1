<#
.SYNOPSIS
  Animate dashboard 12 Authentication & Sessions.

.DESCRIPTION
  Panel map:
    Logins / Success Rate / Outcomes success / Duration / p95 → john login
    Bad Credentials                                           → wrong password
    Unknown User                                              → nobody@...
    Active Sessions / Sessions & Logouts / Login vs Logout    → login then logout
    not_activated (in Outcomes)                               → pending register + login

.EXAMPLE
  .\scripts\animate\12-auth-sessions.ps1
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$DurationSec = 60,
    [int]$DelayMs = 150
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "12 Authentication & Sessions" -GrafanaUrl "http://localhost:3000/d/auth-sessions" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0
$auth = "$BaseUrl/rest/auth"
$rest = "$BaseUrl/rest/members"

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 5
    switch ($step) {
        0 {
            Write-AnimatePanel "Logins success / Active Sessions / Duration" "john login (+logout)"
            $s = New-AnimateSession
            Invoke-AnimateJson -Uri "$auth/login" -Method POST -Body @{
                email = "john.smith@mailinator.com"; password = "demo"
            } -Session $s | Out-Null
            if ((Get-Random -Maximum 100) -lt 70) {
                Write-AnimatePanel "Logouts / Sessions & Logouts" "logout"
                Invoke-AnimateJson -Uri "$auth/logout" -Method POST -Session $s | Out-Null
            }
        }
        1 {
            Write-AnimatePanel "Bad Credentials / sec" "wrong password"
            Invoke-AnimateJson -Uri "$auth/login" -Method POST -Body @{
                email = "john.smith@mailinator.com"; password = "wrong-$n"
            } | Out-Null
        }
        2 {
            Write-AnimatePanel "Unknown User / sec" "nobody email"
            Invoke-AnimateJson -Uri "$auth/login" -Method POST -Body @{
                email = "nobody-$n@example.com"; password = "demo"
            } | Out-Null
        }
        3 {
            Write-AnimatePanel "Outcomes not_activated" "pending login"
            $suffix = Get-AnimateRandSuffix
            $email = "pending-$suffix-$(Get-Random)@example.com"
            Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Load User $suffix"; email = $email
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            } | Out-Null
            Invoke-AnimateJson -Uri "$auth/login" -Method POST -Body @{
                email = $email; password = "demo"
            } | Out-Null
        }
        4 {
            Write-AnimatePanel "Login vs Logout / session check" "login + GET session"
            $s = New-AnimateSession
            Invoke-AnimateJson -Uri "$auth/login" -Method POST -Body @{
                email = "jane.doe@mailinator.com"; password = "demo"
            } -Session $s | Out-Null
            Invoke-AnimateJson -Uri "$auth/session" -Session $s | Out-Null
            Invoke-AnimateJson -Uri "$auth/logout" -Method POST -Session $s | Out-Null
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/auth-sessions"
