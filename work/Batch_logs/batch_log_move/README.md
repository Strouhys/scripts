# Přesun log souborů - Dokumentace

## 📋 Přehled

Projekt automatizuje přesun starých log souborů ze zdrojové složky do archivní složky. Po úspěšném přesunu už soubor ve zdrojové složce neexistuje.

---

## ❓ Co se přenáší?

**Předmět přesunu:**
- Log soubory (standardně `*.log`)
- Soubory starší než **24 hodin** (konfigurovatelné)
- Pouze běžné soubory, ne složky

**Příklad:**
```
C:\Reporting NT\dp\done\
├── app_2024-08-13.log      ✓ Přesunout (staršší 24h)
├── app_2024-08-14.log      ✗ Ponechat (mladší 24h)
└── error_2024-08-12.log    ✓ Přesunout (staršší 24h)
```

---

## 🔄 Jak se přenáší?

### Mechanismus

1. **Čtení konfigurací** z `.env` souboru
2. **Skenování** zdrojové složky podle vzoru (`FILE_PATTERN`)
3. **Porovnání času** - zjistí, která data byla poslední upravena
4. **Kontrola věku** - jsou starší než `MIN_AGE_HOURS`?
5. **Přesun** (`move`) - fyzicky přemístí soubor do cílové složky
6. **Logování** - zaznamenává každý krok do log souboru

### Ochrana duplikátů

Pokud v cílové složce existuje soubor se stejným jménem:
- Přejmenuje se se **časovým razítkem**: `backup_20240814_143022.log`
- Případně se **čísluje**: `backup_20240814_143022_1.log`

### Chyby

Pokud přesun selže (chybí práva, cílová cesta neexistuje atd.):
- Chyba se **zaloguje**
- Soubor **zůstane** ve zdrojové složce
- **Skript pokračuje** s dalšími soubory

---

## ⏰ Kdy se přenáší?

### Automatické spuštění

Skript se spouští přes **Windows Task Scheduler** (Plánovač úloh):

1. Otevřete **Plánovač úloh** (Win + R → `taskschd.msc`)
2. Vytvořte nový úkol
3. Nastavte spouštěč (trigger):
   - **Čas**: např. každý den v 22:00
   - **Četnost**: každých X hodin/dnů
4. Nastavte akci (action):
   - **Program**: `C:\path\to\run_move_old_logs.bat`
   - **Pracovní složka**: `C:\path\to\batch_log_move`

### Ruční spuštění

```cmd
run_move_old_logs.bat
```

### Podmínka spuštění

Skript se vždy spustí, ale přesune pouze soubory, které jsou starší než `MIN_AGE_HOURS` (výchozí 24 hodin).

---

## 📁 Kam se přenáší?

### Cílové místo

Definuje se v `.env` proměnnou **`TARGET_DIR`**:

```env
SOURCE_DIR=C:\Reporting NT\dp\done
TARGET_DIR=C:\Reporting NT\dp_archiv\dp_log
```

**Zdroj →** Cíl:
```
C:\Reporting NT\dp\done\
    app_2024-08-13.log       →  C:\Reporting NT\dp_archiv\dp_log\app_2024-08-13.log
```

### Struktura cílové složky

- Cílová složka se vytvoří automaticky, pokud neexistuje
- Přesunované soubory si **zachovávají původní jména**
- Pokud soubor existuje, přejmenuje se se **časovým razítkem**

---

## ⚙️ Konfigurace

### Soubor `.env`

Obsahuje všechna nastavení. Příklad:

```env
# Zdrojová složka (odtud se přesouvají soubory)
SOURCE_DIR=C:\Reporting NT\dp\done

# Cílová složka (kam se soubory přesouvají)
TARGET_DIR=C:\Reporting NT\dp_archiv\dp_log

# Maska souborů (jaké soubory se hledají)
FILE_PATTERN=*.log

# Minimální věk v hodinách (jen starší soubory se přesouvají)
MIN_AGE_HOURS=24
```

### Parametry

| Parametr | Popis | Příklad |
|----------|-------|---------|
| `SOURCE_DIR` | **Povinné** - zdrojová složka | `C:\Reporting NT\dp\done` |
| `TARGET_DIR` | **Povinné** - cílová složka | `C:\Reporting NT\dp_archiv\dp_log` |
| `FILE_PATTERN` | Maska souborů (vychozí: `*.log`) | `*.log`, `error_*.log` |
| `MIN_AGE_HOURS` | Minimální věk souboru v hodinách (vychozí: 24) | `24`, `72` |

---

## 📂 Projektové soubory

```
batch_log_move/
├── move_old_logs.py              Python skript (hlavní logika)
├── run_move_old_logs.bat         Spouštěč pro Task Scheduler
├── .env                          Konfigurace (správní)
├── .env.example                  Vzor konfigurace
├── README.md                     Tato dokumentace
└── logs/
    ├── move_old_logs.log         Aktuální log
    ├── move_old_logs.log.1       Starší log (rotace)
    ├── move_old_logs.log.2
    └── ... (max 5 starších logů, každý max 5 MB)
```

---

## 📊 Monitorování (Logy)

### Lokace logů

```
batch_log_move\logs\move_old_logs.log
```

### Příklad logu

```
2024-08-14 22:00:05 [INFO] Start jobu: 2024-08-14 22:00:05.123456
2024-08-14 22:00:05 [INFO] Konfigurace: .env
2024-08-14 22:00:05 [INFO] Zdroj: C:\Reporting NT\dp\done
2024-08-14 22:00:05 [INFO] Cil: C:\Reporting NT\dp_archiv\dp_log
2024-08-14 22:00:05 [INFO] Maska souboru: *.log
2024-08-14 22:00:05 [INFO] Presouvam soubory starsi nez 24.00 hodin, tedy upravene pred: 2024-08-13 22:00:05
2024-08-14 22:00:05 [INFO] Preskakuji mladsi soubor: app_2024-08-14.log (upraveno: 2024-08-14 20:15:32)
2024-08-14 22:00:05 [INFO] Presunuto: C:\Reporting NT\dp\done\app_2024-08-13.log -> C:\Reporting NT\dp_archiv\dp_log\app_2024-08-13.log
2024-08-14 22:00:05 [INFO] Hotovo. Zkontrolovano souboru: 3, presunuto: 2
```

### Rotace logů

- Jeden log soubor max **5 MB**
- Uchovává se max **5 starších** log souborů
- Starší logy se automaticky smažou

### Návratové kódy

| Kód | Význam | Příčina |
|-----|--------|--------|
| `0` | ✓ Úspěch | Vše OK |
| `1` | ✗ Chyba zpracování | Soubor se nepodařilo přesunout, chyba při práci |
| `2` | ✗ Chybná konfigurace | Chybí `.env`, chybí proměnná, neplatné nastavení |

---

## 🚀 Spuštění

### Ruční spuštění

```cmd
cd C:\path\to\batch_log_move
run_move_old_logs.bat
```

### Automatické spuštění (Task Scheduler)

1. **Otevřete Plánovač úloh**: `Win + R` → `taskschd.msc`
2. **Klikněte**: Úkol → Vytvořit úkol
3. **Záložka Obecné**:
   - Název: `Move Old Logs`
   - Účet: SYSTEM (nebo váš účet)
4. **Záložka Spouštěče**:
   - Nový spouštěč
   - Druh: Jednoduše (nebo Podle časového plánu)
   - Čas: např. 22:00 každý den
5. **Záložka Akce**:
   - Nová akce
   - Akce: Spustit program
   - Program: `C:\path\to\batch_log_move\run_move_old_logs.bat`
   - Pracovní adresář: `C:\path\to\batch_log_move`
6. **Podmínky a nastavení**: Nastavte podle potřeby
7. **OK** a uložte

---

## ⚠️ Řešení problémů

### Problem: "Chybí konfigurační soubor .env"

**Řešení**: Zkopírujte `.env.example` jako `.env` a upravte hodnoty.

```cmd
copy .env.example .env
```

### Problem: "Chyba: Zdrojová složka neexistuje"

**Řešení**: Ověřte hodnotu `SOURCE_DIR` v `.env`. Cesta musí existovat.

### Problem: "Soubor se nepřesunul, přestože je starší 24 hodin"

**Řešení**: 
- Ověřte `MIN_AGE_HOURS` v `.env`
- Zkontrolujte čas posledního přístupu (`Ctrl+Alt+Shift+I` na souboru)
- Ověřte, že vzor `FILE_PATTERN` odpovídá názvu souboru

### Problem: "Oprávnění zabráňují přesunu"

**Řešení**: Spusťte skript pod účtem s právy ke složkám. V Task Scheduleru nastavte "Spustit s nejvyššími oprávněními".

---

## 📝 Shrnutí

| Otázka | Odpověď |
|--------|---------|
| **CO?** | Log soubory starší než 24 hodin (*.log) |
| **JAK?** | Python skript načte konfiguraci, prohledá zdroj, ověří věk a přesune |
| **KDY?** | Dle nastavení v Task Scheduleru (např. každý den v 22:00) |
 **KAM?** | Do cílové složky definované v `TARGET_DIR` v `.env` 