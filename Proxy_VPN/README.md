# Proxy_VPN – dokumentace skriptů

Tato složka obsahuje dva PowerShell skripty pro rychlé zapnutí a vypnutí HTTP/HTTPS proxy proměnných prostředí v aktuálním PowerShell okně. Používají se typicky při přepínání mezi prací přes VPN/interní síť O2 a přímým připojením k internetu.

> **Poznámka:** Nastavení platí pouze pro aktuální relaci PowerShellu (proces). Po zavření okna nebo spuštění nového PowerShellu se proměnné neuchovávají a je potřeba skript spustit znovu.

## proxy-on.ps1

Nastaví proxy proměnné prostředí pro aktuální PowerShell okno.

**Co dělá:**
- Nastaví `http_proxy`, `https_proxy`, `HTTP_PROXY`, `HTTPS_PROXY` na `http://internet-proxy-s1.cz.o2:8080`
- Nastaví `no_proxy`/`NO_PROXY` na seznam výjimek, pro které se proxy nepoužije:
  - `localhost`, `127.0.0.1`, `::1`
  - `litellm.ai-sandbox.azure.to2cz.cz`, `.to2.to2cz.cz` (interní O2 domény)
  - `googleapis.com`, `.googleapis.com`, `google.com`, `.google.com`, `gcr.io`, `pkg.dev`, `cloudresourcemanager.googleapis.com` (Google API a související služby)
- Vypíše potvrzovací hlášku a aktuální hodnoty nastavených proměnných

**Použití:**
```powershell
.\proxy-on.ps1
```

## proxy-off.ps1

Odebere (smaže) proxy proměnné prostředí z aktuálního PowerShell okna.

**Co dělá:**
- Odstraní proměnné `http_proxy`, `https_proxy`, `HTTP_PROXY`, `HTTPS_PROXY`, `no_proxy`, `NO_PROXY` (pokud existují; chyba při neexistenci proměnné je potlačena)
- Vypíše potvrzovací hlášku, že proxy proměnné byly odebrány

**Použití:**
```powershell
.\proxy-off.ps1
```

## Kontrola aktuálního stavu proxy proměnných

Pro ověření, zda jsou proxy proměnné v aktuálním okně nastavené, lze použít:
```powershell
Get-ChildItem Env: | Where-Object { $_.Name -match '(?i)proxy' }
```
