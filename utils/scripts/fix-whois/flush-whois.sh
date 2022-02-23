#!/bin/bash

HOST=$1
PORT=$2
DB=$3
USERNAME=$4
PWD=$5

HOST=${HOST:-test-d3oc.cmfxlqcsk74c.us-east-2.rds.amazonaws.com}
PORT=${PORT:-5432}
DB=${DB:-d3main}
USERNAME=${USERNAME:-d3ocadmin}
#PWD=${PWD:-pVSycpXGa2chgqEP}

if [ "$PWD" != "" ]; then
   SETPWD="env PGPASSWORD=$PWD"
else
   PWDOPT="-W"
fi

$SETPWD psql -e -h $HOST -p $PORT -U $USERNAME $PWDOPT $DB <<EOQ

\echo 'Create temp table for IP threats...'
CREATE temp TABLE no_whois (
    "sensor" text,
    "threat" text,
    "lastseen" int8
);

\echo 'Import contents from CSV file...'
\COPY no_whois FROM 'no_whois.csv' CSV HEADER;

\echo 'Find distinct threats'
SELECT
    DISTINCT (threat) AS ip 
INTO temp TABLE no_whois_distinct
FROM
    no_whois;

\echo 'Delete threats from LOOKUP_WHOIS_IP_LOG...'
DELETE FROM lookup_whois_ip_log log USING no_whois_distinct nw
WHERE log.cidr_block >>= nw.ip::INET;

\echo 'Delete threats from IP_SCORE_LOG...'
DELETE FROM ip_score_log log USING no_whois_distinct nw
WHERE log.ip = nw.ip::INET;

EOQ