-- Migration: split source dataset and BigQuery dataset mapping in table_retention
-- Target table: o2czed1.opr_data.table_retention
--
-- Goal:
-- 1) rename legacy dataset_name -> source_dataset_name
-- 2) add bq_dataset_name for BigQuery mapping
-- 3) preload known mapping for test: ap_stg -> stg_data

-- Step 1: rename legacy column (run once)
ALTER TABLE `o2czed1.opr_data.table_retention`
RENAME COLUMN dataset_name TO source_dataset_name;

-- Step 2: add new target mapping column
ALTER TABLE `o2czed1.opr_data.table_retention`
ADD COLUMN IF NOT EXISTS bq_dataset_name STRING OPTIONS(
  description="Název cílového BigQuery datasetu; NULL znamená dosud nepřemigrovaný dataset"
);

-- Step 3: known mapping for current test scope
UPDATE `o2czed1.opr_data.table_retention`
SET bq_dataset_name = 'stg_data'
WHERE LOWER(source_dataset_name) = 'ap_stg'
  AND (bq_dataset_name IS NULL OR TRIM(COLLATE(bq_dataset_name, '')) = '');

-- Optional QA
-- SELECT
--   source_dataset_name,
--   bq_dataset_name,
--   COUNT(*) AS cnt
-- FROM `o2czed1.opr_data.table_retention`
-- GROUP BY source_dataset_name, bq_dataset_name
-- ORDER BY source_dataset_name, bq_dataset_name;
