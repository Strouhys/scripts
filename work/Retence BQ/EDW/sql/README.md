# Retence BigQuery - SQL orientace

Tento adresar obsahuje SQL skripty pro retention maintenance proces v BigQuery.

## Aktivni skripty

### 1) retention_ddl.sql
- Ucel: zalozeni/udrzba zakladnich tabulek a view.
- Obsah:
  - `o2czed1.opr_data.table_retention`
  - `o2czed1.opr_data.retention_run`
  - `o2czed1.opr_data.retention_task_run`
  - `o2czed1.opr_data.retention_status_model`
  - monitoring view
- Kdy pouzit: pri inicializaci prostredi nebo pri rizenych schema zmenach.

### 1a) retention_dataset_mapping_migration.sql
- Ucel: prechod `table_retention` na model `source_dataset_name` + `bq_dataset_name`.
- Co dela:
  - rename `dataset_name` -> `source_dataset_name`
  - prida `bq_dataset_name`
  - predvyplni mapovani `ap_stg -> stg_data`
- Kdy pouzit: jednorazove po nasazeni nove verze orchestratoru.

### 1b) retention_column_age_refresh.sql
- Ucel: sladeni `COLUMN_AGE` metadat se skutecnym typem sloupce v BigQuery.
- Co dela:
  - nacita realne `data_type` z `INFORMATION_SCHEMA.COLUMNS`
  - aktualizuje `column_data_type`
  - pregeneruje `bq_execution_where_clause`
- Kdy pouzit: po doplneni `bq_dataset_name` mapovani a vzdy po nove migraci datasetu.

### 2) retention_final_validation.sql
- Ucel: finalni quality gate pred go-live.
- Obsah:
  - souhrn problemu podle issue_code
  - detailni seznam problematickych pravidel
  - go-live metrika `blocking_issues`
- Kdy pouzit: po manualnich opravach pravidel, tesne pred zapnutim scheduleru.

## Doporucene poradi spousteni

1. `retention_ddl.sql`
2. `retention_dataset_mapping_migration.sql` (pokud jeste nebylo provedeno)
3. `retention_column_age_refresh.sql`
4. `retention_final_validation.sql`

## Co znamena "pripraveno na go-live"

Minimalni podminky:
- `blocking_issues = 0` ve vystupu `retention_final_validation.sql`.
- zadne aktivni pravidlo bez `bq_execution_where_clause`.
- pravidla oznacena jako `nemazat` zustavaji `is_active = FALSE`.

## Struktura adresaru

- `sql/` = aktivne pouzivane provozni skripty.
- `sql/archive/` = jednorazove migracni artefakty, helper SQL a historie (neprovozni).
- `tools/archive/` = pomocne PowerShell skripty pro puvodni seed/migracni fazi (neprovozni).
- `sql/CHANGELOG.md` = prubezna evidence zmen v SQL casti projektu.

## Poznamky pro budoucnost

- Pokud se bude migrovat nova davka pravidel z Teradata exportu, puvodni helpery najdete v `tools/archive/` a vysledky umistete nejprve do `sql/archive/`.
- Aktivni provozni skripty drzte v koreni `sql/`, aby zustalo jasne, co se ma spoustet v produkcnim provozu.
