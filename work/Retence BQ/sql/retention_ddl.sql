-- Retence BigQuery - MVP DDL
-- Scope: konfigurace pravidel + audit runu + audit tasku + stavovy model.
-- Test project: o2czed1

-- =========================================================
-- 1) Konfiguracni tabulka pravidel
-- =========================================================
CREATE TABLE IF NOT EXISTS `o2czed1.opr_data.table_retention` (
  retention_rule_id STRING NOT NULL OPTIONS(description="Jedinečný identifikátor retenčního pravidla"),
  project_id STRING NOT NULL OPTIONS(description="ID cílového BigQuery projektu"),
  dataset_name STRING NOT NULL OPTIONS(description="Název cílového BigQuery datasetu"),
  table_name STRING NOT NULL OPTIONS(description="Název cílové BigQuery tabulky"),

  is_active BOOL NOT NULL OPTIONS(description="Příznak aktivace pravidla"),
  execution_frequency STRING NOT NULL OPTIONS(description="Kód frekvence spuštění D nebo W nebo M"),          -- D | W | M
  execution_day_of_week INT64 OPTIONS(description="Den v týdnu 1 pondělí až 7 neděle pro týdenní pravidla"),                  -- 1=Mon .. 7=Sun (pro W)
  execution_day_of_month INT64 OPTIONS(description="Den v měsíci 1 až 31 pro měsíční pravidla"),                 -- 1..31 (pro M) pokud by se pouzilo
  execution_schedule STRING OPTIONS(description="Volitelný rozšířený výraz pro plán spuštění"),                    -- volitelny textovy rozsireny schedule

  retention_type STRING NOT NULL OPTIONS(description="Typ retenčního pravidla například COLUMN_AGE nebo CUSTOM_SQL"),               -- COLUMN_AGE | CUSTOM_SQL | ...
  retention_column STRING OPTIONS(description="Sloupec použitý pro vyhodnocení retenční hranice"),
  retention_value INT64 OPTIONS(description="Číselná retenční hodnota použitá s retenční jednotkou"),
  retention_unit STRING OPTIONS(description="Retenční jednotka DAY nebo MONTH nebo YEAR"),                        -- DAY | MONTH | YEAR
  column_data_type STRING OPTIONS(description="Datový typ retenčního sloupce DATE nebo DATETIME nebo TIMESTAMP"),                      -- DATE | DATETIME | TIMESTAMP
  boundary_mode STRING OPTIONS(description="Režim hranice LOAD_DTTM nebo CURRENT_DATE nebo CUSTOM"),                         -- LOAD_DTTM | CURRENT_DATE | CUSTOM
  source_execution_where_clause STRING OPTIONS(description="Původní WHERE podmínka v Teradata syntaxi pro audit a dohledání"),
  bq_execution_where_clause STRING OPTIONS(description="WHERE podmínka přepsaná do BigQuery syntaxe pro reálné spuštění"),

  -- Volitelne sloupce pro rozsirenou CDC logiku
  end_column STRING OPTIONS(description="Volitelný koncový sloupec pro CDC nebo temporal pravidla"),
  operation_column STRING OPTIONS(description="Volitelný sloupec operace pro CDC pravidla"),
  delete_operation_value STRING OPTIONS(description="Volitelná hodnota značící mazací operaci"),
  source_time_column STRING OPTIONS(description="Volitelný zdrojový časový sloupec pro pokročilá pravidla"),

  retention_comment STRING OPTIONS(description="Volná provozní poznámka k retenčnímu pravidlu"),

  created_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Čas vytvoření řádku"),
  updated_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Čas poslední aktualizace řádku"),

  created_by STRING OPTIONS(description="Uživatel nebo proces, který pravidlo vytvořil"),
  updated_by STRING OPTIONS(description="Uživatel nebo proces, který pravidlo naposledy upravil")
)
PARTITION BY DATE(created_dttm)
-- Keep clustering only on non-string columns to avoid collation-related failures.
CLUSTER BY is_active, execution_day_of_week, execution_day_of_month
OPTIONS (
  description = "Metadata retenčních pravidel pro centralizovaný maintenance proces v BQ"
);

-- Doporucene semeno datove kvality (nepovinne):
-- 1) retention_rule_id by mel byt globalne unikatni (hlida aplikace/orchestrator).
-- 2) execution_frequency povolit jen D/W/M (hlida orchestrator validace).


-- =========================================================
-- 2) Audit hlavniho retention runu
-- =========================================================
CREATE TABLE IF NOT EXISTS `o2czed1.opr_data.retention_run` (
  run_id STRING NOT NULL OPTIONS(description="Jedinečný identifikátor retenčního běhu"),
  run_date DATE NOT NULL OPTIONS(description="Provozní datum provedení retenčního běhu"),

  run_start_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Čas zahájení běhu"),
  run_end_dttm TIMESTAMP OPTIONS(description="Čas ukončení běhu"),
  retention_reference_dttm DATETIME NOT NULL OPTIONS(description="Referenční datum a čas společné pro všechny tasky v běhu"),  -- napr. 2026-07-14 00:00:00

  orchestrator STRING NOT NULL OPTIONS(description="Orchestrátor spuštění TASK_SCHEDULER nebo OFLOW nebo AIRFLOW"),                -- TASK_SCHEDULER | OFLOW | AIRFLOW
  trigger_type STRING NOT NULL OPTIONS(description="Typ spuštění běhu SCHEDULED nebo MANUAL nebo RETRY"),                -- SCHEDULED | MANUAL | RETRY

  status STRING NOT NULL OPTIONS(description="Stav běhu CREATED nebo RUNNING nebo SUCCESS nebo PARTIAL_SUCCESS nebo FAILED"),                      -- CREATED | RUNNING | SUCCESS | PARTIAL_SUCCESS | FAILED
  error_message STRING OPTIONS(description="Chybová zpráva na úrovni běhu"),

  host_name STRING OPTIONS(description="Název hostitele, kde byl běh spuštěn"),
  process_id STRING OPTIONS(description="Identifikátor procesu v prostředí runneru"),
  git_revision STRING OPTIONS(description="Volitelný identifikátor revize kódu"),

  created_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Čas vytvoření řádku"),
  updated_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Čas poslední aktualizace řádku")
)
PARTITION BY run_date
OPTIONS (
  description = "Auditní tabulka hlavních retenčních běhů"
);


-- =========================================================
-- 3) Audit jednotlivych retention tasku (po pravidlech)
-- =========================================================
CREATE TABLE IF NOT EXISTS `o2czed1.opr_data.retention_task_run` (
  task_run_id STRING NOT NULL OPTIONS(description="Jedinečný identifikátor řádku provedení tasku"),
  run_id STRING NOT NULL OPTIONS(description="Identifikátor nadřazeného retenčního běhu"),
  execution_date DATE NOT NULL OPTIONS(description="Provozní datum provedení pro idempotenci"),

  retention_rule_id STRING NOT NULL OPTIONS(description="Identifikátor retenčního pravidla"),
  project_id STRING NOT NULL OPTIONS(description="ID cílového projektu"),
  dataset_name STRING NOT NULL OPTIONS(description="Název cílového datasetu"),
  table_name STRING NOT NULL OPTIONS(description="Název cílové tabulky"),

  status STRING NOT NULL OPTIONS(description="Stav tasku RUNNING nebo SUCCESS nebo FAILED nebo některý SKIPPED"),
  -- RUNNING | SUCCESS | FAILED |
  -- SKIPPED_FREQUENCY | SKIPPED_ALREADY_SUCCESS |
  -- SKIPPED_TABLE_NOT_FOUND | SKIPPED_COLUMN_NOT_FOUND | SKIPPED_NOT_ACTIVE |
  -- SKIPPED_NOT_IMPLEMENTED | SKIPPED_VALIDATION

  status_reason STRING OPTIONS(description="Krátký kód nebo text důvodu stavu"),
  error_message STRING OPTIONS(description="Detailní chybová zpráva provedení"),

  generated_sql STRING OPTIONS(description="Vygenerovaný text mazacího SQL"),
  affected_rows INT64 OPTIONS(description="Počet řádků ovlivněných mazacím příkazem"),

  started_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Čas zahájení tasku"),
  finished_dttm TIMESTAMP OPTIONS(description="Čas dokončení tasku"),

  is_retry BOOL DEFAULT FALSE OPTIONS(description="Příznak, zda jde o retry neúspěšného tasku"),
  retry_of_task_run_id STRING OPTIONS(description="Identifikátor původního neúspěšného tasku"),

  unique_task_key STRING NOT NULL OPTIONS(description="Idempotentní klíč retention_rule_id plus execution_date"),             -- retention_rule_id|execution_date

  created_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Čas vytvoření řádku"),
  updated_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Čas poslední aktualizace řádku")
)
PARTITION BY execution_date
CLUSTER BY is_retry, started_dttm
OPTIONS (
  description = "Auditní tabulka vyhodnocení a provedení retenčních tasků"
);

-- DULEZITE: BigQuery negarantuje unikatnost omezenim jako klasicky RDBMS.
-- Idempotenci pro unique_task_key je potreba zajistit atomicky v orchestratoru,
-- napr. pres MERGE s podminkou, ze se vlozi jen pokud target neexistuje.


-- =========================================================
-- 4) Stavovy model (referencni tabulka)
-- =========================================================
CREATE TABLE IF NOT EXISTS `o2czed1.opr_data.retention_status_model` (
  entity_type STRING NOT NULL OPTIONS(description="Typ záznamu RUN nebo TASK"),                 -- RUN | TASK
  status_code STRING NOT NULL OPTIONS(description="Kód stavu životního cyklu"),
  is_terminal BOOL NOT NULL OPTIONS(description="Příznak, zda je stav koncový"),
  is_success BOOL NOT NULL OPTIONS(description="Příznak, zda stav znamená úspěch"),
  status_order INT64 NOT NULL OPTIONS(description="Pořadí stavu pro dokumentaci lifecycle"),
  description STRING OPTIONS(description="Srozumitelný textový popis stavu"),
  created_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Čas vytvoření řádku")
)
PARTITION BY DATE(created_dttm)
CLUSTER BY is_terminal, is_success
OPTIONS (
  description = "Referenční stavový model pro run a task retenčního procesu"
);

-- Seed status model (idempotent load style).
MERGE `o2czed1.opr_data.retention_status_model` T
USING (
  SELECT 'RUN' AS entity_type, 'CREATED' AS status_code, FALSE AS is_terminal, FALSE AS is_success, 10 AS status_order, 'Run row created' AS description UNION ALL
  SELECT 'RUN', 'RUNNING', FALSE, FALSE, 20, 'Run execution in progress' UNION ALL
  SELECT 'RUN', 'SUCCESS', TRUE, TRUE, 30, 'All tasks successful or skipped as expected' UNION ALL
  SELECT 'RUN', 'PARTIAL_SUCCESS', TRUE, FALSE, 40, 'At least one task failed and at least one succeeded/skipped' UNION ALL
  SELECT 'RUN', 'FAILED', TRUE, FALSE, 50, 'System failure, run not completed'

  UNION ALL

  SELECT 'TASK', 'RUNNING', FALSE, FALSE, 10, 'Task is being executed' UNION ALL
  SELECT 'TASK', 'SUCCESS', TRUE, TRUE, 20, 'Delete executed successfully' UNION ALL
  SELECT 'TASK', 'FAILED', TRUE, FALSE, 30, 'Delete execution failed' UNION ALL
  SELECT 'TASK', 'SKIPPED_FREQUENCY', TRUE, TRUE, 40, 'Not scheduled for current date' UNION ALL
  SELECT 'TASK', 'SKIPPED_ALREADY_SUCCESS', TRUE, TRUE, 50, 'Already completed for rule+day' UNION ALL
  SELECT 'TASK', 'SKIPPED_TABLE_NOT_FOUND', TRUE, TRUE, 60, 'Target table does not exist yet' UNION ALL
  SELECT 'TASK', 'SKIPPED_COLUMN_NOT_FOUND', TRUE, TRUE, 70, 'Required retention column does not exist' UNION ALL
  SELECT 'TASK', 'SKIPPED_NOT_ACTIVE', TRUE, TRUE, 80, 'Rule is inactive' UNION ALL
  SELECT 'TASK', 'SKIPPED_NOT_IMPLEMENTED', TRUE, TRUE, 90, 'Retention type not implemented in current release' UNION ALL
  SELECT 'TASK', 'SKIPPED_VALIDATION', TRUE, TRUE, 100, 'Rule failed static validation'
) S
ON T.entity_type = S.entity_type
AND T.status_code = S.status_code
WHEN NOT MATCHED THEN
  INSERT (entity_type, status_code, is_terminal, is_success, status_order, description)
  VALUES (S.entity_type, S.status_code, S.is_terminal, S.is_success, S.status_order, S.description);


-- =========================================================
-- 5) Doporucene pomocne pohledy pro monitoring
-- =========================================================
CREATE OR REPLACE VIEW `o2czed1.opr_data.v_retention_run_last_14d` AS
SELECT
  run_id,
  run_date,
  run_start_dttm,
  run_end_dttm,
  orchestrator,
  trigger_type,
  status,
  error_message
FROM `o2czed1.opr_data.retention_run`
WHERE run_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
ORDER BY run_start_dttm DESC;

CREATE OR REPLACE VIEW `o2czed1.opr_data.v_retention_task_failures_last_14d` AS
SELECT
  execution_date,
  run_id,
  retention_rule_id,
  CONCAT(project_id, '.', dataset_name, '.', table_name) AS target_table,
  status,
  status_reason,
  error_message,
  started_dttm,
  finished_dttm
FROM `o2czed1.opr_data.retention_task_run`
WHERE execution_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
  AND status = 'FAILED'
ORDER BY started_dttm DESC;
