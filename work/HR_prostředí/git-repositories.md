---
description: This document outlines the final structure, types, and configuration of Git repositories for the project, including shared components, code repositories, and temporary assets.
tags:
    - git
    - repository_management
    - architecture
    - development_workflow
    - ci_cd
    - code_sharing
timestamp: "2026-07-02T07:47:58Z"
title: Git Repository Structure and Configuration
type: Git Repository Structure
---
- [Finální git repozitáře](#finální-git-repozitáře)
  - [Hlavní sdílené repozitáře](#hlavní-sdílené-repozitáře)
  - [Hlavní repozitáře s kódem](#hlavní-repozitáře-s-kódem)
  - [Externí komponenty](#externí-komponenty)
  - [Dočasné/pomocné repozitáře](#dočasnépomocné-repozitáře)
  - [TODO - Jak zajistit sdílení kódu který jde napříč prostředím?](#todo---jak-zajistit-sdílení-kódu-který-jde-napříč-prostředím)
- [Konfigurace Gitu](#konfigurace-gitu)

# Finální git repozitáře

Pro lepší pochopení tohoto textu je vhodné se podívat také do confluence, na aktuální popis struktury GitHub pro BI.
Viz <https://confluence.cz.o2/display/BIS/Dokumentace+GitHub>.

## Hlavní sdílené repozitáře

Toto jsou repozitáře, které obsahují

- kód sdílený napříč celou infrastrukturou (exekutor, generátor)
- sdílená metadata
- sdílenou dokumentaci

Z procesního pohledu:
- Jde o repozitáře, které zpravidla mají jednu hlavní branch (`main`) na které se odehrává celá práce (ano, výjimky jsou možné).
- To znamená, že všichni vývojáři k nim musí mít ADMIN práva - mohou zůstat v module grupě `BIDEV-MAIN`.
- Není/nemá na nich být spuštěné CI/CD.

> **Výjimka — agentní vývoj šablon:** Pravidlo "všechno na `main`" platí pro **lidské vývojáře v běžném provozu**. Pro **agentní vývoj šablon** v repozitáři `BIDEV-MAIN_og` (např. migrace press → og) platí místo toho [ADR-006](../../adrs/adr-006-agent-template-dev-feature-branch-lifecycle.md): agent se vždy zeptá, zda pro danou úlohu založit `feature/<stub>` branch, a po dokončení úlohy ji uzavře (merge do `main` + smazání) — plný git-flow životní cyklus.

⚠️ **Pre-commit:**  povinně používat **všude** na těchto repozitářích  `pre-commit`, návod k instalaci (a nastavení pro dané repo) je na [odkazu](../../infrastructure/install-pre-commit.md)!

**Poznámky**

- TODO - pro repo `BIDEV-MAIN_ondp` budu chtít provést - až se bude blížit "go live" - začištění; zachováme pouze "živé" artefakty.
- TODO - z repa `BIDEV-MAIN_ondp` budeme "nějak" chtít distribuovat složku [/ondp/src](../../../ondp/src/) na repos s kódem ETL transformací
- Rosťa: myslí si, že by "knihovny" měly být v `-lib` a ne v `-ondp`
- **Většina repository zatím neexistuje,** indikuje to ikona vedle názvu
  - ✅ - ano, existuje
  - ☑️ - existuje ale není ještě "korektně osazené"
  - ⛔ - ne, zatím neexistuje


| **název**                       | **skupina**                   | **účel**                                                                         |
| ------------------------------- | ----------------------------- | -------------------------------------------------------------------------------- |
| ✅ `BIDEV-MAIN_og`               | metadata                      | `og` šablony a další artefakty                                                   |
| ✅ `BIDEV-MAIN_ondp`             | knihovny                      | `ondp` namespace a **centrální dokumentace**                                     |
| ⁉️ `BIDEV-APP-PY_og`             | zdroják                       | `og` generátor; nutno dodělat a nastavit na NTINFOT404 (Herout)                  |
| ✅ `BIDEV-APP-PY_ondp`           | zdroják                       | `ondp` namespace; ještě zvažujeme ... asi se tam přestěhuje finální kód knihoven |
| ✅ `BIDEV-MAIN_o2czep-bq-deploy` | jednorázové přelévací skripty | **deploy evidence** - Jirka Strouhal                                             |


## Hlavní repozitáře s kódem

Repozitáře s ETL datových transformací a/nebo stage ingestu. Sem **nepatří**: dokumentace, patří se pouze kód.

⚠️ **Pre-commit:**  povinně používat **všude** na těchto repozitářích  `pre-commit`, návod k instalaci (a nastavení pro dané repo) je na [odkazu](../../infrastructure/install-pre-commit.md)!

Viz také [doc/architecture/naming-conventions.md](../naming-conventions.md) - "musí" to s tím být v souladu

| **název**                      | **skupina** | **účel**                                                | pre-commit? | **ci/cd?** | **cíl je**           |
| ------------------------------ | ----------- | ------------------------------------------------------- | ----------- | ---------- | -------------------- |
| ✅ `BIDEV-MAIN_o2czep-stg`      | o2czep-stg  | stage ingest EDW                                        | ✅           | ne         | on prem: `ntinfo403` |
| ☑️ `BIDEV-MAIN_o2czhp-stg`      | o2czhp-stg  | stage ingest HR                                         | ✅           | ne         | on prem: `ntinfo403` |
| ☑️ `BIDEV-MAIN_o2czvp-stg`      | o2czvp-stg  | stage ingest VODWH                                      | ✅           | ne         | on prem: `ntinfo404` |
| ☑️ `BIDEV-MAIN_o2czep-dag10_gg` | o2czep-cdc  | GoldenGate — streaming stage DAGy pro composer          | ✅           | ano        | bucket               |
| ☑️ `BIDEV-MAIN_o2czep-dag10_eh` | o2czep-cdc  | Event Hub / Kafka — streaming stage DAGy pro composer   | ✅           | ano        | bucket               |
| ☑️ `BIDEV-MAIN_o2czep-dag20`    | o2czep-trf  | L2 pro EDW (dags)                                       | ✅           | ano        | bucket               |
| ⛔ `BIDEV-MAIN_o2czhp-dag20`    | o2czhp-trf  | L2 pro HR (dags)                                        | ✅           | ano        | bucket               |
| ⛔ `BIDEV-MAIN_o2czvp-dag20`    | o2czvp-trf  | L2 pro VODWH (dags)                                     | ✅           | ano        | bucket               |
| ⛔ `BIDEV-MAIN_o2czep-dag40`    | o2czep-trf  | L1 pro EDW (**všechny** dagy pro target, mrep, ucm, rr) | ✅           | ano        | bucket               |
| ⛔ `BIDEV-MAIN_o2czhp-dag40`    | o2czep-trf  | L1 pro EDW (dagy pro HR mart - dnes je na EP infra)     | ✅           | ano        | bucket               |




## Externí komponenty

| název                   | skupina      | účel             | pre-commit? | cíl je               |
| ----------------------- | ------------ | ---------------- | ----------- | -------------------- |
| `BIDEV-MAIN_ondp-op-of` | oflow source | exekutor pro stg | ano         | on prem: `ntinfo403` |


## Dočasné/pomocné repozitáře

Toto jsou repozitáře, které "podporují migraci", a z dlouhodobého hlediska nebudou existovat, časem je budeme archivovat/likvidovat.
****

| **název**                    | **skupina** | **účel**                                 | **workflow**           |
| ---------------------------- | ----------- | ---------------------------------------- | ---------------------- |
| ✅ `BIDEV-MAIN_ondp-ddl`      | migrace     | Teradata DDLs                            | jedna centrální branch |
| ✅ `BIDEV-MAIN_ondp-meta`     | migrace     | registry                                 | jedna centrální branch |
| 🖐️ `BIDEV-WORK_ondp-test`     | migrace     | prototyp pro generátor (**k likvidaci**) | jedna centrální branch |
| ✅`BIDEV-WORK_ondp-translate` | migrace     | pro překlad pro byznys                   | jedna centrální branch |


## TODO - Jak zajistit sdílení kódu který jde napříč prostředím?

**Problém**

- všechny komponenty které jsou tam uvedené se budou opírat o namespace `ondp` - návrh do repa `BIDEV-MAIN_ondp`
- **nemáme** k dispozici žádné místo, odkud by se tento kód dal nějak rozumně instalovat (jiné než souborový systém) na composer
- proto v první fázi **pravděpodobně** budeme tento kód **kopírovat** napříš na všechny repozitáře (a na to je potřeba postavit proces; pre-commit hook?)

**Úvahy**

- oslovil jsem Petra Stanislava.

> - muzes si vydeploynout vlastni pypi server, neni to nic slozityho a nepotrebuje to nic moc zdroje
> - v baraku je nexus, ktery by mel umet i python balicky, ale nevim jestli byrokracie s tim neni moc overkill,
> - tohle jsme zatim neprostouchavali, ale Martin Fryzl rikal, ze to je pripadne preferovana varianta.

- z diskuze s Rosťou: můžeme mít jeden bucket cílovaný ze dvou míst, tj jiná CI/CD trubka pro "libs" a jiná pro ETL transformace
- z dokumentace Google: [Artifact Registry repository](https://docs.cloud.google.com/composer/docs/composer-2/install-python-dependencies#install-ar-repo)
  - tohle asi chci, neboť by to řešilo problémy se sdílením kódu, kterým čelím již teď



# Konfigurace Gitu

Viz [../infrastructure/install-git.md](../../infrastructure/install-git.md)
