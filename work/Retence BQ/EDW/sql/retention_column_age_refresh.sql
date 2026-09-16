-- Refresh COLUMN_AGE metadata from actual BigQuery column types.
-- Target table: o2czed1.opr_data.table_retention
--
-- Purpose:
-- 1) read real column data types from mapped BigQuery datasets
-- 2) update column_data_type in table_retention
-- 3) regenerate bq_execution_where_clause consistently for COLUMN_AGE rules

CREATE TEMP TABLE tmp_column_metadata (
  project_id STRING,
  bq_dataset_name STRING,
  table_name STRING,
  column_name STRING,
  data_type STRING
);

FOR dataset_rec IN (
  SELECT DISTINCT project_id, bq_dataset_name
  FROM `o2czed1.opr_data.table_retention`
  WHERE retention_type = 'COLUMN_AGE'
    AND bq_dataset_name IS NOT NULL
    AND TRIM(COLLATE(bq_dataset_name, '')) <> ''
) DO
  EXECUTE IMMEDIATE FORMAT(
    '''
    INSERT INTO tmp_column_metadata (project_id, bq_dataset_name, table_name, column_name, data_type)
    SELECT
      @project_id,
      @bq_dataset_name,
      table_name,
      column_name,
      UPPER(data_type)
    FROM `%s.%s.INFORMATION_SCHEMA.COLUMNS`
    ''',
    dataset_rec.project_id,
    dataset_rec.bq_dataset_name
  )
  USING dataset_rec.project_id AS project_id, dataset_rec.bq_dataset_name AS bq_dataset_name;
END FOR;

UPDATE `o2czed1.opr_data.table_retention` AS target
SET
  column_data_type = meta.data_type,
  bq_execution_where_clause = CASE
    WHEN meta.data_type = 'DATE' THEN FORMAT(
      '%s < DATE_SUB(DATE(@retention_reference_dttm), INTERVAL %d %s)',
      target.retention_column,
      target.retention_value,
      target.retention_unit
    )
    WHEN meta.data_type = 'DATETIME' THEN FORMAT(
      '%s < DATETIME_SUB(@retention_reference_dttm, INTERVAL %d %s)',
      target.retention_column,
      target.retention_value,
      target.retention_unit
    )
    ELSE FORMAT(
      '%s < TIMESTAMP_SUB(TIMESTAMP(@retention_reference_dttm), INTERVAL %d %s)',
      target.retention_column,
      target.retention_value,
      target.retention_unit
    )
  END,
  updated_by = 'retention_column_age_refresh',
  updated_dttm = CURRENT_TIMESTAMP()
FROM tmp_column_metadata AS meta
WHERE target.retention_type = 'COLUMN_AGE'
  AND target.project_id = meta.project_id
  AND target.bq_dataset_name = meta.bq_dataset_name
  AND LOWER(COLLATE(target.table_name, '')) = LOWER(COLLATE(meta.table_name, ''))
  AND LOWER(COLLATE(target.retention_column, '')) = LOWER(COLLATE(meta.column_name, ''))
  AND target.retention_value IS NOT NULL
  AND target.retention_unit IN ('DAY', 'MONTH', 'YEAR');

-- Optional QA:
-- SELECT
--   retention_rule_id,
--   source_dataset_name,
--   bq_dataset_name,
--   table_name,
--   retention_column,
--   column_data_type,
--   bq_execution_where_clause
-- FROM `o2czed1.opr_data.table_retention`
-- WHERE retention_type = 'COLUMN_AGE'
-- ORDER BY source_dataset_name, table_name, retention_rule_id;