$proxy = "http://internet-proxy-s1.cz.o2:8080"

$noProxy = "localhost,127.0.0.1,::1,litellm.ai-sandbox.azure.to2cz.cz,.to2.to2cz.cz,googleapis.com,google.com,gcr.io,pkg.dev,cloudresourcemanager.googleapis.com,googleapis.com,.googleapis.com,google.com,.google.com,gcr.io,pkg.dev"

$env:http_proxy = $proxy
$env:https_proxy = $proxy
$env:HTTP_PROXY = $proxy
$env:HTTPS_PROXY = $proxy

$env:no_proxy = $noProxy
$env:NO_PROXY = $noProxy

Write-Host "Proxy proměnné byly nastaveny pro toto PowerShell okno." -ForegroundColor Green
Write-Host "http_proxy=$env:http_proxy"
Write-Host "https_proxy=$env:https_proxy"
Write-Host "no_proxy=$env:no_proxy"