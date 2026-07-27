<#
.SYNOPSIS
  Animate dashboard 06 Application - Kitchensink Business.

.DESCRIPTION
  Panel map:
    Members / Members Over Time / Registrations* / Success Rate / Duration* → successful POSTs
    Failures Total / by Reason / Activity logs                              → validation + duplicate

.EXAMPLE
  .\scripts\animate\06-kitchensink-app.ps1
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$DurationSec = 60,
    [int]$DelayMs = 100
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "06 Kitchensink Business" -GrafanaUrl "http://localhost:3000/d/kitchensink-app" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0
$rest = "$BaseUrl/rest/members"

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 3
    switch ($step) {
        0 {
            Write-AnimatePanel "Registrations / Members / Duration" "successful register"
            $suffix = Get-AnimateRandSuffix
            $r = Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name        = "Load User $suffix"
                email       = "biz-$suffix-$(Get-Random)@example.com"
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            }
            if ($r.Ok -and $r.Json.activationToken) {
                Invoke-AnimateJson -Uri "$BaseUrl/rest/auth/activate" -Method POST -Body @{ token = $r.Json.activationToken } | Out-Null
            }
        }
        1 {
            Write-AnimatePanel "Failures by Reason (validation)" "bad name/email/phone"
            $suffix = Get-AnimateRandSuffix
            $pick = Get-Random -Maximum 3
            if ($pick -eq 0) {
                Invoke-AnimateJson -Uri $rest -Method POST -Body @{ name = "Bad123"; email = "x-$suffix@example.com"; phoneNumber = "2125551234" } | Out-Null
            } elseif ($pick -eq 1) {
                Invoke-AnimateJson -Uri $rest -Method POST -Body @{ name = "Bad Email $suffix"; email = "not-an-email"; phoneNumber = "2125559999" } | Out-Null
            } else {
                Invoke-AnimateJson -Uri $rest -Method POST -Body @{ name = "Bad Phone $suffix"; email = "p-$suffix@example.com"; phoneNumber = "12ab" } | Out-Null
            }
        }
        2 {
            Write-AnimatePanel "Failures by Reason (duplicate)" "jane.doe duplicate"
            Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Jane Doe"; email = "jane.doe@mailinator.com"; phoneNumber = "2125551234"
            } | Out-Null
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/kitchensink-app"
