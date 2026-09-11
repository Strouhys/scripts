---
description: This document describes the configuration changes that need to be made on production servers (ntinfo403, ntinfo404) in connection with the parallel operation of the extract load into Teradata, and simultaneously into Big Query.
tags:
    - NTINFO40x
    - production_server
    - data_load
    - BigQuery
    - Teradata
    - configuration
    - software_installation
timestamp: "2026-06-25T20:20:39Z"
title: 'NTINFO40x Production Server Configuration: Parallel Data Load Setup'
type: Server_Configuration
---
- [Základní východiska](#základní-východiska)
  - [Doménový účet -  `su_dp_admin`](#doménový-účet----su_dp_admin)
  - [Instalace software](#instalace-software)
    - [Git: doinstalovat](#git-doinstalovat)
    - [Python: použít existující instalaci](#python-použít-existující-instalaci)
    - [Python: venv](#python-venv)
    - [Google SDK: nainstalovat](#google-sdk-nainstalovat)
    - [oflow: nainstalovat](#oflow-nainstalovat)
  - [Adresářová struktura](#adresářová-struktura)
  - [Security, síťovno, firewally](#security-síťovno-firewally)
    - [Windows Defender](#windows-defender)
    - [Přístupová práva pro technické účty](#přístupová-práva-pro-technické-účty)
    - [Přístupová práva na `i:\dp\.config`](#přístupová-práva-na-idpconfig)
    - [Průchody: outgoing](#průchody-outgoing)
    - [Průchody: incoming](#průchody-incoming)
  - [Parametrizace loadu](#parametrizace-loadu)
    - [Globálně nastavené proměnné prostředí](#globálně-nastavené-proměnné-prostředí)
  - [Task scheduler](#task-scheduler)
- [Tectia a co dělat po zasmrcení EDW loadu?](#tectia-a-co-dělat-po-zasmrcení-edw-loadu)


---

# Základní východiska

Tento dokument popisuje konfigurační změny, které je potřeba udělat na produkčních serverech (`ntinfo403`, `ntinfo404`)
v souvislosti s paralelním provozem extraktového loadu do Teradaty, a současně do Big Query.

## Doménový účet -  `su_dp_admin`

- existuje nový technický doménový účet, nazvaný `su_dp_admin`; vlastníkem je Richard Švec; účet je admin na serverech NTINFO02, NTINFO402, NTINFO403, NTINFO404


## Instalace software

Instalační soubory jsem stáhnul na následující umístění:

| server      | co         | soubor                                        |
| ----------- | ---------- | --------------------------------------------- |
| `ntinfo404` | git        | `F:\install\_DP_\Git-2.54.0-64-bit.exe`       |
| `ntinfo404` | gcloud sdk | `F:\install\_DP_\GoogleCloudSDKInstaller.exe` |

### Git: doinstalovat

**Zdůvodnění**

- Počítám s tím, že deployment bude probíhat pomocí operace `git pull` přímo z remote desktopu obou serverů.
- Na to konto je nezbytná instalace gitu na oba servery. Instalujeme poslední dostupnou verzi.

**Zdroj**

- <https://git-scm.com/install/windows>

**Nastavení během instalace a postinstalační kroky**

- Viz [Doporučené nastavení Gitu](../install-git.md#doporučené-nastavení-gitu) — zejména:
  - při instalaci zvolit `Checkout as-is, commit Unix-style line endings` (`core.autocrlf = input`)
  - po instalaci nastavit `core.whitespace` a na produkčních serverech `receive.denyNonFastForwards`
  - **po `git clone` nastavit sdílený přístup** — viz [Nastavení pro sdílený přístup více uživatelů](../install-git.md#nastavení-pro-sdílený-přístup-více-uživatelů) (`core.sharedRepository`, `safe.directory`, NTFS oprávnění). Bez toho `git pull` selže, pokud `clone` provedl jiný uživatel.
  - dlouhodobě zavést `.gitattributes` do všech repozitářů

```
i:

cd I:\dp\BIDEV-APP-PY_ondp
git config core.sharedRepository group
git config --global --add safe.directory I:\dp\BIDEV-APP-PY_ondp
git gc

cd I:\dp\BIDEV-MAIN_o2czep-stg
git config core.sharedRepository group
git config --global --add safe.directory I:\dp\BIDEV-MAIN_o2czep-stg
git gc
```


### Python: použít existující instalaci

**Zdůvodnění**

- Na obou serverech je nainstalovaný Python ve verzi `3.13.5`
- Workload poběží s touto verzí


### Python: venv

**Postup instalace**

```
i:\
mkdir \dp
cd \dp
python --version
python -m venv .venv
```

**Instalace knihoven**

```
i:\
mkdir \dp
.venv\scripts\activate
pip install -r requirements.txt
```

**`requirements.txt`** - založil jsem v cestě `i:\dp\requirements.txt` s následujícím obsahem:
```
attrs>=25.4.0
cattrs>=25.3.0
croniter>=6.2.2,<7.0.0
google-auth>=2.49.1,<3.0.0
google-cloud-bigquery>=3.40.1
google-cloud-storage>=3.10.1
jinja2>=3.1.6,<4.0.0
pendulum>=3.1.0
pg8000>=1.31.5,<2.0.0
python-dotenv>=1.2.1
pyyaml>=6.0.3
requests>=2.32.5,<3.0.0
tenacity>=9.1.4
```

### Google SDK: nainstalovat

- Postupujeme podle návodu na [install-google-sdk.md](../install-google-sdk.md)
- Instalujeme verzi pro windows, součástí instalace bude i "bundled python"

**Resolved** — interaktivní `gcloud init` pod technickým účtem **není potřeba**. Místo toho se použije `gcloud auth activate-service-account`, což plně nahrazuje `gcloud init` pro service account. Všechny níže uvedené příkazy fungují v `cmd.exe` (PowerShell není vyžadován).

Postup (jednorázový, provede admin pod svým účtem):

1. Přihlásit se na server pod vlastním admin účtem (remote desktop)
2. Otevřít `cmd.exe` a přepnout kontext na technický účet: `runas /user:DOMAIN\su_dp_admin cmd`
3. Provést konfiguraci:

```cmd
rem Nasměrovat gcloud konfiguraci do produkčního adresáře
i:
mkdir i:\dp.config
mkdir i:\dp.config\.config
mkdir i:\dp.config\keys
mkdir i:\dp.config\.config\gcloud.ext_load
set CLOUDSDK_CONFIG=i:\dp.config\.config\gcloud.ext_load

rem Aktivovat service account klíčem (nahrazuje gcloud init + gcloud auth login)
gcloud auth activate-service-account --key-file="i:\dp.config\keys\gcloud.ext_load\o2cz-dp-admin-edw-ext-load-prod.json"

rem Nastavit defaultní projekt
gcloud config set project o2cz-dp-wm-100

rem Ověřit identitu
gcloud auth list
```

4. Ověřit, že konfigurace funguje:

```cmd
rem Zkusit výpis datasetů v BigQuery
bq ls --project_id=o2cz-dp-wm-100
```

5. Nastavit práva
- uživatel `su_dp_admin` musí mít právo číst a psát do:
  -  `I:\dp`
  -  `I:\dp.config`
  -  TODO do EDW archivu
- TODO uživatel `su_info_admin`



### oflow: nainstalovat

- na serveru bude provozována komponenta `oflow`
- jde o binárku programu, který slouží jako scheduler pro load do Big Query;
  ke dni 4.6.2026 je její zdrojový kód součástí tohoto repository, viz složka [/of](../../../of/)

**Resolved** — binárka se nakopíruje z `of/dist/` na server do adresáře `i:\dp\bin\`. Distribuce probíhá ručně (kopie souboru `oflow-windows-amd64.exe`). Adresář `i:\dp\bin\` je součástí adresářové struktury (viz níže).

Zvažované alternativy distribuce:

| Varianta                        | Popis                                                              | Výhody                                  | Nevýhody                                              |
| ------------------------------- | ------------------------------------------------------------------ | --------------------------------------- | ----------------------------------------------------- |
| **Ruční kopie do `i:\dp\bin\`** | Aktuální rozhodnutí. Binárka z `of/dist/` se nakopíruje na server. | Jednoduché, žádná infrastruktura navíc. | Ruční postup, bez automatického verzování.            |
| GitHub Releases                 | Build v CI (GitHub Actions), stažení přes `gh release download`.   | Verzování, audit trail.                 | Vyžaduje CI pipeline pro Go build.                    |
| GCS bucket                      | Upload do `gs://...`, stažení přes `gcloud storage cp`.            | V ekosystému GCP.                       | Ruční upload, méně automatizace.                      |
| Git LFS                         | Binary tracking přes LFS.                                          | Jednoduchá varianta.                    | Verzujeme něco, co není "kód". Není to best practice. |

## Adresářová struktura

Na serveru je potřeba připravit následující adresáře. Chceme, aby servery pro EDW a VODWH byly "redundantní" a schppné "převzít zodpovědnost" za druhý stroj v případě havárie,
a proto adresářová struktura bude na obou serverech identická.

Viz také [popis adresářové struktury git repos pro stage load](../../architecture/090-metadata/batch-directory-structure-stage.md).

```
i:\dp.config\
    ├── .config                 # 🔐 OMEZENÁ PRÁVA: adresář, kam bude mít READ právo pouze "admin" a su_dp_admin
    |   └── gcloud.ext_load     # ❕              - kongigurace SDA pod SA ext_load
    └── keys                    # 🔑              - SA klíče pro SDK
i:\dp\
    ├── .venv                   # 🐍 virtuální python, JEDNO SDÍLENÉ PROSTŘEDÍ pro všechny loady, udržované ručně
    ├── bin                     # 🟢 BINÁRKY, které na server "jednorázově" (mimo proces) nasadíme; oflow, govalidator, ...
    ├── BIDEV-MAIN_ondp         # 🛢️ git clone, repo kde je sdílený kód, ondp namespace (knihovny)
    ├── BIDEV-MAIN_o2czep-stg   # 🛢️ git clone, implementace EDW stage
    ├── BIDEV-MAIN_o2czhp-stg   # 🛢️ git clone, implementace HR stage
    ├── BIDEV-MAIN_o2czvp-stg   # 🛢️ git clone, implementace VODWH stage
    ├── data_o2czep-stg         # 🛞 pracovní složka loadu
    │   ├── forked              # 🫀        ==> SEM BUDE "VIDLIČKA" DORUČOVAT SOUBORY <==
    │   ├── log                 # 🛞            logy z loadu
    │   ├── oflow               # 🫀            sem si oflow odkládá infomace o svém stavu
    │   ├── persistent          # 🫀            zarážky, odkladiště YAML souborů které "mají přežít"
    │   └── tmp                 # 🛞            dočasné a neperzistující artefakty
    │       ├── comps           # 🛞              - paramfiles pro validátor, vytvářené pro daný run
    │       ├── ctx             # 🛞              - LoadContext, checkpointy
    │       ├── stg_bad         # 🛞              - AVRO "bad files", výstup z validace  (batch má podsložku)
    │       ├── stg_good        # 🛞              - AVRO "good files", výstup z validace (batch má podsložku)
    │       └── stg_sniffed     # 🛞              - uzavřený datový set pro daný load    (batch má podsložku)
    ├── data_o2czhp-stg         # 🛞🔐 DTTO, viz výše; omezená práva (HR požadavek)
    └── data_o2czvp-stg         # 🛞 DTTO, viz výše
```

Současně ale chceme zabránit spuštění "omylem", což znamená, že příslušná složka bude "přejmenovaná" pokud patří
na "druhý server.

Například tedy: na serveru `NTINFO403` adresář `BIDEV-MAIN_o2czvp-stg` přejmenujeme na `BIDEV-MAIN_o2czvp-stg@VODWH` (tzn workload nepůjde z této ložky spustit, invalidní cesty).

**Nezapomenout**

- `su_dp_admin` - musí mít právo psát do EDW archivu (tzn pod `i:\VIRT_NODE`)
- naopak, EDW load (`su_infa_admin` ???) musí mít právo psát do složky `forked` pod daným tenantem - **nastavit**
- read práva na zabezpečené složky (excludovat z read pro všechny)

```
mkdir i:\dp\data_o2czep-stg
mkdir i:\dp\data_o2czep-stg\
mkdir i:\dp\data_o2czep-stg\tmp
mkdir i:\dp\data_o2czep-stg\tmp\ctx
mkdir i:\dp\data_o2czep-stg\persistent
mkdir i:\dp\data_o2czep-stg\persistent\oflow
mkdir i:\dp\data_o2czep-stg\log
mkdir i:\dp\data_o2czep-stg\src
mkdir i:\dp\data_o2czep-stg\src\sources
mkdir i:\dp\data_o2czep-stg\forked
mkdir i:\dp\data_o2czep-stg\archive
```


## Security, síťovno, firewally


### Windows Defender

Následující cesty bude potřeba doplnit do výjimek pro defender, neprovádět pro ně scanování obsahu:

```
i:\dp\data_o2czep-stg   # tady žije load
i:\dp\data_o2czhp-stg   # tady žije load
i:\dp\data_o2czvp-stg   # tady žije load
i:\lnd\                 # sem se doručují data
i:\arch_data\           # sem odklízíme zpracované soubory
i:\arch_log\            # sem odklízíme logy
```

**Doporučení pro klonované repozitáře:**

- Složky `BIDEV-MAIN_*` **nepřidávat** do výjimek Defenderu. Obsahují zdrojový kód (Python, Go, šablony), který se mění při `git pull` a je rozumné ho skenovat. Jde o relativně malý objem souborů — na rozdíl od `data_*` složek, kde se produkují tisíce AVRO souborů v rychlém sledu a kde by Defender výrazně zpomaloval provoz.
- **Doporučeno přidat `.git` podsložky** uvnitř repozitářů do výjimek Defenderu — obsahují pack files a indexy, které Git přepisuje při `git pull`/`gc`. Defender drží na těchto souborech file lock (real-time scanning) a může způsobit chybu *"Unlink of file failed"*. Samotný working tree ponechat skenovaný. Viz [podrobnosti k file locking problému](../../knowledgebase/git/windows-server-file-locking.md).

**K postupu nasazování přes `git pull`:**

- Postup je přijatelný pro naše prostředí — servery jsou v interní síti (přístup přes RDP/VPN), GitHub repo je privátní (org `o2cz-it-dev`), `git pull` stahuje pouze commity z `main` branch.
- Doporučení: na produkčních serverech nastavit `receive.denyNonFastForwards` (viz [Doporučené nastavení Gitu](../install-git.md#nastavení-pro-produkční-servery)) a na GitHub nastavit branch protection rules (require reviews, no force push na `main`).
- Toto nemá vliv na adresářovou strukturu, pouze na pracovní postup.

### Přístupová práva pro technické účty

**účty**


JST _nastaveno
i:\dp\data_o2czvp-stg\forked pro su_info_admin 
d


i:\VIRT_NODE\VODWH\Source\SrcSystems_LND\archive\VODWH_ARCHIVE\ pro su_dp_admin
J

| cesta                                                | účet            | oprávnění               |
| ---------------------------------------------------- | --------------- | ----------------------- |
| `i:\dp\data_o2czep-stg\forked`                       | `su_info_admin` | read + modify + execute |
| `i:\VIRT_NODE\EDW\Source\SrcSystems_LND\ARCHIVE_ASG` | `su_dp_admin`   | read + modify + execute |


**lokální skupi


JST_nastaveno group_gc na složky



- skupina `Group_GC`
  - A1 Rostislav Levíček
  - A1 Jiří Strouhal
  - A1 Jan Herout
- oprávnění FULL CONTROL na
  - `i:\dp`
  - `i:\dp.config`


### Přístupová práva na `i:\dp\.config`

Adresář `i:\dp\.config` obsahuje citlivé materiály — konfiguraci gcloud a SA klíče. Právo číst obsah tohoto adresáře smí mít **pouze**:

- lokální administrátor (nebo skupina `Administrators`)
- technický účet `su_dp_admin`

Ostatní uživatelé (včetně vývojářů s RDP přístupem) by neměli mít možnost SA klíče číst.

**TODO** - útvar security má nějakou vlastní kuchařku, zjistit jak to dělají (Jirka Strouhal).


### Průchody: outgoing

**Předpoklad:** Na základě zkušenosti z provozu nepředpokládáme, že je nutné zařizovat speciální firewall průchody pro odchozí HTTPS provoz na Google Cloud API — komunikace by měla procházet přes standardní firemní infrastrukturu (podobně jako na dev serveru). Nastavení `http_proxy` / `https_proxy` se **netýká** produkčního workflow (to je relevantní pro vývojáře na VPN, viz [setup-proxy.md](../setup-proxy.md)).

Pokud by komunikace s Google Cloudem z produkčních serverů nefungovala, je potřeba zajistit průchod na následující endpointy (vše HTTPS, port 443):

| Endpoint                       | Proč                                                     |
| ------------------------------ | -------------------------------------------------------- |
| `bigquery.googleapis.com`      | BigQuery API — spouštění dotazů, load dat                |
| `storage.googleapis.com`       | Google Cloud Storage — upload/download souborů na bucket |
| `oauth2.googleapis.com`        | Obnova OAuth2 tokenů (token refresh)                     |
| `secretmanager.googleapis.com` | Čtení secretů ze Secret Manager                          |
| `www.googleapis.com`           | Obecné Google API volání                                 |

**Jak ověřit dostupnost** — viz [Google Cloud — ověření síťové dostupnosti](../../knowledgebase/google/networking.md) (PowerShell snippet + interpretace výsledků). Test byl proveden na `NTINFO404` a prošel.

> **Poznámka:** Průchody pro CloudSQL (DEV: `10.35.12.2:5432`) se řeší samostatně, viz [setup-iam.md](../../infrastructure/setup-iam.md).

### Průchody: incoming

- Na serveru bude provozovaná komponenta `oflow`
  - ta má dvě části:
    - samotný scheduler/exekutor - vystavuje REST end point
    - web front end - vystavuje http/https server - **nepočítal jsem** s tím, že permanentně na serveru poběží (**k diskuzi?**)
- Z toho titulu je potřeba povolit na oba servery průchody přes firewall, a to jak přes VPN, tak po "drátové" síti.
- Považuji za rozumné řešit průchody jak pro scheduler, tak i pro web front end (pro jistotu)

**Rezervované porty**:
- chceme minimalizovat riziko konfliktu, Gemini mi doporučuje range `5001` – `49151` (Designated by IANA for registered third-party applications). Range `49152` až `65535` jsou efemerální porty.
- nepoužité (ale dopředu připravené) porty jsou označené symbolem ⛔

| port     | komponenta  | prostředí                            |
| -------- | ----------- | ------------------------------------ |
| ✅ `8010` | `oflow`     | produkční EDW stage                  |
| ✅ `8020` | `oflow`     | produkční HR stage                   |
| ✅ `8030` | `oflow`     | produkční VODWH stage                |
| ⛔ `8011` | `oflow-web` | web front end, produkční EDW stage   |
| ⛔ `8012` | `oflow-web` | web front end, produkční HR stage    |
| ⛔ `8013` | `oflow-web` | web front end, produkční VODWH stage |

**Poznámka** - původně jsme pro web komponentu plánovali použít porty `8081`, `8082`, `8083` - ale docházelo ke kolizi s McAfee Agent (`macmnsvc`), který na portu `8081` naslouchá. Příznakem byl `curl: (52) Empty reply from server` — TCP spojení se navázalo, ale nepřišla žádná HTTP odpověď. Diagnostika: viz [Port Diagnostics](../../knowledgebase/windows/port-diagnostics.md) — jak zjistit, který proces obsadil port, a jak ověřit, že port skutečně odpovídá.

**Nastavení firewallu:

JST_nížebylonastaveno

**

- spustit `Windows Defender Firewall with advanced security`
  - inbound rules
  - nový rule
    - `port` - rule that controls connections for a tcp or udp port
    - protokol `tcp`
    - specific local ports: `8010,8020,8030,8081,8082,8083`
    - `allow the connection`
    - scope: `domain`, `private`, `public`
    - name: `OFLOW`
- nastaveno na
  - ntinfo404 - Levíček
  - ntinfo403 - Herout

Autentikace: přes bearer token, který se nastavuje jako proměná prostředí (jeden bearer token pro všechny tři).

- **Nastavení na lokálním FW** - to si uděláme sami (povolíme je).
- **Síťová cesta přes VPN** - ať si každý zažádá sám.

## Parametrizace loadu

### Globálně nastavené proměnné prostředí

Následující proměnné prostředí se nastaví globálně "pro všechny". Proměnné které jsou použité

| proměnná                  | komponenta  | proč                                                                                                 |
| ------------------------- | ----------- | ---------------------------------------------------------------------------------------------------- |
| `ONDP_OFLOW_AUTH`         | `oflow`     | **bearer token** pro autentikaci na `oflow` přes REST API; například `yTEWkelwtycdel52$546YYidsake!` |
| `ONDP_OFLOW_WEB_USER`     | `oflow-web` | uživatelské jméno pro web front end: například `admin`                                               |
| `ONDP_OFLOW_WEB_PASSWORD` | `oflow-web` | heslo pro web frontend: například `1235dsaeixserrwet??##$`                                           |
| `PATH`                    | n/a         | doplnit tam `i:\dp\bin` protože tam je "just" task runner                                            |

Kompletní popis všech proměnných prostředí (adresářové `ONDP_*`, oflow, pomocné) viz [Stage Ingest — Environment Variables](../../architecture/080-integration/ingest/file/file-ingest-env-vars.md).

## Task scheduler

Založena skupina `OpsBQ` a pod ní založen task pro startování oflow.Název tasku je `oflow_BIDEV-MAIN_o2czep-stg`


| param     | val                                                                    |
| --------- | ---------------------------------------------------------------------- |
| task name | oflow_BIDEV-MAIN_o2czep-stg                                            |
| trigger   | daily, repeat every 10 minutes                                         |
| run       | `I:\dp\BIDEV-MAIN_o2czep-stg\tenant\edw\bin\prod-run-oflow.bat`        |
| settings  | jediné nastavení bylo "allow to be run on demand", vše ostatní vypnuto |



# Tectia a co dělat po zasmrcení EDW loadu?

- cílově chceme vypnout EDW load
- až se to bude dělat, tak budeme chtít "narovnat" adresářovou strukturu
  - dnes data chodí pod `i:\virt_node\edw\SRCSystems_LND`
  - změníme na
    - `i:\lnd\o2czep` - edw
    - `i:\lnd\o2czhp` - hr
    - `i:\lnd\o2czvp` - vodwh
- další adresáře které vzniknou
  - `i:\arch_data\o2czep`
  - `i:\arch_log\o2czep`
