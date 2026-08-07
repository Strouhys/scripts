import argparse
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

from google.api_core.exceptions import NotFound, ServiceUnavailable, TooManyRequests
from google.api_core.retry import Retry
from google.cloud import bigquery


DEFAULT_PROJECT_ID = os.getenv("BQ_PROJECT_ID", "o2czed1")
DEFAULT_DATASET_ID = os.getenv("BQ_DATASET_ID", "stg_lnd")
DEFAULT_LOCATION = os.getenv("BQ_LOCATION", "europe-west4")
DEFAULT_MAX_WORKERS = int(os.getenv("BQ_MAX_WORKERS", "20"))


def build_table_query(project_id: str, location: str) -> str:
    return f"""
SELECT
  s.table_catalog,
  s.table_schema,
  s.table_name
FROM `{project_id}.region-{location}`.INFORMATION_SCHEMA.TABLE_STORAGE AS s
JOIN `{project_id}.region-{location}`.INFORMATION_SCHEMA.TABLES AS t
  ON s.table_catalog = t.table_catalog
 AND s.table_schema = t.table_schema
 AND s.table_name = t.table_name
WHERE s.table_schema = @dataset_id
  AND t.table_type = 'BASE TABLE'
  AND REGEXP_CONTAINS(s.table_name, r'__dq10000__[0-9]+$')
  AND s.total_rows = 0
"""


def fetch_table_ids(
    client: bigquery.Client,
    query: str,
    dataset_id: str,
    query_timeout_seconds: int,
) -> list[str]:
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("dataset_id", "STRING", dataset_id)
        ]
    )
    query_job = client.query(query, job_config=job_config)
    rows = list(query_job.result(timeout=query_timeout_seconds))
    return [f"{row.table_catalog}.{row.table_schema}.{row.table_name}" for row in rows]


def delete_table(
    client: bigquery.Client,
    table_id: str,
    retry: Retry,
) -> tuple[str, str]:
    try:
        client.delete_table(table_id, not_found_ok=True, retry=retry)
        return table_id, "DELETED"
    except NotFound:
        return table_id, "NOT_FOUND"
    except Exception as exc:
        return table_id, f"ERROR: {exc}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Najde v datasetu prázdné tabulky odpovídající patternu "
            "__dq10000__[0-9]+ a volitelně je smaže."
        )
    )
    parser.add_argument(
        "--mode",
        choices=["count", "delete"],
        default="count",
        help="count = jen vypsat počet; delete = smazat tabulky",
    )
    parser.add_argument("--project-id", default=DEFAULT_PROJECT_ID)
    parser.add_argument("--dataset-id", default=DEFAULT_DATASET_ID)
    parser.add_argument("--location", default=DEFAULT_LOCATION)
    parser.add_argument("--max-workers", type=int, default=DEFAULT_MAX_WORKERS)
    parser.add_argument(
        "--query-timeout-seconds",
        type=int,
        default=120,
        help="Timeout pro SELECT dotaz v sekundách",
    )
    parser.add_argument(
        "--show-sample",
        type=int,
        default=10,
        help="Kolik prvních nalezených tabulek vypsat v režimu count",
    )
    parser.add_argument(
        "--confirm-delete",
        action="store_true",
        help="Povinné potvrzení pro mode=delete",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    client = bigquery.Client(project=args.project_id, location=args.location)
    query = build_table_query(args.project_id, args.location)

    print(
        "Spouštím SELECT nad INFORMATION_SCHEMA "
        f"(project={args.project_id}, dataset={args.dataset_id}, location={args.location})..."
    )
    table_ids = fetch_table_ids(
        client,
        query,
        args.dataset_id,
        args.query_timeout_seconds,
    )
    print(f"Nalezeno tabulek: {len(table_ids)}")

    if args.mode == "count":
        sample = table_ids[: max(args.show_sample, 0)]
        if sample:
            print("Ukázka nalezených tabulek:")
            for table_id in sample:
                print(f"- {table_id}")
        print("Režim count dokončen. Nic se nemaže.")
        return

    if not args.confirm_delete:
        raise SystemExit(
            "Pro mazání použij --mode delete --confirm-delete "
            "(bez potvrzení se nic nemaže)."
        )

    retry = Retry(
        predicate=lambda exc: isinstance(exc, (TooManyRequests, ServiceUnavailable)),
        initial=1.0,
        maximum=30.0,
        multiplier=2.0,
        deadline=300.0,
    )

    deleted = 0
    failed = 0

    with ThreadPoolExecutor(max_workers=args.max_workers) as executor:
        futures = {
            executor.submit(delete_table, client, table_id, retry): table_id
            for table_id in table_ids
        }

        for number, future in enumerate(as_completed(futures), start=1):
            table_id, status = future.result()

            if status in ("DELETED", "NOT_FOUND"):
                deleted += 1
            else:
                failed += 1
                print(f"{table_id}: {status}")

            if number % 500 == 0:
                print(
                    f"Zpracováno {number}/{len(table_ids)}, "
                    f"úspěšně {deleted}, chyby {failed}"
                )

    print(f"Hotovo. Úspěšně: {deleted}, chyby: {failed}")


if __name__ == "__main__":
    main()