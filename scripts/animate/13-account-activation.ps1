<#
.SYNOPSIS
  Animate dashboard 13 Account Activation.

.DESCRIPTION
  Panel map:
    Activations / Success Rate / Outcomes success / Duration / Funnel → register+activate
    already_activated                                                  → activate twice
    invalid_token                                                      → bad token
    Expired / sec                                                      → expire helper + activate
    Pending Accounts / Pending vs Activated                            → leave some pending
    Login Blocked (pending)                                            → login before activate

.EXAMPLE
  .\scripts\animate\13-account-activation.ps1
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$DurationSec = 60,
    [int]$DelayMs = 150
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "13 Account Activation" -GrafanaUrl "http://localhost:3000/d/account-activation" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0
$auth = "$BaseUrl/rest/auth"
$rest = "$BaseUrl/rest/members"

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 5
    $suffix = Get-AnimateRandSuffix
    switch ($step) {
        0 {
            Write-AnimatePanel "Activations success / Funnel / Duration" "register+activate (+retry)"
            $r = Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Load User $suffix"; email = "act-$suffix-$(Get-Random)@example.com"
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            }
            if ($r.Ok -and $r.Json.activationToken) {
                $tok = $r.Json.activationToken
                Invoke-AnimateJson -Uri "$auth/activate" -Method POST -Body @{ token = $tok } | Out-Null
                if ((Get-Random -Maximum 100) -lt 40) {
                    Write-AnimatePanel "already_activated" "activate twice"
                    Invoke-AnimateJson -Uri "$auth/activate" -Method POST -Body @{ token = $tok } | Out-Null
                }
            }
        }
        1 {
            Write-AnimatePanel "invalid_token" "bad token"
            Invoke-AnimateJson -Uri "$auth/activate" -Method POST -Body @{ token = "badtoken$n$(Get-Random)" } | Out-Null
        }
        2 {
            Write-AnimatePanel "Expired / sec" "expire helper + activate"
            $r = Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Load User $suffix"; email = "exp-$suffix-$(Get-Random)@example.com"
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            }
            if ($r.Ok -and $r.Json.activationToken) {
                $tok = $r.Json.activationToken
                Invoke-AnimateJson -Uri "$auth/activation/expire" -Method POST -Body @{ token = $tok } | Out-Null
                Invoke-AnimateJson -Uri "$auth/activate" -Method POST -Body @{ token = $tok } | Out-Null
            }
        }
        3 {
            Write-AnimatePanel "Pending Accounts" "register leave pending"
            Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Load User $suffix"; email = "pend-$suffix-$(Get-Random)@example.com"
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            } | Out-Null
        }
        4 {
            Write-AnimatePanel "Login Blocked (pending)" "login before activate"
            $email = "block-$suffix-$(Get-Random)@example.com"
            Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Load User $suffix"; email = $email
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            } | Out-Null
            Invoke-AnimateJson -Uri "$auth/login" -Method POST -Body @{ email = $email; password = "demo" } | Out-Null
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/account-activation"
