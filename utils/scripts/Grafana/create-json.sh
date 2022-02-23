#!/bin/sh

set -e

usage="$(basename "$0") [-h] -n <customer name> -c <code name>

This will create a JSON file for importing into Grafana.

where:
  -h show this help text
  -n customer name for the dashboard title 
  -c code name for the appliance"

while getopts ':hn:c:' option; do
  case "$option" in
    h)  echo -e "$usage\n"
        exit ;;
    n)  customer="$OPTARG" ;;
    c)  code="$OPTARG"     ;;
    \?) echo -e "illegal option: -$OPTARG\n" >&2
        echo -e "$usage\n" >&2
        exit 255 ;;
  esac
done

# Check to see if there is a customer name provided.
if [ -z "$customer" ] ; then
	echo "No customer name provided. Try again."
	exit 1
fi

# Check to see if there is an appliance code name.
if [ -z "$code" ] ; then
        echo "No appliance code name provided. Try again."
        exit 1
fi

cp ./master.json ./JSONs/$code.json
sed -i '' -e "s~{{CUSTOMER}}~$customer~; s~{{NODENAME}}~$code~" ./JSONs/$code.json

echo "File "./JSONs/$code.json "created with "$customer" and "$code"."