# Manuál – nasazení STG / BQ

_Pracovní postup pro nasazení – revidovaná verze pro zaškolení nového kolegy_

## Účel dokumentu

Tento dokument popisuje strukturovaný postup pro přípravu, spuštění a kontrolu nasazení v prostředí STG / BQ. Je psán tak, aby podle něj dokázal nasazení provést i kolega bez předchozí zkušenosti s tímto postupem.

## 0. Předpoklady – přístupy a nástroje (před prvním nasazením)

Než je možné podle tohoto manuálu poprvé nasazovat, musíme mít funkční:

- [ ] VPN připojení do firemní sítě.
- [ ] RDP přístup na server 403/404 (přihlašovací účet a heslo).
- [ ] Nainstalovaný a nakonfigurovaný Google Cloud SDK (gcloud, bq CLI) na lokální stanici.
- [ ] Přidělená IAM oprávnění v GCP projektu pro čtení/zápis do BigQuery (dataset stg_data apod.).
- [ ] Přístup do webového/Powerschell rozhraní Oflow (Nastavené pro svůj lokál).
- [ ] Přístup (read/write) do git repozitářů uvedených v kapitole 1.

## Rychlý přehled postupu

- [ ] Potvrdit, že E9/E29 neběží, a že proběhla migrace dat na EM1 viz document migrace z TD do EM1 (Aplikace Rosti Levíčka  )
- [ ] Zastavit BQ STG zpracování přes oflow změnou capacity na 0.
- [ ] Na 403 při nasazení změn na repository udělat git pull na stg a na app_data.
- [ ] Zkontrolovat repozitáře, tag/release a konfigurační soubory.
- [ ] Na lokálu spustit PowerShell, zapnout proxy a ověřit gcloud účet/projekt.
- [ ] Spustit preplach_bq.bat (nebo runme_for_bq.bat) ze správného adresáře a zapisovat výstup do logu.
- [ ] Zkontrolovat log – nesmí obsahovat chybové hlášky (viz kapitola 10).
- [ ] Po nasazení provést shutdown Oflow .
- [ ] Informovat DevOps / Teradata, že BQ část je hotová.

## Důležité pravidlo

**BQ STG zastavovat až po potvrzení, že E9/E29 neběží a že se dokončila migrace dat na EM1. Do té doby do běhu STG nezasahovat.**

## 1. Předpoklady a používané komponenty

Postup počítá s těmito komponentami a cestami, každý uživatel má jiné cesty:

| Oblast | Poznámka / cesta |
| --- | --- |
| Lokální stanice | PowerShell pro spuštění proxy, kontrolu gcloud a spuštění preplach_bq.bat. |
| oflow APP – PowerShell | C:\Users\x0577063\scripts\PowerShell_403\oflow_2_5.bat |
| oflow WEB – CMD | C:\Users\x0577063\scripts\bin\just web-403 |
| Deploy repo / balíčky | C:\Users\x0577063\BIDEV-MAIN_o2czep-bq-deploy\pkg |
| STG repo na 403 | i:\dp\BIDEV-MAIN_o2czep-stg\ (přístup přes RDP na server 403) |
| VIRT_NODE varianta (UNC) | \\ntinfot404\VIRT_NODE\temp |
| VIRT_NODE varianta (mapovaný disk) | F:\VIRT_NODE\temp\... (disk F: je na serveru ntinfo404 namapován na stejné umístění jako výše uvedené UNC) |
| Výchozí DEV projekt | o2cz-dp-wm-200 |

## 2. Příprava před nasazením

Před vlastním nasazením je potřeba omezit běh zpracování tak, aby se nespouštěly další joby a zároveň doběhlo vše, co už je rozpracované.

### 2.1 Zastavení E9/E29 a BQ STG

- [ ] Ověřit s odpovědnou osobou, že E9/E29 neběží.
- [ ] Ověřit, že se dokončila migrace dat na EM1 ().
- [ ] Ve webovém/powerschell rozhraní oflow změnit capacity z 30 na 0.
- [ ] Potvrdit změnu přes Apply.
- [ ] Počkat, až doběhnou rozpracované STG joby – stav zkontrolovat v oflow WEB (viz kapitola 3.2), všechny joby musí mít status "Finished"/"OK" (ne "Running").
**Poznámka:** BQ STG není nutné zastavovat přes Task Scheduler. Pro tento postup stačí změnit kapacitu ve webovém rozhraní oflow na 0.

## 3. Příprava monitoringu na lokálu

Na lokálním počítači si před nasazením připravím oflow APP a oflow WEB pro monitoring stavu zpracování.

### 3.1 Spuštění oflow APP – PowerShell

```
cd C:\Users\x0577063\scripts\PowerShell_403\oflow_2_5.bat
```

### 3.2 Spuštění oflow WEB – z CMD

```
cd C:\Users\x0577063\scripts\bin
just web-403
```

Oflow web běží na http://localhost:8011/

## 4. Kontrola repozitářů a release

Před spuštěním nasazovacích BAT souborů je potřeba ověřit, že jsou připravené správné balíčky a že na serveru 403 je stažený správný release.

### 4.1 Lokální deploy repo

Balíčky od vývojářů se připraví do deploy repozitáře, typicky do adresáře:

```
C:\Users\x0577063\BIDEV-MAIN_o2czep-bq-deploy\pkg
git pull
git status
git push
```

### 4.2 STG repo na serveru 403

Na server 403 se přihlásit přes RDP. V otevřeném okně CMD (ne PowerShell) přejít do STG repozitáře a provést aktualizaci:

```
cd /d i:\dp\BIDEV-MAIN_o2czep-stg
git pull
git log -n3
```

**Kontrola TAGu:** Z výstupu git log -n3 zkontroluji, že odpovídá správný tag/release, který se má nasazovat. Po kontrole na 403 se vracím zpět na lokální stanici.

## 5. Kontrola konfiguračních souborů

Před spuštěním BAT souborů je vhodné zkontrolovat hlavně seznam objektů/tabulek, které se budou zakládat nebo přelévat.

- [ ] Zkontrolovat seznam tabulek/objektů v konfiguračním souboru.

## 6. Spuštění preplach_bq.bat z PowerShellu

Nově se preplach_bq.bat spouští z PowerShellu, aby bylo možné předem nastavit proxy proměnné pro VPN. Proxy se musí zapnout ve stejném PowerShell okně, ze kterého se následně spouští BAT soubor.

### 6.1 Zapnutí proxy

```
cd C:\Users\x0577063\scripts\Proxy_VPN
.\proxy-on.ps1
Get-ChildItem Env:\*proxy*
```

Zkontrolovat, že proměnné http_proxy/https_proxy mají vyplněnou hodnotu (nejsou prázdné).

**Důležité:** Proxy nastavená přes proxy-on.ps1 platí pouze pro aktuální PowerShell okno a procesy, které z něj spustím. Pokud otevřu nové okno, musím proxy zapnout znovu.

### 6.2 Kontrola účtu a projektu

Před spuštěním nasazení vždy ověřím účet a aktuální projekt:

```
gcloud auth list
gcloud config get-value project
```

Pokud některý z následujících příkazů selže na chybu oprávnění, i přesto že gcloud auth list ukazuje aktivní přihlášený účet, je potřeba se přihlásit znovu:

```
gcloud auth login
```

Primárně se pro DEV používá projekt:

```
o2cz-dp-wm-200
```

Pokud je potřeba projekt změnit:

```
gcloud config set project o2cz-dp-wm-200
```

### 6.3 Spuštění BAT souboru a logování

Přejdu do adresáře aktuálního release a spustím BAT soubor. Výstup ukládám do logu.

```
cd C:\Users\x0577063\BIDEV-MAIN_o2czep-bq-deploy\pkg
.\preplach_bq.bat > .\log.log 2>&1
```

Nebo pro opravu dat (data fix):

```
.\runme_for_bq.bat > .\log.log 2>&1
```

**Doporučení:** Varianta 2>&1 zapíše do logu i chybový výstup. Díky tomu je log použitelnější při dohledávání chyby.

### 6.4 Když je více BAT souborů ve více složkách

Každý BAT soubor je potřeba spustit ze své vlastní složky. Pokud otevírám nové PowerShell okno, musím v něm znovu zapnout proxy a provést kontrolu gcloud účtu/projektu.

```
cd C:\Users\x0577063\scripts\Proxy_VPN
.\proxy-on.ps1
cd C:\cesta\k\druhemu\release
.\preplach_bq.bat > .\log_preplach_2.log 2>&1
```

## 7. Varianta přes VIRT_NODE

Pokud nasazení probíhá přes VIRT_NODE, soubory od vývojáře se nahrají do sdíleného adresáře:

```
\\ntinfot404\VIRT_NODE\temp
```

Na serveru ntinfo404 je toto umístění zároveň dostupné jako mapovaný disk F:. CMD je v této variantě potřeba spustit jako administrátor (pravé tlačítko na CMD → "Spustit jako správce"), protože se zapisuje do sdíleného síťového umístění, kam běžný uživatelský účet nemá dostatečná práva.

### 7.1 Kontrola účtu a projektu

```
gcloud auth list
gcloud config get-value project
```

Primárně se pro DEV používá projekt:

```
o2cz-dp-wm-200
```

Pokud je potřeba projekt změnit:

```
gcloud config set project o2cz-dp-wm-200
```

Poté se přejde do adresáře s BAT souborem, například na ntinfo404 nemusíme nastavovat proxy:

```
F:\VIRT_NODE\temp\260630R\bidev-10614-org_and_bscs
```

Spuštění s vytvořením nového logu:

```
preplach_bq.bat > log.log 2>&1
```

Příklad celé cesty:

```
F:\VIRT_NODE\temp\260630R\bidev-10614-org_and_bscs>preplach_bq.bat > log.log 2>&1
```

## 8. Postup při pádu nasazení

Pokud BAT soubor spadne, nepouštím ho slepě znovu od začátku. Nejdříve zjistím, kde skončil, a podle toho upravím config.

- [ ] Otevřít původní log.log.
- [ ] Najít poslední úspěšně zpracovanou tabulku nebo objekt.
- [ ] Zálohovat konfigurační soubor (uložit kopii, např. config_backup.txt), než se do něj zasáhne.
- [ ] V config souboru (ve stejné složce jako .bat) odmazat už zpracované tabulky/objekty.
- [ ] Znovu spustit BAT soubor s navázáním výstupu do stejného logu.
- [ ] Po doběhu zkontrolovat konec logu a případné chybové hlášky.
```
.\preplach_bq.bat >> .\log.log 2>&1
```

| Zápis | Význam |
| --- | --- |
| > log.log | Vytvoří nový log nebo přepíše původní. |
| >> log.log | Přidá nový výstup na konec existujícího logu. |

**Pozor / Doplnit:** při opakovaném spuštění po chybě používat >> log.log, ne > log.log. Jinak by se původní log přepsal.

## 9. Vrácení kapacity STG oflow po nasazení

Po úspěšném dokončení a kontrole BQ části (viz kapitola 10) provést shutdown Oflow – načte nové zdroje a nastaví původní pool kapacitu.

## 10. Kontrola úspěšnosti nasazení

Než se pošle informace DevOps/Teradatě, zkontrolovat log.log:

- [ ] V logu vyhledat řetězce jako "ERROR", "FAILED", "Exception" – neměly by se tam objevit.
- [ ] Zkontrolovat, že poslední řádky logu odpovídají úspěšnému dokončení (ne přerušení uprostřed).

## 11. Informování DevOps / Teradata

Po úspěšné BQ části a kontrole logů je možné informovat navazující tým, že z naší strany mohou pokračovat.

| Komu | Poznámka |
| --- | --- |
| o2devops@teradata.com | Hlavní adresát podle poznámky. |
| Rostislav, Honza | Dát do kopie podle aktuální domluvy. |

**Vzor e-mailu:**

```
Předmět: BQ část nasazení dokončena
```

Ahoj,

BQ část je připravená. Můžete pokračovat s navazujícím nasazením podle standardního postupu.

Díky.

Jiří
