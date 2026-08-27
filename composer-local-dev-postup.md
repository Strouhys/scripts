# Composer Local Dev ve WSL – postup pro opakované spuštění

Tento postup navazuje na funkční stav z 26. 8. 2026.  
Cíl: spustit lokální Cloud Composer / Airflow instanci `airflow-dag20` ve WSL za O2 proxy.

> Důležité: problém byl způsoben tím, že `googleapis.com` a další Google domény byly v `no_proxy`. `composer-dev` se pak pokoušel připojit na Google API napřímo a končil na `503 / tcp handshaker shutdown`. Funkční stav je takový, že Google API **jdou přes O2 proxy**.

---

## 1. Připojit VPN a otevřít WSL

Připojit se na firemní VPN.

Ve Windows případně restart WSL:

```powershell
wsl --shutdown
wsl
```

---

## 2. Přejít do Composer repozitáře

```bash
cd ~/bi_domain/composer-local-dev
```

Aktivovat Python virtuální prostředí:

```bash
source .venv/bin/activate
```

Prompt by měl začínat:

```text
(composer-local-dev)
```

---

## 3. Zapnout firemní proxy

```bash
proxy-on
```

Ověřit:

```bash
env | grep -i proxy
```

Musí být nastaveno minimálně:

```text
http_proxy=http://internet-proxy-s1.cz.o2:8080
https_proxy=http://internet-proxy-s1.cz.o2:8080
HTTP_PROXY=http://internet-proxy-s1.cz.o2:8080
HTTPS_PROXY=http://internet-proxy-s1.cz.o2:8080
```

### DŮLEŽITÁ OPRAVA `no_proxy`

Pro spuštění `composer-dev` nesmí být v `no_proxy` například:

```text
googleapis.com
.googleapis.com
google.com
.google.com
gcr.io
pkg.dev
cloudresourcemanager.googleapis.com
```

V aktuálním shellu nastav:

```bash
export no_proxy="localhost,127.0.0.1,::1,litellm.ai-sandbox.azure.to2cz.cz,.to2.to2cz.cz"
export NO_PROXY="$no_proxy"
```

Ověřit:

```bash
env | grep -i proxy
```

Správný výsledek má obsahovat přibližně:

```text
no_proxy=localhost,127.0.0.1,::1,litellm.ai-sandbox.azure.to2cz.cz,.to2.to2cz.cz
NO_PROXY=localhost,127.0.0.1,::1,litellm.ai-sandbox.azure.to2cz.cz,.to2.to2cz.cz
```

---

## 4. Ověřit Google autentizaci

Běžné přihlášení:

```bash
gcloud auth list
```

Aktivní účet musí být označen `*`.

Ověřit projekt:

```bash
gcloud config get-value project
```

Ověřit ADC:

```bash
gcloud auth application-default print-access-token
```

Pokud příkaz vrátí dlouhý token, ADC funguje.

### Když je potřeba přihlášení obnovit

```bash
gcloud auth login --no-launch-browser
```

a následně:

```bash
gcloud auth application-default login --no-launch-browser
```

Při obou příkazech:
1. otevřít vygenerovaný odkaz ve Windows prohlížeči,
2. přihlásit se,
3. vložit verification code zpět do WSL.

---

## 5. Ověřit Docker autentizaci pro GCR

```bash
gcloud auth configure-docker
```

Pokud je vše správně, stačí hláška:

```text
gcloud credential helpers already registered correctly.
```

---

## 6. Ověřit Docker proxy

Soubor:

```bash
cat /etc/systemd/system/docker.service.d/http-proxy.conf
```

Má obsahovat:

```ini
[Service]
Environment="HTTP_PROXY=http://internet-proxy-s1.cz.o2:8080"
Environment="HTTPS_PROXY=http://internet-proxy-s1.cz.o2:8080"
Environment="NO_PROXY=localhost,127.0.0.1"
```

Pokud se tento soubor měnil, načíst změny:

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

---

## 7. Ověřit Docker user config

```bash
cat ~/.docker/config.json
```

Má obsahovat `credHelpers` a také:

```json
"proxies": {
  "default": {
    "httpProxy": "http://internet-proxy-s1.cz.o2:8080",
    "httpsProxy": "http://internet-proxy-s1.cz.o2:8080",
    "noProxy": "localhost,127.0.0.1,metadata.google.internal,169.254.169.254"
  }
}
```

---

## 8. Ověřit, že Docker umí stáhnout image

Test:

```bash
docker pull postgres:14-alpine
```

Funkční výsledek:

```text
Status: Downloaded newer image for postgres:14-alpine
```

nebo informace, že image je již aktuální.

---

## 9. Ověřit proxy uvnitř Composer konfigurace

Soubor:

```bash
nano composer/airflow-dag20/variables.env
```

Musí obsahovat:

```text
http_proxy=http://internet-proxy-s1.cz.o2:8080
https_proxy=http://internet-proxy-s1.cz.o2:8080
no_proxy=localhost,127.0.0.1,::1
```

Kontrola:

```bash
cat composer/airflow-dag20/variables.env
```

---

## 10. Nastavit práva na lokální gcloud credentials pro Airflow

Airflow uvnitř Composer image běží s UID/GID `999`.

Proto:

```bash
sudo chgrp -R 999 "$HOME/.config/gcloud"
sudo chmod -R g+rwX "$HOME/.config/gcloud"
```

Ověřit:

```bash
ls -ld ~/.config/gcloud
ls -l ~/.config/gcloud/application_default_credentials.json
```

Na hostitelském WSL se GID `999` zobrazí názvem:

```text
systemd-journal
```

To je očekávané. Uvnitř Composer kontejneru stejné číselné GID `999` odpovídá uživateli/skupině `airflow`.

Příklad správného stavu:

```text
drwxrwx--- ... x0577063 systemd-journal ... /home/x0577063/.config/gcloud
-rw-rw---- ... x0577063 systemd-journal ... application_default_credentials.json
```

Příkaz z interního návodu:

```bash
sudo usermod -aG empower $(whoami)
```

u tohoto WSL nefunguje, protože skupina `empower` zde neexistuje. Pro samotné čtení ADC jsme použili GID `999`.

---

## 11. Ověřit existenci lokální instance

```bash
composer-dev list
```

Instance má být:

```text
airflow-dag20
```

Pokud už existuje, **není potřeba znovu spouštět `composer-dev create`**.

Původně byla vytvořena příkazem:

```bash
composer-dev create \
  --from-image-version composer-3-airflow-3.1.7-build.10 \
  --project o2cz-dp-shared-dev \
  --port 8081 \
  airflow-dag20
```

---

## 12. Spustit Composer

Nejdřív se ještě jednou ujistit, že Google domény nejsou v `no_proxy`:

```bash
export no_proxy="localhost,127.0.0.1,::1,litellm.ai-sandbox.azure.to2cz.cz,.to2.to2cz.cz"
export NO_PROXY="$no_proxy"
```

Pak:

```bash
composer-dev start airflow-dag20
```

První start může trvat delší dobu, protože se stahuje Composer image.

Funkční průběh už byl potvrzen až do:

```text
database system is ready to accept connections
Pulling Composer image. It can take a few minutes.
```

Pokud prostředí existuje a je potřeba ho znovu sestavit/restartovat, lze použít:

```bash
composer-dev restart airflow-dag20
```

---

## 13. Po úspěšném startu

Ověřit kontejnery:

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

Airflow UI:

```text
http://localhost:8081
```

---

## 14. Ověřit přístup Airflow k ADC uvnitř kontejneru

Až instance **běží**:

```bash
docker exec -it composer-local-dev-airflow-dag20 /bin/bash
```

Uvnitř kontejneru:

```bash
cat /home/airflow/.config/gcloud/application_default_credentials.json
```

Pokud se JSON zobrazí, Airflow má k ADC souboru právo.

Ukončit shell kontejneru:

```bash
exit
```

---

# Nejkratší postup pro zítřejší start

Pokud už je vše jednou nakonfigurované:

```bash
cd ~/bi_domain/composer-local-dev
source .venv/bin/activate

proxy-on

export no_proxy="localhost,127.0.0.1,::1,litellm.ai-sandbox.azure.to2cz.cz,.to2.to2cz.cz"
export NO_PROXY="$no_proxy"

gcloud auth list
gcloud auth application-default print-access-token

docker pull postgres:14-alpine

composer-dev start airflow-dag20
```

Pokud se start podaří:

```bash
docker ps
```

a otevřít:

```text
http://localhost:8081
```

---

# Troubleshooting

## Chyba 503 / Google API / `tcp handshaker shutdown`

Typický problém:

```text
Could not validate authentication data: 503 failed to connect to all addresses
...
ipv4:142.251.x.x:443
tcp handshaker shutdown
```

Nejprve ověřit:

```bash
env | grep -i proxy
```

Pokud je v `no_proxy` `googleapis.com`, `google.com`, `gcr.io`, `pkg.dev` apod., odstranit je pro aktuální shell:

```bash
export no_proxy="localhost,127.0.0.1,::1,litellm.ai-sandbox.azure.to2cz.cz,.to2.to2cz.cz"
export NO_PROXY="$no_proxy"
```

Pak znovu:

```bash
composer-dev start airflow-dag20
```

---

## Docker Hub timeout

Typická chyba:

```text
registry-1.docker.io:443
i/o timeout
```

Ověřit:
- VPN,
- Docker daemon proxy,
- Docker user proxy config.

Test:

```bash
docker pull postgres:14-alpine
```

---

## Přerušený start kvůli výpadku sítě

Nejprve zkontrolovat:

```bash
docker ps -a
composer-dev list
```

Pak zkusit:

```bash
composer-dev start airflow-dag20
```

Pokud Composer hlásí, že prostředí už existuje nebo je částečně spuštěné:

```bash
composer-dev restart airflow-dag20
```

---

## Debug režim

Když chyba není jasná:

```bash
composer-dev start airflow-dag20 --debug
```

Pokud tato syntaxe není podporovaná:

```bash
composer-dev --debug start airflow-dag20
```
