---
title: 'NTINFO403 — Checklist nastavení pro rozchození EDW loadu'
date: 2026-09-01
source_repo: BIDEV-MAIN_ondp
source_docs:
    - doc/infrastructure/ntinfo40x/prod-ntinfo40x.md
    - doc/infrastructure/ntinfo40x/config-new-stage-repo.md
    - doc/infrastructure/ntinfo40x/dev-sa-ntinfot404.md
    - doc/architecture/090-metadata/git-repositories.md
    - doc/infrastructure/setup-iam.md
---

# NTINFO403 — Checklist nastavení pro rozchození EDW loadu

Shrnutí toho, co je potřeba nastavit na produkčním serveru `NTINFO403` v souvislosti s
paralelním provozem extraktového loadu do Teradaty a Big Query (EDW vertikála).

## 1. Účty

- Doménový technický účet **`su_dp_admin`** (vlastník Richard Švec) — admin na NTINFO02/402/403/404.
- Lokální skupina **`Group_GC`** (Levíček, Strouhal, Herout) — FULL CONTROL na `i:\dp` a `i:\dp.config`.
- `su_info_admin` — práva na `forked` složku (EDW load tam zapisuje).

## 2. Instalace software

- **Git** (poslední verze) — při instalaci `Checkout as-is, commit Unix-style line endings`
  (`core.autocrlf = input`); nastavit `core.whitespace` a na produkci `receive.denyNonFastForwards`.
  Po `git clone` nastavit sdílený přístup (`core.sharedRepository group`, `safe.directory`, NTFS oprávnění).
- **Python 3.13.5** (už je nainstalovaný) + `venv` v `i:\dp\.venv` — jedno sdílené prostředí pro
  všechny loady, `pip install -r requirements.txt`.
- **Google Cloud SDK** — instalace (Windows verze s bundled Python) + `gcloud auth
  activate-service-account` (interaktivní `gcloud init` pod technickým účtem **není potřeba**).
- **oflow** binárka — ruční kopie `oflow-windows-amd64.exe` z `of/dist/` do `i:\dp\bin\`.

## 3. Klony repozitářů (do `i:\dp\`)

```
i:\dp\BIDEV-MAIN_ondp          # sdílený kód (ondp namespace)
i:\dp\BIDEV-MAIN_o2czep-stg    # EDW stage implementace
```

Po klonu vždy:

```
git config core.sharedRepository group
git config --global --add safe.directory <cesta>
git gc
```

## 4. Adresářová struktura dat

```
i:\dp\data_o2czep-stg\
    ├── archive
    ├── forked        # zapisuje EDW load (su_info_admin); zabránit přístupu vývojářům
    ├── log
    ├── persistent
    ├── src\sources
    └── tmp\ctx
```

Na serveru NTINFO403 navíc přejmenovat cizí vertikálu (např. `BIDEV-MAIN_o2czvp-stg@VODWH`),
aby se load omylem nespustil ze složky patřící druhému serveru.

## 5. `.config` pro JSON klíče (Service Account)

```cmd
mkdir i:\dp.config\.config\gcloud.ext_load
mkdir i:\dp.config\keys
set CLOUDSDK_CONFIG=i:\dp.config\.config\gcloud.ext_load

gcloud auth activate-service-account --key-file="i:\dp.config\keys\gcloud.ext_load\o2cz-dp-admin-edw-ext-load-prod.json"
gcloud config set project o2cz-dp-wm-100
gcloud auth list

rem ověření
bq ls --project_id=o2cz-dp-wm-100
```

**Práva na `i:\dp.config`**: číst smí pouze lokální `Administrators` a `su_dp_admin` —
vývojáři (ani přes RDP) nesmí vidět SA klíče.

## 6. Práva na disku (souhrn)

| cesta                                                 | účet/skupina  | práva                   |
| ------------------------------------------------------ | ------------- | ------------------------ |
| `i:\dp\data_o2czep-stg\forked`                        | `su_info_admin` | read + modify + execute |
| `i:\VIRT_NODE\EDW\Source\SrcSystems_LND\ARCHIVE_ASG`  | `su_dp_admin` | read + modify + execute |
| `i:\dp`, `i:\dp.config`                                | `Group_GC`    | FULL CONTROL            |
| `i:\dp.config` (číst obsah)                            | jen `Administrators` + `su_dp_admin` | — |

## 7. Windows Defender výjimky

Přidat do výjimek (bez obsahového skenování):

```
i:\dp\data_o2czep-stg
i:\dp\data_o2czhp-stg
i:\dp\data_o2czvp-stg
i:\lnd\
i:\arch_data\
i:\arch_log\
```

- Složky `BIDEV-MAIN_*` (repo) **nepřidávat** do výjimek — obsahují zdrojový kód, který je rozumné skenovat.
- **Doporučeno přidat pouze `.git` podsložky** uvnitř repozitářů — kvůli file-locku Defenderu
  při `git pull`/`gc` (chyba *"Unlink of file failed"*).

## 8. Firewall

**Outgoing** (HTTPS, port 443) — obvykle jde přes standardní firemní infrastrukturu bez zvláštního
průchodu, ale pokud nefunguje, zajistit průchod na:

| Endpoint                       | Proč                                    |
| ------------------------------- | ---------------------------------------- |
| `bigquery.googleapis.com`      | BigQuery API — dotazy, load dat          |
| `storage.googleapis.com`       | GCS — upload/download souborů na bucket  |
| `oauth2.googleapis.com`        | Obnova OAuth2 tokenů                     |
| `secretmanager.googleapis.com` | Čtení secretů ze Secret Manager          |
| `www.googleapis.com`           | Obecné Google API volání                 |

**Incoming**:

| port     | komponenta  | prostředí            |
| -------- | ----------- | --------------------- |
| `8010`   | `oflow`     | produkční EDW stage   |
| `8011`   | `oflow-web` | web front end EDW (rezerva) |

Windows Defender Firewall — inbound rule `OFLOW`, TCP, specifické porty `8010,8020,8030,8081,8082,8083`,
scope `domain/private/public`, autentikace bearer tokenem (proměnná prostředí).

CloudSQL PROD: `10.32.162.134:5432` — NTINFO403 už má průchod zajištěný (viz seznam serverů v `setup-iam.md`).

## 9. Proměnné prostředí (globálně)

| proměnná                  | komponenta  | proč                                          |
| -------------------------- | ----------- | ---------------------------------------------- |
| `ONDP_OFLOW_AUTH`         | `oflow`     | bearer token pro autentikaci přes REST API     |
| `ONDP_OFLOW_WEB_USER`     | `oflow-web` | uživatelské jméno pro web front end            |
| `ONDP_OFLOW_WEB_PASSWORD` | `oflow-web` | heslo pro web front end                        |
| `PATH`                    | n/a         | doplnit `i:\dp\bin` (obsahuje `just`)          |

## 10. Task Scheduler

Skupina `OpsBQ`, task `oflow_BIDEV-MAIN_o2czep-stg`:

| param     | val                                                                    |
| --------- | ------------------------------------------------------------------------ |
| task name | `oflow_BIDEV-MAIN_o2czep-stg`                                          |
| trigger   | daily, repeat every 10 minutes                                          |
| run       | `I:\dp\BIDEV-MAIN_o2czep-stg\tenant\edw\bin\prod-run-oflow.bat`        |
| settings  | pouze "allow to be run on demand", vše ostatní vypnuto                 |

## 11. IAM (mimo samotný server)

- `GCP_Folder_DATAPLATFORM_EDW_Developer` — GCP práva pro EDW vertikálu.
- Průchod na PROD CloudSQL `10.32.162.134:5432`.
- Průchody na porty oflow na NTINFO403/404 (viz sekce 8).
- ⚠️ Role `SRV-NTINFO403_Server_read` v IAMu **neexistuje** — zatím se řeší jen lokálními
  skupinami přímo na strojích (kontakt: Rostislav Levíček / Jan Herout).

## Otevřené TODO (dosud nedořešené v zdrojové dokumentaci)

- Přesné nastavení práv pro `su_info_admin` na EDW archiv.
- Konzultace se security ohledně přístupu k `i:\dp.config` (Jiří Strouhal).
- Definitivní vlastník/postup pro rotaci a zálohu SA klíčů (`i:\dp.config\keys`).

---

*Zdroj: repozitář `BIDEV-MAIN_ondp`, dokumenty v `doc/infrastructure/ntinfo40x/` a
`doc/infrastructure/setup-iam.md` (stav k 2026-09-01).*
