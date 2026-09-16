-- =============================================================================
-- retention_custom_to_column_age_conversion.sql
-- Generated: 2026-07-27
-- Source:    Manuální review zbývajících CUSTOM_SQL.csv (21 pravidel)
--
-- Konvertuje CUSTOM_SQL pravidla s přeložitelnou syntaxí na COLUMN_AGE
-- a deaktivuje pravidla, která nejde převést (subquery na Teradata tabulky).
--
-- Skupiny:
--   A  (8 pravidel): DM/DM01 – nested CAST pattern        → COLUMN_AGE
--   B  (1 pravidlo): AP_SDA  – DATE FORMAT Teradata syntax → COLUMN_AGE
--   C  (2 pravidla): AP_STG NIC – subquery ep_opr.asg_consumed_stat → deaktivovat
--   D (10 pravidel): EP_STRM_EH – CAST(inserted_ts as DATE) pattern → COLUMN_AGE
--
-- PO SPUŠTĚNÍ TOHOTO SKRIPTU NUTNO:
--   1) Spustit retention_column_age_refresh.sql
--      → ověří column_data_type z INFORMATION_SCHEMA a doplní bq_execution_where_clause
--   2) Spustit retention_final_validation.sql
--      → zkontrolovat blocking_issues = 0
-- =============================================================================


-- =============================================================================
-- SKUPINA A – DM/DM01: Teradata nested CAST → COLUMN_AGE
--
-- Vzor Teradata: col < CAST((CAST(CAST(@retention_reference_dttm AS TIMESTAMP(0))
--                        AS DATE) - INTERVAL 'N' DAY) AS TIMESTAMP(0))
-- BQ ekvivalent:  col < DATETIME_SUB(@retention_reference_dttm, INTERVAL N DAY)
--                (orchestrátor generuje sám podle column_data_type z INFORMATION_SCHEMA)
-- =============================================================================

-- A1: TT_END_DTTM – 90 DAY (1 pravidlo)
UPDATE `o2czed1.opr_data.table_retention`
SET
    retention_type            = 'COLUMN_AGE',
    retention_column          = 'TT_END_DTTM',
    retention_value           = 90,
    retention_unit            = 'DAY',
    column_data_type          = NULL,   -- doplní retention_column_age_refresh.sql
    bq_execution_where_clause = NULL,   -- doplní retention_column_age_refresh.sql
    updated_dttm              = CURRENT_TIMESTAMP(),
    updated_by                = 'custom_to_column_age_2026_07_27'
WHERE retention_rule_id = 'TD_AP_DM_CES_DEL_EVENT_00439';

-- A2: end_dttm – různé hodnoty (7 pravidel)
UPDATE `o2czed1.opr_data.table_retention`
SET
    retention_type            = 'COLUMN_AGE',
    retention_column          = 'end_dttm',
    retention_value           = CASE retention_rule_id
                                    WHEN 'TD_AP_DM_CES_F_EVENT_01271'             THEN 90
                                    WHEN 'TD_AP_DM_DAILY_OCM_F_BASE_OI_OUT_01038' THEN 183
                                    WHEN 'TD_AP_DM01_JRN_VERIF_PARTNER_01731'     THEN 365
                                    ELSE 183  -- SFA_CNTL_HW_BANK_* (4 pravidla)
                                END,
    retention_unit            = 'DAY',
    column_data_type          = NULL,
    bq_execution_where_clause = NULL,
    updated_dttm              = CURRENT_TIMESTAMP(),
    updated_by                = 'custom_to_column_age_2026_07_27'
WHERE retention_rule_id IN (
    'TD_AP_DM_CES_F_EVENT_01271',
    'TD_AP_DM_DAILY_OCM_F_BASE_OI_OUT_01038',
    'TD_AP_DM01_JRN_VERIF_PARTNER_01731',
    'TD_AP_DM01_SFA_CNTL_HW_BANK_ASGN_00906',
    'TD_AP_DM01_SFA_CNTL_HW_BANK_SERV_EOP_00237',
    'TD_AP_DM01_SFA_CNTL_HW_BANK_SERV_USG_00633',
    'TD_AP_DM01_SFA_CNTL_HW_BANK_STATE_00300'
);


-- =============================================================================
-- SKUPINA B – AP_SDA: Teradata DATE FORMAT syntax → COLUMN_AGE
--
-- Vzor: start_at_tv_day < Cast((DATE(@retention_reference_dttm) - INTERVAL '180' DAY)
--                              AS DATE FORMAT 'yyyy-mm-dd')
-- BQ:   DATE_SUB(DATE(@retention_reference_dttm), INTERVAL 180 DAY)
--       column_data_type = DATE (potvrzeno z Teradata syntaxe)
-- =============================================================================

UPDATE `o2czed1.opr_data.table_retention`
SET
    retention_type            = 'COLUMN_AGE',
    retention_column          = 'start_at_tv_day',
    retention_value           = 180,
    retention_unit            = 'DAY',
    column_data_type          = 'DATE',  -- potvrzeno ze zdrojové syntaxe (AS DATE FORMAT)
    bq_execution_where_clause = NULL,
    updated_dttm              = CURRENT_TIMESTAMP(),
    updated_by                = 'custom_to_column_age_2026_07_27'
WHERE retention_rule_id = 'TD_AP_SDA_EBOX_VIEWS_DN1_00010';


-- =============================================================================
-- SKUPINA C – AP_STG NIC: CUSTOM_SQL s subquery na ep_opr.asg_consumed_stat
--
-- Tato pravidla obsahují:
--   AND job_id < (SELECT max(asg_max_job_id) FROM ep_opr.asg_consumed_stat WHERE ...)
-- Tabulka ep_opr.asg_consumed_stat nemá v BQ ekvivalent → deaktivovat.
--
-- MOŽNOSTI PRO BUDOUCÍ REINSTATEMENT:
--   Option 1) Zjednodušit na COLUMN_AGE (jen date podmínka, bez job_id kontroly):
--               retention_type = COLUMN_AGE, retention_column = loaded_dttm,
--               retention_value = 10, retention_unit = DAY
--             Nutno schválení: tím se odstraní guard na spotřebované záznamy.
--   Option 2) Doplnit bq_execution_where_clause s BQ odkazem na tabulku
--             nahrazující ep_opr.asg_consumed_stat, je-li k dispozici.
-- =============================================================================

UPDATE `o2czed1.opr_data.table_retention`
SET
    is_active         = FALSE,
    updated_dttm      = CURRENT_TIMESTAMP(),
    updated_by        = 'custom_to_column_age_2026_07_27',
    retention_comment = COALESCE(NULLIF(TRIM(retention_comment), ''), '') ||
                        ' | DEACTIVATED 2026-07-27: bq_execution_where_clause obsahuje subquery na ep_opr.asg_consumed_stat, ktera nema BQ ekvivalent. Reinstate po doplneni BQ zdroje nebo po schvaleni zjednoduseni na COLUMN_AGE (loaded_dttm, 10 DAY).'
WHERE retention_rule_id IN (
    'TD_AP_STG_NIC_BULK_SPEED_00792',
    'TD_AP_STG_NIC_O2_AP_TECH_ACCESS_00879'
);


-- =============================================================================
-- SKUPINA D – EP_STRM_EH: CAST(inserted_ts as DATE) pattern → COLUMN_AGE
--
-- Vzor: CAST(inserted_ts as DATE) < CAST((CAST(CAST(@retention_reference_dttm
--             AS TIMESTAMP(0)) AS DATE) - INTERVAL 'N' DAY) AS TIMESTAMP(0))
-- BQ ekvivalent:  inserted_ts < TIMESTAMP_SUB(TIMESTAMP(@retention_reference_dttm),
--                               INTERVAL N DAY)
-- (přesný typ a WHERE klauzuli doplní retention_column_age_refresh.sql)
-- =============================================================================

UPDATE `o2czed1.opr_data.table_retention`
SET
    retention_type            = 'COLUMN_AGE',
    retention_column          = 'inserted_ts',
    retention_value           = CASE retention_rule_id
                                    WHEN 'TD_EP_STRM_EH_CTI_IBM_BOT_RAW_DATA_01771' THEN 186
                                    WHEN 'TD_EP_STRM_EH_EH_ANALYTIC_EVENT_00701'    THEN 186
                                    WHEN 'TD_EP_STRM_EH_EH_CONTACT_01543'           THEN 400
                                    ELSE 365  -- EXPN_UNICA_OFFER_RESPONSE + 6x SSQ
                                END,
    retention_unit            = 'DAY',
    column_data_type          = NULL,
    bq_execution_where_clause = NULL,
    updated_dttm              = CURRENT_TIMESTAMP(),
    updated_by                = 'custom_to_column_age_2026_07_27'
WHERE retention_rule_id IN (
    'TD_EP_STRM_EH_CTI_IBM_BOT_RAW_DATA_01771',
    'TD_EP_STRM_EH_EH_ANALYTIC_EVENT_00701',
    'TD_EP_STRM_EH_EH_CONTACT_01543',
    'TD_EP_STRM_EH_EXPN_UNICA_OFFER_RESPONSE_01720',
    'TD_EP_STRM_EH_SSQ_EVALUATION_PARAMS_01478',
    'TD_EP_STRM_EH_SSQ_EVALUATION_TAGS_01334',
    'TD_EP_STRM_EH_SSQ_INTERACTS_PARAMS_01299',
    'TD_EP_STRM_EH_SSQ_INTERACTS_TAGS_01503',
    'TD_EP_STRM_EH_SSQ_SOCIAL_MEDIA_PARAMS_01226',
    'TD_EP_STRM_EH_SSQ_SOCIAL_MEDIA_TAGS_01784'
);


-- =============================================================================
-- OVĚŘENÍ PO SPUŠTĚNÍ
-- Očekáváno: 19 updated (skupiny A+B+D), 2 deaktivovány (skupina C)
-- =============================================================================
SELECT
  updated_by,
  retention_type,
  is_active,
  COUNT(*) AS cnt
FROM `o2czed1.opr_data.table_retention`
WHERE retention_rule_id IN (
    -- Skupina A
    'TD_AP_DM_CES_DEL_EVENT_00439',
    'TD_AP_DM_CES_F_EVENT_01271',
    'TD_AP_DM_DAILY_OCM_F_BASE_OI_OUT_01038',
    'TD_AP_DM01_JRN_VERIF_PARTNER_01731',
    'TD_AP_DM01_SFA_CNTL_HW_BANK_ASGN_00906',
    'TD_AP_DM01_SFA_CNTL_HW_BANK_SERV_EOP_00237',
    'TD_AP_DM01_SFA_CNTL_HW_BANK_SERV_USG_00633',
    'TD_AP_DM01_SFA_CNTL_HW_BANK_STATE_00300',
    -- Skupina B
    'TD_AP_SDA_EBOX_VIEWS_DN1_00010',
    -- Skupina C
    'TD_AP_STG_NIC_BULK_SPEED_00792',
    'TD_AP_STG_NIC_O2_AP_TECH_ACCESS_00879',
    -- Skupina D
    'TD_EP_STRM_EH_CTI_IBM_BOT_RAW_DATA_01771',
    'TD_EP_STRM_EH_EH_ANALYTIC_EVENT_00701',
    'TD_EP_STRM_EH_EH_CONTACT_01543',
    'TD_EP_STRM_EH_EXPN_UNICA_OFFER_RESPONSE_01720',
    'TD_EP_STRM_EH_SSQ_EVALUATION_PARAMS_01478',
    'TD_EP_STRM_EH_SSQ_EVALUATION_TAGS_01334',
    'TD_EP_STRM_EH_SSQ_INTERACTS_PARAMS_01299',
    'TD_EP_STRM_EH_SSQ_INTERACTS_TAGS_01503',
    'TD_EP_STRM_EH_SSQ_SOCIAL_MEDIA_PARAMS_01226',
    'TD_EP_STRM_EH_SSQ_SOCIAL_MEDIA_TAGS_01784'
)
GROUP BY updated_by, retention_type, is_active
ORDER BY retention_type, is_active;
