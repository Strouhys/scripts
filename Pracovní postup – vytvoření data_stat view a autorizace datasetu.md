# Pracovní postup – vytvoření `data_stat` view a autorizace datasetu

## Cíl

Zpřístupnit produkční tabulku `opr_data.data_stat` z Cloud SQL přes BigQuery a následně ji bezpečně vystavit business uživatelům přes dataset:

```text
o2czep.opr
```

Výsledný tok:

```text
Cloud SQL
  opr_data.data_stat
        │
        ▼
BigQuery federované view
  o2czep.opr_data.data_stat
        │
        ▼
Business view
  o2czep.opr.data_stat
        │
        ▼
Business uživatel
```

Dataset `o2czep.opr` musí být zároveň autorizovaný pro čtení z `o2czep.opr_data`.

---

# 1. Vytvoření federovaného view v `opr_data`

Nejprve vytvořit view:

```text
o2czep.opr_data.data_stat
```

SQL:

```sql
CREATE OR REPLACE VIEW `o2czep.opr_data.data_stat`
AS
SELECT
  *
FROM EXTERNAL_QUERY(
  'projects/o2czep/locations/europe-west4/connections/cloud-sql-opr',
  '''
    SELECT *
    FROM opr_data.data_stat
  '''
);
```

Toto view:

- používá BigQuery connection `cloud-sql-opr`,
- připojí se do produkční Cloud SQL databáze,
- přečte tabulku `opr_data.data_stat`,
- zpřístupní ji v BigQuery jako `o2czep.opr_data.data_stat`.

## Kontrola

Po vytvoření:

```sql
SELECT *
FROM `o2czep.opr_data.data_stat`
LIMIT 10;
```

Případně:

```sql
SELECT COUNT(*)
FROM `o2czep.opr_data.data_stat`;
```

Pokud SELECT projde, federované spojení funguje.

---

# 2. Vytvoření business view

Nad federovaným view vytvořit přístupové view:

```text
o2czep.opr.data_stat
```

SQL:

```sql
CREATE OR REPLACE VIEW `o2czep.opr.data_stat`
AS
SELECT
  *
FROM `o2czep.opr_data.data_stat`;
```

## Kontrola

```sql
SELECT *
FROM `o2czep.opr.data_stat`
LIMIT 10;
```

V této chvíli může SELECT pod administrátorským účtem fungovat, ale ještě není zajištěno, že business uživatel bez přístupu do `opr_data` view použije.

Proto je nutné nastavit **Authorized Dataset**.

---

# 3. Autorizace přes Google Cloud UI

Cílem je povolit:

```text
views z o2czep.opr
        ↓
číst data z
        ↓
o2czep.opr_data
```

## Postup

- [ ] Otevřít Google Cloud Console.
- [ ] Přejít do **BigQuery**.
- [ ] Otevřít projekt `o2czep`.
- [ ] Otevřít dataset `opr_data`.
- [ ] Musí být zobrazen detail datasetu, kde jsou vidět jeho tabulky/views.
- [ ] Vpravo nahoře kliknout na **Share**.
- [ ] Vybrat **Authorize Datasets**.
- [ ] V části **Authorize dataset** vybrat:

```text
o2czep.opr
```

- [ ] Kliknout na **Add authorization / Authorize**.

## Kontrola

V části:

```text
Currently authorized datasets
```

musí být:

```text
Project ID    Dataset ID
o2czep        opr
```

Tím je autorizace hotová.

Důležité: autorizujeme **`opr`**, nikoliv `opr_data`.

`opr_data` je zdrojový dataset a `opr` je dataset obsahující views, kterým dovolujeme zdrojový dataset číst.

---

# 4. Kontrola autorizace přes `bq`

Bez jakékoliv změny lze konfiguraci zkontrolovat:

```cmd
bq show --format=prettyjson o2czep:opr_data
```

Ve výstupu hledat v části `access`:

```json
{
  "dataset": {
    "dataset": {
      "datasetId": "opr",
      "projectId": "o2czep"
    },
    "targetTypes": [
      "VIEWS"
    ]
  }
}
```

Pokud tam tato část je, znamená to:

```text
o2czep.opr je Authorized Dataset pro o2czep.opr_data
```

---

# 5. Autorizace pomocí `bq`

Pokud bych chtěl Authorized Dataset nastavit z příkazové řádky místo UI, postup je následující.

## 5.1 Stáhnout metadata datasetu

```cmd
bq show --format=prettyjson o2czep:opr_data > opr_data.json
```

Tím vznikne například:

```text
C:\Users\x0577063\opr_data.json
```

## 5.2 Upravit část `access`

Do existujícího pole:

```json
"access": [
```

přidat další objekt:

```json
{
  "dataset": {
    "dataset": {
      "datasetId": "opr",
      "projectId": "o2czep"
    },
    "targetTypes": [
      "VIEWS"
    ]
  }
}
```

### POZOR

Původní položky v `access` se nesmí odstranit.

Například mohou existovat:

```json
{
  "role": "WRITER",
  "specialGroup": "projectWriters"
}
```

nebo:

```json
{
  "role": "OWNER",
  "specialGroup": "projectOwners"
}
```

Autorizovaný dataset je pouze **další položka** v existujícím poli `access`.

---

# 6. Nahrání změněných metadat

Po úpravě JSON:

```cmd
bq update --source opr_data.json o2czep:opr_data
```

Tento krok již mění konfiguraci datasetu, proto před spuštěním zkontrolovat obsah JSON.

---

# 7. Kontrola po změně

```cmd
bq show --format=prettyjson o2czep:opr_data
```

Musí být vidět:

```json
{
  "dataset": {
    "dataset": {
      "datasetId": "opr",
      "projectId": "o2czep"
    },
    "targetTypes": [
      "VIEWS"
    ]
  }
}
```

---

# 8. Finální funkční test

Nejdříve administrátorská kontrola:

```sql
SELECT *
FROM `o2czep.opr.data_stat`
LIMIT 10;
```

Nejlepší finální test je provést SELECT uživatelem, který:

- má přístup do `o2czep.opr`,
- nemá přímý přístup do `o2czep.opr_data`.

Test:

```sql
SELECT *
FROM `o2czep.opr.data_stat`
LIMIT 10;
```

Pokud dotaz projde, Authorized Dataset funguje správně.

Přímý dotaz stejného uživatele:

```sql
SELECT *
FROM `o2czep.opr_data.data_stat`
LIMIT 10;
```

naopak nemusí být povolen.

To je požadované chování.

---

# 9. Rychlá kontrola celého řešení

Výsledný stav má být:

```text
1. Cloud SQL
   opr_data.data_stat
            ↓
2. Federované BigQuery view
   o2czep.opr_data.data_stat
            ↓
3. Business view
   o2czep.opr.data_stat
            ↓
4. Authorized Dataset
   o2czep.opr → o2czep.opr_data
            ↓
5. Business uživatel používá pouze
   o2czep.opr.data_stat
```

## Rychlé SQL kontroly

Federované view:

```sql
SELECT COUNT(*)
FROM `o2czep.opr_data.data_stat`;
```

Business view:

```sql
SELECT COUNT(*)
FROM `o2czep.opr.data_stat`;
```

Oba počty by měly odpovídat.

## Rychlá kontrola Authorized Dataset

```cmd
bq show --format=prettyjson o2czep:opr_data
```

Hledat:

```text
datasetId: opr
projectId: o2czep
targetTypes: VIEWS
```

---

# Doporučený bezpečný postup

Při jednorázové manuální změně:

```text
CREATE federovaného view
        ↓
kontrolní SELECT
        ↓
CREATE business view
        ↓
kontrolní SELECT
        ↓
Authorized Dataset přes UI
        ↓
bq show pro kontrolu
        ↓
test business view
```

Pro automatizaci nebo opakovatelné nasazení je vhodné řešit Authorized Dataset přes IaC / deployment proces. Ruční `bq update --source` používat opatrně, protože pracuje s celými metadaty datasetu a nechceme omylem odstranit existující položky v `access`.