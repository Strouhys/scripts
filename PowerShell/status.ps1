<#
.SYNOPSIS
    Check EDW oflow scheduler status, running jobs and failed jobs.
#>

[CmdletBinding()]
param(
    [string]$HostName = "ntinfo403",
    [int]$Port = 8010,

    # Volitelně: pokud budeš chtít volat chráněné endpointy
    [string]$Token = $env:OFLOW_TOKEN
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$BaseUrl = "http://$HostName`:$Port"

function Invoke-OflowGet {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$UseToken
    )

    $headers = @{}

    if ($UseToken) {
        if ([string]::IsNullOrWhiteSpace($Token)) {
            throw "Token is required, but OFLOW_TOKEN is empty."
        }

        $headers["Authorization"] = "Bearer $Token"
    }

    Invoke-RestMethod "$BaseUrl$Path" -Headers $headers -ErrorAction Stop
}

try {
    $status = Invoke-OflowGet -Path "/status"
}
catch {
    Write-Host "oflow is NOT reachable at $BaseUrl" -ForegroundColor Red
    Write-Host "  (either not running, wrong port, DNS issue, or firewall blocked)"
    exit 1
}

Write-Host "oflow is RUNNING" -ForegroundColor Green
Write-Host ""
Write-Host "Base URL:         $BaseUrl"
Write-Host "Status:           $($status.status)"
Write-Host "Running since:    $($status.running_since)"
Write-Host "Pool capacity:    $($status.pool.capacity)"
Write-Host "Pool used:        $($status.pool.used)"
Write-Host "Total executed:   $($status.pool.total_executed)"
Write-Host "Current failed:   $($status.pool.current_failed)"
Write-Host ""

$jobs = @($status.pool.jobs)

if ($jobs.Count -eq 0) {
    Write-Host "No jobs currently in pool." -ForegroundColor Green
    exit 0
}

$runningJobs = @($jobs | Where-Object { $_.status -eq "running" })
$failedJobs  = @($jobs | Where-Object { $_.status -like "failed*" })
$otherJobs   = @($jobs | Where-Object { $_.status -ne "running" -and $_.status -notlike "failed*" })

Write-Host "Jobs in pool: $($jobs.Count)"
Write-Host ""

if ($runningJobs.Count -gt 0) {
    Write-Host "Running jobs ($($runningJobs.Count)):" -ForegroundColor Cyan
    $runningJobs | ForEach-Object {
        Write-Host ("  ID {0,-6} | {1,-40} | {2,-12} | runs: {3} | last change: {4}" -f `
            $_.id, $_.job_name, $_.status, $_.run_count, $_.last_change)
    }
    Write-Host ""
}
else {
    Write-Host "No running jobs." -ForegroundColor Green
    Write-Host ""
}

if ($failedJobs.Count -gt 0) {
    Write-Host "Failed jobs ($($failedJobs.Count)):" -ForegroundColor Yellow
    $failedJobs | ForEach-Object {
        Write-Host ("  ID {0,-6} | {1,-40} | {2,-18} | runs: {3} | last change: {4}" -f `
            $_.id, $_.job_name, $_.status, $_.run_count, $_.last_change)
    }
    Write-Host ""
}
else {
    Write-Host "No failed jobs." -ForegroundColor Green
    Write-Host ""
}

if ($otherJobs.Count -gt 0) {
    Write-Host "Other jobs ($($otherJobs.Count)):" -ForegroundColor DarkGray
    $otherJobs | ForEach-Object {
        Write-Host ("  ID {0,-6} | {1,-40} | {2,-18} | runs: {3} | last change: {4}" -f `
            $_.id, $_.job_name, $_.status, $_.run_count, $_.last_change)
    }
}