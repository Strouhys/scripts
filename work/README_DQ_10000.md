Ověřit názvy a region

project: o2czed1
landing dataset: stg_lnd
cílový dataset: daq_data
region datasetu stg_lnd: europe-west4
pattern DQ tabulek: názvy obsahují __dq10000__
počet DQ tabulek: 832
všechny DQ tabulky mají stejný počet sloupců: 9
pro spojení/merge do cíle používat pouze DQ tabulky, které mají data (total_rows > 0)
prázdné DQ tabulky nebudou součástí UNION ALL; řešit je samostatně jako cleanup

Struktura DQ tabulek:

| Sloupec | Pořadí | Datový typ | Nullable |
|---|---:|---|---|
| load_dttm | 1 | DATETIME | NO |
| job_id | 2 | INT64 | NO |
| table_name | 3 | STRING | NO |
| file_name | 4 | STRING | NO |
| line_no | 5 | INT64 | NO |
| error_cd | 6 | INT64 | NO |
| input_port | 7 | STRING | YES |
| sanitized_val | 8 | STRING | YES |
| raw_line | 9 | STRING | YES |


cílová tabulka: o2czed1.daq_data.dq10000_all


select pro který vybere vhodné tabulky k přenesení

SELECT
  table_catalog AS source_project,
  table_schema AS source_dataset,
  table_name AS source_table,
  creation_time,
  storage_last_modified_time,
  total_rows,
  total_logical_bytes
FROM `o2czed1.region-europe-west4`.INFORMATION_SCHEMA.TABLE_STORAGE
WHERE table_schema = 'stg_lnd'
  AND table_type = 'BASE TABLE'
  AND REGEXP_CONTAINS(table_name, r'__dq10000__')
  AND creation_time < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR)
  AND total_rows > 0
ORDER BY total_rows DESC;


procedura název procedury: o2czed1.daq_data.sp_collect_dq10000
sp = stored procedure
collect = sbírá/přenáší data
dq10000 = typ tabulek, se kterými pracuje



Teď bych si ještě zapsal ověřovací dotazy, které budeme používat po každém běhu:

SELECT
  collect_run_id,
  started_at,
  finished_at,
  status,
  source_table_count,
  inserted_row_count,
  error_message,
  created_by
FROM `o2czed1.daq_data.dq10000_load_audit`
ORDER BY started_at DESC
LIMIT 10;

Detail posledního běhu:

SELECT
  collect_run_id,
  source_table,
  source_rows,
  loaded_row_count,
  source_rows - loaded_row_count AS diff_rows,
  status,
  drop_status,
  dropped_at,
  drop_error_message
FROM `o2czed1.daq_data.dq10000_load_table_audit`
WHERE collect_run_id = (
  SELECT collect_run_id
  FROM `o2czed1.daq_data.dq10000_load_audit`
  ORDER BY started_at DESC
  LIMIT 1
)
ORDER BY source_rows DESC;

Kontrola, že ve stg_lnd nezůstaly neprázdné DQ tabulky:

SELECT
  COUNT(*) AS remaining_non_empty_dq_tables
FROM `o2czed1.region-europe-west4`.INFORMATION_SCHEMA.TABLE_STORAGE
WHERE table_schema = 'stg_lnd'
  AND table_type = 'BASE TABLE'
  AND REGEXP_CONTAINS(table_name, r'__dq10000__')
  AND creation_time < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR)
  AND total_rows > 0;

A rychlejší kontrola existence tabulek:

SELECT
  COUNT(*) AS remaining_dq_tables
FROM `o2czed1.stg_lnd`.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND REGEXP_CONTAINS(table_name, r'__dq10000__');

Za mě máme hotový hlavní provozní tok. Další krok bych viděl buď naplánovat finální Scheduled Query s touto verzí procedury, nebo ještě doplnit úklid prázdných __dq10000__ tabulek.