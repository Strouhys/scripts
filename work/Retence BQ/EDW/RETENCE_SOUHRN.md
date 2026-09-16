# Retence v BigQuery 

Strucny onboarding dokument k retention procesu.

## 1. Co retence resi

Retence je samostatny maintenance proces, ktery pravidelne maze stara data v BigQuery podle centralne spravovanych pravidel.

Cil:
- drzet data pod kontrolou (objem, naklady, provozni hygiena),
- mit auditovatelny, opakovatelny a bezpecny proces,
- oddelit retention od jednotlivych datovych loadu.

## 2. Jak proces funguje

Aktualni provozni tok:
- TASK_SCHEDULER -> Python orchestrator -> BigQuery
- zdrojová složka ntinfo403 f:\dp\scripts\retence_bq\

Cilovy tok:
- Airflow DAG -> Python logika -> BigQuery

Kroky jednoho runu:
1. Zalozi se run v audit tabulce.
2. Nactou se aktivni pravidla z metadat.
3. U kazdeho pravidla se vyhodnoti frekvence a validace.
4. Vygeneruje se DELETE podminka.
5. Provede se DELETE (nebo dry-run bez mazani - pouze u testování nastavitelné v .env).
6. Ulozi se task audit a finalni status runu.

## 3. Kde jsou metadata a audit

Hlavni objekty v datasetu `opr_data`:
- `table_retention` - konfigurace pravidel
- `retention_run` - hlavicka kazdeho behu
- `retention_task_run` - detail pravidel v ramci behu
- `retention_status_model` - referencni stavovy model
- `v_retention_run_last_14d` - rychly monitoring runu
- `v_retention_task_failures_last_14d` - rychly monitoring chyb

## 4. Typy pravidel

V produkcni logice orchestratoru jsou pouzity hlavne:
- `COLUMN_AGE` - standardni mazani podle stari hodnoty ve sloupci (zde se where podmínka nebere z konfig. tabulky ale orchestrátor si jí skládá, ale table_retention může i where podmínku mít uvedenou)
- `CUSTOM_SQL` - vyjimky, kde je potreba vlastni WHERE podminka

Doporuceni:
- preferovat `COLUMN_AGE`,
- `CUSTOM_SQL` pouzivat jen tam, kde to jinak nejde.

## 5. Frekvence spousteni

- `D` = denne
- `W` = tydne (typicky sobota)
- `M` = mesicne (podle dne v mesici, jinak prvni sobota)

Pravidlo se zpracuje maximalne jednou za den.

## 6. Ochrany procesu

### Idempotence
- Klic: `retention_rule_id + execution_date`.
- Pokud uz je pravidlo pro dany den ve stavu RUNNING nebo SUCCESS, dalsi pokus se preskoci.

### Bezpecny start
- Pred mazanim se overuje existence datasetu, tabulky a (u `COLUMN_AGE`) i sloupce.
- Pokud neni `bq_dataset_name`, pravidlo se preskoci jako `DATASET_NOT_MIGRATED`.

### Izolace chyb
- Chyba jedne tabulky nezastavi cely run (pokud nejde o systemovou chybu).
- Chybove pravidlo se zapise jako FAILED a pokracuje se dal.


## 7. Stavovy model (MVP)

### RUN
- RUNNING -> SUCCESS / PARTIAL_SUCCESS / FAILED

### TASK
- RUNNING -> SUCCESS / FAILED / SKIPPED_*

Bezna SKIPPED skupina:
- `SKIPPED_FREQUENCY`
- `SKIPPED_ALREADY_SUCCESS`
- `SKIPPED_TABLE_NOT_FOUND`
- `SKIPPED_COLUMN_NOT_FOUND`
- `SKIPPED_NOT_IMPLEMENTED`
- `SKIPPED_VALIDATION`




