-- Verification script for syntax cleanup in o2czed1.opr_data.table_retention
-- Scope: run after retention_delete_nonexisting_tables.sql and retention_syntax_fix_candidates_after_delete.sql
-- This script is read-only (SELECT only).

-- ============================================================================
-- 1) High-level summary
-- ============================================================================
SELECT
  CURRENT_TIMESTAMP() AS verification_dttm,
  COUNT(*) AS total_rules,
  COUNTIF(is_active) AS active_rules,
  COUNTIF(NOT is_active) AS inactive_rules,
  COUNTIF(retention_type = 'CUSTOM_SQL') AS custom_sql_rules,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active) AS custom_sql_active_rules,
  COUNTIF(retention_type = 'COLUMN_AGE') AS column_age_rules
FROM `o2czed1.opr_data.table_retention`;

-- ============================================================================
-- 2) Problem bucket counts (target is 0 for all)
-- ============================================================================
SELECT
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND (bq_execution_where_clause IS NULL OR TRIM(bq_execution_where_clause) = '')) AS empty_bq,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)retence\s+se')) AS retence_text,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'%this\.run_dttm%')) AS this_run_dttm_placeholder,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'DATE\(@retention_reference_dttm\)\(\)')) AS broken_date_call,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\x27\s*@retention_reference_dttm\s*\x27')) AS quoted_retention_param,
  COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r';\s*$')) AS trailing_semicolon
FROM `o2czed1.opr_data.table_retention`;

-- ============================================================================
-- 3) PASS/FAIL summary for quick check
-- ============================================================================
WITH metrics AS (
  SELECT
    COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND (bq_execution_where_clause IS NULL OR TRIM(bq_execution_where_clause) = '')) AS empty_bq,
    COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)retence\s+se')) AS retence_text,
    COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'%this\.run_dttm%')) AS this_run_dttm_placeholder,
    COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'DATE\(@retention_reference_dttm\)\(\)')) AS broken_date_call,
    COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\x27\s*@retention_reference_dttm\s*\x27')) AS quoted_retention_param,
    COUNTIF(retention_type = 'CUSTOM_SQL' AND is_active AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r';\s*$')) AS trailing_semicolon
  FROM `o2czed1.opr_data.table_retention`
)
SELECT
  IF(empty_bq = 0, 'PASS', 'FAIL') AS empty_bq_status,
  IF(retence_text = 0, 'PASS', 'FAIL') AS retence_text_status,
  IF(this_run_dttm_placeholder = 0, 'PASS', 'FAIL') AS this_run_dttm_status,
  IF(broken_date_call = 0, 'PASS', 'FAIL') AS broken_date_status,
  IF(quoted_retention_param = 0, 'PASS', 'FAIL') AS quoted_param_status,
  IF(trailing_semicolon = 0, 'PASS', 'FAIL') AS trailing_semicolon_status,
  IF(
    empty_bq + retence_text + this_run_dttm_placeholder + broken_date_call + quoted_retention_param + trailing_semicolon = 0,
    'PASS',
    'FAIL'
  ) AS overall_status
FROM metrics;

-- ============================================================================
-- 4) Detailed list of remaining issues by bucket
-- ============================================================================
SELECT
  'empty_bq' AS issue_bucket,
  retention_rule_id,
  source_dataset_name,
  table_name,
  is_active,
  bq_execution_where_clause
FROM `o2czed1.opr_data.table_retention`
WHERE retention_type = 'CUSTOM_SQL'
  AND is_active
  AND (bq_execution_where_clause IS NULL OR TRIM(bq_execution_where_clause) = '')

UNION ALL

SELECT
  'retence_text' AS issue_bucket,
  retention_rule_id,
  source_dataset_name,
  table_name,
  is_active,
  bq_execution_where_clause
FROM `o2czed1.opr_data.table_retention`
WHERE retention_type = 'CUSTOM_SQL'
  AND is_active
  AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)retence\s+se')

UNION ALL

SELECT
  'this_run_dttm_placeholder' AS issue_bucket,
  retention_rule_id,
  source_dataset_name,
  table_name,
  is_active,
  bq_execution_where_clause
FROM `o2czed1.opr_data.table_retention`
WHERE retention_type = 'CUSTOM_SQL'
  AND is_active
  AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'%this\.run_dttm%')

UNION ALL

SELECT
  'broken_date_call' AS issue_bucket,
  retention_rule_id,
  source_dataset_name,
  table_name,
  is_active,
  bq_execution_where_clause
FROM `o2czed1.opr_data.table_retention`
WHERE retention_type = 'CUSTOM_SQL'
  AND is_active
  AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'DATE\(@retention_reference_dttm\)\(\)')

UNION ALL

SELECT
  'quoted_retention_param' AS issue_bucket,
  retention_rule_id,
  source_dataset_name,
  table_name,
  is_active,
  bq_execution_where_clause
FROM `o2czed1.opr_data.table_retention`
WHERE retention_type = 'CUSTOM_SQL'
  AND is_active
  AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\x27\s*@retention_reference_dttm\s*\x27')

UNION ALL

SELECT
  'trailing_semicolon' AS issue_bucket,
  retention_rule_id,
  source_dataset_name,
  table_name,
  is_active,
  bq_execution_where_clause
FROM `o2czed1.opr_data.table_retention`
WHERE retention_type = 'CUSTOM_SQL'
  AND is_active
  AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r';\s*$')

ORDER BY issue_bucket, source_dataset_name, table_name, retention_rule_id;

-- ============================================================================
-- 5) Verify expected deactivated rules from block 1 are really inactive
-- ============================================================================
SELECT
  retention_rule_id,
  source_dataset_name,
  table_name,
  is_active,
  updated_by,
  updated_dttm
FROM `o2czed1.opr_data.table_retention`
WHERE retention_rule_id IN (
  'TD_AP_STG_EBILL_FREE_UNIT_00110',
  'TD_AP_STG_EBILL_CHARGE_01552',
  'TD_AP_STG_EBILL_CHARGE_GROUP_00209',
  'TD_AP_STG_EBILL_INVOICE_01404',
  'TD_AP_STG_EBILL_INVOICE_TAX_01793',
  'TD_AP_STG_EBILL_SERVICE_00415',
  'TD_AP_STG_EBILL_SERVICE_TAX_00663',
  'TD_AP_STG_EBILL_TECHNICAL_PROFILE_00060',
  'TD_AP_STG_O2VDC_OPRAVKY_00948',
  'TD_AP_STG_WSMS_C4S_ROAMING_PLMN_01266',
  'TD_AP_STG_WSMS_C4S_ROAMING_PLMN_CODE_01773',
  'TD_AP_STG_WSMS_C4S_ROAMING_PLMN_QUESTION_01151',
  'TD_AP_STG_WSMS_ROAMING_SURVEY_PLMN_01724',
  'TD_AP_STG_WSMS_ROAMING_SURVEY_PLMN_CODE_01325'
)
ORDER BY retention_rule_id;