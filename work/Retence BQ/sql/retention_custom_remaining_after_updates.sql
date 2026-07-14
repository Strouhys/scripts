-- Remaining custom rules after bulk updates.
-- Use this to review what still needs manual conversion.

SELECT
  retention_rule_id,
  dataset_name,
  table_name,
  execution_frequency,
  source_execution_where_clause,
  bq_execution_where_clause,
  retention_comment,
  updated_by,
  updated_dttm
FROM `o2czed1.opr_data.table_retention`
WHERE retention_type = 'CUSTOM_SQL'
  AND (
    bq_execution_where_clause IS NULL
    OR REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)FORMAT\s+\'')
    OR REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)CAST\s*\(\s*\(\s*CAST\s*\(\s*CAST\s*\(')
    OR REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\bFROM\s+EP_')
  )
ORDER BY dataset_name, table_name, retention_rule_id;
