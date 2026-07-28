# Vysvětlení tabulek v opr_data pro retention proces

Tento dokument popisuje tabulky vytvořené pro centralizovaný retention maintenance proces v BigQuery.
**Aktualizováno:** 2026-07-27

## Přehled objektů

1. `o2czed1.opr_data.table_retention`
2. `o2czed1.opr_data.retention_run`
3. `o2czed1.opr_data.retention_task_run`
4. `o2czed1.opr_data.retention_status_model`
5. `o2czed1.opr_data.v_retention_run_last_14d`
6. `o2czed1.opr_data.v_retention_task_failures_last_14d`

## 1) table_retention

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

### Co přesně znamená retention_type

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

### Praktické doporučení

- Preferovat `COLUMN_AGE` všude, kde to jde
- `CUSTOM_SQL` používat jen tam, kde šablona nestačí
- Důvod:
  - `COLUMN_AGE` je jednodušší na validaci, audit a dlouhodobou údržbu
  - `CUSTOM_SQL` je flexibilnější, ale nese vyšší riziko chyb

## Jak přidat nové pravidlo

### Konvence `retention_rule_id`

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

### SQL template pro vložení nového pravidla

```sql
INSERT INTO `o2czed1.opr_data.table_retention`
(
  retention_rule_id,
  project_id,
  source_dataset_name,
  bq_dataset_name,
  table_name,
  is_active,
  execution_frequency,
  execution_day_of_week,
  execution_day_of_month,
  retention_type,
  retention_column,
  retention_value,
  retention_unit,
  column_data_type,
  source_execution_where_clause,
  bq_execution_where_clause,
  retention_comment,
  created_by,
  updated_by
)
VALUES
(
  'TD_AP_STG_DPM_MESSAGE_20260728',     -- Váš retention_rule_id
  'o2czed1',                             -- Cílový projekt
  'AP_STG',                              -- Zdrojový dataset (historická poznámka)
  'stg_data',                            -- Skutečný BQ dataset
  'DPM_MESSAGE',                         -- Tabulka
  FALSE,                                 -- NEJDŘÍV FALSE pro testování!
  'D',                                   -- Frekvence: D=denní, W=týdenní, M=měsíční
  NULL,                                  -- execution_day_of_week (NULL pro denní)
  NULL,                                  -- execution_day_of_month (NULL pro denní)
  'COLUMN_AGE',                          -- Typ: COLUMN_AGE nebo CUSTOM_SQL
  'load_dttm',                           -- Sloupec se časovým razítkem
  90,                                    -- Počet jednotek (dní/měsíců/let)
  'DAY',                                 -- Jednotka: DAY, MONTH, YEAR
  'TIMESTAMP',                           -- Datový typ: DATE, DATETIME, TIMESTAMP
  'Původní WHERE z Teradata (pokud existuje)',  -- Historická poznámka
  NULL,                                  -- NECHÁTE PRÁZDNÉ pro COLUMN_AGE!
  'Smaž zprávy starší než 90 dní - cleanup staré komunikace',
  'váš_login',
  'váš_login'
);
```

### Postup po vložení pravidla

**1. Spusťte refresh metadat:**
```sql
EXECUTE IMMEDIATE """
  UPDATE `o2czed1.opr_data.table_retention`
  SET column_data_type = 'TIMESTAMP'
  WHERE retention_rule_id = 'TD_AP_STG_DPM_MESSAGE_20260728'
    AND column_data_type IS NULL;
""";
```
Nebo lépe — spusťte `retention_column_age_refresh.sql` pro automatické doplnění skutečného datového typu ze INFORMATION_SCHEMA.

**2. Validujte pravidlo:**
```sql
-- Spusťte retention_final_validation.sql
-- a zkontrolujte, že vaše nové pravidlo nemá žádné issue_code
```

**3. Testujte s dry-run:**
```bash
python orchestrator/retention_orchestrator.py \
  --project-id o2czed1 \
  --dataset opr_data \
  --execution-date 2026-07-28 \
  --filter-rule-id "TD_AP_STG_DPM_MESSAGE_20260728" \
  --dry-run
```

**4. Aktivujte až po úspěšném testu:**
```sql
UPDATE `o2czed1.opr_data.table_retention`
SET is_active = TRUE,
    updated_by = 'váš_login',
    updated_dttm = CURRENT_TIMESTAMP()
WHERE retention_rule_id = 'TD_AP_STG_DPM_MESSAGE_20260728';
```

## 2) retention_run

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

## 3) retention_task_run

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

**Poznámka:**
- Tato tabulka je hlavní zdroj pro troubleshooting a retry

## 4) retention_status_model

**Účel:**
- Referenční číselník povolených stavů pro RUN a TASK
- Centralizuje význam a pořadí stavů

**Nejdůležitější sloupce:**
- `entity_type` — RUN nebo TASK
- `status_code` — Kód stavu
- `is_terminal` — Je stav koncový
- `is_success` — Je stav považován za úspěšný
- `status_order` — Pořadí stavu pro dokumentaci/reporting

## 5) v_retention_run_last_14d

**Účel:**
- Rychlý monitoring posledních 14 dní běhů
- Operativní přehled úspěchů/chyb bez nutnosti psát vlastní dotaz

## 6) v_retention_task_failures_last_14d

**Účel:**
- Rychlý monitoring selhání tasků za posledních 14 dní
- Vhodné pro denní kontrolu incidentů a retry

## Jak objekty spolupracují

1. Orchestrátor založí záznam v `retention_run`
2. Načte pravidla z `table_retention`
3. Pro každé pravidlo vytvoří řádek v `retention_task_run`
4. Provede SQL nebo označí SKIPPED stav
5. Uzavře status běhu v `retention_run`

## Provozní doporučení

- Aktivní pravidla udržovat jen s platným `bq_execution_where_clause`
- `source_execution_where_clause` neměnit, slouží jako auditní zdroj
- Před go-live vždy spustit finální validaci (`retention_final_validation.sql`)
- Monitoring stavů nad 14denními view a v `retention_task_run`
