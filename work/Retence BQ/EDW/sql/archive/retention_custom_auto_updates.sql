-- Bulk updates for migrated CUSTOM_SQL rules.
-- Target: o2czed1.opr_data.table_retention
-- Purpose: reduce manual-review set by normalizing common Teradata patterns to BigQuery syntax.

-- =========================================================
-- 1) CDC OR pattern
-- Pattern example:
--   (TT_END_DTTM < CAST(...$$LOAD_DTTM... INTERVAL '60' DAY ...))
--   OR (Operation = 'D' AND src_dttm < CAST(...$$LOAD_DTTM... INTERVAL '60' DAY ...))
-- =========================================================
UPDATE `o2czed1.opr_data.table_retention`
SET
  bq_execution_where_clause = REGEXP_REPLACE(
    REGEXP_REPLACE(
      REGEXP_REPLACE(COLLATE(source_execution_where_clause, ''), r'\$\$LOAD_DTTM', '@retention_reference_dttm'),
      r'(?i)CAST\s*\(\s*\(\s*CAST\s*\(\s*CAST\s*\(\s*\'@retention_reference_dttm\'\s+AS\s+TIMESTAMP\(0\)\s*\)\s+AS\s+DATE\s*\)\s*-\s*INTERVAL\s*\'([0-9]+)\'\s+DAY\s*\)\s+AS\s+TIMESTAMP\(0\)\s*\)',
      r'TIMESTAMP_SUB(TIMESTAMP(@retention_reference_dttm), INTERVAL \1 DAY)'
    ),
    r'(?i)\s+', ' '
  ),
  updated_by = 'bulk_custom_update_cdc_or',
  updated_dttm = CURRENT_TIMESTAMP()
WHERE retention_type = 'CUSTOM_SQL'
  AND source_execution_where_clause IS NOT NULL
  AND REGEXP_CONTAINS(COLLATE(source_execution_where_clause, ''), r'(?i)TT_END_DTTM')
  AND REGEXP_CONTAINS(COLLATE(source_execution_where_clause, ''), r"(?i)Operation\s*=\s*'D'")
  AND REGEXP_CONTAINS(COLLATE(source_execution_where_clause, ''), r'(?i)\sOR\s');


-- =========================================================
-- 2) Operation-only pattern
-- Pattern example:
--   Operation = 'D' AND src_dttm < CAST(...$$LOAD_DTTM... INTERVAL '60' DAY ...)
-- =========================================================
UPDATE `o2czed1.opr_data.table_retention`
SET
  bq_execution_where_clause = REGEXP_REPLACE(
    REGEXP_REPLACE(
      REGEXP_REPLACE(COLLATE(source_execution_where_clause, ''), r'\$\$LOAD_DTTM', '@retention_reference_dttm'),
      r'(?i)CAST\s*\(\s*\(\s*CAST\s*\(\s*CAST\s*\(\s*\'@retention_reference_dttm\'\s+AS\s+TIMESTAMP\(0\)\s*\)\s+AS\s+DATE\s*\)\s*-\s*INTERVAL\s*\'([0-9]+)\'\s+DAY\s*\)\s+AS\s+TIMESTAMP\(0\)\s*\)',
      r'TIMESTAMP_SUB(TIMESTAMP(@retention_reference_dttm), INTERVAL \1 DAY)'
    ),
    r'(?i)\s+', ' '
  ),
  updated_by = 'bulk_custom_update_operation_only',
  updated_dttm = CURRENT_TIMESTAMP()
WHERE retention_type = 'CUSTOM_SQL'
  AND source_execution_where_clause IS NOT NULL
  AND REGEXP_CONTAINS(COLLATE(source_execution_where_clause, ''), r"(?i)^\s*Operation\s*=\s*'D'")
  AND NOT REGEXP_CONTAINS(COLLATE(source_execution_where_clause, ''), r'(?i)\sOR\s');


-- =========================================================
-- 3) Current_Date pattern
-- Pattern example:
--   ... Current_Date - INTERVAL '180' DAY ...
-- =========================================================
UPDATE `o2czed1.opr_data.table_retention`
SET
  bq_execution_where_clause = REGEXP_REPLACE(
    REGEXP_REPLACE(COLLATE(source_execution_where_clause, ''), r'(?i)Current_Date', 'DATE(@retention_reference_dttm)'),
    r'(?i)\s+', ' '
  ),
  updated_by = 'bulk_custom_update_current_date',
  updated_dttm = CURRENT_TIMESTAMP()
WHERE retention_type = 'CUSTOM_SQL'
  AND source_execution_where_clause IS NOT NULL
  AND REGEXP_CONTAINS(COLLATE(source_execution_where_clause, ''), r'(?i)Current_Date');


-- =========================================================
-- 4) add_months/substring pattern
-- Pattern example:
--   add_months( cast(substring('$$LOAD_DTTM' from 1 for 10) as date), -6)
-- =========================================================
UPDATE `o2czed1.opr_data.table_retention`
SET
  bq_execution_where_clause = REGEXP_REPLACE(
    REGEXP_REPLACE(
      COLLATE(source_execution_where_clause, ''),
      r"(?i)add_months\s*\(\s*cast\s*\(\s*substring\s*\(\s*'\$\$LOAD_DTTM'\s+from\s+1\s+for\s+10\s*\)\s+as\s+date\s*\)\s*,\s*(-?[0-9]+)\s*\)",
      r'DATE_ADD(DATE(@retention_reference_dttm), INTERVAL \1 MONTH)'
    ),
    r'(?i)\s+', ' '
  ),
  updated_by = 'bulk_custom_update_add_months',
  updated_dttm = CURRENT_TIMESTAMP()
WHERE retention_type = 'CUSTOM_SQL'
  AND source_execution_where_clause IS NOT NULL
  AND REGEXP_CONTAINS(COLLATE(source_execution_where_clause, ''), r'(?i)add_months');


-- =========================================================
-- 5) SELECT MAX(load_dttm) from EP_IND.E20_LOAD_RETENTION
-- NOTE: This pattern requires data source migration.
-- For now we only replace database prefix to the expected BQ object naming.
-- =========================================================
UPDATE `o2czed1.opr_data.table_retention`
SET
  bq_execution_where_clause = REGEXP_REPLACE(
    REGEXP_REPLACE(COLLATE(source_execution_where_clause, ''), r'(?i)EP_IND\.E20_LOAD_RETENTION', 'o2czed1.opr_data.e20_load_retention'),
    r'(?i)\s+', ' '
  ),
  updated_by = 'bulk_custom_update_select_max',
  updated_dttm = CURRENT_TIMESTAMP()
WHERE retention_type = 'CUSTOM_SQL'
  AND source_execution_where_clause IS NOT NULL
  AND REGEXP_CONTAINS(COLLATE(source_execution_where_clause, ''), r'(?i)SELECT\s+MAX\(load_dttm\)');


-- =========================================================
-- 6) Safety: explicit no-delete rules (contains 'nemazat')
-- Deactivate and clear executable where-clause.
-- =========================================================
UPDATE `o2czed1.opr_data.table_retention`
SET
  is_active = FALSE,
  bq_execution_where_clause = NULL,
  updated_by = 'bulk_custom_update_nemazat',
  updated_dttm = CURRENT_TIMESTAMP()
WHERE source_execution_where_clause IS NOT NULL
  AND REGEXP_CONTAINS(COLLATE(source_execution_where_clause, ''), r'(?i)nemazat');


-- =========================================================
-- 7) Optional QA summary after updates
-- =========================================================
-- SELECT
--   retention_type,
--   COUNT(*) AS cnt,
--   COUNTIF(retention_type = 'CUSTOM_SQL' AND bq_execution_where_clause IS NULL) AS custom_without_bq_where
-- FROM `o2czed1.opr_data.table_retention`
-- GROUP BY retention_type
-- ORDER BY cnt DESC;
