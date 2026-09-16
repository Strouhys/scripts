-- Syntax fix candidates after deleting non-existing tables
-- Generated: 2026-07-16
-- Remaining rows in snapshot: 771
-- Remaining CUSTOM_SQL: 439
-- Buckets: empty_bq=8, retence_text=6, this_run_dttm=8, broken_date=4, quoted_param=12, semicolon=1
-- NOTE: This is an apply script (UPDATE only). Use retention_syntax_verification_after_delete.sql for checks.

-- 1) Deactivate invalid/no-op clauses
UPDATE `o2czed1.opr_data.table_retention`
SET is_active = FALSE, updated_dttm = CURRENT_TIMESTAMP(), updated_by = 'syntax_review_after_delete_2026_07_16'
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
);

-- 2) Replace %this.run_dttm% placeholder
UPDATE `o2czed1.opr_data.table_retention`
SET bq_execution_where_clause = REPLACE(bq_execution_where_clause, '%this.run_dttm%', '@retention_reference_dttm'),
    updated_dttm = CURRENT_TIMESTAMP(), updated_by = 'syntax_review_after_delete_2026_07_16'
WHERE retention_rule_id IN (
  'TD_AP_DM_CES_DEL_EVENT_00439',
  'TD_AP_DM_CES_F_EVENT_01271',
  'TD_AP_DM_DAILY_OCM_F_BASE_OI_OUT_01038',
  'TD_AP_DM01_JRN_VERIF_PARTNER_01731',
  'TD_AP_DM01_SFA_CNTL_HW_BANK_ASGN_00906',
  'TD_AP_DM01_SFA_CNTL_HW_BANK_SERV_EOP_00237',
  'TD_AP_DM01_SFA_CNTL_HW_BANK_SERV_USG_00633',
  'TD_AP_DM01_SFA_CNTL_HW_BANK_STATE_00300'
);

-- 3) Fix malformed DATE(@retention_reference_dttm)()
UPDATE `o2czed1.opr_data.table_retention`
SET bq_execution_where_clause = REPLACE(bq_execution_where_clause, 'DATE(@retention_reference_dttm)()', 'DATE(@retention_reference_dttm)'),
    updated_dttm = CURRENT_TIMESTAMP(), updated_by = 'syntax_review_after_delete_2026_07_16'
WHERE retention_rule_id IN (
  'TD_AP_DM01_CCR_ASSET_VT_00302',
  'TD_AP_DM01_CCR_PARTY_CA_VT_00989',
  'TD_AP_DM01_CCR_PARTY_CU_VT_01601',
  'TD_AP_DM01_CCR_PARTY_TS_VT_01135'
);

-- 4) Fix quoted runtime parameter
UPDATE `o2czed1.opr_data.table_retention`
SET bq_execution_where_clause = REGEXP_REPLACE(
      COLLATE(bq_execution_where_clause, ''),
      r'(?i)\x27\s*@retention_reference_dttm\s*\x27',
      '@retention_reference_dttm'
    ),
    updated_dttm = CURRENT_TIMESTAMP(), updated_by = 'syntax_review_after_delete_2026_07_16'
WHERE retention_type = 'CUSTOM_SQL'
  AND REGEXP_CONTAINS(COLLATE(bq_execution_where_clause, ''), r'(?i)\x27\s*@retention_reference_dttm\s*\x27');

-- 5) Remove trailing semicolon
UPDATE `o2czed1.opr_data.table_retention`
SET bq_execution_where_clause = REGEXP_REPLACE(COLLATE(bq_execution_where_clause, ''), r';\s*$', ''),
    updated_dttm = CURRENT_TIMESTAMP(), updated_by = 'syntax_review_after_delete_2026_07_16'
WHERE retention_rule_id IN (
  'TD_EP_STRM_EH_EXPN_EVENT_00350'
);
