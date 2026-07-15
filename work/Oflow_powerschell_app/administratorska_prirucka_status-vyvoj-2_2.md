# Administratorska prirucka pro oflow PowerShell ovladani

> Cílovy skript: `status-vyvoj-2_2.ps1`
> Datum aktualizace: 2026-07-15
> Tato verze nahrazuje obsah puvodniho dokumentu `administratorska_prirucka_status-vyvoj-2_1.docx` pro aktualni kod.

## Obsah

1. Ucel a pouziti skriptu
2. Spusteni skriptu a vstupni parametry
3. Hlavni menu podle aktualniho kodu
4. Interpretace stavu jobu
5. Pravidla bezpecne obsluhy
6. Popis vsech voleb 1-22
7. Provozni prehledy 30-33
8. Prakticke scenare
9. Nejcastejsi chyby a reakce
10. Doporucene provozni postupy
11. Rychla tahakova karta
12. Co je nove proti verzi 2_1

## 1. Ucel a pouziti skriptu

Skript `status-vyvoj-2_2.ps1` je interaktivni administracni konzole nad REST API oflow.

Pouziva se pro:

- rychlou diagnostiku dostupnosti a kapacity scheduleru,
- kontrolu definic a stavu jobu,
- cteni statistik a logu,
- operativni zasahy do jobu,
- rizene zmeny chovani scheduleru,
- prehledy podle systemu nebo prefixu jobu.

Skript rozdeluje akce do tri skupin:

- `STATUS / READ-ONLY` pro cteni a diagnostiku,
- `JOB CONTROL` pro zasahy do jednotlivych jobu nebo skupin jobu,
- `POOL / SYSTEM` pro zmeny chovani scheduleru jako celku.

Zakladni pravidlo:

- Na produkci vzdy nejdriv over `BaseUrl`.
- Pred zasahem si znovu over aktualni ID jobu.
- Hromadne akce pouzivej az po kontrole dopadu.

## 2. Spusteni skriptu a vstupni parametry

Skript podporuje tyto hlavni parametry:

- `-HostName`
- `-Port`
- `-Scheme`
- `-Token`
- `-DefaultCapacity`
- `-SkipCertificateCheck`

Token se bere v tomto poradi:

1. z parametru `-Token`,
2. z promenne prostredi `ONDP_OFLOW_AUTH`,
3. z promenne prostredi `OFLOW_TOKEN`,
4. z interaktivniho zadani.

Skript token nikam neuklada, drzi ho pouze v pameti aktualniho behu.

### HTTPS a certifikaty

Pokud skript bezi s `-Scheme https`:

- bez `-SkipCertificateCheck` probiha standardni validace certifikatu,
- s `-SkipCertificateCheck` PowerShell 7 pouzije nativni request volbu,
- s `-SkipCertificateCheck` ve Windows PowerShell 5.1 skript prepne validaci certifikatu do legacy callback rezimu pouze pro tento proces.

Pokud je zadano `-SkipCertificateCheck` a soucasne `-Scheme http`, prepinač nema zadny efekt.

Doporuceni:

- V produkci preferuj standardni validaci certifikatu.
- `SkipCertificateCheck` pouzivej jen pro test, diagnostiku nebo prostredi se self-signed certifikatem.
- Pred zasahem sleduj radek `TLS` v hlavicce menu, pokud jedes pres HTTPS.

## 3. Hlavni menu podle aktualniho kodu

### STATUS / READ-ONLY

1. Health check / rychla diagnostika
2. Detailni status + joby podle stavu
3. Running / Waiting jobs
4. Status jednoho jobu
5. Seznam job definic (`/jobs`)
6. Vyhledavani jobu podle masky + stav
7. Detail jobu (`/job/name`)
8. Next jobs (`/next_jobs`)
9. Job stats
10. Job log
11. Live monitor
12. Export status snapshot
13. Kompletni diagnostika jobu

### JOB CONTROL - zasahuje do jobu

14. Start job now
15. Start multiple jobs
16. Cancel job by ID
17. Restart job by ID
18. Restart all failed/cancelled
19. Pause job do konkretniho casu
20. Enable job now

### POOL / SYSTEM - meni beh scheduleru

21. Pool capacity
22. Graceful shutdown oflow

### PROVOZNI PREHLEDY / SYSTEMY

30. Systemy/prefixy v oflow
31. Souhrn stavu podle systemu
32. Failed joby podle systemu
33. Detail jobu pro system

### Poznamka k Live monitoru

Volba `11` ma dva rezimy:

- konzolovy rezim: `Q` nebo `ESC` vraci do menu, `R` udela okamzity refresh,
- kompatibilni rezim: pokud host PowerShellu neumi bezpecne cist klavesy z konzole, po kazdem obnoveni se zobrazi prompt `Enter = refresh | Q = navrat do menu`.

To je zamerne, aby monitor fungoval i ve VS Code nebo v hostech, kde `Console.KeyAvailable` neni spolehlive.

## 4. Interpretace stavu jobu

### `running`

Proces prave bezi. Zabira capacity slot. Lze ho cancelovat pres aktualni ID.

### `failed_restart`

Job spadl, ale ceka na automaticky retry. Stale zabira capacity slot. Lze ho cancelovat.

### `failed_final`

Job vycerpal vsechny pokusy. Nezabira capacity, ale blokuje dalsi planovani stejneho jobu. Lze restartovat pres ID.

### `cancelled`

Job byl explicitne zrusen. Nezabira capacity, ale blokuje dalsi planovani stejneho jobu. Lze restartovat pres ID.

### `succeeded`

Job uspesne dobehl. V beznem `/status` vystupu uz obvykle neni, protoze byl odstranen z poolu.

### Typicke prechody stavu

- `running -> succeeded`
- `running -> failed_restart -> running -> failed_final`
- `running -> cancelled`
- `failed_final / cancelled -> restart_job -> znovu eligible pro scheduler`

Poznamka:

- `restart_job` neni okamzity start.
- `start_job` spousti job hned.

## 5. Pravidla bezpecne obsluhy

### Restart neni start

`Restart job by ID` odstrani job z dead poolu a dovoli scheduleru ho znovu naplanovat. Nespousti ho okamzite.

### `failed_restart` drzi slot

Pool muze byt plny i ve stavu, kdy `Running = 0`, protoze `failed_restart` drzi capacity slot po dobu cekani na retry.

### Hromadne akce maji preview

Aktualni skript pred rizikovejsimi akcemi ukazuje kontrolni preview:

- `14 - Start job now` ukaze kontrolu konkretniho jobu,
- `15 - Start multiple jobs` ukaze prefix, existenci v `/jobs` a aktualni stav,
- `18 - Restart all failed/cancelled` ukaze souhrn podle systemu a detail jobu k odblokovani.

Pokud preview hlasi, ze job neni v `/jobs`, akci neopakuj bez opravy nazvu.

### ID se musi brat z aktualniho vystupu

Nikdy nepouzivej stare ID bez nove kontroly. Pred `cancel` nebo `restart` si ID znovu over ve volbe `2`, `3`, `4` nebo `13`.

## 6. Popis vsech voleb 1-22

### 1 - Health check / rychla diagnostika

Typ akce:
`GET /status`

Ucel:
Rychly provozni semafor celeho oflow.

Kdy pouzit:

- na zacatku kontroly,
- po nasazeni,
- po restartu,
- pri prvni reakci na incident.

Co sledovat:

- API reachable,
- scheduler status,
- capacity,
- used,
- pocty stavu jobu,
- doporuceni na konci vystupu.

Doporuceny postup:

1. Spust volbu `1`.
2. Zkontroluj `BaseUrl`.
3. Sleduj `capacity`, `used` a pocty failed jobu.
4. Pokud je pool plny, pokracuj volbou `3` nebo `2`.

### 2 - Detailni status + joby podle stavu

Typ akce:
`GET /status`

Ucel:
Zobrazi celkovy stav scheduleru a seznam jobu v poolu.

Kdy pouzit:

- jako hlavni detailni kontrolu pred zasahem,
- po zmene stavu,
- po hromadne akci.

Co sledovat:

- `running_since`,
- `Pool capacity`,
- `Pool used`,
- `Current failed`,
- `Jobs in pool`,
- seznam jobu podle stavu.

Poznamka:
Status je cteci akce, ale obsahuje ID pouzitelna pro zasah.

### 3 - Running / Waiting jobs

Typ akce:
`GET /status` s filtrem `running` a `failed_restart`

Ucel:
Vypise joby, ktere aktualne drzi capacity slot.

Kdy pouzit:

- kdyz `Used = Capacity`,
- kdyz `Running = 0`, ale pool je plny,
- pri sledovani blokujicich retry jobu.

Co sledovat:

- `ID`,
- `job_name`,
- `status`,
- `run_count`,
- `last_change`.

### 4 - Status jednoho jobu

Typ akce:
`GET /status` s filtrem podle `job_name`

Ucel:
Zobrazi aktualni stav konkretniho jobu podle nazvu.

Kdy pouzit:

- kdyz nechces prochazet dlouhy globalni status,
- kdyz potrebujes rychle zjistit aktualni ID jobu,
- pred `cancel` nebo `restart`.

Poznamka:
Pokud job neni v poolu, nemusi to byt chyba. Muze byt uspesne dobehnuty nebo cekat na dalsi planovani.

### 5 - Seznam job definic

Typ akce:
`GET /jobs` nebo `GET /jobs?mask=`

Ucel:
Vypise definice jobu nactene pri startu oflow.

Kdy pouzit:

- kdyz hledas spravny nazev jobu,
- kdyz overujes, zda job existuje v konfiguraci,
- jako vychozi krok pred volbami `4`, `7`, `9`, `10` a `13`.

### 6 - Vyhledavani jobu podle masky + stav

Typ akce:
Kombinace `GET /jobs?mask=` a `GET /status`

Ucel:
Najde job definice a doplni, zda jsou aktualne v poolu a v jakem stavu.

Kdy pouzit:

- kdyz znas jen cast nazvu,
- kdyz hledas joby jedne oblasti,
- kdyz chces rovnou videt i aktualni stav.

### 7 - Detail jobu

Typ akce:
`GET /job/{name}`

Ucel:
Zobrazi konfiguraci jednoho jobu.

Co sledovat:

- `command_line`,
- `priority`,
- `first_run_attempt`,
- `restart_after_seconds`,
- `max_runs`,
- `max_run_time_seconds`.

Poznamka:
Detail definice neni aktualni stav behu. Aktualni stav resi volba `4` nebo `13`.

### 8 - Next jobs

Typ akce:
`GET /next_jobs?limit=`

Ucel:
Ukaze joby, ktere scheduler planuje jako dalsi.

Kdy pouzit:

- kdyz chces zjistit, co se bude spoustet,
- kdyz chces zjistit, proc se neco nespousti hned,
- po `restart_job` nebo `enable job`.

Co sledovat:

- `job_name`,
- `next_run`,
- `seconds_until`,
- `reason`.

### 9 - Job stats

Typ akce:
`GET /job_stats/{name}`

Ucel:
Zobrazi statistiku jednoho jobu.

Kdy pouzit:

- pri analyze dlouhodobe nestability,
- pri timeout problémech,
- kdyz porovnavas padani konkretniho jobu v case.

Poznamka:
Stats mohou vyzadovat token. `401` znamena problem s tokenem, ne se samotnym jobem.

### 10 - Job log

Typ akce:
`GET /job_log/{name}`

Ucel:
Zobrazi konec log souboru daneho jobu.

Kdy pouzit:

- kdyz potrebujes vystup konkretniho jobu,
- kdyz job pada a potrebujes posledni chybu,
- pri overovani timeoutu nebo spatnych argumentu.

Poznamka:

- Pri `500` zkontroluj `ONDP_TENANT_LOG_DIR`.
- Pri `404` zkontroluj existenci souboru `<job_name>.log`.
- V DEV demu nemusi existovat per-job logy.

### 11 - Live monitor

Typ akce:
Opakovane `GET /status`

Ucel:
Prubezne obnovuje prehled stavu oflow v konzoli.

Kdy pouzit:

- pri sledovani restartu,
- pri hromadne vlne jobu,
- pri nasazeni,
- pri sledovani kapacity.

Co sledovat:

- cas,
- capacity,
- running,
- failed_restart,
- failed_final,
- cancelled,
- vybrane joby.

### 12 - Export status snapshot

Typ akce:
`GET /status` + zapis do souboru

Ucel:
Ulozi aktualni stav do JSON a TXT souboru v aktualnim pracovnim adresari.

Kdy pouzit:

- pri incidentu,
- pred zasahem,
- po zasahu,
- pro predani kolegovi.

Vystup:

- `oflow_status_YYYYMMDD_HHMMSS.json`
- `oflow_status_YYYYMMDD_HHMMSS.txt`

### 13 - Kompletni diagnostika jobu

Typ akce:
Kombinace `/status`, `/job`, `/job_stats`, `/next_jobs`

Ucel:
Nejkompletnejsi pohled na jeden job vcetne doporuceni dalsiho kroku.

Kdy pouzit:

- pri incidentu na konkretnim jobu,
- kdyz si nejsi jisty, zda restartovat,
- pred rozhodnutim mezi `cancel`, `restart`, `start` nebo cekanim.

### 14 - Start job now

Typ akce:
`GET /start_job/{name}`

Ucel:
Okamzite spusti job podle nazvu mimo normalni scheduler loop.

Aktualni skript pred potvrzenim ukaze preview konkretniho jobu.

Pozor:
Muže obejit kapacitu poolu a zpusobit oversubscription.

### 15 - Start multiple jobs

Typ akce:
`POST /start_jobs`

Ucel:
Okamzite spusti vice jobu podle seznamu nazvu.

Aktualni skript navic:

- odfiltruje duplicitni nazvy,
- zobrazi preview jobu,
- odmitne davku, pokud nektery nazev neni v `/jobs`,
- pri vetsich nebo rizikovejsich davkach vyzaduje silnejsi potvrzeni s poctem jobu.

Pouziti na produkci:
Jen kdyz znas dopad cele davky.

### 16 - Cancel job by ID

Typ akce:
`GET /cancel_job/{id}`

Ucel:
Zrusi `running` nebo `failed_restart` job podle ID.

Kdy pouzit:

- kdyz job bezi prilis dlouho,
- kdyz blokuje pool,
- kdyz nechces cekat na auto-retry.

### 17 - Restart job by ID

Typ akce:
`GET /restart_job/{id}`

Ucel:
Odblokuje `failed_final` nebo `cancelled` job z dead poolu.

Poznamka:
Nespousti job okamzite. Jen ho vrati do stavu, kdy ho scheduler muze znovu vyhodnotit.

### 18 - Restart all failed/cancelled

Typ akce:
Vice volani `GET /restart_job/{id}`

Ucel:
Odblokuje vsechny joby v dead poolu.

Aktualni skript pred potvrzenim zobrazi:

- souhrn podle systemu/prefixu,
- detail jobu k odblokovani,
- silnejsi potvrzeni obsahujici pocet jobu.

Pozor:
Na produkci jde o vysoce rizikovou volbu. Muze odblokovat velke mnozstvi jobu a vytvorit vlnu zpracovani.

### 19 - Pause job do konkretniho casu

Typ akce:
`PUT /set_job_first_run_attempt/{name}`

Ucel:
Posune `first_run_attempt` do budoucnosti a tim zabrani novemu naplanovani jobu.

Poznamka:
Pause nezastavi uz bezici job ani pending `failed_restart` retry. Resi nove planovani.

### 20 - Enable job now

Typ akce:
`PUT /set_job_first_run_attempt/{name}`

Ucel:
Vrati `first_run_attempt` do minulosti a povoli planovani jobu.

Kdy pouzit:

- kdyz byl job pause-nuty,
- kdyz ma znovu bezet schedulerem,
- po docasne provozni blokaci.

### 21 - Pool capacity

Typ akce:
Volani `GET /set_pool_capacity/{capacity}`

Ucel:
Zmeni maximalni pocet aktivnich jobu za behu.

Typicke pouziti:

- odstávka,
- nasazeni,
- testovani,
- reseni pretizeni.

Poznamka:
`Capacity 0` nezabiji bezici joby. Pouze zabrani spousteni novych jobu schedulerem.

### 22 - Graceful shutdown oflow

Typ akce:
`GET /shutdown`

Ucel:
Zahaji korektni ukonceni scheduleru.

Kdy pouzit:

- pri planovanem vypnuti oflow,
- pri rizene odstávce,
- ne jako nahradu za `capacity 0`.

## 7. Provozni prehledy 30-33

### 30 - Systemy/prefixy v oflow

Typ akce:
Read-only agregace nad `/jobs` a `/status`.

Ucel:
Ukaze, jake systemy nebo oblasti jsou v oflow zastoupeny podle prefixu v nazvu jobu pred prvnim podtrzitkem.

Priklad:
`ocs_sms_import` ma prefix `ocs`.

Kdy pouzit:

- kdyz potrebujes rychly prehled, kolik systemu oflow obsluhuje,
- kdyz si overujes naming konvence,
- kdyz pripravujes hromadne zasahy podle oblasti.

### 31 - Souhrn stavu podle systemu

Typ akce:
Read-only agregace nad `/jobs` a `/status`.

Ucel:
Da rychly pohled, kde se kumuluji problemy podle oblasti nebo systemu.

Co sledovat:

- `Total`,
- `NotInPool`,
- `Running`,
- `FailedRestart`,
- `FailedFinal`,
- `Cancelled`,
- `Succeeded`,
- `Other`.

Poznamka:
`NotInPool` neznamena chybu. Znamena jen to, ze job existuje v definicich, ale neni aktualne v poolu.

### 32 - Failed joby podle systemu

Typ akce:
Read-only agregace nad `/jobs` a `/status`.

Ucel:
Ukaze problemove joby seskupene podle prefixu a rozdeli je na `failed_restart`, `failed_final` a `cancelled`.

Kdy pouzit:

- kdyz je treba najit nejproblematictejsi oblast,
- kdyz se pool plni retry joby,
- pred volbou `18`.

### 33 - Detail jobu pro system

Typ akce:
Read-only filtr nad internim inventarem jobu.

Ucel:
Umoznuje vypsat vsechny joby konkretniho prefixu/systemu a jejich aktualni stav.

Kdy pouzit:

- kdyz incident zasahuje jednu aplikaci nebo integraci,
- kdyz chces operatorovi predat jen joby relevantni pro danou oblast,
- kdyz analyzujes, zda je system zablokovany retry nebo dead joby.

## 8. Prakticke scenare

### Rychla kontrola stavu oflow

1. Spust volbu `1`.
2. Pokud vse vypada dobre, zkontroluj volbu `8`.
3. Pri chybach pokracuj volbou `2` a `13`.

### Pool je plny, ale Running = 0

1. Volba `1` ukaze `Used = Capacity` a `Running = 0`.
2. Spust volbu `3`.
3. Pokud uvidis `failed_restart`, joby cekaji na retry a drzi sloty.
4. Pockej retry interval nebo podle situace pouzij `16`.

### Zastaveni noveho planovani pri odstavce

1. Spust volbu `21`.
2. Nastav `capacity 0`.
3. Ověř volbou `2`.
4. Bezi-li joby dale, nech je dobehnout nebo je res podle dohody.

### Navrat po odstavce

1. Spust volbu `21`.
2. Vrat standardni capacity.
3. Ověř volbou `2`.
4. Sleduj volbu `11` nekolik minut.

### Restart jednoho failed_final jobu

1. Spust `13` nebo `4` a zjisti aktualni ID.
2. Over duvod padu podle `9` a `10`.
3. Pouzij `17`.
4. Sleduj `8`, `4` nebo `11`.

### Hromadne odblokovani po rizenem zasahu

1. Spust `32`, abys videl problemove systemy.
2. Spust `18` a precti preview.
3. Potvrd akci jen pokud rozumis dopadu.
4. Sleduj `2`, `11` a `31`.

## 9. Nejcastejsi chyby a reakce

### oflow neni reachable

Mozne priciny:

- oflow nebezi,
- spatny host nebo port,
- DNS,
- firewall,
- VPN,
- API posloucha jinde.

Reakce:

1. Zkontroluj `BaseUrl`.
2. Over `HostName`, `Port`, `Scheme`.
3. Over sitovou dostupnost.

### 401 Unauthorized

Mozne priciny:

- token chybi,
- token je neplatny,
- token nema potrebna prava.

Reakce:

1. Over, jestli je token nacteny.
2. Pokud je treba, zadej ho znovu.
3. Zkus stejnou akci znovu.

### 404 na jobu nebo logu

Mozne priciny:

- job neexistuje,
- zadany nazev ma preklep,
- log soubor neni vytvoreny.

Reakce:

1. Over nazev pres volbu `5` nebo `6`.
2. U logu over existenci `<job_name>.log`.

### Start job skoncí konfliktem

Mozne priciny:

- job uz je v `running`,
- job je v `failed_restart`,
- job je v `failed_final` nebo `cancelled` a blokuje planovani.

Reakce:

1. Over stav pres `4` nebo `13`.
2. Podle stavu proved `cancel` nebo `restart`.
3. Az potom zkus `start` znovu.

### Pool je plny

Mozne priciny:

- moc `running` jobu,
- `failed_restart` drzi sloty,
- capacity je nastavena prilis nizko.

Reakce:

1. Pouzij `3`.
2. Pripadne `21`.
3. Nezasahuj hromadne bez znalosti dopadu.

## 10. Doporucene provozni postupy

- Pred zasahem si uloz snapshot pres volbu `12`.
- Pred `cancel` a `restart` si vzdy over aktualni ID.
- Pri problemu s jednim jobem postupuj pres `13`, ne rovnou pres `17`.
- Hromadne starty a restarty delaj az po kontrole prefixu a stavu systemu.
- Po zasahu pouzij `11`, `2` nebo `31` pro nasledne sledovani.
- Na produkci preferuj `capacity 0` pred shutdownem, pokud nechces oflow skutecne ukoncit.

## 11. Rychla tahakova karta

- Chci rychly stav: `1`
- Chci detail poolu: `2`
- Pool je plny: `3`
- Chci stav jednoho jobu: `4`
- Neznam presny nazev jobu: `5` nebo `6`
- Chci detail definice jobu: `7`
- Chci vedet, co pobezi dal: `8`
- Chci statistiky jobu: `9`
- Chci log jobu: `10`
- Chci sledovat zmeny v case: `11`
- Chci ulozit stav: `12`
- Chci kompletni diagnostiku jobu: `13`
- Chci job spustit hned: `14`
- Chci spustit vic jobu: `15`
- Chci job zrusit: `16`
- Chci odblokovat failed/cancelled job: `17`
- Chci odblokovat vsechny dead joby: `18`
- Chci job docasne vypnout: `19`
- Chci job znovu povolit: `20`
- Chci zmenit kapacitu: `21`
- Chci korektne vypnout oflow: `22`
- Chci pohled po systemech: `30`, `31`, `32`, `33`

## 12. Co je nove proti verzi 2_1

- Prirucka je prevedena do markdownu a vazana na aktualni skript `status-vyvoj-2_2.ps1`.
- Byly doplneny provozni prehledy `30-33`.
- Live monitor ma kompatibilni rezim pro hosty, kde nefunguje prime cteni klaves.
- HTTPS/TLS chovani je v menu viditelnejsi a presneji popsane.
- Hromadne akce maji bezpecnostni preview a silnejsi potvrzovani.
