# BigQuery monitoring v Looker Studiu – aktuální stav a roadmapa

**Stav:** 12. 8. 2026  
**Testovací monitoring prostředí:** `o2czed1.opr_data`  
**Region:** `europe-west4`  
**Časová zóna pro denní reporting:** `Europe/Prague`

---

## 1. Cíl

Cílem je vytvořit v Looker Studiu managementový a provozní přehled BigQuery, který bude postupně nahrazovat / doplňovat obdobné metriky dnes reportované v Teradata Monthly Service Review.

Základní princip:

```text
BigQuery INFORMATION_SCHEMA
        │
        ├── aktuální stav → VIEW → Looker Studio
        │
        └── historický stav → Scheduled Query → snapshot tabulka → Looker Studio
```

Používané projekty:

| Účel | Projekt |
|---|---|
| Produkční data / storage | `o2czep` |
| Produkční load / technický workload | `o2cz-dp-wm-100` |
| Business interaktivní workload | `o2czdb` |
| Testovací monitoring objekty | `o2czed1.opr_data` |

---

# 2. Co máme aktuálně hotové

## 2.1 Looker Studio stránky

### Stránka 1 – BigQuery Storage Overview O2CZEP

Aktuálně obsahuje:

- Logical storage
- Physical storage
- Storage podle datasetu

Zdroj:
- `v_bq_current_storage`
- případně snapshot tabulka pro poslední dostupný den

### Stránka 2 – BigQuery Storage Growth

Historický vývoj storage v čase.

Zdroj:

```text
o2czed1.opr_data.bq_storage_daily_snapshot
```

Typické metriky:

- `logical_tb`
- `physical_tb`
- `table_count`

Typický filtr:

```text
dataset_name = stg_data
```

### Stránka 3 – BigQuery Source Overview – stg_data

Aktuálně obsahuje:

- počet zdrojových systémů,
- počet tabulek podle zdroje,
- zdroj je odvozen z prefixu názvu tabulky před prvním `_`.

Zdroj:

```text
v_bq_tables_by_source
```

Na stránce je napevno aplikovaný filtr:

```text
dataset_name = stg_data
```

### Stránka 4 – BigQuery Production Load – WM100

Managementově zjednodušený produkční workload.

Aktuálně obsahuje:

- Total Jobs
- Processed TB
- Failed Jobs
- Production Jobs by Day

Zdroj:

```text
v_bq_prod_jobs_daily
```

Compute projekt:

```text
o2cz-dp-wm-100
```

### Stránka 5 – BigQuery Business Usage – O2CZDB, D-7

Aktuálně obsahuje:

- Total Business Queries
- Unique Users
- Processed Data GB
- Top Users by Query Count

Zdroj:

```text
v_bq_jobs_last_7d_users
```

Compute projekt:

```text
o2czdb
```

---

# 3. Aktuálně vytvořené VIEW

V `o2czed1.opr_data` jsou aktuálně vytvořené tyto objekty:

```text
v_bq_current_storage
v_bq_jobs_last_7d_users
v_bq_prod_jobs_daily
v_bq_prod_load_daily
v_bq_slot_usage
v_bq_tables_by_source
v_bq_tables_storage
```

Níže jsou doporučené definice pro uchování / přenos do produkce.

> **Poznámka k produkci:** při nasazení bude typicky stačit změnit cílový dataset  
> `o2czed1.opr_data` → `o2czep.opr_data`
>
> Zdrojové reference jako `o2czep.region-europe-west4`, `o2czdb.region-europe-west4` a `o2cz-dp-wm-100.region-europe-west4` se nemění.

---

# 4. CREATE VIEW – SQL definice

## 4.1 `v_bq_current_storage`

Účel: aktuální storage za jednotlivé datasety projektu `o2czep`, pouze pro aktuálně existující tabulky.

```sql
CREATE OR REPLACE VIEW
  `o2czed1.opr_data.v_bq_current_storage`
OPTIONS (
  description = 'Aktuální velikost datasetů v projektu o2czep. Zobrazuje pouze aktuálně existující tabulky a obsahuje logical storage, physical storage a počet tabulek za jednotlivé datasety.'
)
AS
SELECT
  s.table_schema AS dataset_name,
  SUM(s.total_logical_bytes) AS logical_bytes,
  SUM(s.total_physical_bytes) AS physical_bytes,
  ROUND(SUM(s.total_logical_bytes) / POW(1024, 4), 2) AS logical_tb,
  ROUND(SUM(s.total_physical_bytes) / POW(1024, 4), 2) AS physical_tb,
  COUNT(*) AS table_count
FROM
  `o2czep.region-europe-west4`.INFORMATION_SCHEMA.TABLE_STORAGE AS s
INNER JOIN
  `o2czep.region-europe-west4`.INFORMATION_SCHEMA.TABLES AS t
ON
  s.table_catalog = t.table_catalog
  AND s.table_schema = t.table_schema
  AND s.table_name = t.table_name
GROUP BY
  s.table_schema;
```

## 4.2 `v_bq_tables_storage`

Účel: detail aktuálně existujících tabulek a jejich velikostí.

```sql
CREATE OR REPLACE VIEW
  `o2czed1.opr_data.v_bq_tables_storage`
OPTIONS (
  description = 'Přehled aktuálně existujících tabulek v projektu o2czep včetně datasetu, logical storage a physical storage. Pohled lze použít pro analýzu největších tabulek a filtrování podle datasetu.'
)
AS
SELECT
  s.table_schema AS dataset_name,
  s.table_name,
  s.total_logical_bytes AS logical_bytes,
  s.total_physical_bytes AS physical_bytes,
  ROUND(s.total_logical_bytes / POW(1024, 3), 2) AS logical_gb,
  ROUND(s.total_physical_bytes / POW(1024, 3), 2) AS physical_gb
FROM
  `o2czep.region-europe-west4`.INFORMATION_SCHEMA.TABLE_STORAGE AS s
INNER JOIN
  `o2czep.region-europe-west4`.INFORMATION_SCHEMA.TABLES AS t
ON
  s.table_catalog = t.table_catalog
  AND s.table_schema = t.table_schema
  AND s.table_name = t.table_name;
```

**Poznámka:** view dnes není nutné pro hlavní management dashboard, ale je vhodné jako technický detail pro TOP největší tabulky.

## 4.3 `v_bq_tables_by_source`

Účel: počet tabulek podle zdrojového systému.

```sql
CREATE OR REPLACE VIEW
  `o2czed1.opr_data.v_bq_tables_by_source`
OPTIONS (
  description = 'Přehled počtu aktuálně existujících tabulek v projektu o2czep podle datasetu a zdrojového systému. Zdrojový systém je odvozen z prefixu názvu tabulky před prvním znakem "_".'
)
AS
SELECT
  s.table_schema AS dataset_name,
  SPLIT(s.table_name, '_')[SAFE_OFFSET(0)] AS source_name,
  COUNT(*) AS table_count
FROM
  `o2czep.region-europe-west4`.INFORMATION_SCHEMA.TABLE_STORAGE AS s
INNER JOIN
  `o2czep.region-europe-west4`.INFORMATION_SCHEMA.TABLES AS t
ON
  s.table_catalog = t.table_catalog
  AND s.table_schema = t.table_schema
  AND s.table_name = t.table_name
GROUP BY
  s.table_schema,
  source_name;
```

Příklad filtru v Looker Studiu:

```text
dataset_name = stg_data
```

## 4.4 `v_bq_slot_usage`

Účel: technický pohled na spotřebu slotů v produkčním compute projektu.

```sql
CREATE OR REPLACE VIEW
  `o2czed1.opr_data.v_bq_slot_usage`
OPTIONS (
  description = 'Technický časový přehled využití BigQuery slotů v compute projektu o2cz-dp-wm-100. Data jsou agregována do pětiminutových intervalů a slouží pro detailní provozní analýzu, nikoliv jako hlavní management KPI.'
)
AS
SELECT
  TIMESTAMP_SECONDS(
    DIV(UNIX_SECONDS(period_start), 300) * 300
  ) AS time_5min,

  ROUND(
    SUM(period_slot_ms) / 1000 / 300,
    2
  ) AS avg_slots

FROM
  `o2cz-dp-wm-100.region-europe-west4`
    .INFORMATION_SCHEMA.JOBS_TIMELINE_BY_PROJECT

WHERE
  period_start >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)

GROUP BY
  time_5min;
```

**Poznámka:** slot usage je vhodné ponechat jako technický troubleshooting pohled. Pro management se ukázalo být obtížně interpretovatelné bez znalosti celkové reservation capacity.

## 4.5 `v_bq_prod_load_daily`

Účel: denní technický pohled na produkční load – sloty a concurrency.

Doporučená definice používá sekundovou granularitu `JOBS_TIMELINE_BY_PROJECT`, ze které se následně vytvoří denní agregace.

```sql
CREATE OR REPLACE VIEW
  `o2czed1.opr_data.v_bq_prod_load_daily`
OPTIONS (
  description = 'Denní technický přehled produkčního BigQuery workloadu v compute projektu o2cz-dp-wm-100. Obsahuje průměrné a špičkové využití slotů a maximální počet současně běžících a čekajících jobů za den.'
)
AS

WITH per_second AS (
  SELECT
    period_start,

    SUM(period_slot_ms) / 1000 AS slots_used,

    COUNTIF(state = 'RUNNING') AS running_jobs,

    COUNTIF(state = 'PENDING') AS pending_jobs

  FROM
    `o2cz-dp-wm-100.region-europe-west4`
      .INFORMATION_SCHEMA.JOBS_TIMELINE_BY_PROJECT

  WHERE
    period_start >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)

  GROUP BY
    period_start
)

SELECT
  DATE(period_start, 'Europe/Prague') AS load_date,

  ROUND(AVG(slots_used), 2) AS avg_slots,

  ROUND(MAX(slots_used), 2) AS peak_slots,

  MAX(running_jobs) AS peak_running_jobs,

  MAX(pending_jobs) AS peak_pending_jobs

FROM
  per_second

GROUP BY
  load_date
ORDER BY
  load_date;
```

**Interpretace:**

- `avg_slots` – průměrné využití slotů za den.
- `peak_slots` – nejvyšší využití slotů v jedné sekundě.
- `peak_running_jobs` – nejvyšší počet současně běžících jobů.
- `peak_pending_jobs` – nejvyšší počet současně čekajících jobů.

**Poznámka:** pro management jsme nakonec zvolili jednodušší `v_bq_prod_jobs_daily`.

## 4.6 `v_bq_prod_jobs_daily`

Účel: managementově čitelný produkční workload.

```sql
CREATE OR REPLACE VIEW
  `o2czed1.opr_data.v_bq_prod_jobs_daily`
OPTIONS (
  description = 'Denní přehled produkčních BigQuery jobů v compute projektu o2cz-dp-wm-100. Obsahuje počet všech, úspěšných a chybových jobů a objem zpracovaných dat. Slouží jako jednoduchý management přehled produkčního workloadu.'
)
AS

SELECT
  DATE(creation_time, 'Europe/Prague') AS job_date,

  COUNT(*) AS total_jobs,

  COUNTIF(
    state = 'DONE'
    AND error_result IS NULL
  ) AS successful_jobs,

  COUNTIF(
    state = 'DONE'
    AND error_result IS NOT NULL
  ) AS failed_jobs,

  ROUND(
    SUM(total_bytes_processed) / POW(1024, 4),
    2
  ) AS processed_tb

FROM
  `o2cz-dp-wm-100.region-europe-west4`
    .INFORMATION_SCHEMA.JOBS_BY_PROJECT

WHERE
  creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)

GROUP BY
  job_date;
```

Aktuální využití v Looker Studiu:

- Total Jobs
- Processed TB
- Failed Jobs
- Production Jobs by Day

## 4.7 `v_bq_jobs_last_7d_users`

Účel: business usage z compute projektu `o2czdb`.

```sql
CREATE OR REPLACE VIEW
  `o2czed1.opr_data.v_bq_jobs_last_7d_users`
OPTIONS (
  description = 'Přehled BigQuery jobů za posledních 7 dní v business compute projektu o2czdb. Obsahuje uživatele, časy jobu, délku běhu, stav, množství zpracovaných dat, spotřebu slotů a informaci o chybě. Slouží jako zdroj pro monitoring business usage v Looker Studiu.'
)
AS

SELECT
  job_id,
  user_email,
  creation_time,
  start_time,
  end_time,

  DATE(creation_time, 'Europe/Prague') AS job_date,

  state,

  CASE
    WHEN state = 'DONE' AND error_result IS NULL THEN 'SUCCESS'
    WHEN state = 'DONE' AND error_result IS NOT NULL THEN 'FAILED'
    ELSE state
  END AS job_status,

  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_seconds,

  job_type,
  statement_type,

  total_bytes_processed,

  ROUND(
    total_bytes_processed / POW(1024, 3),
    2
  ) AS processed_gb,

  total_slot_ms,

  ROUND(
    total_slot_ms / 1000,
    2
  ) AS slot_seconds,

  error_result

FROM
  `o2czdb.region-europe-west4`.INFORMATION_SCHEMA.JOBS_BY_PROJECT

WHERE
  creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY);
```

### Důležitá poznámka

Současná logika zahrnuje všechny typy jobů.

Pokud má KPI **Total Business Queries** znamenat skutečně pouze SQL query joby, doporučuji do produkční verze zvážit:

```sql
AND job_type = 'QUERY'
```

Je potřeba nejprve ověřit, zda chceme reportovat:

1. všechny business joby, nebo
2. pouze query joby.

---

# 5. Supporting objekt – denní storage snapshot

Tato tabulka není mezi sedmi views, ale je zásadní pro historický vývoj storage.

## 5.1 Tabulka

```sql
CREATE TABLE IF NOT EXISTS
  `o2czed1.opr_data.bq_storage_daily_snapshot`
(
  snapshot_date DATE,
  snapshot_dttm TIMESTAMP,
  project_id STRING,
  dataset_name STRING,
  logical_bytes INT64,
  physical_bytes INT64,
  logical_tb FLOAT64,
  physical_tb FLOAT64,
  table_count INT64
)
PARTITION BY snapshot_date
OPTIONS (
  description = 'Denní snapshot velikosti datasetů v projektu o2czep. Obsahuje pouze aktuálně existující tabulky. Slouží pro sledování historického vývoje logical storage, physical storage a počtu tabulek v Looker Studiu.'
);
```

## 5.2 Scheduled Query – denní naplnění

```sql
DELETE FROM
  `o2czed1.opr_data.bq_storage_daily_snapshot`
WHERE
  snapshot_date = CURRENT_DATE('Europe/Prague');


INSERT INTO
  `o2czed1.opr_data.bq_storage_daily_snapshot`
(
  snapshot_date,
  snapshot_dttm,
  project_id,
  dataset_name,
  logical_bytes,
  physical_bytes,
  logical_tb,
  physical_tb,
  table_count
)

SELECT
  CURRENT_DATE('Europe/Prague') AS snapshot_date,
  CURRENT_TIMESTAMP() AS snapshot_dttm,
  'o2czep' AS project_id,

  s.table_schema AS dataset_name,

  SUM(s.total_logical_bytes) AS logical_bytes,
  SUM(s.total_physical_bytes) AS physical_bytes,

  ROUND(
    SUM(s.total_logical_bytes) / POW(1024, 4),
    4
  ) AS logical_tb,

  ROUND(
    SUM(s.total_physical_bytes) / POW(1024, 4),
    4
  ) AS physical_tb,

  COUNT(*) AS table_count

FROM
  `o2czep.region-europe-west4`.INFORMATION_SCHEMA.TABLE_STORAGE AS s

INNER JOIN
  `o2czep.region-europe-west4`.INFORMATION_SCHEMA.TABLES AS t
ON
  s.table_catalog = t.table_catalog
  AND s.table_schema = t.table_schema
  AND s.table_name = t.table_name

GROUP BY
  s.table_schema;
```

Scheduled Query:

```text
Name: BQ Storage Daily Snapshot
Frequency: Daily
Target: stejná tabulka bq_storage_daily_snapshot
```

Destination table se v nastavení Scheduled Query nepoužívá, protože cíl je definovaný přímo v SQL přes `DELETE + INSERT`.

---

# 6. Přenos do produkce – checklist

Před nasazením views z ED1 do produkce:

1. Změnit cílové view:
   ```text
   o2czed1.opr_data
   ```
   na:
   ```text
   o2czep.opr_data
   ```

2. Ověřit region:
   ```text
   europe-west4
   ```

3. Ověřit oprávnění produkčního projektu / identity k:
   - `o2czep.region-europe-west4.INFORMATION_SCHEMA.*`
   - `o2cz-dp-wm-100.region-europe-west4.INFORMATION_SCHEMA.*`
   - `o2czdb.region-europe-west4.INFORMATION_SCHEMA.*`

4. Ověřit, zda mají business KPI počítat:
   - všechny joby,
   - nebo pouze `job_type = 'QUERY'`.

5. Ověřit účet, pod kterým poběží Scheduled Query.

6. U snapshot tabulky zachovat:
   ```text
   PARTITION BY snapshot_date
   ```

7. Po nasazení přepojit Looker Studio datasource z ED1 na produkční objekty.

---

# 7. Teradata Monthly Service Review – co je dnes reportováno

V Teradata Monthly Service Review jsou mezi hlavními provozními tématy:

- Capacity / PERM Space
- Performance / Busy %
- CPU & IO
- Bad Query Identification
- ETL Load Duration & Delay
- Number of Delayed Loads
- Number of loaded extracts
- Number of ETL load jobs
- Aborted Query Count by Workload
- CPU heatmap
- IO heatmap
- workload CPU / IO profiles
- spotřeba CPU / IO podle aplikace
- spotřeba CPU / IO podle jednotlivých uživatelů
- provozní SLA / KPI / incidenty / deploymenty

V červencovém Teradata MSR jsou například uvedeny:

- Capacity: 69 % average
- Performance: 72 % busy v business okně 08:00–17:00
- CPU & IO: normal state
- Bad Query Identification: seznam worst performing queries týdně
- ETL: sledování délky a zpoždění loadu
- samostatný trend denního počtu ETL jobů
- samostatné grafy aborted queries podle workloadu
- detailní CPU a IO load profily

---

# 8. Teradata vs BigQuery – doporučená obdoba

BigQuery je serverless, proto není vhodné kopírovat Teradata CPU/IO metriky 1:1.

Doporučené mapování:

| Teradata | BigQuery obdoba | BQ zdroj | Stav |
|---|---|---|---|
| DB Perm Space / Capacity | Logical + Physical Storage | `TABLE_STORAGE` | **HOTOVO** |
| Capacity history | Storage Growth | daily snapshot | **HOTOVO** |
| Number of ETL jobs | Production Jobs by Day | WM100 `JOBS_BY_PROJECT` | **HOTOVO** |
| Workload volume | Processed TB | `total_bytes_processed` | **HOTOVO** |
| Failed / Aborted queries | Failed Jobs / Failed Queries | `error_result` | **ČÁSTEČNĚ** |
| CPU | Slot consumption / slot utilization | `total_slot_ms`, `JOBS_TIMELINE` | **TECHNICKÝ POHLED HOTOV** |
| IO | Bytes processed / billed, případně shuffle | `JOBS_BY_PROJECT` | **ČÁSTEČNĚ** |
| Busy % | Compute Capacity Utilization % | slots vs reservation capacity | **TODO** |
| Bad Query Identification | Top expensive / long queries | duration, bytes, slots | **TODO** |
| ETL Load Duration | Production job / load duration | start/end time | **TODO** |
| Delayed Loads | Loads mimo SLA / expected window | BQ + scheduler metadata | **TODO – potřebuje pravidla SLA** |
| CPU/IO by user | Slots + processed bytes by user | O2CZDB jobs | **ČÁSTEČNĚ HOTOVO** |
| CPU/IO by workload | Slots + processed bytes by project/workload | JOBS views | **TODO / lze doplnit** |
| CPU heatmap | Slot utilization heatmap | JOBS_TIMELINE | **TODO – technical** |
| IO heatmap | Processed bytes heatmap | JOBS_BY_PROJECT | **TODO – technical** |
| Incidents / deployments | externí provozní zdroj | Jira / Oflow / Git / monitoring | **MIMO BQ METADATA** |

---

# 9. Co bychom měli doplnit jako další

## PRIORITA 1 – Query Performance / Bad Queries

Toto je nejbližší obdoba Teradata „Bad Query Identification“.

Doporučená stránka:

```text
BigQuery Query Performance – D-7
```

KPI:

- Average Query Duration
- Max Query Duration
- Failed Queries
- Processed TB

Grafy / tabulky:

- Top 10 Longest Queries
- Top 10 Queries by Processed Data
- Top 10 Queries by Slot Consumption
- Top users by processed data
- Top users by slot consumption

Možný nový view:

```text
v_bq_query_performance_7d
```

## PRIORITA 2 – Errors & Reliability

Doporučená stránka:

```text
BigQuery Errors & Reliability
```

KPI:

- Total Queries
- Failed Queries
- Failure Rate %
- Successful Queries

Grafy:

- Failed Queries by Day
- Top Error Reasons
- Failed Queries by User
- Failed Queries by Statement Type

Zdroj:

```text
error_result
```

## PRIORITA 3 – Business Usage

Aktuální stránku dále rozšířit o:

- Queries by Day
- Processed Data by Day
- Top Users by Processed Data
- Top Users by Slot Consumption

Management otázky:

- Kolik business uživatelů BQ používá?
- Kolik query spouští?
- Kolik dat zpracovávají?
- Kdo jsou největší konzumenti?

## PRIORITA 4 – Compute Capacity Utilization %

Toto je nejbližší obdoba Teradata `Busy %`.

Cíl:

```text
Average Compute Utilization: xx %
Peak Compute Utilization: xx %
```

Pro výpočet je potřeba doplnit:

- dostupnou slot reservation capacity,
- případný autoscaling,
- assignment projektu do reservation.

Potenciální zdroje:

```text
INFORMATION_SCHEMA.RESERVATIONS*
INFORMATION_SCHEMA.ASSIGNMENTS*
INFORMATION_SCHEMA.JOBS_TIMELINE*
```

Teprve porovnání skutečně využitých slotů s dostupnou kapacitou dá managementově srozumitelnou hodnotu v procentech.

## PRIORITA 5 – Production Load Duration / SLA

Teradata dnes sleduje:

- L0 + L1 load duration,
- L2 duration,
- delayed loads,
- loady mimo očekávané D-x okno.

V BigQuery lze z job metadata získat:

```text
start_time
end_time
duration
```

Samotné BigQuery ale neví, kdy **měl konkrétní business load doběhnout**.

Pro přesnou SLA obdobu bude potřeba propojit:

```text
BigQuery JOBS
+
Oflow / scheduler metadata
+
očekávaný load window / SLA
```

Pak lze vytvořit:

- Avg Load Duration
- Max Load Duration
- Delayed Loads
- Loads Out of SLA
- SLA Success Rate %

---

# 10. Doporučená cílová struktura Looker Studio

## Management stránky

### 1. BigQuery Storage Overview
- Logical Storage
- Physical Storage
- Table Count
- Storage by Dataset

### 2. BigQuery Storage Growth
- Logical TB over time
- Physical TB over time
- Table Count over time

### 3. BigQuery Source Overview – stg_data
- Number of Sources
- Number of Tables
- Tables by Source

### 4. BigQuery Production Load – WM100
- Total Jobs
- Processed TB
- Failed Jobs
- Production Jobs by Day

### 5. BigQuery Business Usage – O2CZDB
- Total Queries
- Unique Users
- Processed Data
- Top Users
- Queries by Day
- Processed Data by Day

### 6. BigQuery Query Performance
- Avg Query Duration
- Max Query Duration
- Failed Queries
- Top longest queries
- Top expensive queries

### 7. BigQuery Compute Capacity
- Average Compute Utilization %
- Peak Compute Utilization %
- případně capacity threshold

## Technické / Operations stránky

Volitelně oddělit od management reportu:

### Technical Performance
- Slot usage
- Peak slots
- Running jobs
- Pending jobs
- concurrency
- heatmap podle hodin

### Errors
- Failed jobs
- Error reason
- Error message
- user
- statement type

---

# 11. Doporučení k objektům

Ne všech sedm současných views musí být dlouhodobě prezentováno přímo managementu.

Doporučené rozdělení:

### Management

```text
v_bq_current_storage
v_bq_prod_jobs_daily
v_bq_jobs_last_7d_users
v_bq_tables_by_source
bq_storage_daily_snapshot
```

### Technical / Operations

```text
v_bq_slot_usage
v_bq_prod_load_daily
v_bq_tables_storage
```

Tím zůstane dashboard managementově jednoduchý, ale současně budou dostupná detailní data pro troubleshooting.

---

# 12. Další navrhované VIEW

Postupně lze přidat:

```text
v_bq_query_performance_7d
v_bq_errors_daily
v_bq_business_usage_daily
v_bq_reservation_utilization_daily
v_bq_load_sla_daily
```

`v_bq_load_sla_daily` bude vyžadovat data mimo samotný BigQuery `INFORMATION_SCHEMA`.

---

# 13. Shrnutí

Aktuálně máme postavený základ BigQuery monitoring vrstvy:

- storage,
- storage history,
- zdrojové systémy,
- produkční workload,
- technický slot workload,
- business usage.

Největší další přínos proti dnešnímu Teradata Monthly Service Review bude mít:

1. **Query Performance / Bad Queries**
2. **Errors & Reliability**
3. **Top Users by Processed Data / Slot Usage**
4. **Compute Capacity Utilization %**
5. **Production Load Duration / SLA**

BigQuery nemá být kopie Teradata reportingu 1:1. Pro management je vhodnější převést Teradata CPU / IO pohledy na jednodušší BigQuery metriky:

```text
Capacity       → Storage + Compute Utilization
CPU            → Slot Consumption
IO             → Processed Data
Performance    → Query Duration
Reliability    → Failed Queries / Failure Rate
ETL workload   → Production Jobs / Processed TB / Load Duration
Business usage → Users / Queries / Processed Data / Slots
```
