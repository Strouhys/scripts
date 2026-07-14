# Stavovy model retention procesu (MVP)

## 1) RUN lifecycle

1. CREATED
2. RUNNING
3. SUCCESS | PARTIAL_SUCCESS | FAILED

### Pravidla prechodu

- CREATED -> RUNNING: po zalozeni runu a zacatku zpracovani.
- RUNNING -> SUCCESS: zadny TASK nema FAILED.
- RUNNING -> PARTIAL_SUCCESS: aspon 1 TASK je FAILED a aspon 1 TASK je SUCCESS nebo SKIPPED_*
- RUNNING -> FAILED: systemova chyba (napr. nelze nacist pravidla, nelze zapisovat audit).

## 2) TASK lifecycle

1. RUNNING
2. SUCCESS | FAILED | SKIPPED_*

### Podporovane SKIPPED stavy

- SKIPPED_FREQUENCY
- SKIPPED_ALREADY_SUCCESS
- SKIPPED_TABLE_NOT_FOUND
- SKIPPED_COLUMN_NOT_FOUND
- SKIPPED_NOT_ACTIVE
- SKIPPED_NOT_IMPLEMENTED
- SKIPPED_VALIDATION

## 3) Idempotence

- Jednoznacny business klic TASKu: retention_rule_id + execution_date.
- V tabulce je ulozen jako unique_task_key.
- Ochrana proti soubehu: atomicky MERGE pred spustenim delete SQL.

## 4) Retry politika (MVP)

- Retry povolit pouze pro TASK status FAILED.
- SKIPPED_* se v MVP nere-tryuji.
- Retry zapisovat jako novy task_run_id, s vyplnenym retry_of_task_run_id.

## 5) Mapovani na orchestratory

- Task Scheduler / oflow / Airflow maji stejny lifecycle model.
- Rozdil je jen ve spousteci vrstve, ne v retention business logice.
