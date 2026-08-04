# Retence BigQuery - Kompletní dokumentace

Tento dokument spojuje přehled orchestrátoru, SQL skriptů a popis datových objektů pro centralizovaný retention maintenance proces v BigQuery.
**Aktualizováno:** 2026-07-31

---


## Část 1: Datové objekty v opr_data

Tento přehled popisuje tabulky a view vytvořené pro retention proces.

### Přehled objektů

1. `o2czed1.opr_data.table_retention`
2. `o2czed1.opr_data.retention_run`
3. `o2czed1.opr_data.retention_task_run`
4. `o2czed1.opr_data.retention_status_model`
5. `o2czed1.opr_data.v_retention_run_last_14d`
6. `o2czed1.opr_data.v_retention_task_failures_last_14d`

### 1) table_retention

**Účel:**
- Konfigurační tabulka retenčních pravidel.
- Jeden řádek reprezentuje jedno pravidlo, které určuje, co a jak se má mazat.

**Nejdůležitější sloupce:**
- `retention_rule_id` — Jedinečný identifikátor pravidla
- `project_id`, `source_dataset_name`, `bq_dataset_name`, `table_name` — Cíl pravidla
  - `source_dataset_name` = původní dataset z Teradata evidence
  - `bq_dataset_name` = skutečný cílový dataset v BigQuery
- `is_active` — Zapnuto/vypnuto
- `execution_frequency` — D/W/M
- `retention_type` — Typ pravidla (např. COLUMN_AGE, CUSTOM_SQL)
- `source_execution_where_clause` — Původní Teradata podmínka pro audit
- `bq_execution_where_clause` — Finální podmínka v BigQuery syntaxi

#### Co přesně znamená retention_type

`retention_type` je technicky přepínač logiky v orchestrátoru. Podle hodnoty orchestrátor rozhoduje, jakým způsobem se sestrojí a provede mazací podmínka.

**1. COLUMN_AGE**
- Standardní šablonové pravidlo
- Očekává vyplněné parametry:
  - `retention_column`
  - `retention_value`
  - `retention_unit`
- Orchestrátor z těchto parametrů sestrojí podmínku automaticky
- Typický význam: "smaž data starší než X dní/měsíců/let"

**2. CUSTOM_SQL**
- Výjimečný režim pro složitější logiku
- Orchestrátor nepoužije šablonu, ale spouští podmínku z `bq_execution_where_clause`
- Vhodné pro komplexní pravidla (např. více podmínek OR, speciální business logika, specifické CDC vzory)

#### Praktické doporučení

- Preferovat `COLUMN_AGE` všude, kde to jde
- `CUSTOM_SQL` používat jen tam, kde šablona nestačí
- Důvod:
  - `COLUMN_AGE` je jednodušší na validaci, audit a dlouhodobou údržbu
  - `CUSTOM_SQL` je flexibilnější, ale nese vyšší riziko chyb

### Jak přidat nové pravidlo

#### Konvence `retention_rule_id`

ID pravidla musí být **globálně jedinečné** a slouží jako business klíč pro idempotenci orchestrátoru.

**Doporučený formát:**
```
TD_<DATASET>_<TABLE>_<SUFFIX>
```

**Komponenty:**
- `TD` — Prefix (Teradata origin; lze přizpůsobit, např. `MANUÁLNÍ_` pro ručně přidaná pravidla)
- `<DATASET>` — Zdroj dataset z BigQuery (např. AP_STG, EP_CDC)
- `<TABLE>` — Název tabulky
- `<SUFFIX>` — Unikátní identifikátor (datum, JIRA ID, nebo Teradata ID)

**Příklady:**
- `TD_AP_STG_DPM_MESSAGE_20260728` — nové pravidlo z 28.7.2026
- `TD_AP_STG_DPM_MESSAGE_STATUS_20260728` — další pravidlo ze stejného datasetu, stejný datum
- `TD_EP_CDC_ORDERS_BIDEV1234` — podle JIRA ticketu
- `TD_EP_CDC_EVENTS_00350` — původní Teradata ID ze migrace

**Důležité:** Suffix můžete mít stejný (např. datum) i pro různé tabulky ze stejného datasetu. Unikátnost se vynucuje kombinací `retention_rule_id + execution_date`.

#### Vložení nového pravidla přes proceduru

Pro vkládání pravidel typu `COLUMN_AGE` slouží uložená procedura `sp_add_column_age_retention_rule`.

##### Obecný vzor

```sql
CALL `o2czep.opr_data.sp_add_column_age_retention_rule`(
  'AP_STG',                 -- 1. source_dataset_name:
                            --    Původní název datasetu ze zdrojové/Teradata evidence.

  'stg_data',               -- 2. bq_dataset_name:
                            --    Skutečný cílový dataset v BigQuery.

  'DPM_MESSAGE',            -- 3. table_name:
                            --    Název cílové tabulky v BigQuery.

  'D',                      -- 4. execution_frequency:
                            --    D = denně
                            --    W = týdně
                            --    M = měsíčně

  NULL,                     -- 5. execution_day_of_week:
                            --    Pouze pro frekvenci W.
                            --    1 = pondělí, 2 = úterý, ... 6 = sobota, 7 = neděle.
                            --    Pro D a M musí být NULL.

  NULL,                     -- 6. execution_day_of_month:
                            --    Pouze pro frekvenci M.
                            --    Povolená hodnota 1 až 31.
                            --    Pro D a W musí být NULL.

  'load_dttm',              -- 7. retention_column:
                            --    Datumový sloupec, podle kterého se určuje stáří dat.
                            --    Musí být typu DATE, DATETIME nebo TIMESTAMP.

  90,                       -- 8. retention_value:
                            --    Počet retenčních jednotek.
                            --    Musí být větší než 0.

  'DAY',                    -- 9. retention_unit:
                            --    DAY, MONTH nebo YEAR.

  'Původní podmínka z TD',  -- 10. source_execution_where_clause:
                            --     Původní Teradata podmínka pro audit.
                            --     Pokud neexistuje, použijte NULL.

  'Mazání dat starších než 90 dní'
                            -- 11. retention_comment:
                            --     Srozumitelný popis účelu retenčního pravidla.
);
```

##### Denní pravidlo

```sql
CALL `o2czep.opr_data.sp_add_column_age_retention_rule`(
  'AP_STG', 'stg_data', 'DPM_MESSAGE',
  'D', NULL, NULL,
  'load_dttm', 90, 'DAY',
  NULL,
  'Denní mazání záznamů starších než 90 dní'
);
```

##### Týdenní pravidlo – sobota

```sql
CALL `o2czep.opr_data.sp_add_column_age_retention_rule`(
  'AP_STG', 'stg_data', 'DPM_MESSAGE',
  'W', 6, NULL,
  'load_dttm', 90, 'DAY',
  NULL,
  'Týdenní mazání záznamů starších než 90 dní, spuštění v sobotu'
);
```

##### Měsíční pravidlo – první den v měsíci

```sql
CALL `o2czep.opr_data.sp_add_column_age_retention_rule`(
  'AP_STG', 'stg_data', 'DPM_MESSAGE',
  'M', NULL, 1,
  'load_dttm', 12, 'MONTH',
  NULL,
  'Měsíční mazání záznamů starších než 12 měsíců'
);
```

#### Co procedura udělá automaticky

Procedura:

- ověří existenci cílové tabulky,
- ověří existenci retenčního sloupce,
- zjistí `column_data_type`,
- ověří kombinaci D/W/M a plánovacích dnů,
- vygeneruje unikátní `retention_rule_id`,
- nastaví `retention_type = 'COLUMN_AGE'`,
- nastaví `bq_execution_where_clause = NULL`,
- doplní uživatele přes `SESSION_USER()`,
- vloží pravidlo jako `is_active = FALSE`.

Po vložení je tedy potřeba pravidlo zkontrolovat, otestovat a následně samostatně aktivovat.

### 2) retention_run

**Účel:**
- Hlavička jednoho celkového retention běhu
- Jeden řádek = jeden běh orchestrátoru

**Nejdůležitější sloupce:**
- `run_id` — Jedinečný identifikátor běhu
- `run_date` — Provozní datum běhu
- `run_start_dttm`, `run_end_dttm` — Čas začátku/konce
- `retention_reference_dttm` — Referenční čas fixovaný pro celý běh
- `orchestrator` — TASK_SCHEDULER / OFLOW / AIRFLOW
- `status` — CREATED, RUNNING, SUCCESS, PARTIAL_SUCCESS, FAILED
- `error_message` — Chyba na úrovni celého běhu

### 3) retention_task_run

**Účel:**
- Detailní audit zpracování jednotlivých pravidel v rámci běhu
- Jeden řádek = jedno vyhodnocené pravidlo (provedeno nebo přeskočeno)

**Nejdůležitější sloupce:**
- `task_run_id` — Jedinečný identifikátor tasku
- `run_id` — Vazba na `retention_run`
- `retention_rule_id` — Vazba na `table_retention`
- `execution_date` — Datum idempotence
- `status` — SUCCESS/FAILED/SKIPPED_*
- `generated_sql` — Vygenerované SQL pro mazání
- `affected_rows` — Počet ovlivněných řádků
- `unique_task_key` — Business klíč `retention_rule_id + execution_date`
- `is_retry`, `retry_of_task_run_id` — Evidence retry pokusů

**Poznámka:** Tato tabulka je hlavní zdroj pro troubleshooting a retry.

### 4) retention_status_model

**Účel:**
- Referenční číselník povolených stavů pro RUN a TASK
- Centralizuje význam a pořadí stavů

**Nejdůležitější sloupce:**
- `entity_type` — RUN nebo TASK
- `status_code` — Kód stavu
- `is_terminal` — Je stav koncový
- `is_success` — Je stav považován za úspěšný
- `status_order` — Pořadí stavu pro dokumentaci/reporting

### 5) v_retention_run_last_14d

**Účel:**
- Rychlý monitoring posledních 14 dní běhů
- Operativní přehled úspěchů/chyb bez nutnosti psát vlastní dotaz

### 6) v_retention_task_failures_last_14d

**Účel:**
- Rychlý monitoring selhání tasků za posledních 14 dní
- Vhodné pro denní kontrolu incidentů a retry

### Jak objekty spolupracují

1. Orchestrátor založí záznam v `retention_run`
2. Načte pravidla z `table_retention`
3. Pro každé pravidlo vytvoří řádek v `retention_task_run`
4. Provede SQL nebo označí SKIPPED stav
5. Uzavře status běhu v `retention_run`

### Provozní doporučení

- Aktivní pravidla udržovat jen s platným `bq_execution_where_clause`
- `source_execution_where_clause` neměnit, slouží jako auditní zdroj
- Před go-live vždy spustit finální validaci (`retention_final_validation.sql`)
- Monitoring stavů nad 14denními view a v `retention_task_run`

---

## Část 3: Orchestrátor – instalace, konfigurace a spuštění

Python orchestrátor pro centralizovanou správu retenčních pravidel v BigQuery.
**Stav:** Produkčně připraveno (k 2026-07-30)

### Rozsah

**Hlavní funkce:**
- Načítá aktivní pravidla z `table_retention` s volitelným filtrováním (rule_id, projekt, dataset, tabulka)
- Vyhodnocuje frekvenci D/W/M (denně, týdně podle dne v týdnu, měsíčně podle dne v měsíci)
- Zapisuje audit běhu a tasků do `retention_run` a `retention_task_run`
- Zajišťuje idempotenci pomocí `retention_rule_id + execution_date`
- Podporuje `COLUMN_AGE` (automatická WHERE generace) a `CUSTOM_SQL` (vlastní podmínka)
- Podporuje mód `--dry-run` pro bezpečné testování bez skutečného mazání
- Mechanismus přepsání pro ověřovací testování (dočasné přepsání retention_value/unit)

**Známá omezení:**
- Pravidla bez mapování `bq_dataset_name` mohou být stále aktivní, ale orchestrátor je korektně přeskočí se `status_reason=DATASET_NOT_MIGRATED`.
- Některá pravidla mohou být dočasně deaktivována kvůli externím závislostem, které v BigQuery nejsou dostupné.
- Aktivní `CUSTOM_SQL` pravidla s prázdným `bq_execution_where_clause` vyžadují ruční doplnění nebo konverzi.

### Instalace a autentizace

#### Předpoklady

1. Python 3.10+
2. Instalace závislostí:

```powershell
pip install -r ../requirements.txt
```

3. Google BigQuery autentizace dostupná v runtime prostředí

#### Nastavení Service Account (doporučeno)

1. Vytvořte soubor `.env` v kořenovém adresáři projektu:

```env
GOOGLE_APPLICATION_CREDENTIALS=C:\cesta\k\retention-sa.json
RETENTION_PROJECT_ID=o2czep  # pro test: o2czed1
RETENTION_METADATA_DATASET=opr_data
```

2. Service account vyžaduje minimálně tyto role:
   - BigQuery Job User
   - BigQuery Data Viewer + BigQuery Data Editor na datasetu `opr_data`

### Konfigurace přes .env

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
RETENTION_LOG_DIR=logs
RETENTION_LOG_TO_FILE=true

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

**Logování do souboru:**
- Při každém spuštění se vytvoří samostatný log soubor, defaultně ve složce `logs/`.
- Složku změníte přes `RETENTION_LOG_DIR` nebo CLI `--log-dir`.
- Souborové logování lze vypnout přes `RETENTION_LOG_TO_FILE=false` nebo CLI `--no-file-log`.

**Chování filtrů:**
- Pokud je nastaveno alespoň jedno z `RETENTION_RULE_ID`, `RETENTION_TARGET_PROJECT`, `RETENTION_TARGET_DATASET`, `RETENTION_TARGET_TABLE`, orchestrátor spustí jen odpovídající podmnožinu pravidel.
- Pokud není nastaven žádný filtr, orchestrátor zpracuje celý aktivní obsah `<RETENTION_PROJECT_ID>.<RETENTION_METADATA_DATASET>.table_retention`.

**Mapování datasetů:**
- `source_dataset_name` = původní dataset z Teradata evidence
- `bq_dataset_name` = skutečný cílový dataset v BigQuery
- Orchestrátor vždy používá `bq_dataset_name`; pokud je prázdný, pravidlo se přeskočí s `status_reason=DATASET_NOT_MIGRATED`.

**Test přepsání retention:**
- `RETENTION_OVERRIDE_VALUE` a `RETENTION_OVERRIDE_UNIT` platí jen pro `COLUMN_AGE`.
- Přepsání je aktivní jen když `RETENTION_ALLOW_OVERRIDE=true` (bezpečnost proti nechtěnému použití).
- Doporučeno kombinovat s `RETENTION_RULE_ID` a `RETENTION_DRY_RUN=true`.

### Příklady spuštění

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

**Simulace testu s dočasným přepsáním retention_value na 15 dní:**

```powershell
python .\orchestrator\retention_orchestrator.py --project-id o2czed1 --dataset opr_data --rule-id TD_AP_STG_EBOX_VIEWS_V2_00003 --execution-date 2026-05-08 --dry-run --allow-retention-override --override-retention-value 15 --override-retention-unit DAY
```

### Poznámky

- Zachovejte `--project-id` konfigurovatelné; nevkládejte testovací projekt do produkčního kódu.
- Produkční projekt bude jiný než `o2czed1`.
- Selhání jedné tabulky nezastaví zpracování ostatních pravidel.
- Orchestrátor se automaticky pokusí načíst OS trust store (Windows cert store) přes modul `truststore`.
- Pravidla mohou zůstat v metadatové tabulce i pro datasety, které ještě nejsou migrovány; v tom případě se pravidlo přeskočí s `status_reason=DATASET_NOT_MIGRATED`.

### Řešení potíží

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

Poznámka: Service account zjednodušuje autentizaci, ale pokud je v síti TLS inspekce s korporátním certifikátem, CA trust je stále potřeba nastavit i pro Python. Ve většině korporátních Windows prostředí by to měl vyřešit automaticky modul `truststore` (pokud je korporátní CA v systémovém úložišti certifikátů).
