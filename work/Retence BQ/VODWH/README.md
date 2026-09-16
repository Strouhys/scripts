# Retence VODWH (VP_STG) v BigQuery

Obdoba retenčního procesu z `EDW/` pro zdroj VODWH (Teradata databáze `VP_STG`).
Architektura, stavový model a orchestrátor jsou **shodné** s EDW - liší se jen
cílový projekt/dataset a zdrojová sada pravidel.

## 1. Zdroje

- Zdrojová Teradata evidence: [`vodwh retence teradata.csv`](vodwh%20retence%20teradata.csv)
  (92 pravidel, vše databáze `VP_STG`, typ `COLUMN_AGE` nad sloupcem `loaded_dttm`,
  frekvence `D` nebo `W`, retence 180 nebo 365 dní).
- Generátor seed SQL: [`tools/generate_retention_seed.py`](tools/generate_retention_seed.py)
  -> vygeneruje [`sql/retention_seed_vodwh.sql`](sql/retention_seed_vodwh.sql).

## 2. Cílové prostředí

- Projekt: `o2czvd1`
- Metadata a audit (config + monitoring): dataset `opr_data`
  - `o2czvd1.opr_data.table_retention`
  - `o2czvd1.opr_data.retention_run`, `o2czvd1.opr_data.retention_task_run`
- Cílové `VP_STG` tabulky (např. `VPOB_X_CHARGED_USAGE`): dataset `stg_data`
  (`bq_dataset_name = stg_data` pro všech 92 pravidel v seed SQL)

## 3. Postup nasazení

1. Spusť [`sql/retention_ddl.sql`](sql/retention_ddl.sql) - vytvoří `table_retention`,
   `retention_run`, `retention_task_run`, `retention_status_model` a monitoring views.
2. Naplň pravidla pomocí [`sql/retention_seed_vodwh.sql`](sql/retention_seed_vodwh.sql).
3. Nastav `.env` podle [`.env.example`](.env.example) (zejména
   `GOOGLE_APPLICATION_CREDENTIALS`, `RETENTION_PROJECT_ID=o2czvd1`).
4. Otestuj dry-run:

   ```powershell
   python .\orchestrator\retention_orchestrator.py --project-id o2czvd1 --dataset opr_data --dry-run --max-rules 5
   ```
5. Naplánuj ostrý běh přes `run_orchestrator.bat` (stejný mechanismus jako v EDW).

## 4. Poznámky

- Logika orchestrátoru (`orchestrator/retention_orchestrator.py`) je 1:1 kopie z EDW -
  je plně parametrizovaná přes `--project-id`/`.env`, žádný kód se neupravoval.
- Pokud se `VP_STG` tabulky později přesunou ze `stg_data` do jiného datasetu,
  stačí přegenerovat `bq_dataset_name` v `table_retention` (obdoba
  `EDW/sql/retention_dataset_mapping_migration.sql`).
- Detailní vysvětlení architektury a stavového modelu viz `EDW/Retence_bigquery.md`
  a `EDW/orchestrator/README_ORCHESTRATOR.md`.
