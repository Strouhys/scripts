import os

from google.cloud import bigquery
from dotenv import load_dotenv

try:
  import truststore
except Exception:
  truststore = None

load_dotenv()
if truststore is not None:
  truststore.inject_into_ssl()

client = bigquery.Client(project="o2czed1")
sql = """
SELECT
  execution_date,
  retention_rule_id,
  status,
  status_reason,
  error_message,
  generated_sql,
  affected_rows
FROM `o2czed1.opr_data.retention_task_run`
WHERE retention_rule_id = 'TD_AP_STG_EBOX_VIEWS_V2_00003'
ORDER BY created_dttm DESC
LIMIT 1
"""
rows = list(client.query(sql).result())
row = rows[0]
with open(r"C:\Users\x0577063\scripts\work\Retence BQ\tmp_last_task_output.txt", "w", encoding="utf-8") as handle:
  handle.write(str(dict(row.items())))
print("WROTE tmp_last_task_output.txt")
