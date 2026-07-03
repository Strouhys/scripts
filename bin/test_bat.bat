@echo off
echo ========================================
echo TEST BAT SOUBORU
echo ========================================
echo.

echo Aktualni slozka:
cd
echo.

echo Aktualni uzivatel:
whoami
echo.

echo Proxy promenne:
echo http_proxy=%http_proxy%
echo https_proxy=%https_proxy%
echo no_proxy=%no_proxy%
echo.

echo Test gcloud:
gcloud auth list
echo.

echo ========================================
echo HOTOVO
echo ========================================
pause
