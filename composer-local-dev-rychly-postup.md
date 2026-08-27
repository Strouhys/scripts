# Composer Local Dev – rychlý postup

## 1. Připojit VPN
Nejdřív se připoj na firemní VPN.

## 2. Otevřít WSL a přejít do Composeru

```bash
cd ~/bi_domain/composer-local-dev
source .venv/bin/activate
```

## 3. Zapnout proxy

```bash
proxy-on
```

Pak nastav `no_proxy` tak, aby Google API šla přes proxy:

```bash
export no_proxy="localhost,127.0.0.1,::1,litellm.ai-sandbox.azure.to2cz.cz,.to2.to2cz.cz"
export NO_PROXY="$no_proxy"
```

Kontrola:

```bash
env | grep -i proxy
```

V `no_proxy` nesmí být například:

```text
googleapis.com
google.com
gcr.io
pkg.dev
```

## 4. Ověřit Google přihlášení

```bash
gcloud auth list
gcloud auth application-default print-access-token
```

Pokud druhý příkaz vrátí dlouhý token, ADC funguje.

Když ne, obnov přihlášení:

```bash
gcloud auth login --no-launch-browser
gcloud auth application-default login --no-launch-browser
```

## 5. Nastavit práva pro Airflow

```bash
sudo chgrp -R 999 "$HOME/.config/gcloud"
sudo chmod -R g+rwX "$HOME/.config/gcloud"
```

## 6. Ověřit Docker

```bash
docker pull postgres:14-alpine
```

Pokud pull projde, Docker síť/proxy funguje.

## 7. Ověřit Composer proxy

```bash
cat composer/airflow-dag20/variables.env
```

Musí obsahovat:

```text
http_proxy=http://internet-proxy-s1.cz.o2:8080
https_proxy=http://internet-proxy-s1.cz.o2:8080
no_proxy=localhost,127.0.0.1,::1
```

## 8. Spustit Airflow

```bash
composer-dev start airflow-dag20
```

Když je potřeba restart:

```bash
composer-dev restart airflow-dag20
```

## 9. Po spuštění

```bash
docker ps
```

Airflow UI:

```text
http://localhost:8081
```

---

# Nejkratší varianta pro běžný další start

```bash
cd ~/bi_domain/composer-local-dev
source .venv/bin/activate
proxy-on

export no_proxy="localhost,127.0.0.1,::1,litellm.ai-sandbox.azure.to2cz.cz,.to2.to2cz.cz"
export NO_PROXY="$no_proxy"

gcloud auth application-default print-access-token
docker pull postgres:14-alpine
composer-dev start airflow-dag20
```

## Když Composer spadne na 503 / Google API

Zkontroluj:

```bash
env | grep -i proxy
```

Pokud vidíš v `no_proxy` Google domény, znovu spusť:

```bash
export no_proxy="localhost,127.0.0.1,::1,litellm.ai-sandbox.azure.to2cz.cz,.to2.to2cz.cz"
export NO_PROXY="$no_proxy"
```

a pak:

```bash
composer-dev start airflow-dag20
```
