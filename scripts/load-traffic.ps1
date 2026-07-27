<#
.SYNOPSIS
  Continuous traffic against kitchensink so Grafana panels move (not flat).

.EXAMPLE
  .\scripts\load-traffic.ps1 -Failures
  .\scripts\load-traffic.ps1 -DurationSec 600 -DelayMs 50 -Workers 6 -Failures
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$DurationSec = 300,
    [int]$DelayMs = 80,
    [int]$Workers = 6,
    [switch]$Failures
)

$ErrorActionPreference = "Continue"
$rest = "$BaseUrl/rest/members"
$end = [DateTime]::UtcNow.AddSeconds($DurationSec)
$ok = 0; $fail = 0; $get = 0; $n = 0

$sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$pool = [RunspaceFactory]::CreateRunspacePool(1, [Math]::Max(1, $Workers), $sessionState, $Host)
$pool.Open()

$workerScript = {
    param($BaseUrl, $Rest, $DoFailures, $Index)
    $ErrorActionPreference = "Continue"
    $roll = Get-Random -Maximum 100
    try {
        if ($roll -lt 28) {
            # List members -> findAll DB op + Undertow GET
            Invoke-WebRequest -Uri $Rest -UseBasicParsing -TimeoutSec 10 | Out-Null
            return "get"
        }
        if ($roll -lt 36) {
            # HTML page -> Undertow request + JSF session
            Invoke-WebRequest -Uri "$BaseUrl/" -UseBasicParsing -TimeoutSec 10 | Out-Null
            return "get"
        }
        if ($roll -lt 44) {
            # Lookup by id -> findById DB op. Mix hits (200) and misses (404).
            $id = if ((Get-Random -Maximum 2) -eq 0) { Get-Random -Minimum 1 -Maximum 8 } else { Get-Random -Minimum 900000 -Maximum 999999 }
            try {
                Invoke-WebRequest -Uri "$Rest/$id" -UseBasicParsing -TimeoutSec 10 | Out-Null
            } catch { }
            return "get"
        }
        if ($roll -lt 54) {
            # Dashboard 11 — search hit / zero / empty / refine
            $pick = Get-Random -Maximum 100
            if ($pick -lt 40) {
                $q = "Load"
            } elseif ($pick -lt 55) {
                $q = "Jane"
            } elseif ($pick -lt 70) {
                $q = "zzznofind$Index"
            } elseif ($pick -lt 85) {
                $q = "a"
            } else {
                $q = ""
            }
            $uri = if ([string]::IsNullOrEmpty($q)) { "$Rest/search" } else { "$Rest/search?q=$([uri]::EscapeDataString($q))" }
            try {
                Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 10 | Out-Null
            } catch { }
            return "get"
        }
        if ($roll -lt 66) {
            # Dashboard 12 — app login / logout
            $auth = "$BaseUrl/rest/auth"
            $pick = Get-Random -Maximum 100
            $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            if ($pick -lt 50) {
                $body = @{ email = "john.smith@mailinator.com"; password = "demo" } | ConvertTo-Json -Compress
                try {
                    Invoke-WebRequest -Uri "$auth/login" -Method POST -Body $body -ContentType "application/json; charset=utf-8" -WebSession $session -UseBasicParsing -TimeoutSec 10 | Out-Null
                    if ((Get-Random -Maximum 100) -lt 60) {
                        Invoke-WebRequest -Uri "$auth/logout" -Method POST -WebSession $session -UseBasicParsing -TimeoutSec 10 | Out-Null
                    }
                } catch { }
                return "get"
            }
            if ($pick -lt 70) {
                $body = @{ email = "john.smith@mailinator.com"; password = "wrong-$Index" } | ConvertTo-Json -Compress
                try {
                    Invoke-WebRequest -Uri "$auth/login" -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                } catch { }
                return "fail"
            }
            if ($pick -lt 85) {
                # Unknown user
                $body = @{ email = "nobody-$Index@example.com"; password = "demo" } | ConvertTo-Json -Compress
                try {
                    Invoke-WebRequest -Uri "$auth/login" -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                } catch { }
                return "fail"
            }
            # not_activated: register pending user, try login before activate
            $suffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
            $email = "pending-$suffix-$(Get-Random)@example.com"
            $reg = @{ name = "Load User $suffix"; email = $email; phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000)) } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri $Rest -Method POST -Body $reg -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                $loginBody = @{ email = $email; password = "demo" } | ConvertTo-Json -Compress
                Invoke-WebRequest -Uri "$auth/login" -Method POST -Body $loginBody -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
            } catch { }
            return "fail"
        }
        if ($roll -lt 76) {
            # Dashboard 13 — account activation funnel
            $auth = "$BaseUrl/rest/auth"
            $pick = Get-Random -Maximum 100
            if ($pick -lt 45) {
                # Register + activate (success); sometimes activate twice (already_activated)
                $suffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
                $reg = @{
                    name        = "Load User $suffix"
                    email       = "act-$suffix-$(Get-Random)@example.com"
                    phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
                } | ConvertTo-Json -Compress
                try {
                    $resp = Invoke-WebRequest -Uri $Rest -Method POST -Body $reg -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10
                    $json = $resp.Content | ConvertFrom-Json
                    $tok = $json.activationToken
                    if ($tok) {
                        $ab = @{ token = $tok } | ConvertTo-Json -Compress
                        Invoke-WebRequest -Uri "$auth/activate" -Method POST -Body $ab -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                        if ((Get-Random -Maximum 100) -lt 35) {
                            try {
                                Invoke-WebRequest -Uri "$auth/activate" -Method POST -Body $ab -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                            } catch { }
                        }
                    }
                    return "ok"
                } catch { return "fail" }
            }
            if ($pick -lt 70) {
                # invalid_token
                $ab = @{ token = "badtoken$Index$(Get-Random)" } | ConvertTo-Json -Compress
                try {
                    Invoke-WebRequest -Uri "$auth/activate" -Method POST -Body $ab -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                } catch { }
                return "fail"
            }
            # expired: register → force expire → activate
            $suffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
            $reg = @{
                name        = "Load User $suffix"
                email       = "exp-$suffix-$(Get-Random)@example.com"
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            } | ConvertTo-Json -Compress
            try {
                $resp = Invoke-WebRequest -Uri $Rest -Method POST -Body $reg -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10
                $json = $resp.Content | ConvertFrom-Json
                $tok = $json.activationToken
                if ($tok) {
                    $ab = @{ token = $tok } | ConvertTo-Json -Compress
                    Invoke-WebRequest -Uri "$auth/activation/expire" -Method POST -Body $ab -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                    try {
                        Invoke-WebRequest -Uri "$auth/activate" -Method POST -Body $ab -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                    } catch { }
                }
            } catch { }
            return "fail"
        }
        if ($roll -lt 86) {
            # Dashboard 14 — account recovery (never mutate seeded john.smith password)
            $auth = "$BaseUrl/rest/auth"
            $pick = Get-Random -Maximum 100
            if ($pick -lt 40) {
                # success: register → activate → request → reset → login with new password
                $suffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
                $email = "rec-$suffix-$(Get-Random)@example.com"
                $newPass = "reset-$suffix"
                $reg = @{
                    name        = "Load User $suffix"
                    email       = $email
                    phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
                } | ConvertTo-Json -Compress
                try {
                    $resp = Invoke-WebRequest -Uri $Rest -Method POST -Body $reg -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10
                    $json = $resp.Content | ConvertFrom-Json
                    if ($json.activationToken) {
                        $ab = @{ token = $json.activationToken } | ConvertTo-Json -Compress
                        Invoke-WebRequest -Uri "$auth/activate" -Method POST -Body $ab -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                    }
                    $req = @{ email = $email } | ConvertTo-Json -Compress
                    $rresp = Invoke-WebRequest -Uri "$auth/recovery/request" -Method POST -Body $req -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10
                    $rtok = ($rresp.Content | ConvertFrom-Json).recoveryToken
                    if ($rtok) {
                        $rb = @{ token = $rtok; password = $newPass } | ConvertTo-Json -Compress
                        Invoke-WebRequest -Uri "$auth/recovery/reset" -Method POST -Body $rb -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                        $login = @{ email = $email; password = $newPass } | ConvertTo-Json -Compress
                        Invoke-WebRequest -Uri "$auth/login" -Method POST -Body $login -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                    }
                    return "ok"
                } catch { return "fail" }
            }
            if ($pick -lt 55) {
                # unknown_user
                $req = @{ email = "nobody-rec-$Index-$(Get-Random)@example.com" } | ConvertTo-Json -Compress
                try {
                    Invoke-WebRequest -Uri "$auth/recovery/request" -Method POST -Body $req -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                } catch { }
                return "fail"
            }
            if ($pick -lt 70) {
                # not_activated: pending account cannot recover
                $suffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
                $email = "pend-rec-$suffix-$(Get-Random)@example.com"
                $reg = @{
                    name        = "Load User $suffix"
                    email       = $email
                    phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
                } | ConvertTo-Json -Compress
                try {
                    Invoke-WebRequest -Uri $Rest -Method POST -Body $reg -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                    $req = @{ email = $email } | ConvertTo-Json -Compress
                    Invoke-WebRequest -Uri "$auth/recovery/request" -Method POST -Body $req -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                } catch { }
                return "fail"
            }
            if ($pick -lt 85) {
                # invalid_token
                $rb = @{ token = "badrec$Index$(Get-Random)"; password = "x" } | ConvertTo-Json -Compress
                try {
                    Invoke-WebRequest -Uri "$auth/recovery/reset" -Method POST -Body $rb -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                } catch { }
                return "fail"
            }
            # expired: register → activate → request → force expire → reset
            $suffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
            $email = "recexp-$suffix-$(Get-Random)@example.com"
            $reg = @{
                name        = "Load User $suffix"
                email       = $email
                phoneNumber = ("212555{0:D4}" -f (Get-Random -Maximum 10000))
            } | ConvertTo-Json -Compress
            try {
                $resp = Invoke-WebRequest -Uri $Rest -Method POST -Body $reg -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10
                $json = $resp.Content | ConvertFrom-Json
                if ($json.activationToken) {
                    $ab = @{ token = $json.activationToken } | ConvertTo-Json -Compress
                    Invoke-WebRequest -Uri "$auth/activate" -Method POST -Body $ab -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                }
                $req = @{ email = $email } | ConvertTo-Json -Compress
                $rresp = Invoke-WebRequest -Uri "$auth/recovery/request" -Method POST -Body $req -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10
                $rtok = ($rresp.Content | ConvertFrom-Json).recoveryToken
                if ($rtok) {
                    $eb = @{ token = $rtok } | ConvertTo-Json -Compress
                    Invoke-WebRequest -Uri "$auth/recovery/expire" -Method POST -Body $eb -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                    try {
                        $rb = @{ token = $rtok; password = "too-late" } | ConvertTo-Json -Compress
                        Invoke-WebRequest -Uri "$auth/recovery/reset" -Method POST -Body $rb -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                    } catch { }
                }
            } catch { }
            return "fail"
        }
        if ($roll -lt 89 -and $DoFailures) {
            # Bad name (digits) → Bean Validation Pattern on name
            $body = @{ name = "Bad123"; email = "bad-name-$Index@example.com"; phoneNumber = "2125551234" } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri $Rest -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                return "ok"
            } catch { return "fail" }
        }
        if ($roll -lt 91 -and $DoFailures) {
            # Bad email → Email constraint
            $suffix = -join ((97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ })
            $body = @{ name = "Bad Email $suffix"; email = "not-an-email"; phoneNumber = "2125559999" } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri $Rest -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                return "ok"
            } catch { return "fail" }
        }
        if ($roll -lt 93 -and $DoFailures) {
            # Short / non-digit phone → Size + Digits on phoneNumber
            $suffix = -join ((97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ })
            $body = @{ name = "Bad Phone $suffix"; email = "bad-phone-$suffix@example.com"; phoneNumber = "12ab" } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri $Rest -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                return "ok"
            } catch { return "fail" }
        }
        if ($roll -lt 95 -and $DoFailures) {
            # Duplicate email (seeded Jane Doe)
            $body = @{ name = "Jane Doe"; email = "jane.doe@mailinator.com"; phoneNumber = "2125551234" } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri $Rest -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                return "ok"
            } catch { return "fail" }
        }
        # Successful registration — often activate so pending backlog stays bounded
        $suffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
        $phone = "212555{0:D4}" -f (Get-Random -Maximum 10000)
        $body = @{
            name        = "Load User $suffix"
            email       = "load-$suffix-$(Get-Random)@example.com"
            phoneNumber = $phone
        } | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri $Rest -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10
        if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
            if ((Get-Random -Maximum 100) -lt 75) {
                try {
                    $json = $resp.Content | ConvertFrom-Json
                    if ($json.activationToken) {
                        $ab = @{ token = $json.activationToken } | ConvertTo-Json -Compress
                        Invoke-WebRequest -Uri "$BaseUrl/rest/auth/activate" -Method POST -Body $ab -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                    }
                } catch { }
            }
            return "ok"
        }
        return "fail"
    } catch {
        return "fail"
    }
}

Write-Host "Load traffic -> $BaseUrl  for ${DurationSec}s  delay=${DelayMs}ms  workers=$Workers  failures=$Failures"
Write-Host "Open Grafana (HTTP / DB / App). Ctrl+C to stop early."
Write-Host ""

try {
    while ([DateTime]::UtcNow -lt $end) {
        $handles = @()
        1..[Math]::Max(1, $Workers) | ForEach-Object {
            $n++
            $ps = [PowerShell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddScript($workerScript).AddArgument($BaseUrl).AddArgument($rest).AddArgument([bool]$Failures).AddArgument($n)
            $handles += [pscustomobject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() }
        }

        foreach ($h in $handles) {
            $result = $h.Pipe.EndInvoke($h.Handle)
            $h.Pipe.Dispose()
            switch ($result) {
                "get"  { $get++ }
                "ok"   { $ok++ }
                default { $fail++ }
            }
        }

        if ($n % (20 * [Math]::Max(1, $Workers)) -lt $Workers) {
            $left = [math]::Max(0, [int]($end - [DateTime]::UtcNow).TotalSeconds)
            Write-Host ("[{0}] req~{1} get={2} post_ok={3} fail={4}  ~{5}s left" -f (Get-Date -Format "HH:mm:ss"), $n, $get, $ok, $fail, $left)
        }

        Start-Sleep -Milliseconds $DelayMs
    }
}
finally {
    $pool.Close()
    $pool.Dispose()
}

Write-Host ""
Write-Host "Done. total~$n get=$get post_ok=$ok fail=$fail"
Write-Host "Check: http://localhost:3000/d/account-recovery  http://localhost:3000/d/account-activation  http://localhost:3000/d/auth-sessions"
