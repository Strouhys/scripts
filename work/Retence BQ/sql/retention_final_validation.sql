-- Final validation for retention rules before go-live
-- Target table: o2czed1.opr_data.table_retention
--
-- Run sections top-down in BigQuery SQL editor.
-- Each section returns either:
-- 1) summary counts by issue
-- 2) detailed rows requiring manual fix

-- =========================================================
-- SECTION 1: Global quality summary
-- =========================================================
WITH base AS (
  SELECT
    retention_rule_id,
    project_id,
    source_dataset_name,
    bq_dataset_name,
    table_name,
    is_active,
    execution_frequency,
    execution_day_of_week,
    execution_day_of_month,
    retention_type,
    retention_column,
    retention_value,
    retention_unit,
    column_data_type,
    boundary_mode,
    source_execution_where_clause,
    bq_execution_where_clause,
    retention_comment,
    updated_by,
    updated_dttm
  FROM `o2czed1.opr_data.table_retention`
),
issues AS (
  SELECT retention_rule_id, 'INVALID_FREQUENCY' AS issue_code
  FROM base
  WHERE execution_frequency NOT IN ('D', 'W', 'M')

  UNION ALL
  SELECT retention_rule_id, 'WEEKLY_DAY_MISSING'
  FROM base
  WHERE execution_frequency = 'W' AND execution_day_of_week IS NULL

  UNION ALL
  SELECT retention_rule_id, 'WEEKLY_DAY_OUT_OF_RANGE'
  FROM base
  WHERE execution_frequency = 'W' AND execution_day_of_week NOT BETWEEN 1 AND 7

  UNION ALL
  SELECT retention_rule_id, 'COLUMN_AGE_RETENTION_COLUMN_MISSING'
  FROM base
  WHERE retention_type = 'COLUMN_AGE' AND retention_column IS NULL

  UNION ALL
  SELECT retention_rule_id, 'COLUMN_AGE_RETENTION_VALUE_MISSING'
  FROM base
  WHERE retention_type = 'COLUMN_AGE' AND retention_value IS NULL

  UNION ALL
  SELECT retention_rule_id, 'COLUMN_AGE_RETENTION_UNIT_INVALID'
  FROM base
  WHERE retention_type = 'COLUMN_AGE' AND retention_unit NOT IN ('DAY', 'MONTH', 'YEAR')

  UNION ALL
  SELECT retention_rule_id, 'COLUMN_AGE_BOUNDARY_MODE_INVALID'
  FROM base
  WHERE retention_type = 'COLUMN_AGE' AND boundary_mode NOT IN ('LOAD_DTTM', 'CURRENT_DATE', 'CUSTOM')

  UNION ALL
  SELECT retention_rule_id, 'ACTIVE_RULE_WITHOUT_BQ_DATASET_MAPPING'
  FROM base
  WHERE is_active = TRUE
    AND (bq_dataset_name IS NULL OR TRIM(COLLATE(bq_dataset_name, '')) = '')

  UNION ALL
  SELECT retention_rule_id, 'BQ_DATASET_EQUALS_SOURCE_DATASET'
  FROM base
  WHERE bq_dataset_name IS NOT NULL
    AND LOWER(COLLATE(bq_dataset_name, '')) = LOWER(COLLATE(source_dataset_name, ''))

  UNION ALL
  SELECT retention_rule_id, 'CUSTOM_SQL_BQ_WHERE_MISSING'
  FROM base
  WHERE retention_type = 'CUSTOM_SQL' AND bq_execution_where_clause IS NULL

  UNION ALL
  SELECT retention_rule_id, 'ACTIVE_RULE_WITH_EMPTY_BQ_WHERE'
  FROM base
  WHERE is_active = TRUE
    AND (bq_execution_where_clause IS NULL OR TRIM(COLLATE(bq_execution_where_clause, '')) = '')

  UNION ALL
  SELECT retention_rule_id, 'Bq_WHERE_HAS_TERADATA_FORMAT'
  FROM base
  WHERE bq_execution_where_clause IS NOT NULL
    AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\bFORMAT\s+\'')

  UNION ALL
  SELECT retention_rule_id, 'Bq_WHERE_HAS_TERADATA_ADD_MONTHS'
  FROM base
  WHERE bq_execution_where_clause IS NOT NULL
    AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\badd_months\s*\(')

  UNION ALL
  SELECT retention_rule_id, 'Bq_WHERE_HAS_TERADATA_SUBSTRING_FROM_FOR'
  FROM base
  WHERE bq_execution_where_clause IS NOT NULL
    AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\bsubstring\s*\(.*\bfrom\b.*\bfor\b')

  UNION ALL
  SELECT retention_rule_id, 'Bq_WHERE_HAS_UNMIGRATED_EP_SOURCE'
  FROM base
  WHERE bq_execution_where_clause IS NOT NULL
    AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\bFROM\s+EP_')

  UNION ALL
  SELECT retention_rule_id, 'Bq_WHERE_HAS_UNRESOLVED_LOAD_DTTM'
  FROM base
  WHERE bq_execution_where_clause IS NOT NULL
    AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'\$\$LOAD_DTTM')
)
SELECT
  issue_code,
  COUNT(*) AS issue_count
FROM issues
GROUP BY issue_code
ORDER BY issue_count DESC, issue_code;


-- =========================================================
-- SECTION 2: Detailed rows with detected issues
-- =========================================================
WITH base AS (
  SELECT
    retention_rule_id,
    project_id,
    source_dataset_name,
    bq_dataset_name,
    table_name,
    is_active,
    execution_frequency,
    execution_day_of_week,
    retention_type,
    retention_column,
    retention_value,
    retention_unit,
    boundary_mode,
    source_execution_where_clause,
    bq_execution_where_clause,
    retention_comment,
    updated_by,
    updated_dttm
  FROM `o2czed1.opr_data.table_retention`
),
issues AS (
  SELECT retention_rule_id, 'INVALID_FREQUENCY' AS issue_code
  FROM base
  WHERE execution_frequency NOT IN ('D', 'W', 'M')

  UNION ALL
  SELECT retention_rule_id, 'WEEKLY_DAY_MISSING'
  FROM base
  WHERE execution_frequency = 'W' AND execution_day_of_week IS NULL

  UNION ALL
  SELECT retention_rule_id, 'WEEKLY_DAY_OUT_OF_RANGE'
  FROM base
  WHERE execution_frequency = 'W' AND execution_day_of_week NOT BETWEEN 1 AND 7

  UNION ALL
  SELECT retention_rule_id, 'COLUMN_AGE_RETENTION_COLUMN_MISSING'
  FROM base
  WHERE retention_type = 'COLUMN_AGE' AND retention_column IS NULL

  UNION ALL
  SELECT retention_rule_id, 'COLUMN_AGE_RETENTION_VALUE_MISSING'
  FROM base
  WHERE retention_type = 'COLUMN_AGE' AND retention_value IS NULL

  UNION ALL
  SELECT retention_rule_id, 'COLUMN_AGE_RETENTION_UNIT_INVALID'
  FROM base
  WHERE retention_type = 'COLUMN_AGE' AND retention_unit NOT IN ('DAY', 'MONTH', 'YEAR')

  UNION ALL
  SELECT retention_rule_id, 'COLUMN_AGE_BOUNDARY_MODE_INVALID'
  FROM base
  WHERE retention_type = 'COLUMN_AGE' AND boundary_mode NOT IN ('LOAD_DTTM', 'CURRENT_DATE', 'CUSTOM')

  UNION ALL
  SELECT retention_rule_id, 'ACTIVE_RULE_WITHOUT_BQ_DATASET_MAPPING'
  FROM base
  WHERE is_active = TRUE
    AND (bq_dataset_name IS NULL OR TRIM(COLLATE(bq_dataset_name, '')) = '')

  UNION ALL
  SELECT retention_rule_id, 'BQ_DATASET_EQUALS_SOURCE_DATASET'
  FROM base
  WHERE bq_dataset_name IS NOT NULL
    AND LOWER(COLLATE(bq_dataset_name, '')) = LOWER(COLLATE(source_dataset_name, ''))

  UNION ALL
  SELECT retention_rule_id, 'CUSTOM_SQL_BQ_WHERE_MISSING'
  FROM base
  WHERE retention_type = 'CUSTOM_SQL' AND bq_execution_where_clause IS NULL

  UNION ALL
  SELECT retention_rule_id, 'ACTIVE_RULE_WITH_EMPTY_BQ_WHERE'
  FROM base
  WHERE is_active = TRUE
    AND (bq_execution_where_clause IS NULL OR TRIM(COLLATE(bq_execution_where_clause, '')) = '')

  UNION ALL
  SELECT retention_rule_id, 'Bq_WHERE_HAS_TERADATA_FORMAT'
  FROM base
  WHERE bq_execution_where_clause IS NOT NULL
    AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\bFORMAT\s+\'')

  UNION ALL
  SELECT retention_rule_id, 'Bq_WHERE_HAS_TERADATA_ADD_MONTHS'
  FROM base
  WHERE bq_execution_where_clause IS NOT NULL
    AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\badd_months\s*\(')

  UNION ALL
  SELECT retention_rule_id, 'Bq_WHERE_HAS_TERADATA_SUBSTRING_FROM_FOR'
  FROM base
  WHERE bq_execution_where_clause IS NOT NULL
    AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\bsubstring\s*\(.*\bfrom\b.*\bfor\b')

  UNION ALL
  SELECT retention_rule_id, 'Bq_WHERE_HAS_UNMIGRATED_EP_SOURCE'
  FROM base
  WHERE bq_execution_where_clause IS NOT NULL
    AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\bFROM\s+EP_')

  UNION ALL
  SELECT retention_rule_id, 'Bq_WHERE_HAS_UNRESOLVED_LOAD_DTTM'
  FROM base
  WHERE bq_execution_where_clause IS NOT NULL
    AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'\$\$LOAD_DTTM')
)
SELECT
  i.issue_code,
  b.retention_rule_id,
  b.project_id,
  b.source_dataset_name,
  b.bq_dataset_name,
  b.table_name,
  b.is_active,
  b.execution_frequency,
  b.execution_day_of_week,
  b.retention_type,
  b.retention_column,
  b.retention_value,
  b.retention_unit,
  b.boundary_mode,
  b.source_execution_where_clause,
  b.bq_execution_where_clause,
  b.retention_comment,
  b.updated_by,
  b.updated_dttm
FROM issues i
JOIN base b
  ON b.retention_rule_id = i.retention_rule_id
ORDER BY i.issue_code, b.source_dataset_name, b.table_name, b.retention_rule_id;


-- =========================================================
-- SECTION 3: Go-live gate summary
-- Interpretation:
-- - blocking_issues must be 0 before enabling scheduler.
-- =========================================================
WITH base AS (
  SELECT *
  FROM `o2czed1.opr_data.table_retention`
),
blocking AS (
  SELECT retention_rule_id
  FROM base
  WHERE execution_frequency NOT IN ('D', 'W', 'M')

  UNION DISTINCT
  SELECT retention_rule_id
  FROM base
  WHERE execution_frequency = 'W' AND (execution_day_of_week IS NULL OR execution_day_of_week NOT BETWEEN 1 AND 7)

  UNION DISTINCT
  SELECT retention_rule_id
  FROM base
  WHERE retention_type = 'COLUMN_AGE'
    AND (retention_column IS NULL OR retention_value IS NULL OR retention_unit NOT IN ('DAY', 'MONTH', 'YEAR'))

  UNION DISTINCT
  SELECT retention_rule_id
  FROM base
  WHERE is_active = TRUE
    AND (bq_execution_where_clause IS NULL OR TRIM(COLLATE(bq_execution_where_clause, '')) = '')

  UNION DISTINCT
  SELECT retention_rule_id
  FROM base
  WHERE bq_execution_where_clause IS NOT NULL
    AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\bFORMAT\s+\'')
)
SELECT
  (SELECT COUNT(*) FROM base) AS total_rules,
  (SELECT COUNT(*) FROM base WHERE is_active = TRUE) AS active_rules,
  (SELECT COUNT(*) FROM base WHERE retention_type = 'CUSTOM_SQL') AS custom_rules,
  (SELECT COUNT(*) FROM base WHERE retention_type = 'CUSTOM_SQL' AND is_active = TRUE) AS active_custom_rules,
  (SELECT COUNT(*) FROM blocking) AS blocking_issues;
