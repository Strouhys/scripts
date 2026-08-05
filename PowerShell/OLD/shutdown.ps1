<#
.SYNOPSIS
    Graceful shutdown of the EDW oflow scheduler.

.DESCRIPTION
    Sends GET /shutdown to the oflow REST API on localhost:8010.
    Requires the ONDP_OFLOW_AUTH environment variable to be set.

    After the request, oflow will:
      1. Set pool capacity to 0
      2. Wait for all running jobs to finish
      3. Save state to the state file
      4. Exit
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

# --- shutdown ------------------------------------------------------------
Write-Host "Sending shutdown request to oflow at $BaseUrl ..."

try {
    $response = Invoke-RestMethod "$BaseUrl/shutdown" -Headers $Headers
    Write-Host "Shutdown initiated." -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json -Depth 5)
}
catch {
    Write-Error "Failed to send shutdown request: $_"
    exit 1
}
