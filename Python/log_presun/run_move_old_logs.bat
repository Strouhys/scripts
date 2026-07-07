@echo off
setlocal

cd /d "%~dp0"

if not exist ".env" (
    echo Chybi konfiguracni soubor .env
    echo Zkopirujte .env.example jako .env a upravte hodnoty.
    exit /b 2
)

if not exist "logs" mkdir "logs"

where py >nul 2>nul
if %errorlevel% equ 0 (
    py -3 "%~dp0move_old_logs.py" --env "%~dp0.env"
) else (
    python "%~dp0move_old_logs.py" --env "%~dp0.env"
)

exit /b %errorlevel%
