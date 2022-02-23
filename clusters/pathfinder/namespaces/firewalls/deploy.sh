#!/bin/bash

name=$(basename "$0")
usage="usage $name [-h] [-n <namespace>] -c <customer> -d <device type> -i <firewall IP> [-p <firewall port>] -U <API user> -P <API password/key> -s <sensor UUID> [-t <image tag>]

This script will deploy a firewall integration cron job for a customer.

where:
    -h                    show this help text
    -n namespace          namespace to run cron job in (default: firewalls)
    -c customer           name of customer (used to name cron job)
    -d device type        valid types: SOPHOS_SG, SOPHOS_XG
    -i firewall IP        external IP of firewall for API access
    -p firewall port      external port of firewall for API access (default: 4444)
    -U API user           username for API access
    -P API password/key   password / API key for API access
    -s sensor UUID        UUID of sensor in Dark Cubed (for blocklist)
    -t image tag          tag to use for stadium Docker image (default: latest)"
    
# assume help is needed if no args are passed
if [ "$#" -eq 0 ]; then
  echo "$usage"
  exit
fi

namespace=firewalls
port=4444
tag=latest

# loop through positional options/arguments
while getopts ':hn:c:d:i:p:U:P:s:t:' option; do
  case "$option" in
    h)  echo "$usage"; exit ;;
    n)  namespace="$OPTARG" ;;
    c)  customer="$OPTARG"  ;;
    d)  device="$OPTARG"    ;;
    i)  ip="$OPTARG"        ;;
    p)  port="$OPTARG"      ;;
    U)  user="$OPTARG"      ;;
    P)  pass="$OPTARG"      ;;
    s)  sensor="$OPTARG"    ;;
    t)  tag="$OPTARG"       ;;
    \?) echo -e "illegal option: -$OPTARG\n" >$2
        echo "$usage" >&2
        exit 1 ;;
  esac
done

if [ -z "$namespace" ]; then
  echo -e "Must provide a namespace\n"
  echo "$usage"
  exit 1
fi

if [ -z "$customer" ]; then
  echo -e "Must provide a customer name\n"
  echo "$usage"
  exit 1
fi

types=( "SOPHOS_SG" "SOPHOS_XG" )

valid=false
for t in "${types[@]}"; do
  if [[ "$t" == "$device" ]]; then
    valid=true
    break
  fi
done

if [[ "$valid" = false ]]; then
  echo -e "firewall type '$device' is not valid\n"
  echo "$usage"
  exit 1
fi

if [ -z "$ip" ]; then
    echo -e "Must provide an IP address for the firewall API\n"
    echo "$usage"
    exit 1
fi

if [ -z "$port" ]; then
    echo -e "Must provide a port for the firewall API\n"
    echo "$usage"
    exit 1
fi

if [ -z "$sensor" ]; then
    echo -e "Must provide a sensor UUID for the blocklist\n"
    echo "$usage"
    exit 1
fi

if [ -z "$tag" ]; then
    echo -e "Must provide a tag for the stadium Docker image\n"
    echo "$usage"
    exit 1
fi

if [[ "$device" == "SOPHOS_SG" ]]; then
  if [ -z "$pass" ]; then
      echo -e "Must provide an API key for the firewall API\n"
      echo "$usage"
      exit 1
  fi
elif [[ "$device" == "SOPHOS_XG" ]]; then
  if [ -z "$user" ]; then
      echo -e "Must provide a user for the firewall API\n"
      echo "$usage"
      exit 1
  fi

  if [ -z "$pass" ]; then
      echo -e "Must provide a password for the firewall API\n"
      echo "$usage"
      exit 1
  fi
fi

cp sophos.yml.tmpl $customer.yml

if [[ "$device" == "SOPHOS_SG" ]]; then
  sed -i "s~{{JOB_NAME}}~$customer~; s~{{DEVICE}}~$device~; s~{{IP}}~$ip~; s~{{PORT}}~$port~; s~{{USER}}~~; s~{{SENSOR}}~$sensor~; s~{{TAG}}~$tag~" $customer.yml

  kubectl --context gov --namespace $namespace \
    create secret generic $customer \
    --from-literal client-api-key=$pass \
    --from-literal client-pass=
elif [[ "$device" == "SOPHOS_XG" ]]; then
  sed -i "s~{{JOB_NAME}}~$customer~; s~{{DEVICE}}~$device~; s~{{IP}}~$ip~; s~{{PORT}}~$port~; s~{{USER}}~$user~; s~{{SENSOR}}~$sensor~; s~{{TAG}}~$tag~" $customer.yml

  kubectl --context gov --namespace $namespace \
    create secret generic $customer \
    --from-literal client-api-key= \
    --from-literal client-pass=$pass
fi

kubectl --context gov --namespace $namespace apply -f $customer.yml
