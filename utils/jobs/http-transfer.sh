#!/bin/bash

set -e

usage="usage $(basename "$0") [-h] [-s] [-d] -n <namespace> -a <appliance name>

This script will create a http transfer source or destination job for a given appliance.
If destination is selected, the postgres-backup.tar.gz file will be transfered to /home/core.

where:
    -h                    show this help text
    -s                    create a job for source appliance
    -d                    create a job for destination appliance
    -n namespace          k8s namespace to use
    -a appliance          name of customer's appliance"
    
# assume help is needed if no args are passed
if [ "$#" -eq 0 ]; then
    echo "$usage"
    exit
fi

source=false
destination=false

# loop through positional options/arguments
while getopts ':hsdn:a:' option; do
    case "$option" in
        h)  echo "$usage"; exit ;;
        s)  source=true         ;;
        d)  destination=true    ;;
        n)  namespace="$OPTARG" ;;
        a)  appliance="$OPTARG" ;;
        \?) echo -e "illegale option: -$OPTARG\n" >$2
            echo "$usage" >&2
            exit 1 ;;
    esac
done

if [[ "$source" == false && "$destination" == false ]] ; then
    echo -e "You did not add either the -s or -d flag\n"
    echo -e "$usage"
    exit 1
fi

# check of length of appliance name string is 0
if [ -z $appliance ]; then
    echo -e "Must provide an appliance name\n"
    echo -e "$usage"
    exit 1
fi

#check of length of namespace name string is 0
if [ -z $namespace ]; then
    echo -e "Must provide a namepsace name\n"
    echo "$usage"
    exit 1
fi

if [[ "$source" = true ]] ; then
    echo "A http transfer job will be created and deployed for source "$appliance"."
    cp http-source.yml.tmpl http-source-$appliance.yml
    sed -i '' "s~{{APPLIANCE}}~$appliance~; s~{{NAMESPACE}}~$namespace~" http-source-$appliance.yml
    kubectl create -f http-source-$appliance.yml
    echo "Here are the results of the job."
    sleep 5
    kubectl --namespace $namespace get jobs
fi

sleep 5

if [[ "$destination" = true ]] ; then
    read -p "What is the IP of the destination?: " ip
    if [ -z $ip ]; then
        echo -e "Must provide an IP for the destination\n"
        exit 1
    fi
    cp http-dest.yml.tmpl http-dest-$appliance.yml
    sed -i '' "s~{{APPLIANCE}}~$appliance~; s~{{NAMESPACE}}~$namespace~; s~{{IP}}~$ip~" http-dest-$appliance.yml
    read -p "Would you like to see the job for "$appliance"? (YES/no): " job
    job=${job:-"y"}
    if [[ $job =~ ^([yY][eE][sS]|[yY])$ ]]; then
        bbedit --new-window http-dest-$appliance.yml
    fi
    echo "Here are the results of the job."
    sleep 5
    kubectl --namespace $namespace get jobs
fi

exit 0