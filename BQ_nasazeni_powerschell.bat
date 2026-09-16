@echo off
title Proxy-on

cd /d "C:\Users\x0577063\scripts\Proxy_VPN"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\proxy-on.ps1"

cd /d "C:\Users\x0577063\BIDEV-MAIN_o2czep-bq-deploy\pkg"

echo.
echo ============================================================
echo Pracovni adresar:
cd
echo ============================================================
echo.
echo Nejprve:
echo gcloud auth login
echo.
echo Spusteni preplachu pouze do logu:
echo .\preplach_bq.bat ^> .\log.log 2^>^&1
echo.
echo Spusteni preplachu na obrazovku + do logu:
echo .\preplach_bq.bat 2^>^&1 ^| Tee-Object -FilePath .\log.log
echo.

powershell.exe -NoExit