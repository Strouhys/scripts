# Presun log souboru

Job presouva log soubory starsi nez 24 hodin ze zdrojove slozky do archivni slozky.
Po uspesnem presunu uz soubor ve zdrojove slozce nezustava.

## Soubory

- `move_old_logs.py` - hlavni Python skript
- `.env.example` - vzor konfigurace
- `run_move_old_logs.bat` - spousteci soubor pro Task Scheduler
- `logs\move_old_logs.log` - log jobu, vznikne po prvnim spusteni

## Nastaveni

1. Zkopirujte `.env.example` jako `.env`.
2. V `.env` nastavte:

```env
SOURCE_DIR=C:\Reporting NT\dp\done
TARGET_DIR=C:\Reporting NT\dp_archiv\dp_log
FILE_PATTERN=*.log
MIN_AGE_HOURS=24
DRY_RUN=false
JOB_LOG_FILE=logs\move_old_logs.log
```

## Rucni spusteni

```bat
run_move_old_logs.bat
```

Pro test bez skutecneho presunu nastavte v `.env`:

```env
DRY_RUN=true
```

## Task Scheduler

V Task Scheduleru nastavte akci:

- Program/script: cesta k `run_move_old_logs.bat`
- Start in: slozka, kde lezi `run_move_old_logs.bat`

Skript vraci kod `0` pri uspechu, `1` pri chybe zpracovani a `2` pri chybejici nebo neplatne konfiguraci.
