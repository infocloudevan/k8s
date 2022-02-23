#!/bin/bash

EMAIL=${1:-laurentiu@darkubed.com}
DOMAIN=${2:-localhost}
COMPANY=${3:-darkcubed}

SCRIPT=$0
START_DIRECTORY="$(pwd)"
cd "$(dirname "${SCRIPT}")"
SCRIPT="$(basename "${SCRIPT}")"

openssl req -new -nodes -x509 -out ./tls.pem -keyout ./tls.key -days 3650 -subj "/C=DE/ST=NRW/L=Earth/O=${COMPANY}/OU=IT/CN=${DOMAIN}/emailAddress=${EMAIL}"

openssl req -new -nodes -x509 -out ./client.pem -keyout ./client.key -days 3650 -subj "/C=DE/ST=NRW/L=Earth/O=${COMPANY}/OU=IT/CN=${DOMAIN}/emailAddress=${EMAIL}"

openssl req -new -key tls.key -out tls.csr -subj "/C=DE/ST=NRW/L=Earth/O=${COMPANY}/OU=IT/CN=${DOMAIN}/emailAddress=${EMAIL}"

openssl x509 -req -sha256 -days 3650 -in tls.csr -signkey tls.key -out tls.crt

ls -la

cd -