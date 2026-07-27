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
        if ($roll -lt 42) {
            # List members -> findAll DB op + Undertow GET
            Invoke-WebRequest -Uri $Rest -UseBasicParsing -TimeoutSec 10 | Out-Null
            return "get"
        }
        if ($roll -lt 55) {
            # HTML page -> Undertow request + JSF session (Active Sessions panel)
            Invoke-WebRequest -Uri "$BaseUrl/" -UseBasicParsing -TimeoutSec 10 | Out-Null
            return "get"
        }
        if ($roll -lt 65) {
            # Lookup by id -> findById DB op. Mix hits (200) and misses (404).
            $id = if ((Get-Random -Maximum 2) -eq 0) { Get-Random -Minimum 1 -Maximum 8 } else { Get-Random -Minimum 900000 -Maximum 999999 }
            try {
                Invoke-WebRequest -Uri "$Rest/$id" -UseBasicParsing -TimeoutSec 10 | Out-Null
            } catch { }
            return "get"
        }
        if ($roll -lt 70 -and $DoFailures) {
            # Bad name (digits) → Bean Validation Pattern on name
            $body = @{ name = "Bad123"; email = "bad-name-$Index@example.com"; phoneNumber = "2125551234" } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri $Rest -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                return "ok"
            } catch { return "fail" }
        }
        if ($roll -lt 75 -and $DoFailures) {
            # Bad email → Email constraint
            $suffix = -join ((97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ })
            $body = @{ name = "Bad Email $suffix"; email = "not-an-email"; phoneNumber = "2125559999" } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri $Rest -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                return "ok"
            } catch { return "fail" }
        }
        if ($roll -lt 79 -and $DoFailures) {
            # Short / non-digit phone → Size + Digits on phoneNumber
            $suffix = -join ((97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ })
            $body = @{ name = "Bad Phone $suffix"; email = "bad-phone-$suffix@example.com"; phoneNumber = "12ab" } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri $Rest -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                return "ok"
            } catch { return "fail" }
        }
        if ($roll -lt 84 -and $DoFailures) {
            # Duplicate email (seeded Jane Doe)
            $body = @{ name = "Jane Doe"; email = "jane.doe@mailinator.com"; phoneNumber = "2125551234" } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri $Rest -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10 | Out-Null
                return "ok"
            } catch { return "fail" }
        }
        # Successful registration — name must NOT contain digits
        $suffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
        $phone = "212555{0:D4}" -f (Get-Random -Maximum 10000)
        $body = @{
            name        = "Load User $suffix"
            email       = "load-$suffix-$(Get-Random)@example.com"
            phoneNumber = $phone
        } | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri $Rest -Method POST -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 10
        if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) { return "ok" }
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
Write-Host "Check: http://localhost:3000/d/registration-quality  http://localhost:3000/d/kitchensink-app  http://localhost:3000/d/wildfly-http-db"
