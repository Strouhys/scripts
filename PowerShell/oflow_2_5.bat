@echo off
title OFLOW Admin
cd /d "C:\Users\x0577063\scripts\PowerShell"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\status-vyvoj-2_5.ps1"

echo.
echo Skript skoncil. Stiskni libovolnou klavesu.
pause >nul
