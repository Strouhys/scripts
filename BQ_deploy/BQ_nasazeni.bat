@echo off
title Proxy-on

cd /d "C:\Users\x0577063\scripts\Proxy_VPN"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\proxy-on.ps1"

cd /d "C:\Users\x0577063\BIDEV-MAIN_o2czep-bq-deploy\pkg"

echo.
echo gcloud auth login
echo Spustit bat .\preplach_bq.bat ^> .\log.log 2^>^&1
echo Nebo log v CMD .\preplach_bq.bat 2^>^&1 ^| Tee-Object -FilePath .\log.log

cmd /k