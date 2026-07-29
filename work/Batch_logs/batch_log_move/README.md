# Presun log souboru

Job presouva log soubory starsi nez 24 hodin ze zdrojove slozky do archivni slozky.
Po uspesnem presunu uz soubor ve zdrojove slozce nezustava.

## Soubory

- `move_old_logs.py` - hlavni Python skript
- `.env.example` - vzor konfigurace
- `run_move_old_logs.bat` - spousteci soubor pro Task Scheduler
- `logs\move_old_logs.log` - log jobu, vznikne po prvnim spusteni a pri dalsich spustenich se dopisuje na konec
- `logs\move_old_logs.log.1` az `.5` - starsi logy, vzniknou automaticky pri rotaci

## Nastaveni

Skript bere nastaveni ze souboru `.env`. Tento soubor uz je v projektu pripraveny.
Soubor `.env.example` je jen vzor pro pripad, ze budete chtit konfiguraci vytvorit znovu.

V `.env` jsou tyto hodnoty:

```env
SOURCE_DIR=C:\Reporting NT\dp\done
TARGET_DIR=C:\Reporting NT\dp_archiv\dp_log
FILE_PATTERN=*.log
MIN_AGE_HOURS=24
```

## Rucni spusteni

```bat
run_move_old_logs.bat
```

## Task Scheduler

V Task Scheduleru nastavte akci:

- Program/script: cesta k `run_move_old_logs.bat`
- Start in: slozka, kde lezi `run_move_old_logs.bat`

Skript vraci kod `0` pri uspechu, `1` pri chybe zpracovani a `2` pri chybejici nebo neplatne konfiguraci.
Log se automaticky rotuje: jeden soubor muze mit maximalne 5 MB a uchovava se poslednich 5 starsich log souboru.
