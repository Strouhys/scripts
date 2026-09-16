@echo off
setlocal

REM Run from project root regardless of where the script is launched.
cd /d "%~dp0"

set "PYTHON_EXE=%~dp0.venv\Scripts\python.exe"
set "ORCH_SCRIPT=%~dp0orchestrator\retention_orchestrator.py"

if not exist "%PYTHON_EXE%" (
  echo [ERROR] Python venv not found: "%PYTHON_EXE%"
  echo Create the venv or fix the path first.
  exit /b 1
)

if not exist "%ORCH_SCRIPT%" (
  echo [ERROR] Orchestrator script not found: "%ORCH_SCRIPT%"
  exit /b 1
)

echo Running retention orchestrator...
"%PYTHON_EXE%" "%ORCH_SCRIPT%" %*
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
  echo [OK] Orchestrator finished successfully.
) else (
  echo [FAIL] Orchestrator finished with exit code %EXIT_CODE%.
)

exit /b %EXIT_CODE%
