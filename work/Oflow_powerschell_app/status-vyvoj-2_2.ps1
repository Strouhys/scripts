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
$script:CertificateValidationMode = 'standard'

function Initialize-CertificateHandling {
    if (-not $SkipCertificateCheck) {
        $script:CertificateValidationMode = 'standard'
        return
    }

    if ($Scheme -ne 'https') {
        $script:CertificateValidationMode = 'skip-requested-http'
        return
    }

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $script:CertificateValidationMode = 'skip-native-ps7'
        return
    }

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    $script:CertificateValidationMode = 'skip-legacy-callback'
}

function Get-CertificateValidationLabel {
    switch ($script:CertificateValidationMode) {
        'standard'             { return 'standard validation' }
        'skip-requested-http'  { return 'skip requested, but HTTP does not use TLS validation' }
        'skip-native-ps7'      { return 'skipped via PowerShell 7 request option' }
        'skip-legacy-callback' { return 'skipped via legacy callback in this process' }
        default                { return $script:CertificateValidationMode }
    }
}

function Write-ConnectionStartupNotes {
    if ($Scheme -eq 'https') {
        if ($SkipCertificateCheck) {
            Write-Host "HTTPS cert validation: $(Get-CertificateValidationLabel)" -ForegroundColor Yellow
        } else {
            Write-Host "HTTPS cert validation: standard validation" -ForegroundColor DarkGray
        }
        return
    }

    if ($SkipCertificateCheck) {
        Write-Host "SkipCertificateCheck je zapnuty, ale scheme je HTTP - nema zadny efekt." -ForegroundColor DarkGray
    }
}

Initialize-CertificateHandling

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

function Test-ConsoleKeyInputSupport {
    try {
        if ([Console]::IsInputRedirected) {
            return $false
        }

        $null = [Console]::KeyAvailable
        return $true
    }
    catch {
        return $false
    }
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

function Show-JobPreviewTable {
    param(
        [Parameter(Mandatory)][string[]]$JobNames,
        [string]$Title = 'Preview jobu'
    )

    Write-Host $Title -ForegroundColor Cyan

    $inventory = @(Get-OflowJobInventory)
    $inventoryByName = @{}
    foreach ($item in $inventory) {
        if (-not $inventoryByName.ContainsKey($item.JobName)) {
            $inventoryByName[$item.JobName] = @()
        }
        $inventoryByName[$item.JobName] += $item
    }

    $rows = @()
    foreach ($jobName in ($JobNames | Sort-Object -Unique)) {
        $matches = @()
        if ($inventoryByName.ContainsKey($jobName)) {
            $matches = @($inventoryByName[$jobName])
        }

        if ($matches.Count -eq 0) {
            $rows += [PSCustomObject]@{
                JobName      = $jobName
                Prefix       = Get-OflowJobPrefix -JobName $jobName
                Defined      = 'NE'
                CurrentState = 'unknown'
                Note         = 'job neni v /jobs'
            }
            continue
        }

        $rows += [PSCustomObject]@{
            JobName      = $jobName
            Prefix       = $matches[0].Prefix
            Defined      = 'ANO'
            CurrentState = (($matches | Select-Object -ExpandProperty Status -Unique) -join ', ')
            Note         = if ($matches[0].InPool) { 'job uz je blokovan v poolu/dead poolu' } else { 'job neni v poolu' }
        }
    }

    $rows | Format-Table -AutoSize
    return ,$rows
}

function Show-DeadJobsRestartPreview {
    param([Parameter(Mandatory)][object[]]$DeadJobs)

    Write-Host "Souhrn restartu podle systemu/prefixu:" -ForegroundColor Cyan
    $summary = @($DeadJobs |
        Group-Object { Get-OflowJobPrefix -JobName $_.job_name } |
        ForEach-Object {
            $items = @($_.Group)
            [PSCustomObject]@{
                System        = $_.Name
                FailedFinal   = @($items | Where-Object { $_.status -eq 'failed_final' }).Count
                Cancelled     = @($items | Where-Object { $_.status -eq 'cancelled' }).Count
                Celkem        = $items.Count
            }
        } |
        Sort-Object System)

    $summary | Format-Table -AutoSize
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
        $runningJobs | ForEach-Object { Write-JobLine $_ }
        Write-Host ""
    }

    if ($retryJobs.Count -gt 0) {
        Write-Host "Failed_restart jobs ($($retryJobs.Count)) - cekaji na auto-retry, lze cancel:" -ForegroundColor Yellow
        $retryJobs | ForEach-Object { Write-JobLine $_ }
        Write-Host ""
    }

    if ($finalJobs.Count -gt 0) {
        Write-Host "Failed_final jobs ($($finalJobs.Count)) - lze restart:" -ForegroundColor Red
        $finalJobs | ForEach-Object { Write-JobLine $_ }
        Write-Host ""
    }

    if ($cancelled.Count -gt 0) {
        Write-Host "Cancelled jobs ($($cancelled.Count)) - lze restart:" -ForegroundColor DarkYellow
        $cancelled | ForEach-Object { Write-JobLine $_ }
        Write-Host ""
    }

    if ($otherJobs.Count -gt 0) {
        Write-Host "Other jobs ($($otherJobs.Count)):" -ForegroundColor DarkGray
        $otherJobs | ForEach-Object { Write-JobLine $_ }
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
    Write-Host "" 
    [void](Show-JobPreviewTable -JobNames @($name) -Title "Kontrola jobu pred okamzitym startem")
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
    $names = @($raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
    if ($names.Count -eq 0) { Write-Host "Nebyl zadan zadny job." -ForegroundColor Yellow; return }
    Write-Host "Budou spusteny joby:" -ForegroundColor Yellow
    $names | ForEach-Object { Write-Host "  $_" }

    Write-Host ""
    $preview = @(Show-JobPreviewTable -JobNames $names -Title "Kontrola jobu pred hromadnym startem")
    $undefined = @($preview | Where-Object { $_.Defined -ne 'ANO' })
    if ($undefined.Count -gt 0) {
        Write-Host "Hromadny start zrusen - nektere nazvy nejsou v /jobs." -ForegroundColor Red
        return
    }

    $blocked = @($preview | Where-Object { $_.CurrentState -ne 'not_in_pool' })
    $requiredWord = if ($blocked.Count -gt 0 -or $names.Count -ge 5) { "START $($names.Count)" } else { 'ANO' }
    if ($requiredWord -eq 'ANO') {
        if (-not (Confirm-Action "Potvrdit hromadne spusteni?")) { Write-Host "Zruseno."; return }
    } else {
        Write-Host "Nektere joby uz jsou v poolu/dead poolu nebo jde o vetsi davku. Zkontroluj preview vyse." -ForegroundColor Yellow
        if (-not (Confirm-Action "Potvrdit hromadne spusteni $($names.Count) jobu" -Required $requiredWord)) { Write-Host "Zruseno."; return }
    }

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
    Show-DeadJobsRestartPreview -DeadJobs $dead
    Write-Host ""
    Write-Host "Detail jobu k odblokovani:" -ForegroundColor Cyan
    $dead | ForEach-Object { Write-Host (Format-JobLine $_) }
    $requiredWord = "RESTART $($dead.Count)"
    if (-not (Confirm-Action "Bude odblokovano $($dead.Count) jobu pro dalsi naplanovani. Tato akce muze pustit mnoho jobu najednou." -Required $requiredWord)) { Write-Host "Zruseno."; return }
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


function Get-JobStatusColor {
    param([string]$Status)
    switch ($Status) {
        "running"        { return "Green" }
        "failed_restart" { return "Yellow" }
        "failed_final"   { return "Red" }
        "cancelled"      { return "DarkYellow" }
        "succeeded"      { return "Green" }
        default           { return "Gray" }
    }
}

function Write-JobLine {
    param([object]$Job)
    $color = Get-JobStatusColor -Status $Job.status
    Write-Host (Format-JobLine $Job) -ForegroundColor $color
}

function Find-JobRunsByName {
        param(
        [Parameter(Mandatory)][object]$Status,
        [Parameter(Mandatory)][string]$Name
    )

    # Dulezite:
    # PowerShell pri navratu z funkce automaticky "rozbali" pole.
    # Kdyz najde presne jeden job, bez tohoto zapisu by se vratil jeden objekt,
    # ne pole, a pak by v Set-StrictMode spadlo .Count.
    $matches = @($Status.pool.jobs | Where-Object { $_.job_name -eq $Name })

    return ,$matches
}

function Show-JobStatus {
    Write-Section "Status jednoho jobu"
    $name = Read-NonEmpty "Job name"

    $status = Get-OflowStatus
    if ($null -eq $status) { return }

    $matches = Find-JobRunsByName -Status $status -Name $name

    if ($matches.Count -eq 0) {
        Write-Host "Job '$name' neni aktualne v poolu." -ForegroundColor Green
        Write-Host "To muze znamenat, ze je OK/succeeded, jeste nebyl spusten, nebo ceka na dalsi planovani."
        return
    }

    $matches | ForEach-Object { Write-JobLine $_ }
}


function Show-HealthCheck {
    Write-Section "Health check oflow"
    $status = Get-OflowStatus
    if ($null -eq $status) { return }

    $jobs = @($status.pool.jobs)
    $running   = @($jobs | Where-Object { $_.status -eq "running" })
    $retry     = @($jobs | Where-Object { $_.status -eq "failed_restart" })
    $final     = @($jobs | Where-Object { $_.status -eq "failed_final" })
    $cancelled = @($jobs | Where-Object { $_.status -eq "cancelled" })

    Write-Host "API reachable ........ OK" -ForegroundColor Green
    Write-Host "Scheduler status ..... $($status.status)"
    Write-Host "Base URL ............. $script:BaseUrl"
    Write-Host "Running since ........ $($status.running_since)"
    Write-Host "Capacity ............. $($status.pool.capacity)"
    Write-Host "Used ................. $($status.pool.used)"
    Write-Host "Total executed ....... $($status.pool.total_executed)"
    Write-Host "Restarts to OK ....... $($status.pool.total_restarts_to_success)"
    Write-Host "Jobs in pool ......... $($jobs.Count)"
    Write-Host "Running .............. $($running.Count)" -ForegroundColor Green
    Write-Host "Failed restart ....... $($retry.Count)" -ForegroundColor Yellow
    Write-Host "Failed final ......... $($final.Count)" -ForegroundColor Red
    Write-Host "Cancelled ............ $($cancelled.Count)" -ForegroundColor DarkYellow

    Write-Host ""
    if ($status.pool.capacity -eq 0) {
        Write-Host "Doporuceni: Capacity je 0, scheduler neplanuje nove joby. To je OK pri odstavce, jinak ji vrat zpet." -ForegroundColor Yellow
    } elseif ($status.pool.used -ge $status.pool.capacity) {
        Write-Host "Doporuceni: Pool je plny. Zkontroluj running/failed_restart joby." -ForegroundColor Yellow
    } elseif ($final.Count -gt 0) {
        Write-Host "Doporuceni: Existuji failed_final joby. Restartuj jen ty, u kterych znas dopad." -ForegroundColor Yellow
    } else {
        Write-Host "Doporuceni: Zakladni stav vypada v poradku." -ForegroundColor Green
    }
}

function Search-JobsAdvanced {
    Write-Section "Vyhledavani jobu podle masky"
    $mask = Read-Host "Mask/filter nazvu jobu, prazdne = vse"
    if ([string]::IsNullOrWhiteSpace($mask)) {
        $result = Invoke-OflowRequest -Path "/jobs"
    } else {
        $result = Invoke-OflowRequest -Path "/jobs?mask=$([uri]::EscapeDataString($mask))"
    }

    $status = Get-OflowStatus
    $poolJobs = @()
    if ($null -ne $status) { $poolJobs = @($status.pool.jobs) }

    $jobs = @($result.jobs | Sort-Object)
    Write-Host "Pocet nalezenych definic: $($jobs.Count)" -ForegroundColor Green
    foreach ($jobName in $jobs) {
        $run = @($poolJobs | Where-Object { $_.job_name -eq $jobName } | Select-Object -First 1)
        if ($run.Count -gt 0) {
            Write-Host ("  {0,-55} | {1,-16} | ID {2}" -f $jobName, $run[0].status, $run[0].id) -ForegroundColor (Get-JobStatusColor -Status $run[0].status)
        } else {
            Write-Host ("  {0,-55} | {1}" -f $jobName, "not in pool") -ForegroundColor DarkGray
        }
    }
}

function Show-LiveMonitor {
    Write-Section "Live monitor"
    $seconds = Read-Host "Refresh v sekundach, prazdne = 5"
    if ([string]::IsNullOrWhiteSpace($seconds)) { $seconds = 5 }
    $interval = 5
    if (-not [int]::TryParse($seconds, [ref]$interval)) { $interval = 5 }
    if ($interval -lt 1) { $interval = 1 }

    $useConsoleKeys = Test-ConsoleKeyInputSupport

    if ($useConsoleKeys) {
        Write-Host "Live monitor bezi. Q = navrat do menu, ESC = navrat do menu, R = okamzity refresh." -ForegroundColor Yellow
    } else {
        Write-Host "Live monitor bezi v kompatibilnim rezimu pro tento PowerShell host." -ForegroundColor Yellow
        Write-Host "Po kazdem obnoveni: Enter = dalsi refresh, Q = navrat do menu." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 1

    while ($true) {
        Clear-Host
        Write-Host "oflow live monitor - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
        Write-Host "BaseUrl: $script:BaseUrl"

        $status = Get-OflowStatus
        if ($null -ne $status) {
            $jobs = @($status.pool.jobs)
            $running   = @($jobs | Where-Object { $_.status -eq "running" })
            $retry     = @($jobs | Where-Object { $_.status -eq "failed_restart" })
            $final     = @($jobs | Where-Object { $_.status -eq "failed_final" })
            $cancelled = @($jobs | Where-Object { $_.status -eq "cancelled" })

            Write-Host ""
            Write-Host "Capacity: $($status.pool.used) / $($status.pool.capacity) used | Executed: $($status.pool.total_executed) | Failed final: $($final.Count)"
            Write-Host "Running: $($running.Count) | Failed_restart: $($retry.Count) | Cancelled: $($cancelled.Count)"
            Write-Host ""

            if ($running.Count -gt 0) {
                Write-Host "RUNNING" -ForegroundColor Green
                $running | Select-Object -First 10 | ForEach-Object { Write-JobLine $_ }
                Write-Host ""
            }
            if ($retry.Count -gt 0) {
                Write-Host "FAILED_RESTART" -ForegroundColor Yellow
                $retry | Select-Object -First 10 | ForEach-Object { Write-JobLine $_ }
                Write-Host ""
            }
            if ($final.Count -gt 0) {
                Write-Host "FAILED_FINAL - prvnich 10" -ForegroundColor Red
                $final | Select-Object -First 10 | ForEach-Object { Write-JobLine $_ }
            }
        }

        Write-Host ""
        if ($useConsoleKeys) {
            Write-Host "Q/ESC = navrat do menu | R = refresh hned | automaticky refresh za $interval s" -ForegroundColor DarkGray

            # Cekani po kratkych usecich, aby slo z monitoru odejit bez CTRL+C.
            for ($i = 0; $i -lt ($interval * 10); $i++) {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq [ConsoleKey]::Q -or $key.Key -eq [ConsoleKey]::Escape) {
                        return
                    }
                    if ($key.Key -eq [ConsoleKey]::R) {
                        break
                    }
                }
                Start-Sleep -Milliseconds 100
            }
        } else {
            Write-Host "Enter = refresh | Q = navrat do menu" -ForegroundColor DarkGray
            $answer = Read-Host "Dalsi krok"
            if ($answer -match '^(q|Q)$') {
                return
            }
        }
    }
}

function Export-StatusSnapshot {
    Write-Section "Export status snapshot"
    $status = Get-OflowStatus
    if ($null -eq $status) { return }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $jsonFile = "oflow_status_$stamp.json"
    $txtFile  = "oflow_status_$stamp.txt"

    $status | ConvertTo-Json -Depth 20 | Set-Content -Path $jsonFile -Encoding UTF8

    $jobs = @($status.pool.jobs)
    $lines = @()
    $lines += "oflow status snapshot $stamp"
    $lines += "BaseUrl: $script:BaseUrl"
    $lines += "Status: $($status.status)"
    $lines += "Running since: $($status.running_since)"
    $lines += "Capacity: $($status.pool.used) / $($status.pool.capacity) used"
    $lines += "Total executed: $($status.pool.total_executed)"
    $lines += "Current failed: $($status.pool.current_failed)"
    $lines += "Jobs in pool: $($jobs.Count)"
    $lines += ""
    $lines += "Jobs:"
    foreach ($job in $jobs) {
        $lines += (Format-JobLine $job)
    }
    $lines | Set-Content -Path $txtFile -Encoding UTF8

    Write-Host "Export hotov:" -ForegroundColor Green
    Write-Host "  $jsonFile"
    Write-Host "  $txtFile"
}

function Show-RunningOrWaitingJobs {
    Write-Section "Running / Waiting jobs"

    $status = Get-OflowStatus
    if ($null -eq $status) { return }

    $jobs = @($status.pool.jobs | Where-Object {
        $_.status -in @("running", "failed_restart")
    })

    if ($jobs.Count -eq 0) {
        Write-Host "Zadne running ani failed_restart joby." -ForegroundColor Green
        return
    }

    $running = @($jobs | Where-Object { $_.status -eq "running" })
    $waiting = @($jobs | Where-Object { $_.status -eq "failed_restart" })

    Write-Host ""
    Write-Host "Souhrn:" -ForegroundColor Cyan
    Write-Host "  Running        : $($running.Count)" -ForegroundColor Green
    Write-Host "  Failed_restart : $($waiting.Count)" -ForegroundColor Yellow
    Write-Host ""

    if ($running.Count -gt 0) {
        Write-Host "RUNNING jobs:" -ForegroundColor Green
        $running |
            Sort-Object last_change |
            ForEach-Object {
                Write-Host ("  ID {0,-6} | {1,-55} | {2,-16} | runs: {3,-3} | last change: {4}" -f `
                    $_.id, $_.job_name, $_.status, $_.run_count, $_.last_change)
            }
        Write-Host ""
    }

    if ($waiting.Count -gt 0) {
        Write-Host "FAILED_RESTART jobs - cekaji na automaticky retry:" -ForegroundColor Yellow
        $waiting |
            Sort-Object last_change |
            ForEach-Object {
                Write-Host ("  ID {0,-6} | {1,-55} | {2,-16} | runs: {3,-3} | last change: {4}" -f `
                    $_.id, $_.job_name, $_.status, $_.run_count, $_.last_change)
            }

        Write-Host ""
        Write-Host "Doporuceni:" -ForegroundColor Yellow
        Write-Host "  Tyto joby drzi kapacitu poolu a cekaji na retry."
        Write-Host "  Pokud jich je tolik jako capacity, pool bude plny, i kdyz nic aktualne nebezi."
        Write-Host "  Obvykle pockej cca retry_backoff_seconds a znovu zkontroluj status."
    }
}

function Invoke-JobDiagnostics {
    Write-Section "Kompletni diagnostika jobu"
    $name = Read-NonEmpty "Job name"

    $status = Get-OflowStatus
    if ($null -eq $status) { return }

    Write-Host "JOB: $name" -ForegroundColor Cyan
    Write-Host ""

    $runs = Find-JobRunsByName -Status $status -Name $name
    Write-Host "1) Current status" -ForegroundColor Cyan
    if ($runs.Count -eq 0) {
        Write-Host "  Job neni v poolu." -ForegroundColor Green
    } else {
        $runs | ForEach-Object { Write-JobLine $_ }
    }

    Write-Host ""
    Write-Host "2) Definition" -ForegroundColor Cyan
    $job = $null
    try {
        $job = Invoke-OflowRequest -Path "/job/$([uri]::EscapeDataString($name))"
        Write-Host "  Exists:       ANO" -ForegroundColor Green
        Write-Host "  Command:      $($job.command_line -join ' ')"
        Write-Host "  Priority:     $($job.priority)"
        Write-Host "  Max runs:     $($job.max_runs)"
        Write-Host "  Timeout:      $($job.max_run_time_seconds)s"
        Write-Host "  Restart/sec:  $($job.restart_after_seconds)s"
        Write-Host "  First run:    $($job.first_run_attempt)"
    }
    catch {
        Write-Host "  Exists: NE / nelze nacist definici: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "3) Stats" -ForegroundColor Cyan
    try {
        $stats = Invoke-OflowRequest -Path "/job_stats/$([uri]::EscapeDataString($name))" -UseToken
        Write-Host "  Since last start: starts=$($stats.since_last_start.total_starts), success=$($stats.since_last_start.successes), failures=$($stats.since_last_start.failures), timeouts=$($stats.since_last_start.timeouts), avg=$($stats.since_last_start.avg_duration_seconds)s"
        Write-Host "  All time:         exec=$($stats.all_time.total_executions), success=$($stats.all_time.total_successes), failures=$($stats.all_time.total_failures), timeouts=$($stats.all_time.total_timeouts), avg=$($stats.all_time.avg_duration_seconds)s"
    }
    catch {
        Write-Host "  Stats nelze nacist: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "4) Next run" -ForegroundColor Cyan
    try {
        $next = Invoke-OflowRequest -Path "/next_jobs?limit=500"
        $item = @($next.next_jobs | Where-Object { $_.job_name -eq $name } | Select-Object -First 1)
        if ($item.Count -eq 0) {
            Write-Host "  Job neni v next_jobs. Pravdepodobne je blokovan stavem v poolu/dead poolu, nebo zatim nema dalsi termin."
        } else {
            Write-Host "  Next run: $($item[0].next_run), in: $($item[0].seconds_until)s, reason: $($item[0].reason)"
        }
    }
    catch {
        Write-Host "  Next jobs nelze nacist: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "5) Recommendation" -ForegroundColor Cyan
    if ($runs.Count -eq 0) {
        Write-Host "  Job neni v poolu. Pro okamzity test muzes pouzit Start job now, pokud znas dopad." -ForegroundColor Green
    } else {
        $run = $runs[0]
        switch ($run.status) {
            "running"        { Write-Host "  Job prave bezi. Pokud visi nebo blokuje pool, lze ho cancelovat podle ID $($run.id)." -ForegroundColor Yellow }
            "failed_restart" { Write-Host "  Job ceka na auto-retry a drzi slot. Pokud nechces cekat, lze cancel ID $($run.id), potom restart." -ForegroundColor Yellow }
            "failed_final"   { Write-Host "  Job vycerpal pokusy. Lze restartovat ID $($run.id), ale nejdrive zkontroluj duvod padu." -ForegroundColor Red }
            "cancelled"      { Write-Host "  Job je zruseny. Lze restartovat ID $($run.id), pokud ho chces znovu pustit do planovani." -ForegroundColor DarkYellow }
            default           { Write-Host "  Neznamy/neobvykly stav: $($run.status)." -ForegroundColor Yellow }
        }
    }
}


function Get-ObjectPropertyValue {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string[]]$Names,
        $Default = $null
    )

    if ($null -eq $Object) { return $Default }

    foreach ($name in $Names) {
        $prop = $Object.PSObject.Properties[$name]
        if ($null -ne $prop -and $null -ne $prop.Value) {
            return $prop.Value
        }
    }

    return $Default
}

function Get-OflowJobNameFromObject {
    param($Object)

    if ($null -eq $Object) { return $null }

    if ($Object -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Object)) { return $null }
        return $Object.Trim()
    }

    $value = Get-ObjectPropertyValue -Object $Object -Names @('job_name', 'name', 'JobName', 'Name')
    if ($null -eq $value) { return $null }

    $text = [string]$value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return $text.Trim()
}

function Get-OflowJobStatusFromObject {
    param($Object)

    $value = Get-ObjectPropertyValue -Object $Object -Names @('status', 'state', 'Status', 'State') -Default 'unknown'
    $text = [string]$value
    if ([string]::IsNullOrWhiteSpace($text)) { return 'unknown' }
    return $text.Trim().ToLower()
}

function Get-OflowJobPrefix {
    param([string]$JobName)

    if ([string]::IsNullOrWhiteSpace($JobName)) {
        return "unknown"
    }

    $name = $JobName.Trim()
    if ($name -match "_") {
        return (($name -split "_", 2)[0]).ToLower()
    }

    return $name.ToLower()
}

function Get-OflowJobInventory {
    <#
        Vraci sjednoceny pohled nad:
          - definicemi z /jobs
          - aktualnim stavem z /status pool.jobs

        Poznamka:
        /jobs obvykle vraci vsechny definice jobu, ale bez provozniho stavu.
        /status vraci joby, ktere jsou aktualne v poolu / problemovem stavu.
        Proto job bez zaznamu v poolu oznacujeme jako not_in_pool.
    #>

    $definitions = @()
    try {
        $jobsResult = Invoke-OflowRequest -Path "/jobs"

        $rawJobs = @()
        if ($null -ne $jobsResult -and $null -ne $jobsResult.PSObject.Properties['jobs']) {
            $rawJobs = @($jobsResult.jobs)
        }
        elseif ($jobsResult -is [System.Array]) {
            $rawJobs = @($jobsResult)
        }
        else {
            $rawJobs = @($jobsResult)
        }

        $definitions = @($rawJobs |
            ForEach-Object { Get-OflowJobNameFromObject -Object $_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique)
    }
    catch {
        Write-Host "Nepodarilo se nacist /jobs: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }

    $status = Get-OflowStatus
    $poolJobs = @()
    if ($null -ne $status -and $null -ne $status.PSObject.Properties['pool'] -and $null -ne $status.pool -and $null -ne $status.pool.PSObject.Properties['jobs']) {
        $poolJobs = @($status.pool.jobs)
    }

    $poolByName = @{}
    foreach ($poolJob in $poolJobs) {
        $name = Get-OflowJobNameFromObject -Object $poolJob
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if (-not $poolByName.ContainsKey($name)) {
            $poolByName[$name] = @()
        }
        $poolByName[$name] += $poolJob
    }

    $inventory = @()

    foreach ($jobName in $definitions) {
        $prefix = Get-OflowJobPrefix -JobName $jobName

        if ($poolByName.ContainsKey($jobName)) {
            foreach ($run in @($poolByName[$jobName])) {
                $inventory += [PSCustomObject]@{
                    Prefix     = $prefix
                    JobName    = $jobName
                    Status     = Get-OflowJobStatusFromObject -Object $run
                    Id         = Get-ObjectPropertyValue -Object $run -Names @('id', 'Id')
                    RunCount   = Get-ObjectPropertyValue -Object $run -Names @('run_count', 'RunCount')
                    LastChange = Get-ObjectPropertyValue -Object $run -Names @('last_change', 'LastChange')
                    InPool     = $true
                }
            }
        }
        else {
            $inventory += [PSCustomObject]@{
                Prefix     = $prefix
                JobName    = $jobName
                Status     = "not_in_pool"
                Id         = $null
                RunCount   = $null
                LastChange = $null
                InPool     = $false
            }
        }
    }

    # Pojistka: kdyby /status obsahoval job, ktery neni v /jobs.
    foreach ($poolJob in $poolJobs) {
        $name = Get-OflowJobNameFromObject -Object $poolJob
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($definitions -notcontains $name) {
            $inventory += [PSCustomObject]@{
                Prefix     = Get-OflowJobPrefix -JobName $name
                JobName    = $name
                Status     = Get-OflowJobStatusFromObject -Object $poolJob
                Id         = Get-ObjectPropertyValue -Object $poolJob -Names @('id', 'Id')
                RunCount   = Get-ObjectPropertyValue -Object $poolJob -Names @('run_count', 'RunCount')
                LastChange = Get-ObjectPropertyValue -Object $poolJob -Names @('last_change', 'LastChange')
                InPool     = $true
            }
        }
    }

    # Dulezite: nevracet pres carku, jinak PowerShell vrati jednu zabalenou kolekci
    # a dalsi funkce pak nevidi vlastnosti Prefix/JobName na jednotlivych radcich.
    return $inventory
}

function Show-OflowSystemsPrefixes {
    Write-Section "Systemy/prefixy v oflow"

    $inventory = @(Get-OflowJobInventory)
    if ($inventory.Count -eq 0) {
        Write-Host "Nebyly nalezeny zadne joby." -ForegroundColor Yellow
        return
    }

    $systems = @($inventory |
        Group-Object Prefix |
        ForEach-Object {
            $items = @($_.Group)
            [PSCustomObject]@{
                System    = $_.Name
                Jobu      = ($items | Select-Object -ExpandProperty JobName -Unique).Count
                VPoolu    = @($items | Where-Object { $_.InPool }).Count
                MimoPool  = @($items | Where-Object { -not $_.InPool }).Count
            }
        } |
        Sort-Object System)

    Write-Host "Prehled prefixu podle nazvu jobu pred prvnim podtrzitkem." -ForegroundColor Cyan
    Write-Host "Priklad: ocs_sms_import -> system/prefix = ocs"
    Write-Host ""
    $systems | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Celkem systemu/prefixu: $($systems.Count)" -ForegroundColor Green
    $uniqueJobCount = @($inventory | Select-Object -ExpandProperty JobName -Unique).Count
    Write-Host "Celkem job definic:     $uniqueJobCount" -ForegroundColor Green
}

function Show-OflowSystemsStatusSummary {
    Write-Section "Souhrn stavu podle systemu"

    $inventory = @(Get-OflowJobInventory)
    if ($inventory.Count -eq 0) {
        Write-Host "Nebyly nalezeny zadne joby." -ForegroundColor Yellow
        return
    }

    $summary = @($inventory |
        Group-Object Prefix |
        ForEach-Object {
            $items = @($_.Group)
            [PSCustomObject]@{
                System        = $_.Name
                Total         = ($items | Select-Object -ExpandProperty JobName -Unique).Count
                NotInPool     = @($items | Where-Object { $_.Status -eq "not_in_pool" }).Count
                Running       = @($items | Where-Object { $_.Status -eq "running" }).Count
                FailedRestart = @($items | Where-Object { $_.Status -eq "failed_restart" }).Count
                FailedFinal   = @($items | Where-Object { $_.Status -eq "failed_final" }).Count
                Cancelled     = @($items | Where-Object { $_.Status -eq "cancelled" }).Count
                Succeeded     = @($items | Where-Object { $_.Status -in @("succeeded", "success", "done", "completed", "finished") }).Count
                Other         = @($items | Where-Object { $_.Status -notin @("not_in_pool", "running", "failed_restart", "failed_final", "cancelled", "succeeded", "success", "done", "completed", "finished") }).Count
            }
        } |
        Sort-Object System)

    $summary | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Poznamka:" -ForegroundColor Yellow
    Write-Host "  NotInPool = job existuje v /jobs, ale neni aktualne v poolu z /status."
    Write-Host "  FailedRestart = ceka na retry a muze drzet slot v poolu."
    Write-Host "  FailedFinal/Cancelled = obvykle vyzaduje rucni kontrolu nebo restart."
}

function Show-OflowFailedJobsBySystem {
    Write-Section "Failed joby podle systemu"

    $inventory = @(Get-OflowJobInventory)
    if ($inventory.Count -eq 0) {
        Write-Host "Nebyly nalezeny zadne joby." -ForegroundColor Yellow
        return
    }

    $failedStatuses = @("failed_restart", "failed_final", "cancelled")
    $failed = @($inventory | Where-Object { $_.Status -in $failedStatuses } | Sort-Object Prefix, Status, JobName)

    if ($failed.Count -eq 0) {
        Write-Host "Zadne failed_restart / failed_final / cancelled joby." -ForegroundColor Green
        return
    }

    Write-Host "Souhrn:" -ForegroundColor Cyan
    $failed |
        Group-Object Prefix |
        ForEach-Object {
            $items = @($_.Group)
            [PSCustomObject]@{
                System        = $_.Name
                FailedRestart = @($items | Where-Object { $_.Status -eq "failed_restart" }).Count
                FailedFinal   = @($items | Where-Object { $_.Status -eq "failed_final" }).Count
                Cancelled     = @($items | Where-Object { $_.Status -eq "cancelled" }).Count
                Celkem        = $items.Count
            }
        } |
        Sort-Object System |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "Detail:" -ForegroundColor Cyan
    $failed |
        Select-Object Prefix, JobName, Status, Id, RunCount, LastChange |
        Format-Table -AutoSize
}

function Show-OflowJobsBySystemDetail {
    Write-Section "Detail jobu pro system"

    $inventory = @(Get-OflowJobInventory)
    if ($inventory.Count -eq 0) {
        Write-Host "Nebyly nalezeny zadne joby." -ForegroundColor Yellow
        return
    }

    $systems = @($inventory | Select-Object -ExpandProperty Prefix -Unique | Sort-Object)
    Write-Host "Dostupne systemy/prefixy:" -ForegroundColor Cyan
    Write-Host ($systems -join ", ")
    Write-Host ""

    $prefix = Read-NonEmpty "Zadej system/prefix"
    $selected = @($inventory | Where-Object { $_.Prefix -eq $prefix.Trim().ToLower() } | Sort-Object Status, JobName)

    if ($selected.Count -eq 0) {
        Write-Host "Pro prefix '$prefix' nebyly nalezeny zadne joby." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Souhrn pro prefix '$($prefix.Trim().ToLower())':" -ForegroundColor Cyan
    $selected |
        Group-Object Status |
        ForEach-Object {
            [PSCustomObject]@{
                Status = $_.Name
                Pocet  = $_.Count
            }
        } |
        Sort-Object Status |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "Detail jobu:" -ForegroundColor Cyan
    $selected |
        Select-Object JobName, Status, Id, RunCount, LastChange |
        Format-Table -AutoSize
}


function Show-Menu {
    Clear-Host

    $colWidth = 70

    Write-Host "oflow ops admin" -ForegroundColor Cyan
    Write-Host "BaseUrl: $script:BaseUrl"
    if ($Scheme -eq 'https') {
        Write-Host "TLS:     $(Get-CertificateValidationLabel)" -ForegroundColor DarkGray
    }

    if ([string]::IsNullOrWhiteSpace($script:AuthToken)) {
        Write-Host "Token:   not loaded" -ForegroundColor Yellow
    } else {
        Write-Host "Token:   loaded in memory" -ForegroundColor Green
    }

    Write-Host ""

    Write-Host ("STATUS / READ-ONLY".PadRight($colWidth)) -NoNewline -ForegroundColor Cyan
    Write-Host "JOB CONTROL - zasahuje do jobu" -ForegroundColor Cyan

    Write-Host (" 1 - Health check / rychla diagnostika".PadRight($colWidth)) -NoNewline
    Write-Host "14 - Start job now"

    Write-Host (" 2 - Detailni status + joby podle stavu".PadRight($colWidth)) -NoNewline
    Write-Host "15 - Start multiple jobs"

    Write-Host (" 3 - Running / Waiting jobs".PadRight($colWidth)) -NoNewline
    Write-Host "16 - Cancel job by ID"

    Write-Host (" 4 - Status jednoho jobu".PadRight($colWidth)) -NoNewline
    Write-Host "17 - Restart job by ID"

    Write-Host (" 5 - Seznam job definic (/jobs)".PadRight($colWidth)) -NoNewline
    Write-Host "18 - Restart all failed/cancelled"

    Write-Host (" 6 - Vyhledavani jobu podle masky + stav".PadRight($colWidth)) -NoNewline
    Write-Host "19 - Pause job do konkretniho casu"

    Write-Host (" 7 - Detail jobu (/job/name)".PadRight($colWidth)) -NoNewline
    Write-Host "20 - Enable job now"

    Write-Host (" 8 - Next jobs (/next_jobs)".PadRight($colWidth)) -NoNewline
    Write-Host ""

    Write-Host (" 9 - Job stats".PadRight($colWidth)) -NoNewline
    Write-Host ""

    Write-Host ("10 - Job log".PadRight($colWidth)) -NoNewline
    Write-Host ""

    Write-Host ("11 - Live monitor".PadRight($colWidth)) -NoNewline
    Write-Host ""

    Write-Host ("12 - Export status snapshot".PadRight($colWidth)) -NoNewline
    Write-Host ""

    Write-Host ("13 - Kompletni diagnostika jobu".PadRight($colWidth)) -NoNewline
    Write-Host ""

    Write-Host ""

    Write-Host ("POOL / SYSTEM - meni beh scheduleru".PadRight($colWidth)) -NoNewline -ForegroundColor Cyan
    Write-Host "PROVOZNI PREHLEDY / SYSTEMY" -ForegroundColor Cyan

    Write-Host ("21 - Pool capacity".PadRight($colWidth)) -NoNewline
    Write-Host "30 - Systemy/prefixy v oflow"

    Write-Host ("22 - Graceful shutdown oflow".PadRight($colWidth)) -NoNewline
    Write-Host "31 - Souhrn stavu podle systemu"

    Write-Host ("".PadRight($colWidth)) -NoNewline
    Write-Host "32 - Failed joby podle systemu"

    Write-Host ("".PadRight($colWidth)) -NoNewline
    Write-Host "33 - Detail jobu pro system"

    Write-Host ""
    Write-Host " 0 - Konec" -ForegroundColor Yellow
    Write-Host ""
}

Write-ConnectionStartupNotes

while ($true) {
    Show-Menu
    $choice = Read-Host "Vyber akci"

    try {
        switch ($choice) {
            "1"  { Show-HealthCheck }
            "2"  { Show-Status }
            "3"  { Show-RunningOrWaitingJobs }
            "4"  { Show-JobStatus }
            "5"  { Show-Jobs }
            "6"  { Search-JobsAdvanced }
            "7"  { Show-JobDefinition }
            "8"  { Show-NextJobs }
            "9"  { Show-JobStats }
            "10" { Show-JobLog }
            "11" { Show-LiveMonitor }
            "12" { Export-StatusSnapshot }
            "13" { Invoke-JobDiagnostics }

            "14" { Start-JobNow }
            "15" { Start-MultipleJobs }
            "16" { Cancel-JobById }
            "17" { Restart-JobById }
            "18" { Restart-AllDeadJobs }
            "19" { Pause-Job }
            "20" { Enable-JobNow }

            "21" { Set-CapacityMenu }
            "22" { Shutdown-Oflow }

            "30" { Show-OflowSystemsPrefixes }
            "31" { Show-OflowSystemsStatusSummary }
            "32" { Show-OflowFailedJobsBySystem }
            "33" { Show-OflowJobsBySystemDetail }

            "0"  {
                Write-Host "Konec."
                break
            }

            default {
                Write-Host "Neplatna volba: $choice" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "Chyba: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Read-Host "Stiskni Enter pro navrat do menu"
}