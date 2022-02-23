#!/bin/bash

set -x

HOST=$1
PORT=$2
DB=$3
USERNAME=$4
PWD=$5

HOST=${HOST:-test-saas.cmfxlqcsk74c.us-east-2.rds.amazonaws.com}
PORT=${PORT:-5432}
DB=${DB:-dark3}
USERNAME=${USERNAME:-saasadmin}
#PWD=${PWD:-V5vp4eVjQG342UpM}

if [ "$PWD" != "" ]; then
   SETPWD="env PGPASSWORD=$PWD"
else
   PWDOPT="-W"
fi

$SETPWD psql -e -h $HOST -p $PORT -U $USERNAME $PWDOPT $DB <<EOQ

\echo 'Collect IP threats with missing WHOIS info...'
SELECT
    s.uuid AS sensor,
    t.data AS threat,
    t.last AS lastseen
INTO TEMP TABLE no_whois
FROM
    threats t
    JOIN sensors s ON s.id = t.sensor_id
    LEFT JOIN whois w ON w.data = t.data AND w.account_id = t.account_id
WHERE
    t.data SIMILAR TO '[0-9]+.[0-9]+.[0-9]+.[0-9]+'
    AND w.org IS NULL
    AND w.registry IS NULL
ORDER BY
    s.id;
 
\echo 'Save results to CSV file'
\COPY no_whois TO './no_whois.csv' with CSV HEADER

EOQ