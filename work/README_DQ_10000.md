# DQ10000 - provozni postup sbiru dat

Tento dokument popisuje, jak sbirat data z DQ tabulek ve `stg_lnd` do centralni tabulky `dq10000_all`.

## 1. Konfigurace a zakladni fakta

- Projekt: `o2czed1`
- Zdrojovy dataset (landing): `stg_lnd`
- Cilovy dataset: `daq_data`
- Region zdrojoveho datasetu: `europe-west4`
- Pattern DQ tabulek: nazev obsahuje `__dq10000__`
- Pocet DQ tabulek (aktualni stav): `832`
- Vsechny DQ tabulky maji stejne schema: `9` sloupcu

## 2. Pravidla pro vyber tabulek do zpracovani

- Do prenosu pouzivej pouze tabulky s daty (`total_rows > 0`).
- Prazdne DQ tabulky nezahrnuj do `UNION ALL`; res je samostatnym cleanup krokem.
- Doporučeno zpracovavat pouze tabulky starsi nez 12 hodin, aby se omezilo riziko prace s rozpracovanymi daty.

## 3. Schema DQ tabulek

| Sloupec | Poradi | Datovy typ | Nullable |
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

## 4. Cilova tabulka

`o2czed1.daq_data.dq10000_all`

## 5. SQL pro vyber vhodnych tabulek

```sql
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
```

## 6. Procedura pro sbirku dat

Nazev procedury: `o2czed1.daq_data.sp_collect_dq10000`

Vyznam nazvu:
- `sp`: stored procedure
- `collect`: sbira/prenasi data
- `dq10000`: typ tabulek, se kterymi procedura pracuje

## 7. Overovaci dotazy po kazdem behu

### 7.1 Posledni behy (hlavni audit)

```sql
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
```

### 7.2 Detail posledniho behu po tabulkach

```sql
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
```

### 7.3 Kontrola, ze nezustaly neprazdne DQ tabulky ve `stg_lnd`

```sql
SELECT
  COUNT(*) AS remaining_non_empty_dq_tables
FROM `o2czed1.region-europe-west4`.INFORMATION_SCHEMA.TABLE_STORAGE
WHERE table_schema = 'stg_lnd'
  AND table_type = 'BASE TABLE'
  AND REGEXP_CONTAINS(table_name, r'__dq10000__')
  AND creation_time < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR)
  AND total_rows > 0;
```

### 7.4 Rychla kontrola existence DQ tabulek

```sql
SELECT
  COUNT(*) AS remaining_dq_tables
FROM `o2czed1.stg_lnd`.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND REGEXP_CONTAINS(table_name, r'__dq10000__');
```

## 8. Doporuceny dalsi krok

1. Nasadit finalni Scheduled Query, ktera bude volat `sp_collect_dq10000`.
2. Dodelat samostatny cleanup prazdnych `__dq10000__` tabulek.