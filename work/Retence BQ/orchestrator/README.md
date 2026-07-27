# Orchestrátor Retenčních Pravidel (MVP)

Python orchestrátor pro centralizovanou správu retenčních pravidel v BigQuery.
**Stav:** Produkčně připraveno (k 2026-07-27)

## Rozsah

**Hlavní funkce:**
- Načítá aktivní pravidla z `table_retention` s volitelným filtrováním (rule_id, projekt, dataset, tabulka)
- Vyhodnocuje frekvenci D/W/M (denně, týdně podle dne v týdnu, měsíčně podle dne v měsíci)
- Zapisuje audit běhu a tasků do `retention_run` a `retention_task_run`
- Zajišťuje idempotenci pomocí `retention_rule_id + execution_date`
- Podporuje `COLUMN_AGE` (automatická WHERE generace) a `CUSTOM_SQL` (vlastní podmínka)
- Podporuje mód `--dry-run` pro bezpečné testování bez skutečného mazání
- Mechanismus přepsání pro ověřovací testování (dočasné přepsání retention_value/unit)

**Otestované scénáře (2026-07-27):**
- ✅ Mazání jednotlivého pravidla (OCS_SMS, 2 DAY COLUMN_AGE)
- ✅ Ověření módu dry-run
- ✅ Skutečné DELETE s ověřením idempotence
- ✅ Mechanismus přepsání (1 DAY pro testování více pravidel)
- ✅ Vyhodnocení frekvence (D/W/M logika funguje správně)

**Známá omezení:**
- 435 pravidel bez mapování `bq_dataset_name` zůstává aktivních (čeká se na migraci datasetů)
- 2 pravidla deaktivována z důvodu eksterne závislostí (poddotaz ep_opr.asg_consumed_stat není v BQ dostupný)
- 8 pravidel s chybějícím `bq_execution_where_clause` (vyžaduje ruční kontrolu nebo konverzi)

## Instalace a Autentizace

### Předpoklady

1. Python 3.10+
2. Instalace závislostí:

```powershell
pip install -r ../requirements.txt
```

3. Google BigQuery autentizace dostupná v runtime prostředí

### Nastavení Service Account (Doporučeno)

1. Vytvořte soubor `.env` v kořenovém adresáři projektu:

```env
GOOGLE_APPLICATION_CREDENTIALS=C:\cesta\k\retention-sa.json
RETENTION_PROJECT_ID=o2czed1
RETENTION_METADATA_DATASET=opr_data
```

2. Service account vyžaduje minimálně tyto role:
- BigQuery Job User
- BigQuery Data Viewer + BigQuery Data Editor na datasetu `opr_data`

3. Pokud je v korporátní síti aktivní TLS inspekce, Python se může selhat na SSL ověření:

```powershell
$env:REQUESTS_CA_BUNDLE = "C:\cesta\k\corp-ca-bundle.pem"
# nebo
$env:SSL_CERT_FILE = "C:\cesta\k\corp-ca-bundle.pem"
```

Poznámka: Modul Windows `truststore` by měl automaticky načítat systémové certifikáty.

## Konfigurace přes .env (co vše lze nastavit)

Orchestrátor umí načítat konfiguraci ze souboru `.env`. CLI argument má vždy prioritu před `.env`.

Podporované proměnné:

```env
# Umístění metadat
RETENTION_PROJECT_ID=o2czed1
RETENTION_METADATA_DATASET=opr_data

# Režim spuštění
RETENTION_ORCHESTRATOR=TASK_SCHEDULER
RETENTION_TRIGGER_TYPE=MANUAL
RETENTION_EXECUTION_DATE=2026-07-15
RETENTION_WEEKLY_RUN_DAY=6
RETENTION_MAX_RULES=25
RETENTION_DRY_RUN=true
RETENTION_LOG_LEVEL=INFO

# Filtry (když jsou nastavené, běží pouze filtrovaný výběr)
RETENTION_RULE_ID=
RETENTION_TARGET_PROJECT=
RETENTION_TARGET_DATASET=
RETENTION_TARGET_TABLE=

# Test přepsání retention (pouze COLUMN_AGE)
RETENTION_ALLOW_OVERRIDE=false
RETENTION_OVERRIDE_VALUE=
RETENTION_OVERRIDE_UNIT=
```

**Chování filtrů:**
- Pokud je nastaveno alespoň jedno z `RETENTION_RULE_ID`, `RETENTION_TARGET_PROJECT`, `RETENTION_TARGET_DATASET`, `RETENTION_TARGET_TABLE`, orchestrátor spustí jen odpovídající podmnožinu pravidel
- Pokud není nastaven žádný filtr, orchestrátor zpracuje celý aktivní obsah `o2czed1.opr_data.table_retention`

**Mapování datasetů:**
- `source_dataset_name` = původní dataset z Teradata evidence
- `bq_dataset_name` = skutečný cílový dataset v BigQuery
- Orchestrátor vždy používá `bq_dataset_name`; pokud je prázdný, pravidlo se přeskočí s `status_reason=DATASET_NOT_MIGRATED`

**Test přepsání retention:**
- `RETENTION_OVERRIDE_VALUE` a `RETENTION_OVERRIDE_UNIT` platí jen pro `COLUMN_AGE`
- Přepsání je aktivní jen když `RETENTION_ALLOW_OVERRIDE=true` (bezpečnost proti nechtěnému použití)
- Doporučeno kombinovat s `RETENTION_RULE_ID` a `RETENTION_DRY_RUN=true`

## Příklady spuštění

**Dry-run test na testovacím projektu:**

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --orchestrator TASK_SCHEDULER --trigger-type MANUAL --dry-run --max-rules 25
```

**Plánované spuštění:**

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --orchestrator TASK_SCHEDULER --trigger-type SCHEDULED
```

**Týdenní přepsání (sobota=6):**

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --weekly-run-day 6
```

**Spuštění pouze pro jednu konkrétní tabulku:**

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --target-project o2czed1 --target-dataset opr_data --target-table nazev_tabulky --dry-run
```

Poznámka: `--target-dataset` filtruje `bq_dataset_name`.

**Spuštění pouze pro jedno konkrétní pravidlo:**

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --rule-id TD_AP_DM_CES_DEL_EVENT_00439 --dry-run
```

**Simulace testu s dočasným přepsáním retention_value na 15 DNÍ:**

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --rule-id TD_AP_STG_EBOX_VIEWS_V2_00003 --execution-date 2026-05-08 --dry-run --allow-retention-override --override-retention-value 15 --override-retention-unit DAY
```

## Poznámky

- Zachovejte `--project-id` konfigurovatelné; nevkládejte testovací projekt do produkčního kódu.
- Produkční projekt bude jiný než `o2czed1`.
- Selhání jedné tabulky nezastaví zpracování ostatních pravidel.
- Orchestrátor se automaticky pokusí načíst OS trust store (Windows cert store) přes modul `truststore`.
- Pravidla mohou zůstat v `o2czed1.opr_data.table_retention` i pro datasety, které ještě nejsou migrovány; v tom případě se pravidlo přeskočí s `status_reason=DATASET_NOT_MIGRATED`.

## Řešení Potíží

**Chyba SSL certifikátu:**

Pokud se spuštění nezdaří s chybou `CERTIFICATE_VERIFY_FAILED` nebo `self-signed certificate in certificate chain`, Python nedůvěřuje vaší korporátní root CA pro odchozí HTTPS volání do Google API.

Nastavte jednu z těchto proměnných prostředí na soubor PEM obsahující váš trusted certifikát korporátní CA:

```powershell
$env:REQUESTS_CA_BUNDLE = "C:\cesta\k\corp-ca-bundle.pem"
```

nebo

```powershell
$env:SSL_CERT_FILE = "C:\cesta\k\corp-ca-bundle.pem"
```

Pak spusťte dry-run příkaz znovu.

Poznámka: Service account zjednodušuje autentizaci, ale pokud je v síti TLS inspekce s korporátním certifikátem, CA trust je stále potřeba nastavit i pro Python.

Ve většině korporátních Windows prostředí by to měl vyřešit automaticky modul `truststore` (pokud je korporátní CA v systémovém úložišti certifikátů).
