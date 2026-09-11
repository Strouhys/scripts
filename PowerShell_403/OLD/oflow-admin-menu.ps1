<#
.SYNOPSIS
    Multifunkční administrační menu pro EDW oflow scheduler.

.DESCRIPTION
    Spojuje původní skripty:
      - status.ps1
      - cap-to-zero.ps1
      - cap-to-defult.ps1
      - shutdown.ps1

    Umožní z jednoho místa:
      1. Zobrazit stav oflow a failed joby
      2. Nastavit pool capacity na 0
      3. Vrátit pool capacity na default z configu
      4. Graceful shutdown oflow
      5. Ukončit menu

    Výchozí nastavení:
      Port: 8010
      BaseUrl: http://ntinfo403:8010
      Config: ..\config-prod\oflow-edw.json relativně ke skriptu

    Protected endpointy vyžadují proměnnou prostředí ONDP_OFLOW_AUTH.
#>
[CmdletBinding()]
param(
    [int]$Port = 8010,
    [string]$ConfigName = "oflow-edw.json",
    [string]$ConfigRelativePath = "..\config-prod"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$BaseUrl = "http://localhost:$Port"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
}

function Get-AuthHeaders {
    $Token = $env:ONDP_OFLOW_AUTH
    if (-not $Token) {
        throw "Environment variable ONDP_OFLOW_AUTH is not set. Cannot authenticate."
    }
    return @{ Authorization = "Bearer $Token" }
}

function Get-OflowStatus {
    try {
        return Invoke-RestMethod "$BaseUrl/status" -ErrorAction Stop
    }
    catch {
        Write-Host "oflow is NOT reachable at $BaseUrl" -ForegroundColor Red
        Write-Host "  (either not running, or the port is blocked)"
        return $null
    }
}

function Show-OflowStatus {
    Write-Section "Status oflow"

    $status = Get-OflowStatus
    if ($null -eq $status) { return }

    Write-Host "oflow is RUNNING" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Status:          $($status.status)"
    Write-Host "  Running since:   $($status.running_since)"
    Write-Host "  Pool capacity:   $($status.pool.capacity)"
    Write-Host "  Pool used:       $($status.pool.used)"
    Write-Host "  Total executed:  $($status.pool.total_executed)"
    Write-Host "  Current failed:  $($status.pool.current_failed)"
    Write-Host ""

    $failedJobs = @($status.pool.jobs | Where-Object { $_.status -like "failed*" })

    if ($failedJobs.Count -eq 0) {
        Write-Host "No failed jobs." -ForegroundColor Green
    }
    else {
        Write-Host "Failed jobs ($($failedJobs.Count)):" -ForegroundColor Yellow
        Write-Host ""
        $failedJobs | ForEach-Object {
            Write-Host ("  ID {0,-5} | {1,-30} | {2,-16} | runs: {3} | last change: {4}" -f `
                $_.id, $_.job_name, $_.status, $_.run_count, $_.last_change)
        }
    }
}

function Set-PoolCapacity {
    param([Parameter(Mandatory)][int]$Capacity)

    Write-Section "Nastavení pool capacity na $Capacity"

    try {
        $Headers = Get-AuthHeaders
        $response = Invoke-RestMethod "$BaseUrl/set_pool_capacity/$Capacity" -Headers $Headers
        Write-Host "Pool capacity set to $($response.capacity)." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to set pool capacity: $_" -ForegroundColor Red
    }
}

function Get-DefaultPoolCapacityFromConfig {
    $ScriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $ScriptDir) {
        $ScriptDir = Split-Path -Parent $PSCommandPath
    }

    $ConfigPath = Join-Path $ScriptDir $ConfigRelativePath
    $ConfigPath = Join-Path $ConfigPath $ConfigName
    $ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    Write-Host "Reading config from: $ConfigPath"

    $ConfigRaw = Get-Content -Path $ConfigPath -Raw
    $PoolCap = $null

    try {
        $config = $ConfigRaw | ConvertFrom-Json
        $PoolCap = $config.running_pool_cap
    }
    catch {
        if ($ConfigRaw -match '"running_pool_cap"\s*:\s*(\d+)') {
            $PoolCap = [int]$Matches[1]
        }
    }

    if ($null -eq $PoolCap) {
        throw "Could not find running_pool_cap in config file: $ConfigPath"
    }

    return [int]$PoolCap
}

function Restore-DefaultCapacity {
    Write-Section "Vrácení pool capacity na default z configu"

    try {
        $PoolCap = Get-DefaultPoolCapacityFromConfig
        Write-Host "Default running_pool_cap from config: $PoolCap"
        Set-PoolCapacity -Capacity $PoolCap
    }
    catch {
        Write-Host $_ -ForegroundColor Red
    }
}

function Invoke-OflowShutdown {
    Write-Section "Graceful shutdown oflow"

    Write-Host "Tato akce pošle /shutdown na $BaseUrl." -ForegroundColor Yellow
    Write-Host "oflow nastaví capacity na 0, počká na doběhnutí jobů, uloží state a ukončí se."
    $confirm = Read-Host "Opravdu pokračovat? Napiš ANO"

    if ($confirm -ne "ANO") {
        Write-Host "Shutdown zrušen." -ForegroundColor Yellow
        return
    }

    try {
        $Headers = Get-AuthHeaders
        $response = Invoke-RestMethod "$BaseUrl/shutdown" -Headers $Headers
        Write-Host "Shutdown initiated." -ForegroundColor Green
        Write-Host ($response | ConvertTo-Json -Depth 5)
    }
    catch {
        Write-Host "Failed to send shutdown request: $_" -ForegroundColor Red
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "oflow admin menu" -ForegroundColor Cyan
    Write-Host "BaseUrl: $BaseUrl"
    Write-Host ""
    Write-Host "1 - Status + failed joby"
    Write-Host "2 - Nastavit pool capacity na 0"
    Write-Host "3 - Vrátit pool capacity na default z configu"
    Write-Host "4 - Graceful shutdown oflow"
    Write-Host "5 - Konec"
    Write-Host ""
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Vyber akci"

    switch ($choice) {
        "1" { Show-OflowStatus }
        "2" { Set-PoolCapacity -Capacity 0 }
        "3" { Restore-DefaultCapacity }
        "4" { Invoke-OflowShutdown }
        "5" { Write-Host "Konec."; break }
        default { Write-Host "Neplatná volba: $choice" -ForegroundColor Red }
    }

    Write-Host ""
    Read-Host "Stiskni Enter pro návrat do menu"
}
