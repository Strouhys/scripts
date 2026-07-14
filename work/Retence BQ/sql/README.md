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

### 2) retention_custom_auto_updates.sql
- Ucel: hromadny automaticky update casti migrovanych CUSTOM_SQL pravidel.
- Co dela:
  - upravy nejcastejsi vzory (CDC OR, operation-only, Current_Date, add_months, SELECT MAX)
  - deaktivuje explicitni pravidla s `nemazat`
- Kdy pouzit: po nahrani seed dat a pred rucnim doladenim zbytku pravidel.

### 3) retention_custom_remaining_after_updates.sql
- Ucel: vypis pravidel, ktera po auto-update stale vyzaduji manualni kontrolu.
- Kdy pouzit: hned po `retention_custom_auto_updates.sql`.

### 4) retention_final_validation.sql
- Ucel: finalni quality gate pred go-live.
- Obsah:
  - souhrn problemu podle issue_code
  - detailni seznam problematickych pravidel
  - go-live metrika `blocking_issues`
- Kdy pouzit: po manualnich opravach pravidel, tesne pred zapnutim scheduleru.

## Doporucene poradi spousteni

1. `retention_ddl.sql`
2. (po seed importu) `retention_custom_auto_updates.sql`
3. `retention_custom_remaining_after_updates.sql`
4. manualni opravy zbyvajicich pravidel
5. `retention_final_validation.sql`

## Co znamena "pripraveno na go-live"

Minimalni podminky:
- `blocking_issues = 0` ve vystupu `retention_final_validation.sql`.
- zadne aktivni pravidlo bez `bq_execution_where_clause`.
- pravidla oznacena jako `nemazat` zustavaji `is_active = FALSE`.

## Struktura adresaru

- `sql/` = aktivne pouzivane provozni skripty.
- `sql/archive/` = jednorazove migracni artefakty a historie (neprovozni).
- `tools/` = pomocne PowerShell skripty pro regeneraci seed/migracnich dat.
- `sql/CHANGELOG.md` = prubezna evidence zmen v SQL casti projektu.

## Poznamky pro budoucnost

- Pokud se bude migrovat nova davka pravidel z Teradata exportu, pouzijte skripty v `tools/` a vysledky umistete nejprve do `sql/archive/`.
- Aktivni provozni skripty drzte v koreni `sql/`, aby zustalo jasne, co se ma spoustet v produkcnim provozu.
