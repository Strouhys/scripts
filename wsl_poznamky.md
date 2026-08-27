Základní příkazy s prací ve wsl

Nastavení proxy vždy když zapnu wsl

Jsem na firemní sítí/VPN? 
  - vždy musím proxy zapnout příkazem proxy-on
  - ověřím 
  echo $http_proxy  mel bych dostat http://internet-proxy-s1.cz.o2:8080
nebo mohu ovrit ping ntinfot404

Nejsem na siti O2 zadam proxy-off




vždy provedu autentifikaci raději...
gcloud auth login


cd ~/bi_domain/composer-local-dev # jsme ve složce ~/bi_domain/composer-local-dev
source .venv/bin/activate

Musel jsem nastavit proxy přímo pro autentifikaci google

gcloud config set proxy/type http
gcloud config set proxy/address internet-proxy-s1.cz.o2
gcloud config set proxy/port 8080

Pak ověř:

gcloud config list

Měl bys tam vidět něco jako:

[proxy]
address = internet-proxy-s1.cz.o2
port = 8080
type = http


Pak zkus nejprve jednoduchý síťový test přes gcloud:

gcloud auth list

a následně znovu:

gcloud auth login --no-launch-browser

Potom ještě udělej ADC, protože composer-dev ho pravděpodobně potřebuje:

gcloud auth application-default login --no-launch-browser




Sikovne zkratky
CTRL+R historie prikazu

CTRL+T vyhledávám file





Instalace GIT hub
proslo mi az kdyz jsem nastavil
apt-config dump | grep -i proxy

Acquire::http::Proxy "http://internet-proxy-s1.cz.o2:8080/";
Acquire::https::Proxy "http://internet-proxy-s1.cz.o2:8080/";

Pak ulož:

Ctrl + O
potvrď Enterem
Ctrl + X

pak proxy-on  volba 20


