#!/bin/bash

if [ -z "$1" ]; then
    echo "Missing version argument" 1>&2
    exit 1
fi

version=$1
context=$2

repo=078306444420.dkr.ecr.us-east-2.amazonaws.com/darkcubed

# save current context and namespace

oldcontext=$(kubectl config current-context)
oldns=$(kubectl config view -o jsonpath='{.contexts[?(@.name == "'$oldcontext'")].context.namespace}')
if [ -z "oldns" ]; then
  oldns=default
fi

use_namespace() {
  kubectl config set-context $1 --namespace $2
  kubectl config use-context $1
}

revert_context() {
  echo $'\nRestoring context'
  use_namespace $oldcontext $oldns 
}
trap revert_context EXIT

if [ -z "$context" ]; then
    context=$oldcontext
fi

update_container_version() {
  deployment=$1
  container=$2
  image=$3
  if [ -z "$image" ]; then
    container=$deployment
    image=$2
  fi
  kubectl set image deployment/$deployment "$container=$repo/$image:$version"
}

### Update SaaS deployments

echo $'Updating SaaS deployments'
use_namespace $context saas

for deployment in catcher coach mascot meraki; do
  update_container_version $deployment hyperdark
done

update_container_version stats groundskeeper hyperdark
update_container_version ui scoreboard hyperdark
update_container_version workers lineup hyperdark

update_container_version accountant accountant
update_container_version accounts-manager accounts-manager
update_container_version stats statsite statsite

### Update D3OC deployments
 
echo $'\nUpdating D3OC deployments'
 
use_namespace $context d3oc

for deployment in api scorecard scorekeeper ticket-booth; do
   update_container_version $deployment hyperdark
done

for container in "" -dns -geo -whois; do
   update_container_version statistician$container statistician
done

update_container_version statsite statsite
update_container_version timescale timescale


