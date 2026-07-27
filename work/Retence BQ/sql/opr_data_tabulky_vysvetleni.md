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
  - Typicky `boundary_mode = LOAD_DTTM`
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

### Co přesně znamená boundary_mode

`boundary_mode` určuje, vůči jakému referenčnímu bodu se u pravidla počítá hranice mazání.

**Nejčastější hodnoty:**

**1. LOAD_DTTM**
- Hranice se počítá vůči `retention_reference_dttm` daného běhu
- Vhodné pro stabilní denní provoz, kdy všechna pravidla v jednom běhu používají stejný referenční čas
- Nejběžnější volba u `COLUMN_AGE`

**2. CURRENT_DATE**
- Hranice se odvíjí od aktuálního data v okamžiku provedení
- Je potřeba opatrnost při dlouho běžících bězích (může nastat přechod dne)
- Používat jen kde je to business požadavek

**3. CUSTOM**
- Hranice je součástí vlastní logiky v `bq_execution_where_clause`
- Typické pro složité `CUSTOM_SQL` podmínky

**Praktické pravidlo:**

- Pokud to jde, preferovat `LOAD_DTTM`, protože je nejlépe auditovatelný a konzistentní v rámci celého běhu
- `CURRENT_DATE` a `CUSTOM` používat pouze tam, kde to vyžaduje konkrétní logika pravidla

**Poznámka:**
- `source_execution_where_clause` — auditní stopa
- `bq_execution_where_clause` — to, co má orchestrátor vykonávat

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
