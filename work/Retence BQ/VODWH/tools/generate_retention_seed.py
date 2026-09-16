"""One-off generator: builds retention_seed_vodwh.sql INSERT statements
from 'vodwh retence teradata.csv' (semicolon separated Teradata export).

Usage:
    python generate_retention_seed.py
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "vodwh retence teradata.csv"
OUT_PATH = ROOT / "sql" / "retention_seed_vodwh.sql"

PROJECT_ID = "o2czvd1"
METADATA_DATASET = "opr_data"  # holds table_retention / audit tables
BQ_DATASET_NAME = "stg_data"  # holds the actual VP_STG target tables (e.g. VPOB_X_CHARGED_USAGE)
CREATED_BY = "migration_vodwh_retence_teradata_csv"


def sql_str(value):
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "\\'") + "'"


def sql_int(value):
    if value is None or value == "":
        return "NULL"
    return str(int(value))


def build_bq_where(column: str, value: int) -> str:
    return f"{column} < TIMESTAMP_SUB(TIMESTAMP(@retention_reference_dttm), INTERVAL {value} DAY)"


def main() -> None:
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh, delimiter=";", quotechar='"')
        rows = list(reader)

    values_sql = []
    for idx, row in enumerate(rows, start=1):
        database_name = row["database_name"].strip()
        table_name = row["table_name"].strip()
        is_active = row["is_active"].strip() == "1"
        frequency = row["execution_frequency"].strip()
        source_where = row["execution_where_clause"].strip()
        real_window = int(row["real_window"].strip())
        comment = row["retention_comment"].strip()

        execution_day_of_week = 6 if frequency == "W" else None
        rule_id = f"TD_{database_name}_{table_name}_{idx:05d}"
        bq_where = build_bq_where("loaded_dttm", real_window)

        values_sql.append(
            "(" + ", ".join([
                sql_str(rule_id),
                sql_str(PROJECT_ID),
                sql_str(database_name),
                sql_str(BQ_DATASET_NAME),
                sql_str(table_name),
                "TRUE" if is_active else "FALSE",
                sql_str(frequency),
                sql_int(execution_day_of_week),
                "NULL",
                sql_str("COLUMN_AGE"),
                sql_str("loaded_dttm"),
                sql_int(real_window),
                sql_str("DAY"),
                sql_str("TIMESTAMP"),
                sql_str(source_where),
                sql_str(bq_where),
                sql_str(comment) if comment else "NULL",
                sql_str(CREATED_BY),
                sql_str(CREATED_BY),
                "TRUE" if is_active else "FALSE",
            ]) + ")"
        )

    header = f"""-- Generated from 'vodwh retence teradata.csv'
-- Source row count: {len(rows)}
-- Project: {PROJECT_ID}
-- Metadata dataset: {METADATA_DATASET} (table_retention as defined in VODWH/sql/retention_ddl.sql)
-- bq_dataset_name for all rows: {BQ_DATASET_NAME} (actual VP_STG target tables)

INSERT INTO `{PROJECT_ID}.{METADATA_DATASET}.table_retention` (
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
  source_execution_where_clause,
  bq_execution_where_clause,
  retention_comment,
  created_by,
  updated_by,
  td_is_active
)
VALUES
"""

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w", encoding="utf-8") as fh:
        fh.write(header)
        fh.write(",\n".join(values_sql))
        fh.write(";\n")

    print(f"Wrote {len(rows)} rows to {OUT_PATH}")


if __name__ == "__main__":
    main()
