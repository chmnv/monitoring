<#
.SYNOPSIS
  Animate dashboard 14 Account Recovery.

.DESCRIPTION
  Panel map:
    Requests / Reset Success / Funnel / completed / Duration → register+activate+request+reset+login
    Request Outcomes unknown_user                            → nobody email
    Request Outcomes not_activated                           → pending recover
    Reset Outcomes invalid_token                             → bad token
    Expired / Open Recovery Tokens                           → expire helper + reset
    Post-reset Login OK                                      → login after reset

  Never mutates seeded john.smith password.

.EXAMPLE
  .\scripts\animate\14-account-recovery.ps1
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$DurationSec = 60,
    [int]$DelayMs = 180
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "14 Account Recovery" -GrafanaUrl "http://localhost:3000/d/account-recovery" -DurationSec $DurationSec
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
            Write-AnimatePanel "Request->Reset Funnel / Post-reset Login / Duration" "full success path"
            $email = "rec-$suffix-$(Get-Random)@example.com"
            $newPass = "reset-$suffix"
            $r = Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Load User $suffix"; email = $email
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            }
            if ($r.Ok -and $r.Json.activationToken) {
                Invoke-AnimateJson -Uri "$auth/activate" -Method POST -Body @{ token = $r.Json.activationToken } | Out-Null
            }
            $req = Invoke-AnimateJson -Uri "$auth/recovery/request" -Method POST -Body @{ email = $email }
            if ($req.Ok -and $req.Json.recoveryToken) {
                Invoke-AnimateJson -Uri "$auth/recovery/reset" -Method POST -Body @{
                    token = $req.Json.recoveryToken; password = $newPass
                } | Out-Null
                Invoke-AnimateJson -Uri "$auth/login" -Method POST -Body @{
                    email = $email; password = $newPass
                } | Out-Null
            }
        }
        1 {
            Write-AnimatePanel "Requests unknown_user" "nobody email"
            Invoke-AnimateJson -Uri "$auth/recovery/request" -Method POST -Body @{
                email = "nobody-rec-$n-$(Get-Random)@example.com"
            } | Out-Null
        }
        2 {
            Write-AnimatePanel "Requests not_activated" "pending recover"
            $email = "pend-rec-$suffix-$(Get-Random)@example.com"
            Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Load User $suffix"; email = $email
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            } | Out-Null
            Invoke-AnimateJson -Uri "$auth/recovery/request" -Method POST -Body @{ email = $email } | Out-Null
        }
        3 {
            Write-AnimatePanel "Resets invalid_token" "bad recovery token"
            Invoke-AnimateJson -Uri "$auth/recovery/reset" -Method POST -Body @{
                token = "badrec$n$(Get-Random)"; password = "x"
            } | Out-Null
        }
        4 {
            Write-AnimatePanel "Expired / Open Recovery Tokens" "expire + reset"
            $email = "recexp-$suffix-$(Get-Random)@example.com"
            $r = Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Load User $suffix"; email = $email
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            }
            if ($r.Ok -and $r.Json.activationToken) {
                Invoke-AnimateJson -Uri "$auth/activate" -Method POST -Body @{ token = $r.Json.activationToken } | Out-Null
            }
            $req = Invoke-AnimateJson -Uri "$auth/recovery/request" -Method POST -Body @{ email = $email }
            if ($req.Ok -and $req.Json.recoveryToken) {
                $tok = $req.Json.recoveryToken
                Invoke-AnimateJson -Uri "$auth/recovery/expire" -Method POST -Body @{ token = $tok } | Out-Null
                Invoke-AnimateJson -Uri "$auth/recovery/reset" -Method POST -Body @{
                    token = $tok; password = "too-late"
                } | Out-Null
            }
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/account-recovery"
