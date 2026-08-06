# Nálezy z kontroly HR STG repozitáře

**Datum kontroly:** 2026-08-06  
**Kontrolovaný workspace:** HR_prostředí  
**Kontrolovaný repozitář:** BIDEV-MAIN_o2czhp-stg  
**Kontrolovaný dokument:** zapis_priprava_HR_STG.md

## Shrnutí

Byla provedena kontrola souladu mezi dokumentací a aktuálním stavem repozitáře. Většina konfigurací je přepsaná správně pro HR tenant, ale byly nalezeny nesoulady v dokumentaci a několik technických detailů k dořešení.

## Nálezy

### 1. Názvy oflow JSON souborů v zápisu neodpovídají aktuálnímu stavu

**Dopad:** střední  

V zápisu jsou uvedeny názvy `oflow-edw.json`, ale v repozitáři jsou skutečně použity soubory `oflow-hr.json`.

- V dokumentu: `tenant/hr/config-dev/oflow-edw.json`, `tenant/hr/config-prod/oflow-edw.json`
- V repozitáři: `tenant/hr/config-dev/oflow-hr.json`, `tenant/hr/config-prod/oflow-hr.json`

### 2. Git stav uvedený v zápisu je zastaralý

**Dopad:** střední  

Zápis uvádí, že branch byla ahead o 1 commit, ale aktuální stav je synchronizovaný s `origin/develop`.

Aktuální stav při kontrole:
- Branch: `develop`
- HEAD: `67195fa`
- `HEAD -> develop, origin/develop` (bez rozdílu)
- Poslední commit message: `Nepotřebné soubory`

### 3. V dokumentu jsou poškozené cesty s řídicími znaky

**Dopad:** střední  

V části se složkami a příkazy jsou místy neviditelné/řídicí znaky (např. ve slovech `forked`, `archive`, `tmp`, `tenant\hr\bin`), které mohou rozbít copy/paste do shellu.

### 4. Linux cíle v justfile obsahují ne zcela linuxové příkazy

**Dopad:** nízký  

V `tenant/hr/bin/justfile` je v linux části použit `oflow-web-windows-amd64.exe` a v jedné konfiguraci jsou smíšené oddělovače cest. Pro produkční Windows běh to neblokuje, ale pro Linux usage je to kandidát na opravu.

### 5. Servisní účty a key soubory přepsány na HR variantu

**Dopad:** nízký (čeká na vytvoření účtů a klíčů)  

V repozitáři stále zůstávají:
- `edw-hr-load-dev@o2cz-dp-admin.iam`
- `edw-hr-load-prod@o2cz-dp-admin.iam`
- `o2cz-dp-admin-hr-ext-load-dev.json`
- `o2cz-dp-admin-hr-ext-load-prod.json`

Názvy jsou přepsané na HR variantu; je potřeba je vytvořit v IAM/Secret úložišti, pokud ještě neexistují.

## Co bylo ověřeno jako správně

- `.gitignore` obsahuje `data_o2czhp-stg/`.
- DEV a PROD hodnoty v `edw_context_config.yaml` odpovídají HR prostředí (`o2czhd1`, `o2czhp`, příslušné buckety a Cloud SQL connection id).
- Port `8020` je konzistentně použit pro HR oflow API.
- Port `8012` se vyskytuje pouze v `setenv.bat` jako web port.
- Porty `8010` a `8082` zůstaly pouze v komentářové tabulce.
- V repozitáři nebyly nalezeny nežádoucí zbytky `o2czep`, `o2czed1`, `data_o2czep-stg`.

## Doporučené následné kroky

1. Aktualizovat `zapis_priprava_HR_STG.md`, aby odpovídal aktuálním názvům souborů a git stavu.
2. Opravit poškozené cesty v zápisu (řídicí znaky) pro bezpečné kopírování příkazů.
3. Potvrdit rozhodnutí o servisních účtech a key souborech (EDW shared vs HR dedicated).
4. Volitelně upravit Linux sekci v `tenant/hr/bin/justfile`, pokud má být aktivně používaná.
