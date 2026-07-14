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

## Pravidla aktualizace changelogu

Pri kazde dalsi zmene aktualizovat:
1. Datum sekce.
2. Co bylo pridano/zmeneno/opraveno.
3. Ktere soubory byly dotcene.
