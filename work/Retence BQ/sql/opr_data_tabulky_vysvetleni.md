# Vysvetleni tabulek v opr_data pro retention proces

Tento dokument popisuje tabulky vytvorene pro centralni retention maintenance proces v BigQuery.

## Prehled objektu

1. `o2czed1.opr_data.table_retention`
2. `o2czed1.opr_data.retention_run`
3. `o2czed1.opr_data.retention_task_run`
4. `o2czed1.opr_data.retention_status_model`
5. `o2czed1.opr_data.v_retention_run_last_14d`
6. `o2czed1.opr_data.v_retention_task_failures_last_14d`

## 1) table_retention

Ucel:
- Konfiguracni tabulka retenccnich pravidel.
- Jeden radek reprezentuje jedno pravidlo, ktere urcuje co a jak se ma mazat.

Nejdulesitejsi sloupce:
- `retention_rule_id`: Jedinecny identifikator pravidla.
- `project_id`, `source_dataset_name`, `bq_dataset_name`, `table_name`: Cíl pravidla.
	- `source_dataset_name` = puvodni dataset z Teradata evidence.
	- `bq_dataset_name` = realny cilovy dataset v BigQuery.
	- prazdny `bq_dataset_name` znamena, ze dataset jeste neni premigrovany.
- `is_active`: Zapnuto/vypnuto.
- `execution_frequency`: D/W/M.
- `retention_type`: Typ pravidla (napr. COLUMN_AGE, CUSTOM_SQL).
- `source_execution_where_clause`: Puvodni Teradata podminka pro audit.
- `bq_execution_where_clause`: Finalni podminka v BigQuery syntaxi.

### Co presne znamena retention_type

`retention_type` je technicky prepinac logiky v orchestratoru. Podle hodnoty orchestrator rozhoduje, jakym zpusobem se sestavi a provede mazaci podminka.

1. `COLUMN_AGE`
- Standardni sablonove pravidlo.
- Ocekava vyplnene parametry:
	- `retention_column`
	- `retention_value`
	- `retention_unit`
	- typicky `boundary_mode = LOAD_DTTM`
- Orchestrator z techto parametru sestavi podminku automaticky.
- Typicky vyznam: "smaz data starsi nez X dni/mesicu/let".

2. `CUSTOM_SQL`
- Vyjimkovy rezim pro slozitejsi logiku.
- Orchestrator nepouzije sablonu, ale spousti podminku z `bq_execution_where_clause`.
- Vhodne pro komplexni pravidla (napr. vice podminek OR, specialni business logika, specificke CDC vzory).

### Prakticke doporuceni

- Preferovat `COLUMN_AGE` vsude, kde to jde.
- `CUSTOM_SQL` pouzivat jen tam, kde sablona nestaci.
- Duvod:
	- `COLUMN_AGE` je jednodussi na validaci, audit a dlouhodobou udrzbu.
	- `CUSTOM_SQL` je flexibilnejsi, ale nese vyssi riziko chyb.

### Co presne znamena boundary_mode

`boundary_mode` urcuje, vuci jakemu referencnimu bodu se u pravidla pocita hranice mazani.

Nejcastejsi hodnoty:

1. `LOAD_DTTM`
- Hranice se pocita vuci `retention_reference_dttm` daneho runu.
- Vhodne pro stabilni denni provoz, kdy vsechna pravidla v jednom runu pouziji stejny referencni cas.
- Nejbeznejsi volba u `COLUMN_AGE`.

2. `CURRENT_DATE`
- Hranice se odviji od aktualniho data v okamziku provedeni.
- Je potreba opatrnost pri dlouho bezicich runech (muze nastat prechod dne).
- Pouzivat jen kde je to business pozadavek.

3. `CUSTOM`
- Hranice je soucasti vlastni logiky v `bq_execution_where_clause`.
- Typicke pro slozite `CUSTOM_SQL` podminky.

Prakticke pravidlo:

- Pokud to jde, preferovat `LOAD_DTTM`, protoze je nejlepe auditovatelny a konzistentni v ramci celeho runu.
- `CURRENT_DATE` a `CUSTOM` pouzivat pouze tam, kde to vyzaduje konkretni logika pravidla.

Poznamka:
- `source_execution_where_clause` je auditni stopa.
- `bq_execution_where_clause` je to, co ma orchestrator vykonavat.

## 2) retention_run

Ucel:
- Hlavička jednoho celkoveho retention behu.
- Jeden radek = jeden run orchestratoru.

Nejdulesitejsi sloupce:
- `run_id`: Jedinecny identifikator behu.
- `run_date`: Provozni datum behu.
- `run_start_dttm`, `run_end_dttm`: Cas zacatku/konce.
- `retention_reference_dttm`: Referencni cas fixovany pro cely run.
- `orchestrator`: TASK_SCHEDULER / OFLOW / AIRFLOW.
- `status`: CREATED, RUNNING, SUCCESS, PARTIAL_SUCCESS, FAILED.
- `error_message`: Chyba na urovni celeho runu.

## 3) retention_task_run

Ucel:
- Detailni audit zpracovani jednotlivych pravidel v ramci runu.
- Jeden radek = jedno vyhodnocene pravidlo (provedeno nebo preskoceno).

Nejdulesitejsi sloupce:
- `task_run_id`: Jedinecny identifikator tasku.
- `run_id`: Vazba na `retention_run`.
- `retention_rule_id`: Vazba na `table_retention`.
- `execution_date`: Datum idempotence.
- `status`: SUCCESS/FAILED/SKIPPED_*.
- `generated_sql`: Vygenerovane SQL pro mazani.
- `affected_rows`: Pocet ovlivnenych radku.
- `unique_task_key`: Business klic `retention_rule_id + execution_date`.
- `is_retry`, `retry_of_task_run_id`: Evidence retry pokusu.

Poznamka:
- Tato tabulka je hlavni zdroj pro troubleshooting a retry.

## 4) retention_status_model

Ucel:
- Referencni ciselnik povolenych stavu pro RUN a TASK.
- Centralizuje vyznam a poradi stavu.

Nejdulesitejsi sloupce:
- `entity_type`: RUN nebo TASK.
- `status_code`: Kod stavu.
- `is_terminal`: Je stav koncovy.
- `is_success`: Je stav povazovan za uspesny.
- `status_order`: Poradi stavu pro dokumentaci/reporting.

## 5) v_retention_run_last_14d

Ucel:
- Rychly monitoring poslednich 14 dni runu.
- Operativni prehled uspechu/chyb bez nutnosti psat vlastni dotaz.

## 6) v_retention_task_failures_last_14d

Ucel:
- Rychly monitoring selhani tasku za poslednich 14 dni.
- Vhodne pro denni kontrolu incidentu a retry.

## Jak objekty spolupracuji

1. Orchestrator zalozi zaznam v `retention_run`.
2. Nacte pravidla z `table_retention`.
3. Pro kazde pravidlo vytvori radek v `retention_task_run`.
4. Provede SQL nebo oznaci SKIPPED stav.
5. Uzavre status runu v `retention_run`.

## Provozni doporuceni

- Aktivni pravidla udrzovat jen s validnim `bq_execution_where_clause`.
- `source_execution_where_clause` nemenit, slouzi jako auditni zdroj.
- Pred go-live vzdy spustit finalni validaci (`retention_final_validation.sql`).
- Monitoring stavet nad 14dennimi view a `retention_task_run`.
