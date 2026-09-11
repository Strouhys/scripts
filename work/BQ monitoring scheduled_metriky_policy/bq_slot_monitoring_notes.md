# BigQuery – hlídání vytížení slotů (res-200) – aktualizováno 2026-09-11

## Původní problém
Job vyčerpal celou pilotní rezervaci (800 slotů) na ~4,5 hodiny, ostatní uživatelé
nemohli exekuovat. Job byl nakonec ručně zrušen. Cíl: automatizovat detekci, ať
se nemusí kontrolovat ručně.

## Zjištěné/potvrzené prostředí
- Projekt s joby: `o2cz-dp-wm-200`, region `europe-west4`.
- Rezervace: `res-200`, admin projekt `o2cz-dp-admin`.
- `reservation_id` ve tvaru: `o2cz-dp-admin:europe-west4.res-200`.
- Baseline kapacita: 800 slotů, bez autoscalingu (`autoscale.max_slots = 0`),
  `ignore_idle_slots = false` → rezervace si **může půjčovat idle sloty nad 800**,
  krátké přesahy nad 800 jsou tedy očekávané a nejsou samy o sobě problém.

## Root cause incidentu z 9. 9. 2026
- Parent job byl BigQuery **SCRIPT** (`s_cp_nbo_ucm_199_p`, migrovaná Teradata
  procedura, spouštěná service účtem `edw-load-dev@...` přes Airflow).
- Child job zodpovědný za incident: krok **„0500 – UPDATE CUST_VAL s hypospend“**
  (`UPDATE ... FROM` join na `cp_nbo_init_m` / `ucm_proc_mnth` / `cp_hspnd_3m`).
  Běžel 4h37min na průměru **796 slotů** (prakticky 100 % rezervace).
- Podezření na příčinu: tento krok na rozdíl od jiných (např. krok 0490) **nemá
  `QUALIFY`/deduplikaci** na výsledek joinu → možný fan-out (více odpovídajících
  řádků, než se čeká). Nasvědčuje tomu i `total_bytes_processed = 0` u obřího
  `total_slot_ms` (typický otisk drahého shuffle/joinu bez odpovídajícího objemu
  dat). **Toto zatím nebylo opraveno** – řeší kolega, mimo rozsah tohoto úkolu.

## Důležité poznatky o BigQuery (aby se neopakovalo zkoumání)
- **SCRIPT parent job** má vždy `reservation_id = NULL` a `total_slot_ms` prázdné
  v `INFORMATION_SCHEMA.JOBS`. Skutečná data jsou na **child jobech**
  (`parent_job_id = ...`). Zdokumentované chování, ne bug.
- `INFORMATION_SCHEMA.JOBS_TIMELINE_BY_PROJECT` dává per-vteřinová data i pro
  právě běžící joby (`period_slot_ms`, `state='RUNNING'`) – na tomhle stojí
  celé řešení pro "aktuální stav".
- Partitioning column u `JOBS_TIMELINE` je `job_creation_time`, ne `period_start`
  – bez filtru na `job_creation_time` by se skenovala celá historie (drahé).
- **Scheduled Query si při uložení SQL zkopíruje** – úpravy lokálního `.sql`
  souboru se do už vytvořené scheduled query nepropíšou samy. Nutno vždy
  ručně **Edit → přepsat text → Save** v konzoli.
- E-maily z BigQuery Data Transfer Service (scheduled query failure notification)
  ukazují časy v **US Pacific Time**, ne v lokálním časovém pásmu – proto jsme
  do vlastní `RAISE` zprávy přidali explicitní `Europe/Prague` timestamp.
- Scheduled query "Email notifications" jde **jen na vlastníka (owner)**, žádné
  pole pro skupinu/distribution list neexistuje. Řešení: buď Gmail filter/forward
  na vlastníkově schránce, nebo úplně jiná cesta (Cloud Monitoring, viz níže).
- BigQuery Studio "Run" spustí buď celý skript, nebo jen označenou/vybranou
  část – snadno se to splete a člověk si myslí, že testuje celý skript.
- Cloud Monitoring metriky (`bigquery.googleapis.com/slots/...`) jsou
  **agregátní za rezervaci/projekt**, ne per-job – nejdou použít pro "identifikuj
  konkrétní job", na to je potřeba `INFORMATION_SCHEMA`.
- Cloud Monitoring Alerting **umí poslat e-mail na libovolnou adresu** (i skupinu)
  jako "Email" notification channel – na rozdíl od Scheduled Query zde žádné
  omezení na vlastníka není.
- Alert threshold v Monitoring UI je **statické číslo** (nepřepočítá se sám, když
  se kapacita rezervace v budoucnu změní). Scheduled Query načítá kapacitu
  dynamicky z `INFORMATION_SCHEMA.RESERVATIONS_TIMELINE`, ale správnost použitého
  pole je ještě potřeba ověřit, viz otevřený bod níže.
- Graf BigQuery **Reservation – Slot usage | Time average** a graf alert policy
  nezobrazují totéž. První ukazuje skutečné využití rezervace, zatímco alert
  používá metriku `slots/allocated` a vlastní časovou agregaci. Proto se mohou
  lišit tvarem, výškou špičky i časovým posunem.
- `AVG(period_slot_ms)` v Scheduled Query počítá průměr pouze z dostupných
  aktivních sekund jobu v daném lookbacku. Nejde o průměr přes celé časové okno
  s nulami v době, kdy job neběžel.
- `state = 'RUNNING'` v `JOBS_TIMELINE_BY_PROJECT` popisuje stav konkrétního
  historického časového řezu. Samo o sobě nezaručuje, že job stále běží v okamžiku
  spuštění kontroly. Report tedy může dorazit i krátce po dokončení jobu.

## Výsledné řešení – dva doplňkové nástroje

### 1) BigQuery Scheduled Query – `bq_slot_alert_scheduled_query.sql`
- Běží každých **15 minut** v `o2cz-dp-wm-200` (europe-west4) a používá
  `lookback_minutes = 15`. Okna na sebe navazují, takže je nastavení vhodné pro
  detekci bez mezer; upozornění ale může dorazit až přibližně 15 minut po špičce.
- Najde konkrétní job s nejvyšší průměrnou spotřebou během jeho aktivních sekund
  za posledních 15 minut
  v rezervaci `res-200`, včetně `user_email` (kdo job spustil).
- Při překročení prahu (90 % kapacity) vyvolá `RAISE` → scheduled query run
  selže → BigQuery pošle **e-mail vlastníkovi** s detailem (čas v Praze, job_id,
  owner, reservation, průměr slotů, limit).
- Slouží jako **osobní/diagnostický** kanál s detailem na konkrétní job.
- Častější spouštění (např. každých 5 minut při 15minutovém lookbacku) by
  zrychlilo detekci, ale překrývající se okna mohou poslat opakovaný report pro
  stejný job. Pro současný účel zůstává nastavení **15/15**.

### 2) Cloud Monitoring Alert Policy – „BigQuery slot capacity - res-200 (o2cz-dp-wm-200)“
- Vytvořeno v projektu `o2cz-dp-wm-200` (Monitoring → Alerting).
- Metrika: `bigquery.googleapis.com/slots/allocated`, filtr `reservation = res-200`,
  agregace: rolling window 5 min / mean, across time series: sum.
- Podmínka: threshold **above 760** (95 % z 800).
- Notifikace: e-mail (lze přidat i skupinovou adresu jako další kanál).
- Slouží jako **agregátní/oficiální signál pro tým**, bez detailu který job za to
  může. Kvůli vzorkování, zpoždění, 5minutovému průměru a případnému retest
  window nemusí krátké překročení prahu vyvolat e-mail.

### Jednoduché srovnání obou alertů
- **Scheduled Query:** říká „který job byl v posledních 15 minutách náročný“ a
  přidá job ID a vlastníka. Umí zachytit i krátkou špičku, ale jde primárně o
  diagnostický report a může přijít po skončení jobu.
- **Cloud Monitoring:** říká „rezervace jako celek překročila nastavený práh podle
  agregačních pravidel“. Neidentifikuje job ani vlastníka a krátkou špičku může
  vyhladit, zato podporuje týmové notification channels.
- Nástroje se doplňují: Scheduled Query poskytuje příčinu, Cloud Monitoring stav
  rezervace. Jejich grafy ani okamžik odeslání e-mailu nemusí být totožné.

### 3) Diagnostický toolkit – `bq_incident_followup_queries.sql`
- Dotaz 0: bez znalosti ID najde AKTUÁLNĚ nejvíc slotů žeroucí job v `res-200`.
- Dotaz 1–2: parametrizované (`target_job_id`) pro hlubší rozbor konkrétního
  jobu/skriptu a jeho časové osy.
- Dotaz 3: ověření, ke které rezervaci je projekt přiřazený.

## Otevřené / do budoucna
- Root cause (krok 0500 bez `QUALIFY`) zatím **neopraveno** – řeší kolega.
- **Ověřit načítání kapacity v Scheduled Query:** aktuální SQL používá
  `autoscale.max_slots`, ale u rezervace bez autoscalingu byla zaznamenána
  hodnota `0`. Pokud dotaz skutečně vrací `0`, práh se vypočítá jako nula a alert
  bude chybný. Je nutné potvrdit hodnotu v `RESERVATIONS_TIMELINE` a případně
  použít pole s baseline kapacitou nebo bezpečný fallback na 800.
- Threshold `760` v Monitoring alertu je statický – pokud se kapacita rezervace
  v budoucnu změní, je nutné ho ručně upravit. Scheduled Query se změně
  přizpůsobí automaticky až po ověření nebo opravě výše uvedeného načítání.
- Zvážit přidání skupinové e-mailové adresy jako druhého notification channelu
  v Monitoring alertu (dosud tam byl jen osobní e-mail).
