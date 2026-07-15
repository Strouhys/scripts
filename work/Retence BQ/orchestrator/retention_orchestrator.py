import argparse
import datetime as dt
import logging
import os
import sys
import uuid
from dataclasses import dataclass
from typing import Optional

from google.cloud import bigquery
from google.api_core import exceptions as gexc
from dotenv import load_dotenv

try:
    import truststore
except Exception:
    truststore = None

RUNNING = "RUNNING"
SUCCESS = "SUCCESS"
FAILED = "FAILED"
PARTIAL_SUCCESS = "PARTIAL_SUCCESS"
SKIPPED_FREQUENCY = "SKIPPED_FREQUENCY"
SKIPPED_ALREADY_SUCCESS = "SKIPPED_ALREADY_SUCCESS"
SKIPPED_TABLE_NOT_FOUND = "SKIPPED_TABLE_NOT_FOUND"
SKIPPED_COLUMN_NOT_FOUND = "SKIPPED_COLUMN_NOT_FOUND"
SKIPPED_NOT_IMPLEMENTED = "SKIPPED_NOT_IMPLEMENTED"
SKIPPED_VALIDATION = "SKIPPED_VALIDATION"


def env_or_arg(arg_value: Optional[str], env_name: str, default: Optional[str] = None) -> Optional[str]:
    if arg_value is not None and str(arg_value).strip() != "":
        return arg_value
    env_value = os.getenv(env_name)
    if env_value is not None and env_value.strip() != "":
        return env_value
    return default


def parse_env_int(env_name: str, default: Optional[int] = None) -> Optional[int]:
    raw = os.getenv(env_name)
    if raw is None or raw.strip() == "":
        return default
    return int(raw)


def parse_env_bool(env_name: str, default: bool = False) -> bool:
    raw = os.getenv(env_name)
    if raw is None or raw.strip() == "":
        return default
    return raw.strip().lower() in {"1", "true", "yes", "y", "on"}


@dataclass
class Config:
    project_id: str
    dataset: str
    orchestrator: str
    trigger_type: str
    dry_run: bool
    execution_date: dt.date
    weekly_run_day: int
    max_rules: Optional[int]
    filter_rule_id: Optional[str]
    filter_target_project: Optional[str]
    filter_target_dataset: Optional[str]
    filter_target_table: Optional[str]


@dataclass
class Rule:
    retention_rule_id: str
    project_id: str
    dataset_name: str
    table_name: str
    execution_frequency: str
    execution_day_of_week: Optional[int]
    execution_day_of_month: Optional[int]
    retention_type: str
    retention_column: Optional[str]
    retention_value: Optional[int]
    retention_unit: Optional[str]
    boundary_mode: Optional[str]
    source_execution_where_clause: Optional[str]
    bq_execution_where_clause: Optional[str]


class RetentionOrchestrator:
    def __init__(self, client: bigquery.Client, cfg: Config) -> None:
        self.client = client
        self.cfg = cfg
        self.run_id = str(uuid.uuid4())
        self.reference_dttm = dt.datetime.combine(cfg.execution_date, dt.time.min)

        self.task_success = 0
        self.task_failed = 0
        self.task_skipped = 0

    @property
    def table_retention(self) -> str:
        return f"`{self.cfg.project_id}.{self.cfg.dataset}.table_retention`"

    @property
    def table_run(self) -> str:
        return f"`{self.cfg.project_id}.{self.cfg.dataset}.retention_run`"

    @property
    def table_task(self) -> str:
        return f"`{self.cfg.project_id}.{self.cfg.dataset}.retention_task_run`"

    def _query(self, sql: str, params: Optional[list] = None):
        job_config = None
        if params:
            job_config = bigquery.QueryJobConfig(query_parameters=params)
        try:
            return self.client.query(sql, job_config=job_config, retry=None).result(timeout=120)
        except Exception as exc:
            self._raise_with_connectivity_hint(exc)

    def _raise_with_connectivity_hint(self, exc: Exception) -> None:
        message = str(exc)
        if "CERTIFICATE_VERIFY_FAILED" in message or "self-signed certificate" in message:
            raise RuntimeError(
                "SSL certificate verification failed while accessing Google APIs. "
                "Configure corporate CA trust for Python (REQUESTS_CA_BUNDLE or SSL_CERT_FILE), "
                "then retry the orchestrator run."
            ) from exc
        raise exc

    def create_run(self) -> None:
        sql = f"""
        INSERT INTO {self.table_run}
        (run_id, run_date, run_start_dttm, retention_reference_dttm, orchestrator, trigger_type, status, created_dttm, updated_dttm)
        VALUES
        (@run_id, @run_date, CURRENT_TIMESTAMP(), @reference_dttm, @orchestrator, @trigger_type, @status, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())
        """
        params = [
            bigquery.ScalarQueryParameter("run_id", "STRING", self.run_id),
            bigquery.ScalarQueryParameter("run_date", "DATE", self.cfg.execution_date.isoformat()),
            bigquery.ScalarQueryParameter("reference_dttm", "DATETIME", self.reference_dttm),
            bigquery.ScalarQueryParameter("orchestrator", "STRING", self.cfg.orchestrator),
            bigquery.ScalarQueryParameter("trigger_type", "STRING", self.cfg.trigger_type),
            bigquery.ScalarQueryParameter("status", "STRING", RUNNING),
        ]
        self._query(sql, params)

    def close_run(self, status: str, error_message: Optional[str] = None) -> None:
        sql = f"""
        UPDATE {self.table_run}
        SET status = @status,
            error_message = @error_message,
            run_end_dttm = CURRENT_TIMESTAMP(),
            updated_dttm = CURRENT_TIMESTAMP()
        WHERE run_id = @run_id
        """
        params = [
            bigquery.ScalarQueryParameter("status", "STRING", status),
            bigquery.ScalarQueryParameter("error_message", "STRING", error_message),
            bigquery.ScalarQueryParameter("run_id", "STRING", self.run_id),
        ]
        self._query(sql, params)

    def load_rules(self) -> list[Rule]:
        limit_clause = f"LIMIT {self.cfg.max_rules}" if self.cfg.max_rules else ""
        where_clauses = ["is_active = TRUE"]
        query_params: list[bigquery.ScalarQueryParameter] = []

        if self.cfg.filter_rule_id:
            where_clauses.append("retention_rule_id = @filter_rule_id")
            query_params.append(
                bigquery.ScalarQueryParameter("filter_rule_id", "STRING", self.cfg.filter_rule_id)
            )

        if self.cfg.filter_target_project:
            where_clauses.append("project_id = @filter_target_project")
            query_params.append(
                bigquery.ScalarQueryParameter("filter_target_project", "STRING", self.cfg.filter_target_project)
            )

        if self.cfg.filter_target_dataset:
            where_clauses.append("dataset_name = @filter_target_dataset")
            query_params.append(
                bigquery.ScalarQueryParameter("filter_target_dataset", "STRING", self.cfg.filter_target_dataset)
            )

        if self.cfg.filter_target_table:
            where_clauses.append("table_name = @filter_target_table")
            query_params.append(
                bigquery.ScalarQueryParameter("filter_target_table", "STRING", self.cfg.filter_target_table)
            )

        where_sql = " AND\n          ".join(where_clauses)
        sql = f"""
        SELECT
          retention_rule_id,
          project_id,
          dataset_name,
          table_name,
          execution_frequency,
          execution_day_of_week,
          execution_day_of_month,
          retention_type,
          retention_column,
          retention_value,
          retention_unit,
          boundary_mode,
          source_execution_where_clause,
          bq_execution_where_clause
        FROM {self.table_retention}
        WHERE {where_sql}
        ORDER BY retention_rule_id
        {limit_clause}
        """
        rows = self._query(sql, query_params if query_params else None)
        result = []
        for r in rows:
            result.append(
                Rule(
                    retention_rule_id=r["retention_rule_id"],
                    project_id=r["project_id"],
                    dataset_name=r["dataset_name"],
                    table_name=r["table_name"],
                    execution_frequency=(r["execution_frequency"] or "").strip().upper(),
                    execution_day_of_week=r["execution_day_of_week"],
                    execution_day_of_month=r["execution_day_of_month"],
                    retention_type=(r["retention_type"] or "").strip().upper(),
                    retention_column=r["retention_column"],
                    retention_value=r["retention_value"],
                    retention_unit=(r["retention_unit"] or "").strip().upper() if r["retention_unit"] else None,
                    boundary_mode=(r["boundary_mode"] or "").strip().upper() if r["boundary_mode"] else None,
                    source_execution_where_clause=r["source_execution_where_clause"],
                    bq_execution_where_clause=r["bq_execution_where_clause"],
                )
            )
        return result

    def should_run_today(self, rule: Rule) -> bool:
        freq = rule.execution_frequency
        if freq == "D":
            return True
        if freq == "W":
            target_day = rule.execution_day_of_week or self.cfg.weekly_run_day
            return self.cfg.execution_date.isoweekday() == target_day
        if freq == "M":
            if rule.execution_day_of_month:
                return self.cfg.execution_date.day == rule.execution_day_of_month
            return self.cfg.execution_date.isoweekday() == 6 and self.cfg.execution_date.day <= 7
        return False

    def table_exists(self, project_id: str, dataset: str, table: str) -> tuple[bool, str]:
        sql = f"""
        SELECT COUNT(1) AS cnt
        FROM `{project_id}.{dataset}.INFORMATION_SCHEMA.TABLES`
        WHERE table_name = @table_name
        """
        params = [bigquery.ScalarQueryParameter("table_name", "STRING", table)]
        try:
            row = next(iter(self._query(sql, params)))
            if row["cnt"] > 0:
                return True, "TABLE_FOUND"
            return False, "TABLE_NOT_FOUND"
        except gexc.NotFound:
            return False, "DATASET_NOT_MIGRATED"

    def column_exists(self, project_id: str, dataset: str, table: str, column: str) -> bool:
        sql = f"""
        SELECT COUNT(1) AS cnt
        FROM `{project_id}.{dataset}.INFORMATION_SCHEMA.COLUMNS`
        WHERE table_name = @table_name
          AND column_name = @column_name
        """
        params = [
            bigquery.ScalarQueryParameter("table_name", "STRING", table),
            bigquery.ScalarQueryParameter("column_name", "STRING", column),
        ]
        try:
            row = next(iter(self._query(sql, params)))
            return row["cnt"] > 0
        except gexc.NotFound:
            return False

    def already_processed(self, unique_task_key: str) -> bool:
        sql = f"""
        SELECT COUNT(1) AS cnt
        FROM {self.table_task}
        WHERE unique_task_key = @unique_task_key
          AND status IN ('RUNNING', 'SUCCESS')
        """
        params = [bigquery.ScalarQueryParameter("unique_task_key", "STRING", unique_task_key)]
        row = next(iter(self._query(sql, params)))
        return row["cnt"] > 0

    def insert_task(self, rule: Rule, status: str, status_reason: Optional[str], generated_sql: Optional[str], error_message: Optional[str], affected_rows: Optional[int], is_retry: bool = False, retry_of_task_run_id: Optional[str] = None) -> None:
        task_run_id = str(uuid.uuid4())
        unique_key = f"{rule.retention_rule_id}|{self.cfg.execution_date.isoformat()}"
        sql = f"""
        INSERT INTO {self.table_task}
        (task_run_id, run_id, execution_date, retention_rule_id, project_id, dataset_name, table_name,
         status, status_reason, error_message, generated_sql, affected_rows,
         started_dttm, finished_dttm, is_retry, retry_of_task_run_id, unique_task_key, created_dttm, updated_dttm)
        VALUES
        (@task_run_id, @run_id, @execution_date, @retention_rule_id, @project_id, @dataset_name, @table_name,
         @status, @status_reason, @error_message, @generated_sql, @affected_rows,
         CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), @is_retry, @retry_of_task_run_id, @unique_task_key, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())
        """
        params = [
            bigquery.ScalarQueryParameter("task_run_id", "STRING", task_run_id),
            bigquery.ScalarQueryParameter("run_id", "STRING", self.run_id),
            bigquery.ScalarQueryParameter("execution_date", "DATE", self.cfg.execution_date.isoformat()),
            bigquery.ScalarQueryParameter("retention_rule_id", "STRING", rule.retention_rule_id),
            bigquery.ScalarQueryParameter("project_id", "STRING", rule.project_id),
            bigquery.ScalarQueryParameter("dataset_name", "STRING", rule.dataset_name),
            bigquery.ScalarQueryParameter("table_name", "STRING", rule.table_name),
            bigquery.ScalarQueryParameter("status", "STRING", status),
            bigquery.ScalarQueryParameter("status_reason", "STRING", status_reason),
            bigquery.ScalarQueryParameter("error_message", "STRING", error_message),
            bigquery.ScalarQueryParameter("generated_sql", "STRING", generated_sql),
            bigquery.ScalarQueryParameter("affected_rows", "INT64", affected_rows),
            bigquery.ScalarQueryParameter("is_retry", "BOOL", is_retry),
            bigquery.ScalarQueryParameter("retry_of_task_run_id", "STRING", retry_of_task_run_id),
            bigquery.ScalarQueryParameter("unique_task_key", "STRING", unique_key),
        ]
        self._query(sql, params)

    def build_where_clause(self, rule: Rule) -> Optional[str]:
        if rule.retention_type == "COLUMN_AGE":
            if not rule.retention_column or rule.retention_value is None or not rule.retention_unit:
                return None
            if rule.retention_unit not in {"DAY", "MONTH", "YEAR"}:
                return None
            return (
                f"{rule.retention_column} < "
                f"TIMESTAMP_SUB(TIMESTAMP(@retention_reference_dttm), INTERVAL {rule.retention_value} {rule.retention_unit})"
            )

        if rule.retention_type == "CUSTOM_SQL":
            if not rule.bq_execution_where_clause or not rule.bq_execution_where_clause.strip():
                return None
            return rule.bq_execution_where_clause.strip()

        return None

    def execute_delete(self, rule: Rule, where_clause: str) -> int:
        sql = f"DELETE FROM `{rule.project_id}.{rule.dataset_name}.{rule.table_name}` WHERE {where_clause}"
        params = [
            bigquery.ScalarQueryParameter("retention_reference_dttm", "DATETIME", self.reference_dttm)
        ]
        job_config = bigquery.QueryJobConfig(query_parameters=params)
        try:
            job = self.client.query(sql, job_config=job_config, retry=None)
            job.result(timeout=120)
            return job.num_dml_affected_rows or 0
        except Exception as exc:
            self._raise_with_connectivity_hint(exc)

    def process_rule(self, rule: Rule) -> None:
        unique_key = f"{rule.retention_rule_id}|{self.cfg.execution_date.isoformat()}"

        if not self.should_run_today(rule):
            self.task_skipped += 1
            self.insert_task(rule, SKIPPED_FREQUENCY, "NOT_SCHEDULED_TODAY", None, None, None)
            return

        if self.already_processed(unique_key):
            self.task_skipped += 1
            self.insert_task(rule, SKIPPED_ALREADY_SUCCESS, "ALREADY_SUCCESS_OR_RUNNING", None, None, None)
            return

        table_found, missing_reason = self.table_exists(rule.project_id, rule.dataset_name, rule.table_name)
        if not table_found:
            self.task_skipped += 1
            self.insert_task(rule, SKIPPED_TABLE_NOT_FOUND, missing_reason, None, None, None)
            return

        if rule.retention_type == "COLUMN_AGE":
            if not rule.retention_column or not self.column_exists(rule.project_id, rule.dataset_name, rule.table_name, rule.retention_column):
                self.task_skipped += 1
                self.insert_task(rule, SKIPPED_COLUMN_NOT_FOUND, "RETENTION_COLUMN_NOT_FOUND", None, None, None)
                return

        where_clause = self.build_where_clause(rule)
        if not where_clause:
            status = SKIPPED_NOT_IMPLEMENTED if rule.retention_type not in {"COLUMN_AGE", "CUSTOM_SQL"} else SKIPPED_VALIDATION
            self.task_skipped += 1
            self.insert_task(rule, status, "WHERE_CLAUSE_NOT_AVAILABLE", None, None, None)
            return

        delete_sql = f"DELETE FROM `{rule.project_id}.{rule.dataset_name}.{rule.table_name}` WHERE {where_clause}"

        if self.cfg.dry_run:
            self.task_success += 1
            self.insert_task(rule, SUCCESS, "DRY_RUN_NO_DELETE", delete_sql, None, 0)
            return

        try:
            affected = self.execute_delete(rule, where_clause)
            self.task_success += 1
            self.insert_task(rule, SUCCESS, "DELETE_EXECUTED", delete_sql, None, affected)
        except Exception as exc:
            self.task_failed += 1
            self.insert_task(rule, FAILED, "DELETE_FAILED", delete_sql, str(exc), None)

    def run(self) -> int:
        logging.info("Starting run_id=%s execution_date=%s dry_run=%s", self.run_id, self.cfg.execution_date, self.cfg.dry_run)
        run_row_created = False

        try:
            self.create_run()
            run_row_created = True

            if any([
                self.cfg.filter_rule_id,
                self.cfg.filter_target_project,
                self.cfg.filter_target_dataset,
                self.cfg.filter_target_table,
            ]):
                logging.info(
                    "Rule filter enabled rule_id=%s target=%s.%s.%s",
                    self.cfg.filter_rule_id,
                    self.cfg.filter_target_project,
                    self.cfg.filter_target_dataset,
                    self.cfg.filter_target_table,
                )
            else:
                logging.info("Rule filter disabled; loading full active set from retention table")

            rules = self.load_rules()
            logging.info("Loaded %d active rules", len(rules))

            for idx, rule in enumerate(rules, start=1):
                logging.info("Processing %d/%d rule_id=%s", idx, len(rules), rule.retention_rule_id)
                self.process_rule(rule)

            if self.task_failed == 0:
                final_status = SUCCESS
            elif self.task_success > 0 or self.task_skipped > 0:
                final_status = PARTIAL_SUCCESS
            else:
                final_status = FAILED

            self.close_run(final_status, None)
            logging.info(
                "Run finished status=%s success=%d skipped=%d failed=%d",
                final_status,
                self.task_success,
                self.task_skipped,
                self.task_failed,
            )
            return 0 if final_status in {SUCCESS, PARTIAL_SUCCESS} else 1
        except Exception as exc:
            logging.exception("System failure in run")
            if run_row_created:
                self.close_run(FAILED, str(exc))
            return 2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Retention orchestrator MVP for BigQuery")
    parser.add_argument("--project-id", help="GCP project containing retention metadata dataset")
    parser.add_argument("--credentials-path", help="Optional path to service account JSON key")
    parser.add_argument("--dataset", help="Dataset name with retention tables")
    parser.add_argument("--orchestrator", choices=["TASK_SCHEDULER", "OFLOW", "AIRFLOW"])
    parser.add_argument("--trigger-type", choices=["SCHEDULED", "MANUAL", "RETRY"])
    parser.add_argument("--execution-date", help="Execution date YYYY-MM-DD; default=today")
    parser.add_argument("--weekly-run-day", type=int, help="ISO day for weekly runs: 1=Mon..7=Sun; default=6 (Saturday)")
    parser.add_argument("--max-rules", type=int, help="Optional limit for loaded active rules")
    parser.add_argument("--rule-id", help="Run only one specific retention_rule_id")
    parser.add_argument("--target-project", help="Filter rules by target project_id")
    parser.add_argument("--target-dataset", help="Filter rules by target dataset_name")
    parser.add_argument("--target-table", help="Filter rules by target table_name")
    parser.add_argument("--dry-run", action="store_true", help="Do not execute DELETE statements")
    parser.add_argument("--log-level", choices=["DEBUG", "INFO", "WARNING", "ERROR"])
    return parser.parse_args()


def build_config(args: argparse.Namespace) -> Config:
    execution_date_raw = env_or_arg(args.execution_date, "RETENTION_EXECUTION_DATE")
    if execution_date_raw:
        execution_date = dt.date.fromisoformat(execution_date_raw)
    else:
        execution_date = dt.date.today()

    project_id = env_or_arg(args.project_id, "RETENTION_PROJECT_ID")
    if not project_id:
        raise ValueError("project-id is required via --project-id or RETENTION_PROJECT_ID in .env")

    dataset = env_or_arg(args.dataset, "RETENTION_METADATA_DATASET", "opr_data")
    orchestrator = env_or_arg(args.orchestrator, "RETENTION_ORCHESTRATOR", "TASK_SCHEDULER")
    trigger_type = env_or_arg(args.trigger_type, "RETENTION_TRIGGER_TYPE", "MANUAL")

    weekly_run_day = args.weekly_run_day if args.weekly_run_day is not None else parse_env_int("RETENTION_WEEKLY_RUN_DAY", 6)
    if weekly_run_day is None:
        weekly_run_day = 6

    max_rules = args.max_rules if args.max_rules is not None else parse_env_int("RETENTION_MAX_RULES", None)

    dry_run = args.dry_run or parse_env_bool("RETENTION_DRY_RUN", False)

    filter_rule_id = env_or_arg(args.rule_id, "RETENTION_RULE_ID")
    filter_target_project = env_or_arg(args.target_project, "RETENTION_TARGET_PROJECT")
    filter_target_dataset = env_or_arg(args.target_dataset, "RETENTION_TARGET_DATASET")
    filter_target_table = env_or_arg(args.target_table, "RETENTION_TARGET_TABLE")

    if weekly_run_day < 1 or weekly_run_day > 7:
        raise ValueError("weekly-run-day must be in range 1..7")

    return Config(
        project_id=project_id,
        dataset=dataset,
        orchestrator=orchestrator,
        trigger_type=trigger_type,
        dry_run=dry_run,
        execution_date=execution_date,
        weekly_run_day=weekly_run_day,
        max_rules=max_rules,
        filter_rule_id=filter_rule_id,
        filter_target_project=filter_target_project,
        filter_target_dataset=filter_target_dataset,
        filter_target_table=filter_target_table,
    )


def configure_auth(args: argparse.Namespace) -> None:
    load_dotenv()

    # Prefer OS trust store when available (helps in corporate TLS inspection environments).
    if truststore is not None:
        truststore.inject_into_ssl()
        logging.info("Enabled OS trust store via truststore module")

    if args.credentials_path:
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = args.credentials_path

    credentials_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if credentials_path:
        logging.info("Using service account credentials from GOOGLE_APPLICATION_CREDENTIALS=%s", credentials_path)
    else:
        logging.warning(
            "GOOGLE_APPLICATION_CREDENTIALS is not set. Falling back to default ADC resolution. "
            "For simple setup, define GOOGLE_APPLICATION_CREDENTIALS in .env."
        )


def main() -> int:
    args = parse_args()
    log_level = env_or_arg(args.log_level, "RETENTION_LOG_LEVEL", "INFO")
    logging.basicConfig(
        level=getattr(logging, (log_level or "INFO").upper()),
        format="%(asctime)s %(levelname)s %(message)s",
    )
    configure_auth(args)

    cfg = build_config(args)
    client = bigquery.Client(project=cfg.project_id)
    orchestrator = RetentionOrchestrator(client, cfg)
    return orchestrator.run()


if __name__ == "__main__":
    sys.exit(main())
