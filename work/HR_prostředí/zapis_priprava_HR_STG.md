# Příprava nového prostředí HR STG – průběžný zápis

**Datum:** 4. 8. 2026  
**Repo:** `BIDEV-MAIN_o2czhp-stg`  
**Pracovní branch:** `develop`  
**Cíl:** připravit samostatné HR STG prostředí podle vzoru EDW STG.

---

## 1. Co je hotové

### Repository

- Repo `BIDEV-MAIN_o2czhp-stg` bylo nalezeno a naklonováno lokálně.
- Byla vytvořena a používána lokální branch `develop`, která sleduje `origin/develop`.
- Jako vzor bylo použito repo `BIDEV-MAIN_o2czep-stg`.
- Z adresáře `tenant/edw` byla vytvořena nová struktura:

```text
tenant/hr
├── bin
├── config-dev
├── config-prod
├── powershell
└── scripts
```

### `.gitignore`

V kořeni HR repa byl vytvořen soubor `.gitignore` s obsahem:

```gitignore
data_o2czhp-stg/
```

Tím je zajištěno, že provozní datová složka nebude verzována v Gitu.

### DEV konfigurace

Upraven soubor:

```text
tenant/hr/config-dev/edw_context_config.yaml
```

Nastaveno:

```yaml
slot_reservation_project_name: "o2cz-dp-wm-200"
lnd_project_name: "o2czhd1"
lnd_bucket_name: "o2czhd1-ext-in"
gcsql_db_name: "o2czhd1_opr"
gcsql_fq_conn_id: "o2czhd1.europe-west4.cloud-sql-opr"
```

Servisní účet zůstal zatím původní:

```yaml
gcsql_db_user: "edw-ext-load-dev@o2cz-dp-admin.iam"
```

Upraven také nadpis konfigurace z EDW na HR.

### DEV oflow konfigurace

Upraven soubor:

```text
tenant/hr/config-dev/oflow-edw.json
```

Nastaveno:

```json
{
  "log_file_name": "{{ .ONDP_TENANT_LOG_DIR }}/hr-oflow.log",
  "state_file": "{{ .ONDP_TENANT_PERSISTENT_DATA_DIR }}/oflow/hr-oflow-state.json",
  "api_port": {{ .ONDP_OFLOW_API_PORT }},
  "running_pool_cap": 5
}
```

### PROD konfigurace

Upraven soubor:

```text
tenant/hr/config-prod/edw_context_config.yaml
```

Nastaveno:

```yaml
slot_reservation_project_name: o2cz-dp-wm-100
lnd_project_name: o2czhp
lnd_bucket_name: o2czhp-ext-in
gcsql_db_name: "o2czhp_opr"
gcsql_fq_conn_id: "o2czhp.europe-west4.cloud-sql-opr"
```

Servisní účet zůstal zatím původní:

```yaml
gcsql_db_user: "edw-ext-load-prod@o2cz-dp-admin.iam"
```

### PROD oflow konfigurace

Upraven soubor:

```text
tenant/hr/config-prod/oflow-edw.json
```

Nastaveno:

```json
{
  "log_file_name": "{{ .ONDP_TENANT_LOG_DIR }}/hr-oflow.log",
  "state_file": "{{ .ONDP_TENANT_PERSISTENT_DATA_DIR }}/oflow/hr-oflow-state.json",
  "api_port": 8020,
  "running_pool_cap": 5
}
```

### Produkční BAT soubory

Upraveny:

```text
tenant/hr/bin/prod-run-oflow.bat
tenant/hr/bin/prod-stg-ingest.bat
tenant/hr/bin/setenv.bat
```

Hlavní hodnoty v `setenv.bat`:

```bat
SET TENANT_NAME=hr
SET TENANT_REPO_DIR=I:\dp\BIDEV-MAIN_o2czhp-stg

set ONDP_DATA_DIR_NAME=data_o2czhp-stg
set ONDP_TENANT_DATA_DIR=I:\dp\%ONDP_DATA_DIR_NAME%

set ONDP_STG_SNIFF_DIR=I:\VIRT_NODE\EDW_HR\Source\________SrcSystems_LND_______________
set ONDP_STG_SNIFF_FORKED_DIR=%ONDP_TENANT_DATA_DIR%orked
set ONDP_ARCHIVE_DIR=I:\VIRT_NODE\EDW_HR\Source\SrcSystems_LND\Archive\ASG_HR_ARCHIVE

set ONDP_OFLOW_API_PORT=8020
set ONDP_OFLOW_WEB_PORT=8012
```

Port `8012` byl uživatelem ověřen.

### DEV šablony prostředí

Upraveny:

```text
tenant/hr/bin/env.template.ntinfot404
tenant/hr/bin/env.template.linux
```

Základní HR hodnoty:

```env
ROOT_DIR=...BIDEV-MAIN_o2czhp-stg
DATA_DIR_NAME=data_o2czhp-stg
TENANT_NAME=hr
ONDP_TENANT_ROOT=...tenant/hr
```

Porty v šabloně pro NTINFOT404 zůstaly záměrně nevyplněné, protože každý vývojář má použít svůj přidělený rozsah.

### PowerShell skripty

Upraveny:

```text
tenant/hr/powershell/status.ps1
tenant/hr/powershell/cap-to-zero.ps1
tenant/hr/powershell/cap-to-default.ps1
tenant/hr/powershell/shutdown.ps1
```

Ve všech byl změněn kontext EDW → HR a port:

```powershell
$Port = 8020
```

### Kontroly

Byly provedeny kontroly výskytů:

- `o2czep` – nenalezeno
- `o2czed1` – nenalezeno
- `data_o2czep-stg` – nenalezeno
- `8010` – zůstal jen v komentářové tabulce a původně v PROD JSON, kde byl následně změněn na `8020`
- `8020` – výskyty odpovídají HR API portu
- `8012` – výskyt pouze v `setenv.bat`
- `8082` – zůstal pouze v komentářové tabulce

Byly opraveny také chybějící koncové nové řádky u kontrolovaných souborů.

### Git

Byl vytvořen lokální commit:

```text
Prepare HR stage repository configuration
```

Poslední potvrzený stav:

```text
On branch develop
Your branch is ahead of 'origin/develop' by 1 commit.
nothing to commit, working tree clean
```

Není potvrzeno, zda už proběhl `git push`.

---

## 2. Co ještě zkontrolovat před pushnutím / nasazením

### Git a repo

- [ ] Ověřit aktuální stav:

```bat
git status
git log -1 --oneline
```

- [ ] Pokud commit ještě není na GitHubu, provést:

```bat
git push origin develop
```

- [ ] Ověřit na GitHubu, že commit skutečně existuje v branchi `develop`.

### Názvy souborů

Stále zůstávají názvy:

```text
edw_context_config.yaml
oflow-edw.json
```

To může být záměrně kvůli kompatibilitě, ale je vhodné potvrdit s Honzou, zda se soubory nemají později přejmenovat na HR variantu.

### Servisní účty a klíče

Zatím zůstaly původní EDW názvy:

```text
edw-ext-load-dev@o2cz-dp-admin.iam
edw-ext-load-prod@o2cz-dp-admin.iam
o2cz-dp-admin-edw-ext-load-dev.json
o2cz-dp-admin-edw-ext-load-prod.json
```

Je potřeba potvrdit, zda:

- mají být sdílené i pro HR,
- nebo existují samostatné HR servisní účty a klíče.

### Linux template

V `env.template.linux` zůstala cesta:

```env
ONDP_BINUTILS_DIR=${HOME}/o2-workspaces/BIDEV-MAIN_ondp/feature-og/ondp/tenants/edw/bin
```

Tato cesta vypadá jako lokální vývojářská cesta autora šablony. Je vhodné ji ověřit s Honzou. Pro NTINFOT404 není prioritní, ale neměla by se považovat za obecně platnou bez potvrzení.

### Cloud infrastruktura

Ověřit, že skutečně existují a jsou dostupné:

```text
o2czhd1
o2czhp
o2czhd1-ext-in
o2czhp-ext-in
o2czhd1_opr
o2czhp_opr
o2czhd1.europe-west4.cloud-sql-opr
o2czhp.europe-west4.cloud-sql-opr
```

Pokud něco chybí, řeší se přes Terraform/pipeline a pravděpodobně přes Jirku Bodláka.

---

## 3. Co připravit na NTINFOT404

NTINFOT404 slouží pro vývojový test.

- [ ] Naklonovat repo do vlastního pracovního adresáře.
- [ ] Přepnout na `develop`.
- [ ] Vytvořit vlastní `.env` z:

```text
tenant/hr/bin/env.template.ntinfot404
```

- [ ] Doplnit vlastní:

```env
ROOT_DIR
ONDP_OFLOW_API_PORT
ONDP_OFLOW_WEB_PORT
```

- [ ] Použít porty z vlastního přiděleného rozsahu, nikoli produkční `8020/8012`.
- [ ] Ověřit, že se načte HR tenant a DEV konfigurace.
- [ ] Ověřit, že se dá spustit oflow bez kolize s ostatními vývojáři.
- [ ] Následně nechat základ otestovat Zdeňkem Kalinou.

---

## 4. Co připravit na NTINFO403

NTINFO403 je produkční server pro HR STG.

### Repo

Pokud repo na serveru ještě není:

```bat
cd /d I:\DP
git clone https://github.com/o2cz-it-dev/BIDEV-MAIN_o2czhp-stg.git
cd BIDEV-MAIN_o2czhp-stg
git switch develop
git pull --ff-only
```

Pokud už existuje:

```bat
cd /d I:\DP\BIDEV-MAIN_o2czhp-stg
git switch develop
git pull --ff-only
```

### Datová složka

Připravit:

```text
I:\DP\data_o2czhp-stg
├── archive
├── forked
├── log
├── persistent
├── src
└── tmp
    └── ctx
```

Příkazy:

```bat
mkdir I:\DP\data_o2czhp-stg
mkdir I:\DP\data_o2czhp-stgrchive
mkdir I:\DP\data_o2czhp-stgorked
mkdir I:\DP\data_o2czhp-stg\log
mkdir I:\DP\data_o2czhp-stg\persistent
mkdir I:\DP\data_o2czhp-stg\src
mkdir I:\DP\data_o2czhp-stg	mp
mkdir I:\DP\data_o2czhp-stg	mp\ctx
```

Kontrola:

```bat
tree I:\DP\data_o2czhp-stg
```

### Oprávnění

Zvlášť zkontrolovat složku:

```text
I:\DP\data_o2czhp-stgorked
```

Běžní vývojáři se do ní nemají dostat. Přístup mají mít pouze:

- HR developers skupina,
- potřebné servisní účty,
- administrátoři.

Finální nastavení práv projít společně s Rosťou.

### Sdílené komponenty

Ověřit existenci:

```text
I:\DP\BIDEV-APP-PY_ondp
I:\DP\.venv
I:\DPin
I:\dp.config
```

### Task Scheduler

- [ ] Připravit nový task pro HR oflow.
- [ ] Spouštěný BAT:

```text
I:\DP\BIDEV-MAIN_o2czhp-stg	enant\hrin\prod-run-oflow.bat
```

- [ ] Pro první test task pouze jednorázově spustit.
- [ ] Nenechávat zatím trvale běžet.

### První bezpečný test

Očekávání:

- oflow se spustí,
- poslouchá na portu `8020`,
- používá HR konfiguraci,
- kapacita je `5`,
- nevstupuje do EDW portu `8010`,
- nemá co zpracovávat,
- log vzniká v:

```text
I:\DP\data_o2czhp-stg\log\hr-oflow.log
```

- stav vzniká v:

```text
I:\DP\data_o2czhp-stg\persistent\oflow\hr-oflow-state.json
```

Po testu oflow korektně vypnout.

---

## 5. Otevřené otázky

- [ ] Mají se přejmenovat soubory `edw_context_config.yaml` a `oflow-edw.json`, nebo se názvy zachovávají?
- [ ] Jsou EDW servisní účty a klíče správně použitelné i pro HR?
- [ ] Je Linux `ONDP_BINUTILS_DIR` správný?
- [ ] Existují všechny HR cloudové zdroje?
- [ ] Jak se přesně jmenuje HR developers skupina na NTINFO403?
- [ ] Je cesta `ONDP_STG_SNIFF_DIR` záměrně dočasně „rozbitá“ i pro HR?
- [ ] Je `ONDP_OFLOW_WEB_PORT=8012` potvrzen i proti aktuální konfiguraci na serveru? Uživatel uvedl, že ano.
- [ ] Je potřeba doplnit nebo upravit pre-commit konfiguraci v HR repu?

---

## 6. Doporučené pokračování zítra

1. Ověřit, zda byl commit pushnut do `origin/develop`.
2. Ověřit cloudové projekty, buckety, Cloud SQL a connection IDs.
3. Ověřit servisní účty a klíče.
4. Naklonovat repo na NTINFOT404 a provést DEV test.
5. Po úspěšném DEV testu připravit NTINFO403.
6. Vytvořit datovou strukturu.
7. Společně s Rosťou nastavit oprávnění.
8. Připravit Task Scheduler.
9. Provést jednorázový prázdný start HR oflow.
10. Zapsat výsledek testu a případné chyby.

---

## 7. Důležité rozlišení

```text
I:\DP\BIDEV-MAIN_o2czhp-stg
```

je Git repository s kódem a konfigurací.

```text
I:\DP\data_o2czhp-stg
```

je provozní datový prostor pro logy, stav, dočasné soubory a zpracovávaná HR data. Proto je tato složka uvedena v `.gitignore`.
