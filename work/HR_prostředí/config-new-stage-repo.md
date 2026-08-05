# Návod na konfigurace STG repository

Tento návod popisuje, co je potřeba změnit při přípravě další vertikály.

## Referencované zdroje

- [doc/architecture/090-metadata/git-repositories.md](../../architecture/090-metadata/git-repositories.md) - jaké repa máme
- [./prod-ntinfo40x.md](./prod-ntinfo40x.md) - jak je postavená produkce
- [./dev-sa-ntinfot404.md](./dev-sa-ntinfot404.md) - jak je postavený DEV server


## Co udělat

- seznam repozitářů: **`doc/architecture/090-metadata/git-repositories.md`**
  - je potřeba nasetovat repo `BIDEV-MAIN_o2czhp-stg` tak, aby se tam dalo vyvíjet a provozovat - **změnnu udělat v develop branchi!** - připadný test pojedeme na produkci z develop branche; repo existuje, založil jsem develop branch (s nasatavením pro generátor!)
    - opravit `.gitignore` - zadat do něj adresář pro datovou složku, `data_o2czhp-stg`
    - upravit adresář `tenant` v repu, druhá úroveň vnoření není `tenant/edw`, ale `tenant/hr`; adresář vznikne kopií z repa `BIDEV-MAIN_o2czepstg-edw`
    - editace konfigurace
      - `BIDEV-MAIN_o2czhp-stg/tenant/hr/config-dev/edw_context_config.yaml`
        - mění se názvy projektů a bucketů `ed1=>hd1`
        - mění se: `gcsql_fq_conn_id: "o2czhd1.europe-west4.cloud-sql-opr"` - protože connection na postgress je jiná
      - `BIDEV-MAIN_o2czhp-stg/tenant/hr/config-dev/oflow-edw.json`
        - zaměnit `edw` za `hr` "konzistentně všude"
        - nastavit jiný cap na počet tasků, stačí 5
      - obdobně pro `BIDEV-MAIN_o2czhp-stg/tenant/hr/config-prod` - měníš produkční názvy, ne dev názvy
    - editace BAT souborů které jezdí na produkci
      - `BIDEV-MAIN_o2czhp-stg/tenant/hr/bin/prod-run-oflow.bat` - tento spouští oflow
        - `edw => hr` - "všude"
        - `BIDEV-MAIN_o2czep-stg => BIDEV-MAIN_o2czhp-stg` - "všude"
      - `BIDEV-MAIN_o2czvp-stg/tenant/hr/bin/prod-stg-ingest.bat` - méně důležité, spouští jeden load (z ruky, nejezdí běžně loadem, admin zásahy...)
      - `BIDEV-MAIN_o2czvp-stg/tenant/hr/bin/setenv.bat` - **proměnné prostředí**
        - `TENANT_NAME`
        - `TENANT_REPO_DIR`
        - `ONDP_DATA_DIR_NAME`
        - `ONDP_ARCHIVE_DIR` - !!! - `i:\VIRT_NODE\EDW_HR\Source\SrcSystems_LND\Archive\ASG_HR_ARCHIVE`
        - `ONDP_OFLOW_API_PORT=8020`
        - `ONDP_OFLOW_WEB_PORT=8012`
      - `BIDEV-MAIN_o2czhp-stg/tenant/hr/bin/env.template.ntinfot404`
        - `ROOT_DIR`
        - `DATA_DIR_NAME`
        - `TENANT_NAME`

- nastavení pro NTINFO403: **`doc/infrastructure/ntinfo40x/prod-ntinfo40x.md`**
  - **přípravná fáze**
    - udělat klon HR repository
    - zkontrolovat nastavení (uvnitř repository) do `I:\DP\BIDEV-MAIN_o2czhp-stg`
    - připravit adresářovou strukturu `I:\DP\data_o2czhp-stg` podle vzoru z `I:\DP\data_o2czep-stg` - prázdné adresáře; tady je "tree"
      ```
        ntinfo403@i:/dp/data_o2czhp-stg
        ❯ tree -L 1
        .
        ├── archive
        ├── forked                      # tady je potřeba nastavit práva tak, aby se k tomu NEDOSTALI VÝVOJÁŘI kromě skupiny XXXXXXXX
        ├── log
        ├── persistent
        ├── src
        └── tmp
            └── ctx
      ```
    - **přípravná fáze 2**
      - připravit v task scheduleru task, který spouští "oflow"
      - pokusit se ho jednou spustit (naprázdno), měl by se spustit a "nemá co dělat"
      - NENECHÁVAT ho zatím běžet; je to fakt jenom "rychlý test"
