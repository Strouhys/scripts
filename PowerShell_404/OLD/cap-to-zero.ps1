<#
.SYNOPSIS
    Set the EDW oflow pool capacity to zero.

.DESCRIPTION
    Sends GET /set_pool_capacity/0 to the oflow REST API on localhost:8010.
    This prevents new jobs from being scheduled. Already-running jobs continue
    until they finish.

    Requires the ONDP_OFLOW_AUTH environment variable to be set.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- configuration (edit here) -------------------------------------------
$Port    = 8010
$BaseUrl = "http://localhost:$Port"

# --- auth ----------------------------------------------------------------
$Token = $env:ONDP_OFLOW_AUTH
if (-not $Token) {
    Write-Error "Environment variable ONDP_OFLOW_AUTH is not set. Cannot authenticate."
    exit 1
}

$Headers = @{ Authorization = "Bearer $Token" }

# --- cap to zero ---------------------------------------------------------
Write-Host "Setting pool capacity to 0 ..."

try {
    $response = Invoke-RestMethod "$BaseUrl/set_pool_capacity/0" -Headers $Headers
    Write-Host "Pool capacity set to $($response.capacity)." -ForegroundColor Green
}
catch {
    Write-Error "Failed to set pool capacity: $_"
    exit 1
}
