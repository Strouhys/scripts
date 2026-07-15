# CHANGELOG

Tento soubor eviduje prubezne zmeny SQL casti projektu retenci v BQ.

## 2026-07-14

### Pridano
- Inicialni DDL pro retention proces v BQ v `retention_ddl.sql`.
- Stavovy model run/task + seed statusu v DDL.
- Monitoring view pro poslednich 14 dni.
- Migracni generator z CSV exportu Teradata v `tools/generate_retention_seed_from_csv.ps1`.
- Splitter velkeho INSERT skriptu na vice casti v `tools/split_retention_seed_sql.ps1`.
- Automaticke post-migracni update skripty pro nejcastejsi CUSTOM vzory v `retention_custom_auto_updates.sql`.
- Dotaz na zbyvajici pravidla po auto-update v `retention_custom_remaining_after_updates.sql`.
- Finalni validacni skript pred go-live v `retention_final_validation.sql`.
- Dokumentace orientace ve slozce SQL v `README.md`.
- Samostatne vysvetleni zalozenych tabulek a view v `opr_data_tabulky_vysvetleni.md`.

### Zmeneno
- DDL objekty byly plne kvalifikovany na projekt `o2czed1`.
- DDL doplneno o column-level a table-level description v cestine.
- V `table_retention` nahrazeno `custom_where_clause` za:
  - `source_execution_where_clause`
  - `bq_execution_where_clause`
- Opraveny collation problemy v regex skriptech pomoci `COLLATE(..., '')`.
- Opraveno escapovani v generovanych SQL (apostrofy + backslash) pro kompatibilitu s BigQuery parserem.
- Do `Zadani.md` doplnen odkaz na `sql/opr_data_tabulky_vysvetleni.md`.
- Rozsireno vysvetleni sloupce `retention_type` v `opr_data_tabulky_vysvetleni.md` (COLUMN_AGE vs CUSTOM_SQL, doporuceni pouziti).
- Doplneno vysvetleni sloupce `boundary_mode` v `opr_data_tabulky_vysvetleni.md` (LOAD_DTTM vs CURRENT_DATE vs CUSTOM).

## 2026-07-15

### Pridano
- Python MVP orchestrator v `orchestrator/retention_orchestrator.py`.
- Runbook ke spousteni orchestratoru v `orchestrator/README.md`.
- Zavislost `google-cloud-bigquery` v `requirements.txt`.
- Migrcni skript `retention_dataset_mapping_migration.sql` pro prechod na `source_dataset_name` + `bq_dataset_name`.
- Skript `retention_column_age_refresh.sql` pro obnovu `column_data_type` a `bq_execution_where_clause` podle skutecnych BQ sloupcu.

### Poznamka
- Priorita vyvoje byla presunuta na funkcni orchestrator a connectivity testy; manualni doladeni zbyvajicich CUSTOM pravidel zustava az na zaver test faze.

### Zmeneno
- `table_retention` schema zmeneno z `dataset_name` na dvojici `source_dataset_name` + `bq_dataset_name`.
- `retention_final_validation.sql` doplnen o kontroly mapovani BQ datasetu.
- `retention_custom_remaining_after_updates.sql` vypisuje `source_dataset_name` a `bq_dataset_name`.
- `tools/generate_retention_seed_from_csv.ps1` generuje nove sloupce a mapuje `ap_stg -> stg_data`.

### Opraveno
- Chyby syntaxe typu:
  - concatenated string literals
  - illegal escape sequence
  - collation is not allowed on argument 1
- Rozdeleni seed INSERTu na dve casti pro limity BigQuery editoru.

### Uklid slozky
- Vytvoren `sql/archive`.
- Do archivu presunuty jednorazove migracni artefakty:
  - `retention_seed_from_teradata_part1.sql`
  - `retention_seed_from_teradata_part2.sql`
  - `retention_seed_manual_review.csv`
  - `retention_migration_runbook.md`
  - `retention_state_model.md`
- Z aktivni sady byly do archivu presunuty neprodukcnI helper skripty:
  - `sql/retention_custom_auto_updates.sql`
  - `sql/retention_custom_remaining_after_updates.sql`
  - `tools/generate_retention_seed_from_csv.ps1`
  - `tools/split_retention_seed_sql.ps1`
  - `tools/tmp_read_last_task.py`

## Pravidla aktualizace changelogu

Pri kazde dalsi zmene aktualizovat:
1. Datum sekce.
2. Co bylo pridano/zmeneno/opraveno.
3. Ktere soubory byly dotcene.
