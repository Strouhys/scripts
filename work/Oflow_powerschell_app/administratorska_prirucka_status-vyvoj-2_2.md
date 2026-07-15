# Administratorska prirucka

> Verze pro skript `status-vyvoj-2_2.ps1`
> Datum aktualizace: 2026-07-15

Tato markdown verze navazuje na puvodni dokument `administratorska_prirucka_status-vyvoj-2_1.docx` a doplnuje zmeny z aktualniho skriptu 2_2. Je urcena jako provozni referencni prirucka, kterou lze snadno udrzovat spolu se skriptem.

## Hlavni zmeny proti 2_1

- Live monitor ma novy kompatibilni rezim pro PowerShell hosty, kde nefunguje prime cteni klaves z konzole.
- Rezim `-SkipCertificateCheck` je v chovani a vystupu explicitnejsi.
- Hromadne zasahy ukazuji preview jobu pred spustenim nebo odblokovanim.
- Prirucka nize doplnuje volby `30` az `33`.

## Poznamky k HTTPS a certifikatum

Pokud skript bezi s `-Scheme https`:

- Bez `-SkipCertificateCheck` probiha standardni validace certifikatu.
- S `-SkipCertificateCheck` PowerShell 7 vyuzije nativni request volbu.
- S `-SkipCertificateCheck` ve Windows PowerShell 5.1 skript prepne validaci certifikatu do legacy callback rezimu pouze pro tento proces.
- Pokud je zadan `-SkipCertificateCheck` a zaroven `-Scheme http`, prepinač nema zadny efekt.

Doporuceni:

- V produkci pouzivej standardni validaci certifikatu, pokud to prostredi umoznuje.
- `SkipCertificateCheck` pouzivej jen pro test, diagnostiku nebo prostredi se self-signed certifikatem.
- Pred zasahem vzdy zkontroluj `BaseUrl` a rezim TLS v hlavicce menu.

## Poznamky k Live monitoru

Volba `11 - Live monitor` ma dva rezimy:

- Konzolovy rezim: `Q` nebo `ESC` vraci do menu, `R` udela okamzity refresh.
- Kompatibilni rezim: pokud host PowerShellu neumi bezpecne cist klavesy z konzole, po kazdem obnoveni se zobrazi prompt `Enter = refresh | Q = navrat do menu`.

Doporuceni:

- Pokud bezi skript ve VS Code nebo v jinem hostu, kde konzolove klavesy nefunguji stabilne, pouzivej kompatibilni rezim.
- Live monitor je urceny pro sledovani, ne pro zasah. Pro zmenu stavu se vrat do hlavniho menu.

## Bezpecnost hromadnych akci

Volby s vyssim dopadem ted pred zasahem ukazuji preview:

- `14 - Start job now` zobrazi kontrolu konkretniho jobu.
- `15 - Start multiple jobs` zobrazi prefix, existenci v `/jobs` a aktualni stav.
- `18 - Restart all failed/cancelled` zobrazi souhrn podle systemu/prefixu a detail jobu k odblokovani.

Doporuceni:

- Pokud preview hlasi, ze job neni v `/jobs`, akci neopakuj bez opravy nazvu.
- Pokud je job uz v `running`, `failed_restart`, `failed_final` nebo `cancelled`, hromadny start muze skoncit konfliktem.
- U vetsich davek nebo rizikovejsich situaci skript vyzaduje silnejsi potvrzeni s poctem jobu.

## Nove provozni prehledy 30-33

### 30 - Systemy/prefixy v oflow

Typ akce:
Read-only agregace nad `/jobs` a `/status`.

Ucel:
Ukaze, jake systemy nebo oblasti jsou v oflow zastoupeny podle prefixu v nazvu jobu pred prvnim podtrzitkem.

Priklad:
`ocs_sms_import` ma prefix `ocs`.

Kdy pouzit:

- Kdyz potrebujes rychly prehled, kolik systemu oflow obsluhuje.
- Kdyz si overujes naming konvence jobu.
- Kdyz pripravujes hromadne zasahy podle oblasti.

Co sledovat:

- `System`
- `Jobu`
- `VPoolu`
- `MimoPool`

Doporuceny postup:

1. Spust volbu `30`.
2. Najdi prefix oblasti, kterou resis.
3. Podle potreby navaz volbou `31`, `32` nebo `33`.

### 31 - Souhrn stavu podle systemu

Typ akce:
Read-only agregace nad `/jobs` a `/status`.

Ucel:
Dava management i operatorovi rychly pohled, kde se kumuluji problemy podle oblasti nebo systemu.

Kdy pouzit:

- Pri rannim provoznim checku.
- Pri incidentu, kdy chces vedet, jestli se problem tyka jedne oblasti nebo vice systemu.
- Pred restartem vetsi skupiny jobu.

Co sledovat:

- `Total`
- `NotInPool`
- `Running`
- `FailedRestart`
- `FailedFinal`
- `Cancelled`
- `Other`

Doporuceny postup:

1. Spust volbu `31`.
2. Najdi system s nestandardnim poctem `FailedRestart` nebo `FailedFinal`.
3. Pokracuj volbou `32` nebo `33`.

Poznamka:
`NotInPool` neznamena chybu. Znamena jen to, ze job existuje v definicich, ale neni aktualne v poolu.

### 32 - Failed joby podle systemu

Typ akce:
Read-only agregace nad `/jobs` a `/status`.

Ucel:
Ukaze problemove joby seskupene podle prefixu a rozdeli je na `failed_restart`, `failed_final` a `cancelled`.

Kdy pouzit:

- Kdyz je treba najit nejproblematictejsi oblast.
- Kdyz se pool plni retry joby.
- Pred volbou `18 - Restart all failed/cancelled`.

Co sledovat:

- Souhrn po systemech.
- Detailni seznam jobu s `Id`, `RunCount` a `LastChange`.

Doporuceny postup:

1. Spust volbu `32`.
2. Over, zda problemy nejsou koncentrovane do jednoho prefixu.
3. Teprve potom rozhodni o restartu nebo dalsi diagnostice.

### 33 - Detail jobu pro system

Typ akce:
Read-only filtr nad internim inventarem jobu.

Ucel:
Umoznuje vypsat vsechny joby konkretniho prefixu/systemu a jejich aktualni stav.

Kdy pouzit:

- Kdyz incident zasahuje jednu aplikaci nebo integraci.
- Kdyz chces operatorovi predat jen joby relevantni pro danou oblast.
- Kdyz analyzujes, zda je system zablokovany retry nebo dead joby.

Co sledovat:

- Souhrn podle stavu.
- Detail `JobName`, `Status`, `Id`, `RunCount`, `LastChange`.

Doporuceny postup:

1. Spust volbu `33`.
2. Zadej prefix podle vystupu z volby `30`.
3. Vyhodnot, zda jsou joby hlavne `not_in_pool`, `running`, `failed_restart` nebo `failed_final`.
4. Podle potreby navaz volbou `13`, `16`, `17` nebo `18`.

## Doporučeny provozni sled akci pri incidentu

1. Volba `1` nebo `2` pro rychly obraz stavu.
2. Volba `31` nebo `32`, pokud problem vypada systemove.
3. Volba `13`, pokud resis konkretni job.
4. Volba `16`, `17` nebo `18` az po overeni dopadu.
5. Volba `12`, pokud potrebujes ulozit stav pred nebo po zasahu.
