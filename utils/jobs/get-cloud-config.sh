#!/bin/bash

usage="usage $(basename "$0") [-h] -n <namespace> -a <appliance name>

This script will report the cloud-config file from the appliance.

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
 
kubectl --namespace=$namespace get deployments $appliance-sportscast

read -p "Does the appliance need a sportscaster? (YES/no): " sportscaster

sportscaster=${sportscaster:-"n"}

if [[ $sportscaster =~ ^([yY][eE][sS]|[yY])$ ]]; then
    mkdir -p ../../$namespace/utilities
    cp sportscast.yml.tmpl ../../$namespace/deployments/$appliance-sportscast.yml
    sed -i '' "s~{{APPLIANCE}}~$appliance~; s~{{NAMESPACE}}~$namespace~" ../../$namespace/deployments/$appliance-sportscast.yml
    kubectl create -f ../../$namespace/deployments/$appliance-sportscast.yml
    sleep 15
    kubectl --namespace $namespace get deployments $appliance-sportscast
fi

echo "This script will report the cloud-config file from the appliance" $appliance" to the newsroom."
echo ""

read -p "Are you sure you want to do this? (YES/no): " get

get=${get:-"y"}

if [[ $get =~ ^([yY][eE][sS]|[yY])$ ]]; then
    cp get-cloud.yml.tmpl get-cloud-$appliance.yml
    sed -i '' "s~{{APPLIANCE}}~$appliance~; s~{{NAMESPACE}}~$namespace~" get-cloud-$appliance.yml
    kubectl create -f get-cloud-$appliance.yml
    sleep 5
    rm get-cloud-$appliance.yml
    kubectl --namespace=$namespace get jobs
    kubectl --namespace=$namespace delete jobs get-cloud-$appliance
else
    exit 1
fi
