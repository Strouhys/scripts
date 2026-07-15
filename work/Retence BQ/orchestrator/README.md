# Retention Orchestrator MVP

Python MVP orchestrator for centralized retention processing in BigQuery.

## Scope

Current implementation:
- loads active rules from `table_retention`
- evaluates D/W/M frequency
- writes run/task audit records
- applies idempotence check by `retention_rule_id + execution_date`
- supports `COLUMN_AGE` and `CUSTOM_SQL`
- supports `--dry-run` mode

## Prerequisites

1. Python 3.10+
2. Install dependencies:

```powershell
pip install -r requirements.txt
```

3. Google auth available in runtime environment (for example `GOOGLE_APPLICATION_CREDENTIALS`).

## Nejjednodussi autentifikace (service account + .env)

1. Vytvor v rootu projektu soubor `.env` s obsahem:

```env
GOOGLE_APPLICATION_CREDENTIALS=C:\secrets\retention-sa.json
```

2. Ujisti se, ze service account ma opravneni minimalne pro:
- BigQuery Job User na projektu
- BigQuery Data Viewer + BigQuery Data Editor na datasetu `opr_data`

3. Spust orchestrator standardne, bez dalsich auth kroku:

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --orchestrator TASK_SCHEDULER --trigger-type MANUAL --dry-run --max-rules 1
```

Volitelne lze prepsat cestu ke klici i argumentem:

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --credentials-path C:\secrets\retention-sa.json --dry-run
```

## Konfigurace pres .env (co vse lze nastavit)

Orchestrator umi nacitat konfiguraci z `.env`. CLI argument ma vzdy prioritu pred `.env`.

Podporovane promene:

```env
# Metadata umisteni
RETENTION_PROJECT_ID=o2czed1
RETENTION_METADATA_DATASET=opr_data

# Rezim spusteni
RETENTION_ORCHESTRATOR=TASK_SCHEDULER
RETENTION_TRIGGER_TYPE=MANUAL
RETENTION_EXECUTION_DATE=2026-07-15
RETENTION_WEEKLY_RUN_DAY=6
RETENTION_MAX_RULES=25
RETENTION_DRY_RUN=true
RETENTION_LOG_LEVEL=INFO

# Filtry (kdyz jsou nastavene, bezi pouze filtrovany vyber)
RETENTION_RULE_ID=
RETENTION_TARGET_PROJECT=
RETENTION_TARGET_DATASET=
RETENTION_TARGET_TABLE=

# Test override retention (COLUMN_AGE only)
RETENTION_ALLOW_OVERRIDE=false
RETENTION_OVERRIDE_VALUE=
RETENTION_OVERRIDE_UNIT=
```

Chovani filtru:
- pokud je nastaveno alespon jedno z `RETENTION_RULE_ID`, `RETENTION_TARGET_PROJECT`, `RETENTION_TARGET_DATASET`, `RETENTION_TARGET_TABLE`, orchestrator spusti jen odpovidajici podmnozinu pravidel
- pokud neni nastaven zadny filtr, orchestrator zpracuje cely aktivni obsah `o2czed1.opr_data.table_retention`

Mapovani datasetu:
- `source_dataset_name` = puvodni dataset z Teradata evidence
- `bq_dataset_name` = realny cilovy dataset v BigQuery
- orchestrator vzdy pouziva `bq_dataset_name`; pokud je prazdny, pravidlo se preskoci se `status_reason=DATASET_NOT_MIGRATED`

Test override retention:
- `RETENTION_OVERRIDE_VALUE` a `RETENTION_OVERRIDE_UNIT` plati jen pro `COLUMN_AGE`
- override je aktivni jen kdyz `RETENTION_ALLOW_OVERRIDE=true` (bezpecnost proti nechtenemu pouziti)
- doporuceno kombinovat s `RETENTION_RULE_ID` a `RETENTION_DRY_RUN=true`

## Example runs

Dry-run test on test project:

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --orchestrator TASK_SCHEDULER --trigger-type MANUAL --dry-run --max-rules 25
```

Scheduled-like run:

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --orchestrator TASK_SCHEDULER --trigger-type SCHEDULED
```

Weekly override example (Saturday=6):

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --weekly-run-day 6
```

Spusteni pouze pro jednu konkretni tabulku:

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --target-project o2czed1 --target-dataset opr_data --target-table nazev_tabulky --dry-run
```

Poznamka: `--target-dataset` filtruje `bq_dataset_name`.

Spusteni pouze pro jedno konkretni pravidlo:

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --rule-id TD_AP_DM_CES_DEL_EVENT_00439 --dry-run
```

Simulace testu s docasnym prepsanim retention_value na 15 DAY:

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --rule-id TD_AP_STG_EBOX_VIEWS_V2_00003 --execution-date 2026-05-08 --dry-run --allow-retention-override --override-retention-value 15 --override-retention-unit DAY
```

## Notes

- Keep `--project-id` configurable; do not hardcode test project for production.
- Production project will be different from `o2czed1`.
- One table failure does not stop processing of other rules.
- Orchestrator automaticky zkousi nacist OS trust store (Windows cert store) pres `truststore`.
- Pravidla mohou zustat v `o2czed1.opr_data.table_retention` i pro datasety, ktere jeste nejsou premigrovane; v tom pripade se pravidlo oznaci jako skip se `status_reason=DATASET_NOT_MIGRATED`.

## Troubleshooting

If run fails with `CERTIFICATE_VERIFY_FAILED` or `self-signed certificate in certificate chain`, Python does not trust your corporate root CA for outbound HTTPS to Google APIs.

Set one of these environment variables to a PEM bundle containing your trusted corporate CA chain:

```powershell
$env:REQUESTS_CA_BUNDLE = "C:\path\to\corp-ca-bundle.pem"
```

or

```powershell
$env:SSL_CERT_FILE = "C:\path\to\corp-ca-bundle.pem"
```

Then rerun the dry-run command.

Poznamka: service account zjednodusuje autentifikaci, ale pokud je v siti TLS inspekce s firemnim certifikatem, CA trust je stale potreba nastavit i pro Python.

Ve vetsine firemnich Windows prostredi by to mel vyresit automaticky `truststore` (pokud je firemni CA v systemovem ulozisti certifikatu).
