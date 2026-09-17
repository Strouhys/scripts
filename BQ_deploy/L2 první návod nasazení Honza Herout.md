# Pre-rekvizity

- WSL a funkční prostředí pod ním
- ve WSL máme repozitáře ze ktereých nasazujeme, a migrační repo
- provedena customizace WSL podle starter kitu


# PŘÍPRAVNÉ KROKY


- spustíme si WSL, a nainstalujeme si utilitu pro přenos metadat z TD do cloudsql
  ```bash
  # přepneme se do repa s kódem, git pull
  cd ~/bi_domain/BIDEV-MAIN_ondp
  git switch main
  git pull

  # instalace
  cd ~/bi_domain/BIDEV-MAIN_ondp/ondp-opr-migr
  uv build
  uv tool install ../dist/ondp_opr_migr-0.1.2-py3-none-any.whl

  # konfigurace
  ondp-opr-migr config --setup

  # SPUSTÍ SE WIZARD A ZADÁME TOTO 
  # Teradata host: stiskni ENTER, nic neměň
  # Teradata username: zadej logon, ve tvaru x0....
  # Teradata password: zadej heslo do domény (nebo heslo do Teradaty pokud si ho pamatuješ)
  # na následujícím dialogu: 
  #   TAB, a vybereš buď LDAP (zadal jsi heslo do domény) nebo TD (zadal jsi heslo do Teradaty)
  # na následujícím dialogu:
  #   TAB a vyber TERA
  # CloudSQL PostgreSQL username - NECHAT PRÁZDNÉ
  ```

- jdeme na produkci, a zastavíme dag dag20__conductor, a také všechny ostatní dag20 dagy:
  <https://44f7f5deee7e48eb9427f7ffc787d997-dot-europe-west4.composer.googleusercontent.com/dags>



# Kroky na WINDOWS podobně jako pro stage

1) připravit snímek **DVOU** tablek z Teradaty, zdrojová databáze AP_SDA; jde o to dostat data do projektu o2czem1; viz podsložka 260915-marts
   - sfa_account_dn1
   - hwp_credit_hierarchy
2) nasazení z deploy repa jak jsme zvyklí; přeplach **jedné** tabulky z TD podle konfigurace v deployment repu:
  ```
  BIDEV-MAIN_o2czep-bq-deploy/pkg/260903R/260903-sfa-marty
  ```
3) nasazení datafixu, pro tabulku `hwp_credit_hierarchy` se mění povinnosti sloupců, nasadit skripty z podadresáře `BIDEV_hwp_daily`, Miro Frajbiš tam nachystal nasazovací skript `_deployment_\runme_for_bq.bat`

# KROKY POD WSL

## získání metadat

- spustíme utilitu ondp-opr-migr
  ```bash
  cd ~/bi_domain/BIDEV-MAIN_o2czep-bq-deploy/pkg/260915R-l2
  ondp-opr-migr export-mart-stat
  ```
- zobrazí se jednoduchý wizard
- vybereme si oba dva marty které nasazujeme
  - dag20__sda__sda_hwp_daily
  - dag20__sda__sfa_account_dn1
- vznikne datový soubor `~/bi_domain/BIDEV-MAIN_o2czep-bq-deploy/pkg/260915R-l2/mart_stat.dat`


## KONTROLA 1: máme metadata

Soubor nesmí být prázdný, vidím oba datamarty, vidím poslední run_dttm 2026-09-14 23:59:59

```bash
vim ~/bi_domain/BIDEV-MAIN_o2czep-bq-deploy/pkg/260915R-l2/mart_stat.dat
```

## KONTROLA 2: ani jeden z martů nich NEMÁ na produkci žádný záznam

```bash
psql \
  -h lxpgdp401.gcp.to2cz.cz -p 5432 -U postgres -d "o2czep_opr" \
  -c "
    select mart_name,max(run_dttm),count(1) 
    from opr_data.mart_stat 
    where mart_name in ('dag20__sda__sda_hwp_daily'.'dag20__sda__sfa_account_dn1') 
    group by mart_name
    "
```

## IMPORT datového souboru s historií

```bash
cd ~/bi_domain/BIDEV-MAIN_o2czep-bq-deploy/pkg/260915R-l2
psql \
  -h lxpgdp401.gcp.to2cz.cz -p 5432 -U postgres -d o2czep_opr \
  -c "\copy opr_data.mart_stat FROM STDIN" < mart_stat.dat
```

## KONTROLA 3: očekávám že uvidím dva datamarty

```bash
psql \
  -h lxpgdp401.gcp.to2cz.cz -p 5432 -U postgres -d "o2czep_opr" \
  -c "
    select mart_name,max(run_dttm),count(1) 
    from opr_data.mart_stat 
    where mart_name in ('dag20__sda__sda_hwp_daily'.'dag20__sda__sfa_account_dn1') 
    group by mart_name
    "
```

# NASAZENÍ NA bucket

## sdílený kód

```bash
cd ~/bi_domain/BIDEV-APP-PY_ondp
git switch main
git pull
git status

~/bi_domain/BIDEV-MAIN_ondp/doc/infrastructure/airflow/deployment/bucket/airflow-deploy prod BIDEV-APP-PY_ondp
```

## dag20

Nasadit, počkat až to dojede.

```bash
cd ~/bi_domain/BIDEV-MAIN_o2czep-dag20
git switch main
git pull
git status

~/bi_domain/BIDEV-MAIN_ondp/doc/infrastructure/airflow/deployment/bucket/airflow-deploy prod BIDEV-MAIN_o2czep-dag20
```


# SPUŠTĚNÍ DAG20

- jdeme na produkci, a spustíme dag dag20__conductor, a také všechny ostatní dag20 dagy
  https://44f7f5deee7e48eb9427f7ffc787d997-dot-europe-west4.composer.googleusercontent.com/dags
