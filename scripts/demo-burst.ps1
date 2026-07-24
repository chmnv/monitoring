<#
.SYNOPSIS
  Short burst of kitchensink traffic (demo / screenshot window).

.EXAMPLE
  .\scripts\demo-burst.ps1
  .\scripts\demo-burst.ps1 -Count 80
#>
param(
    [string]$BaseUrl = "http://localhost:8080/kitchensink",
    [int]$Count = 60
)

& "$PSScriptRoot\load-traffic.ps1" -BaseUrl $BaseUrl -DurationSec ([math]::Max(20, [int]($Count * 0.2))) -DelayMs 60 -Workers 6 -Failures
