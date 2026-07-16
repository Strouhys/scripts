-- Promote cleaned retention metadata table to production
-- Generated: 2026-07-16
--
-- How to use:
-- 1) Set SOURCE_TABLE to cleaned table (usually non-prod or staging workspace).
-- 2) Set TARGET_TABLE to production table.
-- 3) Run section A (backup current production table).
-- 4) Run section B (promote cleaned table).
-- 5) Run section C (post-promotion validation).

-- ============================================================================
-- A) Backup current production table (adjust suffix/date as needed)
-- ============================================================================
CREATE OR REPLACE TABLE `o2czed1.opr_data.table_retention_backup_20260716`
AS
SELECT *
FROM `o2czed1.opr_data.table_retention`;

-- ============================================================================
-- B) Promote cleaned table to production target
--    IMPORTANT: If source == target, skip this section.
-- ============================================================================
-- Example source/target pair:
--   source: `o2czed1.opr_data.table_retention_clean`
--   target: `o2czed1.opr_data.table_retention`
--
-- CREATE OR REPLACE TABLE `o2czed1.opr_data.table_retention`
-- AS
-- SELECT *
-- FROM `o2czed1.opr_data.table_retention_clean`;

-- ============================================================================
-- C) Post-promotion sanity checks (run on production target)
-- ============================================================================
SELECT
  COUNT(*) AS total_rules,
  COUNTIF(is_active) AS active_rules,
  COUNTIF(NOT is_active) AS inactive_rules,
  COUNTIF(retention_type = 'CUSTOM_SQL') AS custom_sql_rules,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active) AS custom_sql_active_rules,
  COUNTIF(retention_type = 'COLUMN_AGE') AS column_age_rules
FROM `o2czed1.opr_data.table_retention`;

SELECT
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND (bq_execution_where_clause IS NULL OR TRIM(bq_execution_where_clause) = '')) AS empty_bq,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)retence\s+se')) AS retence_text,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'%this\.run_dttm%')) AS this_run_dttm_placeholder,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'DATE\(@retention_reference_dttm\)\(\)')) AS broken_date_call,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\x27\s*@retention_reference_dttm\s*\x27')) AS quoted_retention_param,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r';\s*$')) AS trailing_semicolon
FROM `o2czed1.opr_data.table_retention`;