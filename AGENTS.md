# AGENTS.md

## Komunikace

- Odpovídej česky.
- Buď praktický a stručný, ale u rizikových změn vysvětli důvod a možné dopady.
- Příkazy, SQL a skripty připravuj tak, aby šly pokud možno rovnou zkopírovat a spustit.
- Když navrhuješ postup, uváděj ho ve správném pořadí kroků.
- Pokud existuje bezpečnější varianta postupu, preferuj ji.

## Hlavní zásada

Nikdy neprováděj destruktivní nebo produkční změnu bez předchozí kontroly.

Před operacemi jako:

- `DROP`
- `DELETE`
- `TRUNCATE`
- `ALTER`
- `CREATE OR REPLACE`
- hromadný `UPDATE`
- změna konfigurace produkčního jobu
- změna scheduleru
- změna Git větve nebo historie

nejdříve navrhni způsob, jak ověřit aktuální stav.

Typický postup:

1. Zkontrolovat aktuální stav.
2. Ukázat, čeho se změna dotkne.
3. Provést změnu.
4. Udělat kontrolu po změně.
5. V případě potřeby navrhnout rollback.

## BigQuery

### Prostředí

Používané projekty zahrnují zejména:

- `o2czed1` – testovací / ED1 prostředí
- `o2czep` – produkční prostředí

Výchozí BigQuery region je:

`europe-west4`

Pro datum a čas preferuj české časové pásmo:

`Europe/Prague`

### Bezpečnost SQL

Před `DELETE`, `UPDATE`, `DROP` nebo jinou změnou dat nejdříve připrav kontrolní `SELECT`.

Například před:

```sql
DELETE FROM ...
WHERE ...
```

nejdříve připrav:

```sql
SELECT *
FROM ...
WHERE ...
```

nebo alespoň:

```sql
SELECT COUNT(*)
FROM ...
WHERE ...
```

Pokud se má měnit struktura tabulky, nejdříve zobraz aktuální schéma nebo metadata tabulky.

U produkčních tabulek vždy explicitně upozorni, že jde o produkci.

### BigQuery joby

Pro monitoring jobů používej podle potřeby zejména:

```sql
INFORMATION_SCHEMA.JOBS_BY_PROJECT
```

nebo:

```sql
INFORMATION_SCHEMA.JOBS_BY_USER
```

Při analýze jobů kontroluj zejména:

- `job_id`
- `user_email`
- `creation_time`
- `start_time`
- `end_time`
- `state`
- `statement_type`
- `total_bytes_processed`
- `total_slot_ms`
- `error_result`

Pokud řešíme cenu nebo objem zpracovaných dat, zobrazuj hodnoty přehledně v GB/TB.

## Git

Před každou změnou nejdříve doporuč:

```bash
git status
```

Pokud je potřeba zjistit větev:

```bash
git branch --show-current
```

Před `git push` ověř, zda vzdálená větev neobsahuje nové změny.

Preferovaný bezpečný postup:

```bash
git status
git fetch
git status
```

Podle situace následně:

```bash
git pull
```

a až poté:

```bash
git push
```

Nikdy bez výslovného důvodu nenavrhuj:

```bash
git push --force
```

nebo:

```bash
git reset --hard
```

Pokud jsou potřeba, nejdříve vysvětli jejich dopad.

Před commitem ukaž možnost kontroly:

```bash
git diff
```

a případně:

```bash
git diff --staged
```

### Větve

Při práci s `develop`, `main` nebo feature větvemi vždy ověř aktuální větev před commitem nebo pushem.

Pokud byla změna omylem provedena na špatné větvi, preferuj řešení, které neztratí lokální změny ani již vytvořené commity.

## Citlivé soubory

Nikdy nedoporučuj commitovat:

- `.env`
- servisní JSON klíče
- hesla
- tokeny
- credentials
- privátní certifikáty

Pokud takový soubor vidíš v `git status`, upozorni na něj.

Citlivé soubory patří do `.gitignore`, pokud není výslovný důvod jinak.

## GCP autentizace

Rozlišuj mezi:

```bash
gcloud auth login
```

uživatelským přihlášením a použitím service accountu.

Před změnou aktivního účtu lze zkontrolovat:

```bash
gcloud auth list
```

a aktuální konfiguraci:

```bash
gcloud config list
```

Pokud se pracuje s konkrétním projektem, nepředpokládej automaticky správně nastavený default projekt.

Raději používej explicitní:

```bash
--project
```

nebo:

```bash
--project_id
```

podle konkrétního nástroje.

## Oflow / scheduler

Při zásahu do běžícího prostředí preferuj bezpečný postup:

1. Zjistit aktuální stav.
2. Zkontrolovat běžící a čekající joby.
3. Pokud je potřeba odstávka, nastavit kapacitu na `0`.
4. Počkat, až neběží žádné joby.
5. Teprve potom provést změnu nebo shutdown.
6. Po změně prostředí znovu spustit.
7. Vrátit původní kapacitu.
8. Zkontrolovat, že joby opět normálně běží.

Nikdy automaticky nerestartuj failed job bez kontroly příčiny chyby.

Před restartem zkontroluj minimálně:

- log
- počet předchozích pokusů
- zda předchozí běh nezapsal část dat
- zda je restart idempotentní

## Incidenty

Při analýze incidentu odděluj:

- příčinu
- dopad
- nápravu
- kontrolu po opravě

Pokud z logu není příčina jistá, neprezentuj domněnku jako fakt.

U krátkého shrnutí pro kolegy používej přibližně formát:

**Co se stalo:**  
stručný popis problému

**Dopad:**  
co se neprovedlo nebo které procesy byly ovlivněny

**Řešení:**  
co bylo nebo bude provedeno

## Produkce

Produkční změny dělej konzervativně.

U každé významnější změny si polož otázky:

- Mám kontrolu před změnou?
- Vím přesně, kterých objektů se změna dotkne?
- Dá se změna vrátit?
- Mám kontrolu po změně?
- Nemůže změna ovlivnit aktuálně běžící job?

Pokud odpověď na některou z nich není jasná, nejdříve navrhni ověření.

## Skripty

Při úpravě existujícího skriptu:

- neměň zbytečně části, které nesouvisejí s požadavkem
- zachovej současné chování mimo požadovanou změnu
- před větší úpravou vysvětli, co přesně se změní
- pokud je možné skript nejdříve spustit v testovacím nebo dry-run režimu, preferuj to

U PowerShellu počítej primárně s Windows prostředím.

## Preferovaný styl řešení

Pokud uživatel pošle chybu nebo log:

1. Nejprve vysvětli, co chyba znamená.
2. Označ nejpravděpodobnější příčinu.
3. Dej jednoduchý kontrolní příkaz.
4. Teprve potom navrhni opravu.
5. Nakonec dej příkaz nebo kontrolu, která potvrdí, že je problém vyřešen.

Nevytvářej zbytečně komplikované řešení, pokud lze problém bezpečně ověřit jedním nebo dvěma příkazy.

## Důležité pravidlo pro AI

Pokud si nejsi jistý, zda je příkaz bezpečný, nepředpokládej.

Nejdříve připrav read-only kontrolu.

Platí zásada:

> Nejdřív zjistit stav, potom měnit.