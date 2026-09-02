# Checklist – příprava HR STG na novém (prázdném) serveru

Sestaveno na základě: `config-new-stage-repo.md`, `git-repositories.md`,
`zapis_priprava_HR_STG.md`, `nalezy_kontroly_HR_STG_2026-08-06.md`,
`Příprava prostředí HR.md`.

Na testu (NTINFOT404) je vše hotové a odzkoušené. Na novém serveru
(produkčního typu, dle vzoru NTINFO403) zatím **není nic** – níže je
kompletní seznam toho, co je potřeba vytvořit/nastavit od nuly.

---

## 1. Git repozitáře – naklonovat

Repo `BIDEV-MAIN_o2czhp-stg` je na testu hotové a napushnuté do
`origin/develop` – na novém serveru stačí klonovat, ne znovu konfigurovat.

```bat
cd /d I:\DP
git clone https://github.com/o2cz-it-dev/BIDEV-MAIN_o2czhp-stg.git
cd BIDEV-MAIN_o2czhp-stg
git switch develop
git pull --ff-only
```

- [ ] Ověřit, že `origin/develop` skutečně obsahuje finální commit(y) (viz
      nález č.2 v `nalezy_kontroly_HR_STG_2026-08-06.md` – potvrdit, že je
      pushnuto, ne jen lokálně commitnuto).
- [ ] Nainstalovat a nastavit **pre-commit** dle
      `doc/infrastructure/install-pre-commit.md` (povinné na všech repech
      s kódem).

### Sdílené/podpůrné repozitáře (podle potřeby role serveru)

Podle `git-repositories.md` – zkontrolovat, zda je server potřebuje také:

- [ ] `BIDEV-MAIN_ondp` – centrální dokumentace/knihovny (namespace `ondp`)
- [ ] `BIDEV-APP-PY_ondp` – zdrojový kód `ondp` knihoven
- [ ] `BIDEV-MAIN_ondp-op-of` – oflow exekutor (externí komponenta, cíl:
      on-prem stage servery)

Zápis `zapis_priprava_HR_STG.md` (sekce „Sdílené komponenty“) zmiňuje na
serveru vedle repa i:

```text
I:\DP\BIDEV-APP-PY_ondp
I:\DP\.venv
I:\DP\bin
I:\DP\.config
```

- [ ] Ověřit, zda `.venv` (Python virtuální prostředí) existuje / je
      potřeba založit a nainstalovat závislosti.
- [ ] Ověřit obsah `I:\DP\bin` a `I:\DP\.config` – jestli jde o sdílené
      binárky/config použité napříč tenanty, nebo jen artefakt z DEV
      testu.

---

## 2. Adresářová struktura – kód

```text
I:\DP\BIDEV-MAIN_o2czhp-stg      # git repo (viz bod 1)
```

- [ ] Zkontrolovat po klonu, že adresář `tenant/hr` obsahuje očekávané
      podsložky: `bin`, `config-dev`, `config-prod`, `powershell`,
      `scripts`.

## 3. Adresářová struktura – data (mimo git)

Datová složka **není** součástí repa (je v `.gitignore`) – je nutné ji
založit ručně:

```bat
mkdir I:\DP\data_o2czhp-stg
mkdir I:\DP\data_o2czhp-stg\archive
mkdir I:\DP\data_o2czhp-stg\forked
mkdir I:\DP\data_o2czhp-stg\log
mkdir I:\DP\data_o2czhp-stg\persistent
mkdir I:\DP\data_o2czhp-stg\src
mkdir I:\DP\data_o2czhp-stg\tmp
mkdir I:\DP\data_o2czhp-stg\tmp\ctx
```

- [ ] Ověřit výsledek pomocí `tree I:\DP\data_o2czhp-stg` (pozor na
      poškozené cesty s řídicími znaky zmíněné v nálezech – raději
      přepsat příkazy ručně, nekopírovat ze starých zápisů).

## 4. Oprávnění / AD skupiny

- [ ] Zjistit/ověřit název skupiny **HR developers** na novém serveru
      (na NTINFO403 nebylo jisté přesné jméno – otevřená otázka).
- [ ] Nastavit, že do složky `I:\DP\data_o2czhp-stg\forked` mají přístup
      **pouze** HR developers + potřebné servisní účty + administrátoři –
      **běžní vývojáři (obecná skupina developers) tam nesmí.**
- [ ] Pamatovat na Windows chování: při kombinaci 2 skupin na ACL vyhrává
      nejnižší oprávnění, takže HR developers nesmí být zároveň členy
      obecné skupiny developers, jinak jim to právo „shodí“.
- [ ] Konzultovat finální nastavení práv (v zápisu je to explicitně
      necháno na společnou kontrolu s Rosťou).

## 5. Konfigurace prostředí (.env / setenv.bat)

Podle role serveru:

- **Test/DEV server** – z `tenant/hr/bin/env.template.ntinfot404`
  vytvořit vlastní `.env`, doplnit:
  - [ ] `ROOT_DIR`
  - [ ] `ONDP_OFLOW_API_PORT` (vlastní přidělený rozsah, ne produkční 8020)
  - [ ] `ONDP_OFLOW_WEB_PORT` (vlastní přidělený rozsah, ne produkční 8012)

- **Produkční server** – používá `tenant/hr/bin/setenv.bat` (už hotový
  v repu), klíčové hodnoty už jsou nastavené:
  ```bat
  SET TENANT_NAME=hr
  SET TENANT_REPO_DIR=I:\dp\BIDEV-MAIN_o2czhp-stg
  set ONDP_DATA_DIR_NAME=data_o2czhp-stg
  set ONDP_TENANT_DATA_DIR=I:\dp\%ONDP_DATA_DIR_NAME%
  set ONDP_STG_SNIFF_DIR=I:\VIRT_NODE\EDW_HR\Source\...
  set ONDP_ARCHIVE_DIR=I:\VIRT_NODE\EDW_HR\Source\SrcSystems_LND\Archive\ASG_HR_ARCHIVE
  set ONDP_OFLOW_API_PORT=8020
  set ONDP_OFLOW_WEB_PORT=8012
  ```
  - [ ] Ověřit, že cesty `ONDP_STG_SNIFF_DIR` a `ONDP_ARCHIVE_DIR`
        (`I:\VIRT_NODE\EDW_HR\...`) na novém serveru **skutečně existují**
        a jsou namapované (jde o síťový/virtuální disk, ne lokální
        adresář).

## 6. Servisní účty a klíče

Účty/klíče jsou v konfiguraci již přejmenované na HR variantu, ale
**pravděpodobně ještě neexistují** a je potřeba je vytvořit / potvrdit:

| Prostředí | Servisní účet | Klíčový soubor |
|---|---|---|
| dev | `edw-hr-load-dev@o2cz-dp-admin.iam` | `o2cz-dp-admin-hr-ext-load-dev.json` |
| prod | `edw-hr-load-prod@o2cz-dp-admin.iam` | `o2cz-dp-admin-hr-ext-load-prod.json` |

- [ ] Ověřit v IAM, že tyto servisní účty existují (nebo je vytvořit).
- [ ] Vygenerovat/zajistit JSON klíče pro tyto účty.
- [ ] **Umístit klíče do správné složky na serveru** – v dostupné
      dokumentaci není explicitně napsaná cílová cesta klíčů; před
      nasazením je nutné ji ověřit (typicky vedle repa nebo v
      `I:\DP\.config` – viz bod 1) a případně doplnit do
      `setenv.bat`/`.env` proměnnou typu `GOOGLE_APPLICATION_CREDENTIALS`.
- [ ] Potvrdit s Honzou/Jirkou, zda EDW servisní účty/klíče náhodou
      nejsou (dočasně) použitelné i pro HR, nebo musí být striktně
      oddělené (otevřená otázka ze zápisu).

## 7. Cloud infrastruktura (GCP) – ověřit existenci

Nejde o nic, co se zakládá na serveru, ale je to blokující předpoklad:

```text
o2czhd1                                  (dev projekt)
o2czhp                                   (prod projekt)
o2czhd1-ext-in / o2czhp-ext-in           (buckety)
o2czhd1_opr / o2czhp_opr                 (Cloud SQL DB)
o2czhd1.europe-west4.cloud-sql-opr       (Cloud SQL conn id, dev)
o2czhp.europe-west4.cloud-sql-opr        (Cloud SQL conn id, prod)
```

- [ ] Ověřit se s Jirkou Bodlákem / přes Terraform pipeline, že vše
      existuje, případně nechat založit.
- ⚠️ Připomínka z tvé user memory: produkční nasazení poběží pod **jiným**
  GCP/BQ projektem než testovací `o2czed1` – project ID nechat
  konfigurovatelné, nehardcodovat.

## 8. Task Scheduler

- [ ] Vytvořit task, který spouští:
  ```text
  I:\DP\BIDEV-MAIN_o2czhp-stg\tenant\hr\bin\prod-run-oflow.bat
  ```
- [ ] Task zatím **nenechávat běžet trvale** – jen jednorázově spustit
      jako test.

## 9. Test po nasazení

Očekávaný výsledek jednorázového spuštění:

- [ ] oflow se spustí a poslouchá na portu `8020`,
- [ ] používá HR konfiguraci (`running_pool_cap: 5`),
- [ ] nezasahuje do EDW portu `8010`,
- [ ] nemá co zpracovávat (prázdný běh),
- [ ] log vznikne v `I:\DP\data_o2czhp-stg\log\hr-oflow.log`,
- [ ] stav vznikne v
      `I:\DP\data_o2czhp-stg\persistent\oflow\hr-oflow-state.json`.
- [ ] Po testu oflow korektně vypnout.

---

## 10. Otevřené otázky k dořešení před ostrým nasazením

Přenesené z `zapis_priprava_HR_STG.md`, stále nezodpovězené:

- [ ] Přejmenovat `edw_context_config.yaml` a `oflow-edw.json`/
      `oflow-hr.json` – potvrdit finální název (nález: v repu už je
      `oflow-hr.json`, dokumentace to ještě nereflektovala).
- [ ] Jsou EDW servisní účty/klíče dočasně použitelné pro HR, nebo musí
      být od začátku oddělené?
- [ ] Je `ONDP_STG_SNIFF_DIR` cesta na novém serveru správná/kompletní
      (na testu byla zmíněna jako rozbitá/needit)?
- [ ] Přesný název HR developers skupiny na cílovém serveru.
- [ ] Kam přesně uložit servisní klíčové JSON soubory (cesta není v
      dokumentaci fixovaná).
