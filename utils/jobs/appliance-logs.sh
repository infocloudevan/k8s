#!/bin/bash

name=$(basename "$0")
base=${name%.*}
usage="usage $name [-h] -n <namespace> -a <appliance name> -t <type> -c <command>

This script will trigger logs to be captured from the given appliance.

where:
    -h                    show this help text
    -n namespace          namespace appliance belongs to
    -a appliance          name of appliance 
    -t type               valid types: container, command, file
    -c command            container name, command, or file path"
    
# assume help is needed if no args are passed
if [ "$#" -eq 0 ]; then
  echo "$usage"
  exit
fi

# loop through positional options/arguments
while getopts ':hn:a:t:c:' option; do
  case "$option" in
    h)  echo "$usage"; exit ;;
    n)  namespace="$OPTARG" ;;
    a)  appliance="$OPTARG" ;;
    t)  cmd_type="$OPTARG"  ;;
    c)  cmd="$OPTARG"       ;;
    \?) echo -e "illegale option: -$OPTARG\n" >$2
        echo "$usage" >&2
        exit 1 ;;
  esac
done

# strip off parsed options just in case additional
# options are passed for command type 'pcap'
shift $((OPTIND - 1))

# check of length of namespace string is 0
if [ -z "$namespace" ]; then
  echo -e "Must provide a namespace\n"
  echo "$usage"
  exit 1
fi

# check of length of appliance name string is 0
if [ -z "$appliance" ]; then
  echo -e "Must provide an appliance name\n"
  echo "$usage"
  exit 1
fi

# check of length of command type string is 0
if [ -z "$cmd_type" ]; then
  echo -e "Must provide a command type\n"
  echo "$usage"
  exit 1
fi

types=( "container" "command" "file" )

# check if command type is valid
valid=false
for t in "${types[@]}"; do
  if [[ "$t" == "$cmd_type" ]]; then
    valid=true
    break
  fi
done

if [[ "$valid" = false ]]; then
  echo -e "Command type '$cmd_type' is not valid\n"
  echo "$usage"
  exit 1
fi

# check of length of command string is 0
if [ -z "$cmd" ]; then
    echo -e "Must provide a command string\n"
    echo "$usage"
    exit 1
fi

cp $base.yml.tmpl $base.yml

# The "special sauce" at the end of this for replacing {{COMMAND}} is to
# escape `&` in the command string (ie. "ip addr && ip route"), since
# `&` has special meaning in sed.
sed -i "s~{{APPLIANCE}}~$appliance~; s~{{TYPE}}~$cmd_type~; s~{{COMMAND}}~${cmd//&/\\&}~" $base.yml

kubectl --context appliances --namespace $namespace create -f $base.yml
sleep 5
kubectl --context appliances --namespace $namespace get jobs

rm $base.yml
