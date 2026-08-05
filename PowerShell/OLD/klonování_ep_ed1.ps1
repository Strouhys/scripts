#gcloud auth login jiri.strouhal@o2.cz --force

chcp 65001 | Out-Null

[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$SourceProject = "o2czep"
$TargetProject = "o2czed1"
$Dataset       = "stg_data"

$RunSuffix = Get-Date -Format "yyyyMMdd_HHmmss"

$Tables = @(
    "bscs_ca_o2s3_reve_estimate",
"bscs_rtx",
"bscs_rtx_free",
"bscs_rtx_tap",
"bscs_tot_zone_mdl_map_mpulkgvm",
"ebox_views_v2",
"imd_call_fix_df001",
"imd_call_transit_df001",
"imd_ccdu_df001",
"imd_data_pgwr",
"imd_data_scdr",
"imd_data_sgwr",
"imd_fsms",
"imd_gsm_tap",
"imd_gsm_tap_data",
"imd_gsm_tap_data_out",
"imd_gsm_tap_out",
"imd_hua",
"imd_chat_df001",
"imd_imsn",
"imd_inas",
"imd_info_sms",
"imd_jsms",
"imd_lte_pgwr",
"imd_lte_sgwr",
"imd_mms",
"imd_msgp",
"imd_npp",
"imd_o2tv",
"imd_onapp_event",
"imd_radius_ipqm",
"imd_tmm",
"imd_umts_forw",
"imd_umts_moc",
"imd_umts_mtc",
"imd_umts_pbxo",
"imd_umts_pbxt",
"imd_umts_poc",
"imd_umts_ptc",
"imd_umts_smmo",
"imd_umts_smmt",
"imd_umts_soc",
"imd_umts_stc",
"imd_vlte_forw",
"imd_vlte_moc",
"imd_vlte_mtc",
"imd_wsp",
"imd_xdsl",
"ocs_balance_expiry",
"ocs_bundle_activation",
"ocs_bundle_deactivation",
"ocs_bundle_failed_renewal",
"ocs_bundle_recharge",
"ocs_bundle_renewal",
"ocs_circuit_switched",
"ocs_data_iec",
"ocs_data_scur",
"ocs_change_product_type",
"ocs_charge",
"ocs_initial_credit",
"ocs_mms",
"ocs_prov_account_creation",
"ocs_prov_account_deletion",
"ocs_recharge",
"ocs_sms",
"ocs_subscriber_lifecycle",
"ocs_tariff_update",
"ocs_vas_check_charge",
"ocs_vas_refund",
"ocs_vas_reserve_commit",
"omni_campaign_notifications",
"rmca_dfkkko",
"rmca_dfkkop",
"rmca_dfkkopk",
"rmca_invoice_header",
"rmca_invoice_item",
"rmca_invoice_tax_summary",
"sfa_audit",
"zis_service_parameters"
)

function Test-BqTable {
    param(
        [Parameter(Mandatory)]
        [string]$TableReference
    )

    bq show --format=none $TableReference 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

$Results = foreach ($TableName in $Tables) {
    $Table = $TableName.ToLowerInvariant()

    $Source = "${SourceProject}:${Dataset}.${Table}"
    $Target = "${TargetProject}:${Dataset}.${Table}"

    $BackupTable = "${Table}_backup_${RunSuffix}"
    $Backup = "${TargetProject}:${Dataset}.${BackupTable}"

    $TestTable = "${Table}_clone_test_${RunSuffix}"
    $TestClone = "${TargetProject}:${Dataset}.${TestTable}"

    $TargetOriginallyExisted = $false
    $BackupCreated = $false

    Write-Host ""
    Write-Host "======================================================"
    Write-Host "Tabulka: $Table" -ForegroundColor Cyan
    Write-Host "Zdroj:   $Source"
    Write-Host "Cíl:     $Target"

    try {
        # 1. Kontrola produkční tabulky
        if (-not (Test-BqTable -TableReference $Source)) {
            throw "Produkční tabulka neexistuje nebo k ní není přístup."
        }

        Write-Host "Produkční zdroj existuje." -ForegroundColor Green

        # 2. Zkušební klon – ověří oprávnění, lokaci a možnost klonování
        Write-Host "Vytvářím dočasný kontrolní klon..."

        bq cp -n --clone=true $Source $TestClone

        if ($LASTEXITCODE -ne 0) {
            throw "Dočasný kontrolní klon se nepodařilo vytvořit."
        }

        if (-not (Test-BqTable -TableReference $TestClone)) {
            throw "Dočasný klon byl nahlášen jako vytvořený, ale nelze jej ověřit."
        }

        Write-Host "Kontrolní klon je v pořádku." -ForegroundColor Green

        # 3. Kontrola aktuální ED1 tabulky
        $TargetOriginallyExisted = Test-BqTable -TableReference $Target

        if ($TargetOriginallyExisted) {
            Write-Host "ED1 tabulka existuje. Vytvářím zálohu:"
            Write-Host $Backup

            bq cp -n --clone=true $Target $Backup

            if ($LASTEXITCODE -ne 0) {
                throw "Zálohu původní ED1 tabulky se nepodařilo vytvořit."
            }

            if (-not (Test-BqTable -TableReference $Backup)) {
                throw "Vytvořenou zálohu nelze ověřit."
            }

            $BackupCreated = $true
            Write-Host "Záloha byla vytvořena." -ForegroundColor Green

            # 4. Odstranění staré ED1 tabulky
            Write-Host "Odstraňuji starou ED1 tabulku..."

            bq rm -f -t $Target

            if ($LASTEXITCODE -ne 0) {
                throw "Starou ED1 tabulku se nepodařilo odstranit."
            }

            if (Test-BqTable -TableReference $Target) {
                throw "Stará ED1 tabulka po příkazu bq rm stále existuje."
            }
        }
        else {
            Write-Host "ED1 tabulka neexistuje, záloha není potřeba."
        }

        # 5. Vytvoření finálního klonu přímo z produkce
        Write-Host "Vytvářím finální klon z produkce..."

        bq cp -n --clone=true $Source $Target

        if ($LASTEXITCODE -ne 0) {
            throw "Finální produkční klon se nepodařilo vytvořit."
        }

        if (-not (Test-BqTable -TableReference $Target)) {
            throw "Finální cílovou tabulku nelze po vytvoření ověřit."
        }

        # 6. Ověření, že cílová tabulka je opravdu klon produkčního zdroje
        $TargetJson = bq show --format=prettyjson $Target | ConvertFrom-Json

        $BaseProject = $TargetJson.cloneDefinition.baseTableReference.projectId
        $BaseDataset = $TargetJson.cloneDefinition.baseTableReference.datasetId
        $BaseTable   = $TargetJson.cloneDefinition.baseTableReference.tableId
        $ExpectedTable = $Table.ToLowerInvariant()

        if (
            $BaseProject -ne $SourceProject -or
            $BaseDataset -ne $Dataset -or
            $BaseTable.ToLowerInvariant() -ne $ExpectedTable
        ) {
            throw "Cílová tabulka existuje, ale není klonem očekávané produkční tabulky."
        }

        # 7. Odstranění dočasné zálohy až po úspěšném klonu
        if ($BackupCreated) {
            Write-Host "Odstraňuji dočasnou zálohu..."

            bq rm -f -t $Backup

            if ($LASTEXITCODE -ne 0) {
                Write-Host "Upozornění: klon je vytvořen, ale zálohu se nepodařilo odstranit." -ForegroundColor Yellow
            }
            else {
                Write-Host "Záloha byla odstraněna." -ForegroundColor Green
                $BackupCreated = $false
            }
        }

        # 8. Odstranění dočasného kontrolního klonu
        bq rm -f -t $TestClone

        Write-Host "HOTOVO: $Table" -ForegroundColor Green

        [PSCustomObject]@{
            Table       = $Table
            Status      = "SUCCESS"
            Source      = $Source
            Target      = $Target
            Backup      = if ($BackupCreated) { $Backup } else { "" }
            Message     = "Produkční klon byl úspěšně vytvořen."
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message

        Write-Host "CHYBA: $Table" -ForegroundColor Red
        Write-Host $ErrorMessage -ForegroundColor Red

        # Odstranění případného rozpracovaného cíle
        if (Test-BqTable -TableReference $Target) {
            Write-Host "Odstraňuji neověřenou cílovou tabulku..."
            bq rm -f -t $Target
        }

        # Rollback původní ED1 tabulky
        if ($TargetOriginallyExisted -and $BackupCreated) {
            Write-Host "Pokouším se obnovit původní ED1 tabulku ze zálohy..."

            bq cp -n --clone=true $Backup $Target

            if ($LASTEXITCODE -eq 0) {
                Write-Host "Původní ED1 tabulka byla obnovena." -ForegroundColor Yellow
                $ErrorMessage += " Původní ED1 tabulka byla obnovena ze zálohy."
            }
            else {
                Write-Host "Automatická obnova se nezdařila." -ForegroundColor Red
                $ErrorMessage += " Automatický rollback selhal. Záloha zůstává: $Backup"
            }
        }

        # Úklid kontrolního klonu
        if (Test-BqTable -TableReference $TestClone) {
            bq rm -f -t $TestClone
        }

        [PSCustomObject]@{
            Table       = $Table
            Status      = "FAILED"
            Source      = $Source
            Target      = $Target
            Backup      = if ($BackupCreated) { $Backup } else { "" }
            Message     = $ErrorMessage
        }
    }
}

$LogFile = Join-Path $PWD "clone_prod_to_ed1_${RunSuffix}.csv"

$Results |
    Export-Csv `
        -Path $LogFile `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host ""
Write-Host "==================== VÝSLEDEK ===================="

$Results |
    Format-Table Table, Status, Backup, Message -AutoSize

$SuccessCount = @($Results | Where-Object Status -eq "SUCCESS").Count
$FailedCount  = @($Results | Where-Object Status -eq "FAILED").Count

Write-Host ""
Write-Host "Úspěšně: $SuccessCount"
Write-Host "Chyby:   $FailedCount"
Write-Host "Log:     $LogFile"

if ($FailedCount -gt 0) {
    Write-Host ""
    Write-Host "Tabulky s chybou:" -ForegroundColor Red

    $Results |
        Where-Object Status -eq "FAILED" |
        Format-Table Table, Message -AutoSize
}