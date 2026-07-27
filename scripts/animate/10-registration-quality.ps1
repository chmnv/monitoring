<#
.SYNOPSIS
  Animate dashboard 10 Registration Quality & Validation.

.DESCRIPTION
  Panel map:
    Attempts / Success Rate / Success vs Failures     → mix success + failures
    Validation / sec / Field Friction / by Field       → bad name / email / phone
    Duplicate Email / Failures by Reason               → jane.doe duplicate
    Other Errors / Constraint table                    → same failure branches
    Failure Friction                                   → failures / attempts ratio

.EXAMPLE
  .\scripts\animate\10-registration-quality.ps1
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$DurationSec = 60,
    [int]$DelayMs = 120
)

. "$PSScriptRoot\_common.ps1"
Write-AnimateHeader -Title "10 Registration Quality" -GrafanaUrl "http://localhost:3000/d/registration-quality" -DurationSec $DurationSec
$end = Get-AnimateEndTime $DurationSec
$n = 0
$rest = "$BaseUrl/rest/members"

while (Test-AnimateStillRunning $end) {
    $n++
    $step = $n % 5
    $suffix = Get-AnimateRandSuffix
    switch ($step) {
        0 {
            Write-AnimatePanel "Attempts / Success Rate" "successful register"
            $r = Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Load User $suffix"; email = "rq-$suffix-$(Get-Random)@example.com"
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            }
            if ($r.Ok -and $r.Json.activationToken) {
                Invoke-AnimateJson -Uri "$BaseUrl/rest/auth/activate" -Method POST -Body @{ token = $r.Json.activationToken } | Out-Null
            }
        }
        1 {
            Write-AnimatePanel "Validation / Field Friction (name)" "Bad123 Pattern"
            Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Bad123"; email = "bad-name-$suffix@example.com"; phoneNumber = "2125551234"
            } | Out-Null
        }
        2 {
            Write-AnimatePanel "Validation / Field Friction (email)" "not-an-email"
            Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Bad Email $suffix"; email = "not-an-email"; phoneNumber = "2125559999"
            } | Out-Null
        }
        3 {
            Write-AnimatePanel "Validation / Field Friction (phone)" "12ab Digits/Size"
            Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Bad Phone $suffix"; email = "bad-phone-$suffix@example.com"; phoneNumber = "12ab"
            } | Out-Null
        }
        4 {
            Write-AnimatePanel "Duplicate Email / Failures by Reason" "jane.doe"
            Invoke-AnimateJson -Uri $rest -Method POST -Body @{
                name = "Jane Doe"; email = "jane.doe@mailinator.com"; phoneNumber = "2125551234"
            } | Out-Null
        }
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Done ($n steps). Open http://localhost:3000/d/registration-quality"
