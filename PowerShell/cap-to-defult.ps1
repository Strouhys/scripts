<#
.SYNOPSIS
    Restore the EDW oflow pool capacity to the default value from the config file.

.DESCRIPTION
    Reads running_pool_cap from the oflow config file and sets the pool capacity
    to that value via the REST API.

    The config file is located relative to this script:
        <script_dir>\..\config-prod\oflow-edw.json

    On ntinfo403 this resolves to e.g.:
        i:\dp\BIDEV-MAIN_o2czep-stg\tenant\edw\config-prod\oflow-edw.json

    The config file may contain oflow template placeholders ({{ .VAR_NAME }})
    in string values. These are irrelevant for reading running_pool_cap (an integer)
    and are handled gracefully: string fields with templates are ignored, only
    running_pool_cap is extracted via regex if ConvertFrom-Json fails.

    Requires the ONDP_OFLOW_AUTH environment variable to be set.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- configuration (edit here) -------------------------------------------
$Port       = 8010
$BaseUrl    = "http://localhost:$Port"
$ConfigName = "oflow-edw.json"

# --- auth ----------------------------------------------------------------
$Token = $env:ONDP_OFLOW_AUTH
if (-not $Token) {
    Write-Error "Environment variable ONDP_OFLOW_AUTH is not set. Cannot authenticate."
    exit 1
}

$Headers = @{ Authorization = "Bearer $Token" }

# --- locate config file --------------------------------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigPath = Join-Path $ScriptDir "..\config-prod\$ConfigName"
$ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

Write-Host "Reading config from: $ConfigPath"

# --- extract running_pool_cap --------------------------------------------
# The config file contains oflow Go template placeholders like {{ .VAR }}.
# These make the file invalid JSON for PowerShell's ConvertFrom-Json.
# Strategy: try ConvertFrom-Json first; if it fails, fall back to regex.

$ConfigRaw = Get-Content -Path $ConfigPath -Raw

$PoolCap = $null

try {
    $config = $ConfigRaw | ConvertFrom-Json
    $PoolCap = $config.running_pool_cap
}
catch {
    # JSON parse failed (expected due to {{ }} templates). Use regex.
    if ($ConfigRaw -match '"running_pool_cap"\s*:\s*(\d+)') {
        $PoolCap = [int]$Matches[1]
    }
}

if ($null -eq $PoolCap) {
    Write-Error "Could not find running_pool_cap in config file: $ConfigPath"
    exit 1
}

Write-Host "Default running_pool_cap from config: $PoolCap"

# --- set capacity --------------------------------------------------------
Write-Host "Setting pool capacity to $PoolCap ..."

try {
    $response = Invoke-RestMethod "$BaseUrl/set_pool_capacity/$PoolCap" -Headers $Headers
    Write-Host "Pool capacity set to $($response.capacity)." -ForegroundColor Green
}
catch {
    Write-Error "Failed to set pool capacity: $_"
    exit 1
}
