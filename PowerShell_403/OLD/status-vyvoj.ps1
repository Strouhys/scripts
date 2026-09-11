<#
.SYNOPSIS
    Multifunkcni provozni menu pro oflow scheduler.

.DESCRIPTION
    Verejne akce bez tokenu:
      - status
      - seznam jobu
      - detail jobu
      - next_jobs

    Chranene akce s tokenem:
      - start job
      - start vice jobu
      - cancel running / failed_restart jobu
      - restart failed_final / cancelled jobu
      - pause / enable job pres first_run_attempt
      - pool capacity
      - job stats / job log
      - graceful shutdown

    Token se primarne bere z:
      1) parametru -Token
      2) env:ONDP_OFLOW_AUTH
      3) env:OFLOW_TOKEN
      4) interaktivniho zadani pres Read-Host -AsSecureString

    Skript token nikam neuklada.
#>
[CmdletBinding()]
param(
    [string]$HostName = "ntinfo403",
    [int]$Port = 8010,
    [string]$Scheme = "http",
    [string]$Token = $env:ONDP_OFLOW_AUTH,
    [int]$DefaultCapacity = 15,
    [switch]$SkipCertificateCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Token)) {
    $Token = $env:OFLOW_TOKEN
}

$script:AuthToken = $Token
$script:BaseUrl = "${Scheme}://${HostName}:$Port"
$script:LastStatus = $null

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
}

function Convert-SecureStringToPlainText {
    param([Parameter(Mandatory)][System.Security.SecureString]$SecureString)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Ensure-Token {
    if (-not [string]::IsNullOrWhiteSpace($script:AuthToken)) {
        return $true
    }

    Write-Host ""
    Write-Host "Tato akce vyzaduje bearer token." -ForegroundColor Yellow
    $answer = Read-Host "Chces token zadat ted? (A/N)"
    if ($answer -notin @('A','a','Y','y','ANO','ano','Ano')) {
        Write-Host "Akce zrusena - token nebyl zadan." -ForegroundColor Yellow
        return $false
    }

    $secure = Read-Host "Zadej token" -AsSecureString
    $plain = Convert-SecureStringToPlainText -SecureString $secure

    if ([string]::IsNullOrWhiteSpace($plain)) {
        Write-Host "Token je prazdny. Akce zrusena." -ForegroundColor Red
        return $false
    }

    $script:AuthToken = $plain
    Write-Host "Token nacten pouze do pameti tohoto behu skriptu." -ForegroundColor Green
    return $true
}

function Get-AuthHeaders {
    if (-not (Ensure-Token)) {
        throw "Token required."
    }
    return @{ Authorization = "Bearer $script:AuthToken" }
}

function Invoke-OflowRequest {
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('Get','Post','Put')][string]$Method = 'Get',
        [switch]$UseToken,
        [object]$Body = $null
    )

    $uri = "$script:BaseUrl$Path"
    $headers = @{}
    if ($UseToken) {
        $headers = Get-AuthHeaders
    }

    $params = @{
        Uri = $uri
        Method = $Method
        ErrorAction = 'Stop'
    }

    if ($headers.Count -gt 0) { $params.Headers = $headers }
    if ($null -ne $Body) {
        $params.ContentType = 'application/json'
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
    }

    if ($SkipCertificateCheck -and $PSVersionTable.PSVersion.Major -ge 7) {
        $params.SkipCertificateCheck = $true
    }

    return Invoke-RestMethod @params
}

function Read-NonEmpty {
    param([string]$Prompt)
    do {
        $value = Read-Host $Prompt
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value.Trim() }
        Write-Host "Hodnota nesmi byt prazdna." -ForegroundColor Yellow
    } while ($true)
}

function Read-IntValue {
    param([string]$Prompt)
    do {
        $raw = Read-Host $Prompt
        $number = 0
        if ([int]::TryParse($raw, [ref]$number)) { return $number }
        Write-Host "Zadej cislo." -ForegroundColor Yellow
    } while ($true)
}

function Confirm-Action {
    param(
        [string]$Text,
        [string]$Required = "ANO"
    )
    Write-Host ""
    Write-Host $Text -ForegroundColor Yellow
    $answer = Read-Host "Pro potvrzeni napis $Required"
    return ($answer -eq $Required)
}

function Get-OflowStatus {
    try {
        $script:LastStatus = Invoke-OflowRequest -Path "/status"
        return $script:LastStatus
    }
    catch {
        Write-Host "oflow is NOT reachable at $script:BaseUrl" -ForegroundColor Red
        Write-Host "Mozne priciny: nebězi, spatny port/host, DNS, firewall, VPN, nebo API posloucha jinde."
        Write-Host "Detail: $($_.Exception.Message)" -ForegroundColor DarkGray
        return $null
    }
}

function Format-JobLine {
    param([object]$Job)
    return ("  ID {0,-6} | {1,-55} | {2,-16} | runs: {3,-3} | last change: {4}" -f `
        $Job.id, $Job.job_name, $Job.status, $Job.run_count, $Job.last_change)
}

function Show-Status {
    Write-Section "Status oflow"
    $status = Get-OflowStatus
    if ($null -eq $status) { return }

    Write-Host "oflow is RUNNING" -ForegroundColor Green
    Write-Host ""
    Write-Host "Base URL:         $script:BaseUrl"
    Write-Host "Status:           $($status.status)"
    Write-Host "Running since:    $($status.running_since)"
    Write-Host "Pool capacity:    $($status.pool.capacity)"
    Write-Host "Pool used:        $($status.pool.used)"
    Write-Host "Sleep seconds:    $($status.pool.sleep_seconds)"
    Write-Host "Total executed:   $($status.pool.total_executed)"
    Write-Host "Restarts to OK:   $($status.pool.total_restarts_to_success)"
    Write-Host "Current failed:   $($status.pool.current_failed)"
    Write-Host ""

    $jobs = @($status.pool.jobs)
    if ($jobs.Count -eq 0) {
        Write-Host "No jobs currently in pool." -ForegroundColor Green
        return
    }

    $runningJobs = @($jobs | Where-Object { $_.status -eq "running" })
    $retryJobs   = @($jobs | Where-Object { $_.status -eq "failed_restart" })
    $finalJobs   = @($jobs | Where-Object { $_.status -eq "failed_final" })
    $cancelled   = @($jobs | Where-Object { $_.status -eq "cancelled" })
    $otherJobs   = @($jobs | Where-Object { $_.status -notin @("running","failed_restart","failed_final","cancelled") })

    Write-Host "Jobs in pool: $($jobs.Count)"
    Write-Host ""

    if ($runningJobs.Count -gt 0) {
        Write-Host "Running jobs ($($runningJobs.Count)) - lze cancel:" -ForegroundColor Cyan
        $runningJobs | ForEach-Object { Write-Host (Format-JobLine $_) }
        Write-Host ""
    }

    if ($retryJobs.Count -gt 0) {
        Write-Host "Failed_restart jobs ($($retryJobs.Count)) - cekaji na auto-retry, lze cancel:" -ForegroundColor Yellow
        $retryJobs | ForEach-Object { Write-Host (Format-JobLine $_) }
        Write-Host ""
    }

    if ($finalJobs.Count -gt 0) {
        Write-Host "Failed_final jobs ($($finalJobs.Count)) - lze restart:" -ForegroundColor Red
        $finalJobs | ForEach-Object { Write-Host (Format-JobLine $_) }
        Write-Host ""
    }

    if ($cancelled.Count -gt 0) {
        Write-Host "Cancelled jobs ($($cancelled.Count)) - lze restart:" -ForegroundColor DarkYellow
        $cancelled | ForEach-Object { Write-Host (Format-JobLine $_) }
        Write-Host ""
    }

    if ($otherJobs.Count -gt 0) {
        Write-Host "Other jobs ($($otherJobs.Count)):" -ForegroundColor DarkGray
        $otherJobs | ForEach-Object { Write-Host (Format-JobLine $_) }
        Write-Host ""
    }

    if (($runningJobs.Count + $retryJobs.Count + $finalJobs.Count + $cancelled.Count) -gt 0 -and [string]::IsNullOrWhiteSpace($script:AuthToken)) {
        Write-Host "Vidim joby, se kterymi muzes chtit pracovat. Pro cancel/restart/start bude potreba token." -ForegroundColor Yellow
        [void](Ensure-Token)
    }
}

function Show-Jobs {
    Write-Section "Seznam job definic"
    $mask = Read-Host "Mask/filter nazvu jobu, prazdne = vse"
    if ([string]::IsNullOrWhiteSpace($mask)) {
        $result = Invoke-OflowRequest -Path "/jobs"
    } else {
        $result = Invoke-OflowRequest -Path "/jobs?mask=$([uri]::EscapeDataString($mask))"
    }
    $jobs = @($result.jobs)
    Write-Host "Pocet jobu: $($jobs.Count)" -ForegroundColor Green
    $jobs | Sort-Object | ForEach-Object { Write-Host "  $_" }
}

function Show-NextJobs {
    Write-Section "Next jobs"
    $limit = Read-Host "Limit, prazdne = 20"
    if ([string]::IsNullOrWhiteSpace($limit)) { $limit = 20 }
    $result = Invoke-OflowRequest -Path "/next_jobs?limit=$limit"
    $items = @($result.next_jobs)
    if ($items.Count -eq 0) { Write-Host "No next jobs." -ForegroundColor Green; return }
    $items | ForEach-Object {
        Write-Host ("  {0,-55} | next: {1} | in: {2}s | reason: {3}" -f $_.job_name, $_.next_run, $_.seconds_until, $_.reason)
    }
}

function Show-JobDefinition {
    Write-Section "Detail job definice"
    $name = Read-NonEmpty "Job name"
    try {
        $job = Invoke-OflowRequest -Path "/job/$([uri]::EscapeDataString($name))"
        $job | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Host "Job nenalezen nebo chyba: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-JobStats {
    Write-Section "Job stats"
    $name = Read-NonEmpty "Job name"
    try {
        $stats = Invoke-OflowRequest -Path "/job_stats/$([uri]::EscapeDataString($name))" -UseToken
        $stats | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Host "Chyba job_stats: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-JobLog {
    Write-Section "Job log"
    $name = Read-NonEmpty "Job name"
    $bytes = Read-Host "Kolik bytu z konce logu, prazdne = 4096"
    if ([string]::IsNullOrWhiteSpace($bytes)) { $bytes = 4096 }
    try {
        $log = Invoke-OflowRequest -Path "/job_log/$([uri]::EscapeDataString($name))?bytes=$bytes" -UseToken
        Write-Host "Job: $($log.job_name), returned: $($log.bytes_returned)/$($log.bytes_requested), file size: $($log.file_size)" -ForegroundColor Green
        Write-Host ""
        Write-Host $log.content
    }
    catch {
        Write-Host "Chyba job_log: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Start-JobNow {
    Write-Section "Start job now"
    $name = Read-NonEmpty "Job name"
    if (-not (Confirm-Action "Job '$name' bude spusten okamzite. Muze obejit kapacitu poolu.")) { Write-Host "Zruseno."; return }
    try {
        $result = Invoke-OflowRequest -Path "/start_job/$([uri]::EscapeDataString($name))" -UseToken
        $result | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Host "Chyba start_job: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Poznamka: pokud je job uz v poolu jako running/failed/cancelled, nejdriv ho musis cancel/restartem odstranit podle stavu." -ForegroundColor Yellow
    }
}

function Start-MultipleJobs {
    Write-Section "Start multiple jobs"
    Write-Host "Zadej joby oddelene carkou, napr.: job1,job2,job3"
    $raw = Read-NonEmpty "Job names"
    $names = @($raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($names.Count -eq 0) { Write-Host "Nebyl zadan zadny job." -ForegroundColor Yellow; return }
    Write-Host "Budou spusteny joby:" -ForegroundColor Yellow
    $names | ForEach-Object { Write-Host "  $_" }
    if (-not (Confirm-Action "Potvrdit hromadne spusteni?")) { Write-Host "Zruseno."; return }
    try {
        $body = @{ job_names = $names }
        $result = Invoke-OflowRequest -Path "/start_jobs" -Method Post -UseToken -Body $body
        $result | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Host "Chyba start_jobs: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Cancel-JobById {
    Write-Section "Cancel job"
    Show-Status
    $id = Read-IntValue "ID jobu pro cancel"
    if (-not (Confirm-Action "Job ID $id bude zrusen. U running jobu se zabije proces, u failed_restart se zrusi retry.")) { Write-Host "Zruseno."; return }
    try {
        $result = Invoke-OflowRequest -Path "/cancel_job/$id" -UseToken
        $result | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Host "Chyba cancel_job: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restart-JobById {
    Write-Section "Restart failed/cancelled job"
    Show-Status
    $id = Read-IntValue "ID jobu pro restart"
    if (-not (Confirm-Action "Job ID $id bude odblokovan pro dalsi naplanovani. Nespousti se okamzite.")) { Write-Host "Zruseno."; return }
    try {
        $result = Invoke-OflowRequest -Path "/restart_job/$id" -UseToken
        $result | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Host "Chyba restart_job: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restart-AllDeadJobs {
    Write-Section "Restart all failed_final/cancelled"
    $status = Get-OflowStatus
    if ($null -eq $status) { return }
    $dead = @($status.pool.jobs | Where-Object { $_.status -in @("failed_final", "cancelled") })
    if ($dead.Count -eq 0) { Write-Host "Zadne failed_final/cancelled joby." -ForegroundColor Green; return }
    $dead | ForEach-Object { Write-Host (Format-JobLine $_) }
    if (-not (Confirm-Action "Bude odblokovano $($dead.Count) jobu pro dalsi naplanovani.")) { Write-Host "Zruseno."; return }
    foreach ($job in $dead) {
        try {
            $result = Invoke-OflowRequest -Path "/restart_job/$($job.id)" -UseToken
            Write-Host "OK restart queued: ID $($job.id) $($job.job_name)" -ForegroundColor Green
        }
        catch {
            Write-Host "FAIL ID $($job.id) $($job.job_name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Pause-Job {
    Write-Section "Pause job pres first_run_attempt"
    $name = Read-NonEmpty "Job name"
    Write-Host "Zadej lokalni cas serveru ve formatu YYYY-MM-DDTHH:MM:SS"
    Write-Host "Priklad: 2026-06-25T23:00:00"
    $date = Read-NonEmpty "Pauza do"
    if (-not (Confirm-Action "Job '$name' bude pozastaven do $date. Nebezi-li ted, scheduler ho do te doby nespusti.")) { Write-Host "Zruseno."; return }
    try {
        $body = @{ first_run_attempt = $date }
        $result = Invoke-OflowRequest -Path "/set_job_first_run_attempt/$([uri]::EscapeDataString($name))" -Method Put -UseToken -Body $body
        $result | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Host "Chyba set_job_first_run_attempt: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Enable-JobNow {
    Write-Section "Enable job now"
    $name = Read-NonEmpty "Job name"
    $date = "2020-01-01T00:00:00"
    if (-not (Confirm-Action "Job '$name' bude znovu povolen nastavenim first_run_attempt na $date.")) { Write-Host "Zruseno."; return }
    try {
        $body = @{ first_run_attempt = $date }
        $result = Invoke-OflowRequest -Path "/set_job_first_run_attempt/$([uri]::EscapeDataString($name))" -Method Put -UseToken -Body $body
        $result | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Host "Chyba enable jobu: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-CapacityMenu {
    Write-Section "Pool capacity"
    Write-Host "1 - Nastavit capacity na 0 (stop noveho planovani, bezici joby dobehnou)"
    Write-Host "2 - Vratit default capacity ($DefaultCapacity)"
    Write-Host "3 - Zadat vlastni capacity"
    $choice = Read-Host "Vyber"
    switch ($choice) {
        "1" { $cap = 0 }
        "2" { $cap = $DefaultCapacity }
        "3" { $cap = Read-IntValue "Capacity" }
        default { Write-Host "Neplatna volba." -ForegroundColor Red; return }
    }
    if ($cap -lt 0) { Write-Host "Capacity nesmi byt zaporna." -ForegroundColor Red; return }
    if (-not (Confirm-Action "Pool capacity bude nastavena na $cap.")) { Write-Host "Zruseno."; return }
    try {
        $result = Invoke-OflowRequest -Path "/set_pool_capacity/$cap" -UseToken
        $result | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Host "Chyba set_pool_capacity: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Shutdown-Oflow {
    Write-Section "Graceful shutdown"
    Write-Host "Shutdown nastavi capacity na 0, pocka na dobehnuti jobu, ulozi state a oflow ukonci." -ForegroundColor Yellow
    if (-not (Confirm-Action "Opravdu poslat /shutdown na $script:BaseUrl ?")) { Write-Host "Zruseno."; return }
    try {
        $result = Invoke-OflowRequest -Path "/shutdown" -UseToken
        $result | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Host "Chyba shutdown: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "oflow ops admin" -ForegroundColor Cyan
    Write-Host "BaseUrl: $script:BaseUrl"
    if ([string]::IsNullOrWhiteSpace($script:AuthToken)) {
        Write-Host "Token:   not loaded" -ForegroundColor Yellow
    } else {
        Write-Host "Token:   loaded in memory" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "STATUS / READ"
    Write-Host " 1 - Status + running/failed/cancelled joby"
    Write-Host " 2 - Seznam job definic (/jobs)"
    Write-Host " 3 - Detail jobu (/job/name)"
    Write-Host " 4 - Next jobs (/next_jobs)"
    Write-Host " 5 - Job stats"
    Write-Host " 6 - Job log"
    Write-Host ""
    Write-Host "JOB CONTROL"
    Write-Host " 7 - Start job now"
    Write-Host " 8 - Start multiple jobs"
    Write-Host " 9 - Cancel job by ID (running/failed_restart)"
    Write-Host "10 - Restart job by ID (failed_final/cancelled)"
    Write-Host "11 - Restart all failed_final/cancelled"
    Write-Host "12 - Pause job do konkretniho casu"
    Write-Host "13 - Enable job now"
    Write-Host ""
    Write-Host "POOL / SYSTEM"
    Write-Host "14 - Pool capacity"
    Write-Host "15 - Zadat / zmenit token"
    Write-Host "16 - Graceful shutdown oflow"
    Write-Host " 0 - Konec"
    Write-Host ""
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Vyber akci"
    try {
        switch ($choice) {
            "1"  { Show-Status }
            "2"  { Show-Jobs }
            "3"  { Show-JobDefinition }
            "4"  { Show-NextJobs }
            "5"  { Show-JobStats }
            "6"  { Show-JobLog }
            "7"  { Start-JobNow }
            "8"  { Start-MultipleJobs }
            "9"  { Cancel-JobById }
            "10" { Restart-JobById }
            "11" { Restart-AllDeadJobs }
            "12" { Pause-Job }
            "13" { Enable-JobNow }
            "14" { Set-CapacityMenu }
            "15" { $script:AuthToken = $null; [void](Ensure-Token) }
            "16" { Shutdown-Oflow }
            "0"  { Write-Host "Konec."; break }
            default { Write-Host "Neplatna volba: $choice" -ForegroundColor Red }
        }
    }
    catch {
        Write-Host "Chyba: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
    Read-Host "Stiskni Enter pro navrat do menu"
}
