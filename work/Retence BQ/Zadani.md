# Návrh architektury retencí pro BigQuery

## Obsah
- [1. Cíl řešení](#1-cil-reseni)
- [2. Základní princip architektury](#2-zakladni-princip-architektury)
- [3. Umístění retenčních pravidel](#3-umisteni-retencnich-pravidel)
- [4. Návrh metadat retenčního pravidla](#4-navrh-metadat-retencniho-pravidla)
- [5. Podporované frekvence](#5-podporovane-frekvence)
- [6. Význam placeholderu LOAD_DTTM](#6-vyznam-placeholderu-load_dttm)
- [7. Typy retenčních pravidel](#7-typy-retencnich-pravidel)
- [8. Průběh jednoho retenčního běhu](#8-prubeh-jednoho-retencniho-behu)
- [9. Souběh více instancí procesu](#9-soubeh-vice-instanci-procesu)
- [10. Generování retenčního SQL](#10-generovani-retencniho-sql)
- [11. Spouštění jednotlivých úloh](#11-spousteni-jednotlivych-uloh)
- [12. Audit jednotlivých úloh](#12-audit-jednotlivych-uloh)
- [13. Monitoring](#13-monitoring)
- [14. Jak zjistit, že proces nedojel](#14-jak-zjistit-ze-proces-nedojel)
- [15. Retry chybových úloh](#15-retry-chybovych-uloh)
- [16. Chování při chybě jedné tabulky](#16-chovani-pri-chybe-jedne-tabulky)
- [17. Validace pravidel](#17-validace-pravidel)
- [18. Oprávnění](#18-opravneni)
- [19. Postup implementace](#19-postup-implementace)
- [20. Předběžně dohodnutý cílový stav](#20-predbezne-dohodnuty-cilovy-stav)
- [21. Přepis syntaxe z Teradata do BigQuery](#21-prepis-syntaxe-z-teradata-do-bigquery)
- [22. Výstupy kroku 2 (DDL + stavový model)](#22-vystupy-kroku-2-ddl--stavovy-model)
- [23. Vysvětlení tabulek v opr_data](#23-vysvetleni-tabulek-v-opr_data)

## 1. Cíl řešení

Cílem je vytvořit centrální a oddělený proces pro provádění retencí nad tabulkami v BigQuery.

Retence nebudou součástí jednotlivých datových loadů. Budou řešeny jako samostatný maintenance proces, který:
- načte retenční pravidla,
- vyhodnotí, která pravidla se mají v daném běhu provést,
- vytvoří jednotlivé retenční úlohy,
- provede výmazy v BigQuery,
- uloží výsledek každého pravidla,
- umožní monitoring a bezpečné opakování chybových běhů.

Řešení musí podporovat současné použití pod oflow a zároveň být navržené tak, aby šlo později převést pod Airflow.

## 2. Základní princip architektury

Předběžná architektura:

~~~text
oflow / Airflow
      |
      v
Python retention orchestrator
      |
      +--> načtení pravidel z opr_data
      |
      +--> načtení provozních informací
      |
      +--> vytvoření seznamu úloh pro aktuální běh
      |
      +--> spuštění retenčních SQL v BigQuery
      |
      +--> zápis výsledků do auditních tabulek
      |
      v
monitoring a vyhodnocení celého běhu
~~~

Dočasné řešení:

~~~text
oflow -> Python -> BigQuery
~~~

Cílové řešení:

~~~text
Airflow DAG -> Python / jednotlivé Airflow tasky -> BigQuery
~~~

Logika výběru pravidel, generování SQL a auditu má být co nejméně závislá na orchestrátoru. Díky tomu půjde nahradit oflow za Airflow bez zásadního přepisování retenčního procesu.

## 3. Umístění retenčních pravidel

Retenční pravidla doporučujeme ukládat přímo v BigQuery v datasetu:

~~~text
opr_data
~~~

Například do tabulky:

~~~text
opr_data.table_retention
~~~

Důvody pro uložení v BigQuery:
- retenční proces se týká objektů v BigQuery,
- pravidla lze snadno spojovat s BigQuery metadaty,
- není nutné při každém běhu číst konfiguraci přes federovaný dotaz,
- metadata jsou dostupná Pythonu i budoucímu Airflow,
- jednodušší je validace existence tabulek a sloupců,
- audit pravidel a historie běhů budou ve stejném prostředí.

Cloud SQL může zůstat zdrojem provozních informací, například stavů loadů nebo dat z data_stat.

Tyto informace mohou být v opr_data dostupné pomocí federovaného view:

~~~text
Cloud SQL
   |
   v
federované view v opr_data
~~~

a vedle něj:

~~~text
opr_data.table_retention
opr_data.retention_run
opr_data.retention_task_run
~~~

## 4. Návrh metadat retenčního pravidla

Každé pravidlo musí jednoznačně určit:
- nad jakou tabulkou se má retence provádět,
- zda je pravidlo aktivní,
- jak často se smí spouštět,
- jakým způsobem se mají vybrat data ke smazání,
- zda lze pravidlo zpracovat standardní šablonou, nebo vyžaduje vlastní SQL.

Předběžný obsah tabulky:

~~~text
retention_rule_id
project_id
dataset_name
table_name
is_active
execution_frequency
retention_type
retention_column
retention_value
retention_unit
column_data_type
boundary_mode
custom_where_clause
retention_comment
created_dttm
updated_dttm
~~~

Pro složitější CDC pravidla mohou být potřeba další sloupce:

~~~text
end_column
operation_column
delete_operation_value
source_time_column
~~~

### Aktivace pravidla

Pravidlo se provede pouze tehdy, pokud:

~~~text
is_active = 1
~~~

Pokud má pravidlo jinou hodnotu, retenční proces ho přeskočí.

## 5. Podporované frekvence

Retenční pravidla mohou mít frekvenci:

~~~text
D = každý den
W = každou sobotu
M = první sobotu v měsíci
~~~

Zároveň platí, že stejné retenční pravidlo se smí spustit maximálně jednou za kalendářní den.

I při opakovaném spuštění hlavního procesu během dne se již úspěšně provedená retence pro stejné pravidlo znovu nespustí.

Přesný den pro týdenní nebo měsíční retenci je potřeba uložit v metadatech, například:

~~~text
execution_day_of_week
execution_day_of_month
~~~

Případně lze použít obecnější výraz:

~~~text
execution_schedule
~~~

Pro první verzi je dohodnutá tato interpretační logika:
- D: každý den,
- W: každou sobotu,
- M: první sobotu v měsíci.

## 6. Význam placeholderu LOAD_DTTM

Placeholder LOAD_DTTM má historii z původní Teradata implementace.

Pro nový retenční proces pod ním budeme chápat:

~~~text
aktuální systémové datum s časem 00:00:00
~~~

Například při běhu 13. července 2026:

~~~text
2026-07-13 00:00:00
~~~

Tato hodnota se určí jednou na začátku celého retenčního běhu.

Python ji uloží například jako retention_reference_dttm. Stejná hodnota se použije pro všechny úlohy v rámci jednoho runu.

Tím se zabrání tomu, aby při delším běhu nebo při přechodu přes půlnoc pracovaly různé tasky s jiným referenčním datem.

## 7. Typy retenčních pravidel

Řešení nemá být omezené pouze na jednoduché pravidlo sloupec + počet dní.

Předběžně se počítá s typy:

~~~text
COLUMN_AGE
CDC_HISTORY
CDC_DELETED_ROWS
CALENDAR_PERIOD
LOAD_SET_BOUNDARY
TEMPORAL_CLOSED_ROWS
CUSTOM_SQL
~~~

### COLUMN_AGE
Jednoduché mazání podle stáří hodnoty ve sloupci.

Příklad parametrů:

~~~text
retention_column = extract_dttm
retention_value = 10
retention_unit = DAY
~~~

### CDC_HISTORY
Mazání historických CDC záznamů podle kombinace více technických sloupců.

### CDC_DELETED_ROWS
Mazání starých záznamů označených operací D.

### CALENDAR_PERIOD
Pravidla založená na kalendářních měsících nebo začátku měsíce.

### LOAD_SET_BOUNDARY
Hranice není určena aktuálním datem, ale provozními metadaty nebo pomocnou tabulkou.

### TEMPORAL_CLOSED_ROWS
Specifická pravidla původně využívající Teradata temporal funkcionalitu.

### CUSTOM_SQL
Individuální pravidlo, které nelze pokrýt standardní šablonou.

Většina pravidel by měla používat standardizované typy. CUSTOM_SQL slouží pouze pro výjimky.

## 8. Průběh jednoho retenčního běhu

### Krok 1: založení hlavního runu

Na začátku se vytvoří záznam v auditní tabulce:

~~~text
opr_data.retention_run
~~~

Například:

~~~text
run_id
run_start_dttm
retention_reference_dttm
orchestrator
status
run_end_dttm
error_message
~~~

Stav hlavního runu může být:

~~~text
CREATED
RUNNING
SUCCESS
PARTIAL_SUCCESS
FAILED
~~~

### Krok 2: načtení aktivních pravidel

Proces načte pravidla, pro která platí:

~~~text
is_active = 1
~~~

Neaktivní pravidla budou ignorována.

### Krok 3: kontrola frekvence

Pro každé pravidlo se vyhodnotí:
- zda má běžet dnes,
- zda odpovídá denní, týdenní nebo měsíční frekvenci,
- zda již nebylo dnes úspěšně provedeno.

Nerelevantní pravidla budou označena například:

~~~text
SKIPPED_FREQUENCY
~~~

### Krok 4: kontrola existence objektu

Proces musí před vytvořením výmazu ověřit:
- zda projekt existuje a je přístupný,
- zda dataset existuje,
- zda tabulka existuje,
- zda existují potřebné retenční sloupce.

Pokud tabulka ještě neexistuje, pravidlo nesmí způsobit pád celého procesu.

Výsledek bude například:

~~~text
SKIPPED_TABLE_NOT_FOUND
~~~

Podobně lze evidovat:

~~~text
SKIPPED_COLUMN_NOT_FOUND
SKIPPED_NOT_IMPLEMENTED
~~~

### Krok 5: prevence duplicitního spuštění

Před spuštěním každého výmazu musí proces atomicky založit záznam úlohy v tabulce:

~~~text
opr_data.retention_task_run
~~~

Jedinečnost lze zajistit klíčem:

~~~text
retention_rule_id
execution_date
~~~

Nejbezpečnější je použít retention_rule_id, protože jedna tabulka může mít více retenčních pravidel.

Pokud pro stejné pravidlo a den existuje stav SUCCESS nebo RUNNING, nové spuštění se neprovede.

Pokud existuje FAILED, může být povolen retry podle nastavené politiky.

Doporučený jedinečný klíč:

~~~text
retention_rule_id + execution_date
~~~

## 9. Souběh více instancí procesu

Je potřeba řešit i situaci, kdy se omylem spustí dva celé retention runy současně.

Kontrola před spuštěním nestačí, protože oba procesy mohou ve stejnou chvíli zjistit, že záznam ještě neexistuje.

Proto musí být vytvoření tasku provedeno atomicky, například pomocí BigQuery MERGE.

~~~sql
MERGE INTO retention_task_run
USING data_pro_aktualni_task
ON retention_rule_id = ...
AND execution_date = ...
WHEN NOT MATCHED THEN
  INSERT ...
~~~

Pouze proces, kterému se podaří vytvořit task ve stavu CREATED, smí pokračovat ke spuštění výmazu.

## 10. Generování retenčního SQL

Python načte typ pravidla a jeho parametry.

Pro standardní typ vytvoří SQL pomocí předem definované šablony.

Příklad typu COLUMN_AGE:

~~~sql
DELETE FROM project.dataset.table
WHERE extract_dttm <
  TIMESTAMP(
    DATE_SUB(
      DATE(@retention_reference_dttm),
      INTERVAL 10 DAY
    )
  );
~~~

Názvy projektů, datasetů, tabulek a sloupců nesmí být do SQL přebírány bez validace.

Hodnoty jako datum nebo počet dní mají být předávány parametrizovaně, pokud to BigQuery syntaxe umožňuje.

## 11. Spouštění jednotlivých úloh

Tasky lze zpracovávat:
- sekvenčně,
- paralelně s omezeným počtem současně běžících úloh.

Pro první verzi je doporučená řízená paralelizace.

Důvody:
- ochrana BigQuery kapacity,
- jednodušší monitoring,
- menší riziko velkého množství současných DELETE,
- možnost později zvýšit paralelismus podle reálného provozu.

V oflow může první verze fungovat jako jeden Python job s interní paralelizací.

V Airflow může být každé retenční pravidlo samostatný dynamicky vytvořený task.

## 12. Audit jednotlivých úloh

Pro každý task se ukládá například:

~~~text
task_run_id
run_id
retention_rule_id
execution_date
project_id
dataset_name
table_name
status
attempt_no
task_start_dttm
task_end_dttm
retention_reference_dttm
generated_sql
bigquery_job_id
affected_rows
error_message
~~~

Možné stavy:

~~~text
CREATED
RUNNING
SUCCESS
FAILED
SKIPPED_ALREADY_EXECUTED
SKIPPED_FREQUENCY
SKIPPED_INACTIVE
SKIPPED_TABLE_NOT_FOUND
SKIPPED_COLUMN_NOT_FOUND
~~~

Ukládání bigquery_job_id umožní dohledat detail výmazu přímo v historii BigQuery jobů.

## 13. Monitoring

Monitoring musí fungovat na dvou úrovních.

### Monitoring celého běhu

Sleduje se:
- zda byl retention run spuštěn,
- zda byl dokončen,
- kolik úloh bylo úspěšných,
- kolik úloh selhalo,
- kolik pravidel bylo přeskočeno,
- jak dlouho celý běh trval.

Hlavní run může být SUCCESS pouze tehdy, pokud všechny očekávané úlohy skončí úspěšně nebo očekávaným stavem SKIPPED.

Pokud některé úlohy selžou, run bude PARTIAL_SUCCESS.

Pokud selže samotný orchestrátor a nedokončí vyhodnocení, run bude FAILED.

### Monitoring jednotlivých pravidel

Pro každou tabulku musí být možné zjistit:
- kdy byla retence naposledy spuštěna,
- kdy byla naposledy úspěšná,
- kolik řádků bylo odstraněno,
- zda tabulka chybí,
- zda pravidlo opakovaně selhává.

V opr_data může vzniknout provozní view, například:

~~~text
opr_data.v_retention_current_status
~~~

## 14. Jak zjistit, že proces nedojel

Nestačí sledovat pouze existenci stavu RUNNING.

Je potřeba definovat očekávaný maximální čas běhu.

Pokud zůstane run nebo task ve stavu RUNNING déle než stanovený limit, monitoring jej označí jako STALE.

Například:
- hlavní run běží déle než několik hodin,
- jednotlivý task nemá aktualizovaný stav,
- neexistuje konečný výsledek BigQuery jobu.

Pro oflow může první verze vyhodnocovat návratový kód Python procesu:
- 0: vše v pořádku,
- nenulový kód: celý běh nebo část běhu selhala.

Detail ale musí být vždy uložen v auditních tabulkách.

V Airflow bude možné využít standardní monitoring DAGů a tasků, auditní tabulky zůstanou hlavním aplikačním zdrojem pravdy.

## 15. Retry chybových úloh

Pokud task skončí jako FAILED, musí být možné jej opakovat.

Retry se nesmí považovat za druhé samostatné provedení retence.

Proto auditní záznam obsahuje attempt_no.

Jeden logický task pro retention_rule_id + execution_date může mít více pokusů.

Příklad:
- attempt_no = 1: FAILED,
- attempt_no = 2: SUCCESS.

Jakmile existuje úspěšný pokus, další spuštění stejného pravidla ve stejném dni již není povoleno.

## 16. Chování při chybě jedné tabulky

Chyba jednoho retenčního pravidla nesmí zastavit všechny ostatní nezávislé retence.

Proces musí:
1. zaznamenat chybu konkrétního tasku,
2. pokračovat dalšími pravidly,
3. na konci vyhodnotit celý run jako PARTIAL_SUCCESS nebo FAILED,
4. umožnit opakovat pouze chybové tasky.

Výjimkou mohou být systémové chyby, například:
- nelze načíst retenční metadata,
- nelze zapisovat do auditních tabulek,
- nejsou dostupná oprávnění k BigQuery,
- nelze jednoznačně určit retention_reference_dttm.

Při takové chybě se může ukončit celý run.

## 17. Validace pravidel

Před aktivací pravidla by měla proběhnout kontrola:
- zda je retenční typ podporovaný,
- zda jsou vyplněné povinné parametry,
- zda existuje cílová tabulka,
- zda existují retenční sloupce,
- zda datové typy odpovídají šabloně,
- zda custom_where_clause neobsahuje zakázané příkazy.

Pro CUSTOM_SQL by měl být povolen pouze výraz odpovídající části WHERE, nikoliv kompletní libovolný SQL skript.

Orchestrátor potom sám vytvoří:

~~~sql
DELETE FROM cilova_tabulka
WHERE <custom_where_clause>
~~~

Tím se sníží riziko vložení nebezpečných příkazů do metadat.

## 18. Oprávnění

Service account procesu musí mít:
- čtení retenčních metadat,
- zápis do auditních tabulek,
- právo spouštět BigQuery joby,
- právo mazat data pouze v určených datasetech.

Neměl by mít zbytečně široká oprávnění nad celým projektem.

Je vhodné oddělit:
- správu retenčních pravidel,
- spuštění retenčních jobů,
- čtení provozního monitoringu.

## 19. Postup implementace

### Fáze 1: základní oflow řešení
- tabulka retenčních pravidel v opr_data,
- auditní tabulka hlavních runů,
- auditní tabulka jednotlivých tasků,
- Python orchestrátor,
- spuštění jednou denně pod oflow,
- podpora základních standardních typů,
- prevence duplicit,
- evidence chybějících tabulek,
- základní provozní view.

### Fáze 2: rozšíření pravidel
- CDC pravidla,
- kalendářní období,
- pravidla závislá na provozních metadatech,
- řízený paralelismus,
- automatické retry,
- rozšířený monitoring a alerting.

### Fáze 3: přesun pod Airflow
- Python logika zůstane zachována,
- vznikne samostatný retention DAG,
- pravidla budou dynamicky mapována na Airflow tasky,
- Airflow převezme plánování, retry a technický monitoring,
- audit v opr_data zůstane zachován.

## 20. Předběžně dohodnutý cílový stav

Na základě dosavadní diskuse je navržen tento směr:
- retence budou samostatný maintenance proces,
- nebudou navázané na jednotlivé loady,
- dočasně budou spouštěné jako nový job pod oflow,
- cílově budou přesunuty do samostatného Airflow DAGu,
- retenční pravidla budou uložena v BigQuery v opr_data,
- provozní data z Cloud SQL mohou být zpřístupněna federovaným view,
- podporované budou denní, týdenní a měsíční frekvence,
- pravidlo se smí spustit maximálně jednou za den,
- neaktivní pravidla se nespouštějí,
- pravidla pro dosud neimplementované tabulky se přeskočí a zaevidují,
- LOAD_DTTM bude nahrazeno jednotným referenčním časem odpovídajícím aktuálnímu datu v 00:00:00,
- každý run i jednotlivý task budou auditované,
- duplicitní výmaz bude blokován pomocí kombinace retention_rule_id + execution_date,
- chyba jedné tabulky nezastaví ostatní retenční úlohy,
- většina pravidel bude generována ze standardních šablon,
- individuální výjimky budou podporované řízeným CUSTOM_SQL.

## 21. Přepis syntaxe z Teradata do BigQuery

## 22. Výstupy kroku 2 (DDL + stavový model)

Konkrétní návrh tabulek, partition/clustering, seed stavů a monitorovacích view je připraven v souboru:

~~~text
sql/retention_ddl.sql
~~~

Stručný stavový model (RUN/TASK lifecycle, idempotence, retry) je připraven v souboru:

~~~text
sql/retention_state_model.md
~~~

## 23. Vysvětlení tabulek v opr_data

Samostatný popis založených tabulek a view v datasetu `opr_data` je v dokumentu:

~~~text
sql/opr_data_tabulky_vysvetleni.md
~~~

Ideální přístup není zachovat Teradata SQL text beze změny, ale zachovat stejný funkční princip:

~~~text
metadata pravidla -> dosazení referenčního data -> DELETE nad cílovou tabulkou
~~~

Rozdíl je v tom, že při migraci jednorázově převedeme Teradata execution_where_clause do BigQuery podoby a výsledek uložíme jako nové BigQuery retenční pravidlo.

### Doporučený postup

Navržen je hybridní model se dvěma vrstvami.

### 1. Zachování původní podmínky pro audit

V nové tabulce se ponechá například:

~~~text
source_execution_where_clause
~~~

Zde bude původní Teradata syntaxe přesně tak, jak je dnes.

Vedle ní bude:

~~~text
bq_execution_where_clause
~~~

nebo lépe strukturovaná BigQuery konfigurace.

Tím je vždy dohledatelné:
- jaké bylo původní pravidlo,
- jak bylo přeloženo,
- zda se význam nezměnil.

### 2. Automatický převod většiny pravidel

Pro známé a opakující se vzory vznikne migrační převodník. Nebude to obecný převodník libovolného Teradata SQL, ale cílený převodník retenčních podmínek.

Například Teradata:

~~~sql
extract_dttm < CAST(
  (
    CAST(CAST('$$LOAD_DTTM' AS TIMESTAMP(0)) AS DATE)
    - INTERVAL '10' DAY
  ) AS TIMESTAMP(0)
)
~~~

se převede na BigQuery:

~~~sql
extract_dttm < TIMESTAMP(
  DATE_SUB(DATE(@retention_reference_dttm), INTERVAL 10 DAY)
)
~~~

Nebo se uloží strukturovaně:

~~~text
retention_type   = COLUMN_AGE
retention_column = extract_dttm
retention_value  = 10
retention_unit   = DAY
boundary_mode    = START_OF_DAY
~~~

Vlastní SQL se pak vytvoří až při spuštění, což je bezpečnější než opakované používání ručně psaného SQL textu.

### Jak bude převod prakticky probíhat

#### Fáze A: klasifikace pravidel

Python načte původní execution_where_clause a pokusí se pravidlo zařadit do známé skupiny:

~~~text
COLUMN_AGE
CDC_HISTORY
CDC_DELETED_ROWS
CALENDAR_PERIOD
LOAD_SET_BOUNDARY
TEMPORAL_CLOSED_ROWS
CUSTOM_SQL
~~~

Příklad:
- loaded_dttm < ... -> COLUMN_AGE,
- TT_END_DTTM < ... OR (Operation = 'D' AND src_dttm < ...) -> CDC_HISTORY.

#### Fáze B: extrakce parametrů

Z původního SQL se vytáhnou parametry.

Pro jednodušší pravidla například:

~~~text
retention_column = extract_dttm
retention_value  = 10
retention_unit   = DAY
~~~

U CDC například:

~~~text
end_column             = TT_END_DTTM
operation_column       = Operation
delete_operation_value = D
source_time_column     = src_dttm
retention_value        = 60
retention_unit         = DAY
~~~

#### Fáze C: vytvoření BigQuery varianty

Převodník vygeneruje:
- strukturovaná metadata,
- náhled výsledného BigQuery WHERE,
- stav převodu.

Například:

~~~text
conversion_status = AUTO_CONVERTED
~~~

Další možné stavy:

~~~text
AUTO_CONVERTED
MANUAL_REVIEW_REQUIRED
MANUALLY_CONVERTED
VALIDATED
REJECTED
~~~

#### Fáze D: validace

Každé pravidlo by před aktivací mělo projít kontrolou:
- cílová tabulka existuje,
- použitý sloupec existuje,
- datový typ sloupce odpovídá podmínce,
- výsledná BigQuery syntaxe je validní,
- podmínka neobsahuje nepovolené příkazy.

Doporučen je i bezpečný test počtu řádků:

~~~sql
SELECT COUNT(*)
FROM project.dataset.table
WHERE <nova_bq_podminka>
~~~

Teprve po kontrole se pravidlo aktivuje pro skutečný DELETE.

### Co lze převádět automaticky

Velmi dobře půjdou automaticky převést například:
- CAST(... AS DATE),
- CAST(... AS TIMESTAMP),
- INTERVAL '10' DAY,
- INTERVAL '1' YEAR,
- CURRENT_DATE,
- ADD_MONTHS,
- EXTRACT,
- jednoduché porovnání <, <=, =,
- logické kombinace AND, OR,
- placeholder $$LOAD_DTTM.

Příklady převodu:
- Current_Date -> CURRENT_DATE() nebo referenční datum,
- CAST(x AS DATE) -> DATE(x),
- CAST(x AS TIMESTAMP(0)) -> TIMESTAMP(x),
- x - INTERVAL '10' DAY -> DATE_SUB(x, INTERVAL 10 DAY) nebo TIMESTAMP_SUB,
- ADD_MONTHS(x, -6) -> DATE_SUB(x, INTERVAL 6 MONTH),
- SUBSTRING(x FROM 1 FOR 10) -> SUBSTR(x, 1, 10),
- EXTRACT(DAY FROM x) -> EXTRACT(DAY FROM x).

Ne vše lze převést prostou náhradou textu. Záleží na datovém typu a pořadí castů.

### Co bude vyžadovat ruční posouzení

Ruční zásah bude potřeba hlavně u:
- Teradata temporal syntaxe,
- End(tt_per) IS NOT Until_Closed,
- poddotazů do pomocných Teradata tabulek,
- pravidel závislých na E20_LOAD_RETENTION,
- nestandardních funkcí,
- pravidel s komplikovanou business logikou,
- potenciálně chybných historických podmínek.

Taková pravidla se označí:

~~~text
MANUAL_REVIEW_REQUIRED
~~~

Proces je do té doby nebude spouštět.

### Zachovat text podmínky, nebo strukturovaná metadata

Doporučeno je obojí.

Tabulka může obsahovat například:

~~~text
source_platform
source_execution_where_clause
retention_type
retention_column
retention_value
retention_unit
bq_execution_where_clause
conversion_status
validation_status
~~~

Původní Teradata SQL bude sloužit jako historie a důkaz převodu.

Pro samotné spouštění je preferováno:
1. standardní šablony ze strukturovaných parametrů,
2. BigQuery custom_where_clause pouze pro výjimky.

### Proč nepoužívat pouze přeložený SQL text

Pouhý textový překlad je nejbližší současnému procesu, ale má nevýhody:
- hůře se kontroluje,
- snadněji obsahuje chybu,
- obtížně se zjišťuje retenční sloupec a délka okna,
- komplikovaněji se validují změny,
- různí autoři zapisují stejnou logiku různými způsoby.

Strukturovaný model je větší změna, ale po migraci výrazně stabilnější.

### Návrh kompromisu pro první verzi

Aby se řešení příliš nevzdálilo současnému stavu:

~~~text
Teradata MAN_TABLE_RETENTION
        |
        v
jednorazovy Python konvertor
        |
        +--> puvodni Teradata WHERE
        +--> rozpoznany typ pravidla
        +--> strukturovane parametry
        +--> vygenerovane BigQuery WHERE
        +--> stav validace
        |
        v
opr_data.table_retention
~~~

Při běžném denním provozu už nebude probíhat převod Teradata syntaxe. Denní proces bude pracovat pouze s ověřenými BigQuery pravidly.

Klíčové pravidlo: převod syntaxe je migrační proces, ne součást každodenní retence.

### Doporučený výsledný princip

- Zachovat původní Teradata pravidlo.
- Automaticky převést známé vzory.
- Z převodu vytvořit standardní strukturované pravidlo.
- Vygenerovat BigQuery podmínku.
- Ověřit ji pomocí SELECT COUNT(*).
- Manuálně dořešit jen výjimky.
- Do produkční retence pustit pouze pravidla ve stavu VALIDATED.
