Cíl

Vytvořit v Data Studiu automaticky aktualizovaný přehled o využití BigQuery.

První stránka bude:

01 – BQ Overview

Plánované hlavní KPI:

celková velikost dat
počet tabulek
počet query
počet unikátních uživatelů
objem zpracovaných dat
failed jobs

Později doplníme trendy za posledních 7/30 dní.

Co už máme ověřeno
1. Storage v produkčním projektu o2czep

Používáme:

`o2czep.region-europe-west4`.INFORMATION_SCHEMA.TABLE_STORAGE

Ověřený dotaz:

SELECT
  ROUND(SUM(total_logical_bytes) / POW(1024, 4), 2) AS total_logical_tb,
  ROUND(SUM(total_physical_bytes) / POW(1024, 4), 2) AS total_physical_tb,
  COUNT(*) AS table_count
FROM
  `o2czep.region-europe-west4`.INFORMATION_SCHEMA.TABLE_STORAGE;

Aktuální výsledek:

Logical storage:   5.27 TB
Physical storage:  1.35 TB
Počet tabulek:     49 113

Tyto metriky jsou použitelné pro náš Overview.

Důležité zjištění – Data projekt vs. Compute projekt

o2czep je především datový projekt.

To znamená, že zde mohou fyzicky ležet data:

o2czep.tgt_data
o2czep.stg_data
...

ale business uživatel nemusí query spouštět pod projektem o2czep.

Například:

SELECT *
FROM `o2czep.tgt.customer`;

může fyzicky číst data z o2czep, ale samotný BigQuery job může být spuštěn například pod:

o2cz-edw-wm-business-personal

Proto se query/job objeví v INFORMATION_SCHEMA.JOBS... compute projektu, nikoliv nutně v o2czep.

Compute projekty, o kterých zatím víme

Pro business jsou podle získaných informací určeny minimálně:

o2cz-edw-wm-business-personal

Osobní/interaktivní dotazy business uživatelů.

A:

o2cz-edw-wm-business-technology

Technologické a automatizované business workloady.

Mohou ale existovat ještě další compute projekty.

Co jsme vyzkoušeli v o2czep

Dotaz:

SELECT
  COUNT(*) AS query_count_24h
FROM
  `o2czep.region-europe-west4`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE
  creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND job_type = 'QUERY';

Výsledek:

1 049 query / 24 h

Ale toto číslo zatím nepoužijeme jako celkovou metriku využití BigQuery.

Znamená pouze:

1 049 query bylo za posledních 24 hodin spuštěno s compute projektem o2czep.

Neříká nám to, kolik query business uživatelé provedli nad daty uloženými v o2czep.

Také jsme zkoušeli:

COUNT(DISTINCT user_email)

a objevil ses pouze ty.

To podporuje teorii, že většina workloadu je spuštěna přes jiné compute projekty.

Problém s přístupem

Vyzkoušeli jsme:

`o2cz-edw-wm-business-personal.region-europe-west4`
.INFORMATION_SCHEMA.JOBS_BY_PROJECT

ale dostali jsme:

Access Denied

Aktuálně máš na tomto projektu například:

bigquery.tables.getData

To nestačí pro monitoring všech jobů projektu.

Pro JOBS_BY_PROJECT všech uživatelů potřebujeme zejména:

bigquery.jobs.listAll

Typická IAM role je:

roles/bigquery.resourceViewer

tedy:

BigQuery Resource Viewer
Co teď potřebuješ ověřit

Nejdůležitější je zjistit seznam compute projektů, které reálně používá EDW.

Ideálně se zeptat kolegů / platform týmu:

Jaké jsou všechny BigQuery compute/workload projekty, přes které se spouštějí query nad produkčním EDW?

Zajímají nás minimálně kategorie:

Business users
ETL / ELT
Oflow
Airflow
Looker / reporting
technické service accounty
ad-hoc analytika
ML / Data Science

Zatím známe:

o2cz-edw-wm-business-personal
o2cz-edw-wm-business-technology

ale potřebujeme zjistit, zda existují například další:

EDW technology
operations
batch
reporting
data science
aplikace
Dále ověřit oprávnění

Pro každý relevantní compute projekt potřebujeme možnost číst:

INFORMATION_SCHEMA.JOBS_BY_PROJECT

tedy ideálně:

bigquery.jobs.listAll

Můžeš tedy vznést požadavek typu:

Potřebuji read-only přístup k BigQuery job metadata pro účely monitoringu využití BQ. Potřebuji číst INFORMATION_SCHEMA.JOBS_BY_PROJECT v EDW compute projektech, ideálně oprávnění bigquery.jobs.listAll / roli BigQuery Resource Viewer.

Budoucí architektura dashboardu

Aktuálně to vidíme takto:

                    BQ OVERVIEW
                         |
          +--------------+--------------+
          |                             |
       STORAGE                       WORKLOAD
          |                             |
     Data projekty                 Compute projekty
          |                             |
       o2czep                  business-personal
       o2czhp                 business-technology
       o2czvp                       ...
          |                             |
 TABLE_STORAGE                  JOBS_BY_PROJECT
Storage část

Budeme sledovat například:

Total Logical Storage
Total Physical Storage
Table Count
Dataset Count
Largest datasets
Largest tables
Storage growth
Workload část

Budeme sledovat:

Query count
Unique users
TB processed
Slot usage
Running jobs
Failed jobs
Average duration
TOP users
TOP expensive queries
Co bych teď udělal jako další krok

Než budeme pokračovat v SQL, zjisti prosím:

1. Jaké jsou všechny produkční compute projekty pro EDW.

2. Jestli můžeš získat bigquery.jobs.listAll alespoň na:

o2cz-edw-wm-business-personal
o2cz-edw-wm-business-technology

3. Jestli existuje nějaký centrální monitoring účet/projekt, který už má přístup k jobům napříč organizací.

Jakmile to zjistíme, rozhodneme, jestli budeme workload sbírat z jednotlivých JOBS_BY_PROJECT, nebo centrálně přes JOBS_BY_FOLDER / JOBS_BY_ORGANIZATION. To bude důležité udělat správně ještě předtím, než začneme stavět tabulky pro Looker Studio.