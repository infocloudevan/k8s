#!/bin/bash

usage="usage $(basename "$0") [-h] -n <namespace> -a <appliance name>

This script will update the /etc/hosts file on appliances.

where:
    -h                    show this help text
    -n namespace          k8s namespace to use
    -a appliance          name of customer's appliance"
    
# assume help is needed if no args are passed
if [ "$#" -eq 0 ]; then
    echo "$usage"
    exit
fi

# loop through positional options/arguments
while getopts ':hn:a:' option; do
    case "$option" in
        h)  echo "$usage"; exit ;;
        n)  namespace="$OPTARG" ;;
        a)  appliance="$OPTARG" ;;
        \?) echo -e "illegale option: -$OPTARG\n" >$2
            echo "$usage" >&2
            exit 1 ;;
    esac
done

# check of length of appliance name string is 0
if [ -z $appliance ]; then
    echo -e "Must provide an appliance name\n"
    echo "$usage"
    exit 1
fi

#check of length of namespace name string is 0
if [ -z $namespace ]; then
    echo -e "Must provide a namepsace name\n"
    echo "$usage"
    exit 1
fi

cp etc-hosts.yml.tmpl etc-hosts-$appliance.yml
sed -i '' "s~{{APPLIANCE}}~$appliance~; s~{{NAMESPACE}}~$namespace~" etc-hosts-$appliance.yml
kubectl create -f etc-hosts-$appliance.yml
sleep 7
kubectl --namespace=$namespace get jobs
rm etc-hosts-$appliance.yml