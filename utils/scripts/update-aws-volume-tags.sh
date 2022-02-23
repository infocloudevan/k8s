#!/bin/bash

set -e

# This script assumes you're moving K8S PVs backed by AWS volumes from
# one AWS cluster to another using Ark. It requires the name of the old
# cluster, the new cluster, and the PV in question. It will get the ID
# of the original volume, use the aws cli to get the tags, update the
# relevant tag names for the new cluster, get the ID of the new volume,
# and use the aws cli to create the tags on the new volume.
#
# Assumptions:
#   - the names provided for the old cluster:
#     - are used as the kubectl context names
#     - are used as the cluster names by kops
#
# Requirements:
#   - kubectl
#   - aws cli
#   - jq

# CHECK INPUTS

if [ -z "$1" ]; then
  echo "must specify old cluster name"
  exit 1
fi

if [ -z "$2" ]; then
  echo "must specify new cluster name"
  exit 1
fi

if [ -z "$3" ]; then
  echo "must specify namespace"
  exit 1
fi

claims=$4

if [ -z "$4" ]; then
  echo "no specific claim provided -- using all claims in $2 - $3"
  claims=$(kubectl --context $2 --namespace $3 get pvc | grep Bound | awk '{print $3}' | tr "\n" ' ')
fi

# GET AWS VOLUME IDS (sometimes volume IDs in k8s are prepended w/ 'aws://<availability zone>')

for pvc in $claims; do
  old_vol_id=$(kubectl --context $1 --namespace $3 get pv/$pvc -o json | jq .spec.awsElasticBlockStore.volumeID | tr -d '"' | sed -e 's/aws:\/\/.*\///g')
  echo "Old Volume ID: $old_vol_id"
  echo

  new_vol_id=$(kubectl --context $2 --namespace $3 get pv/$pvc -o json | jq .spec.awsElasticBlockStore.volumeID | tr -d '"' | sed -e 's/aws:\/\/.*\///g')
  echo "New Volume ID: $new_vol_id"
  echo

  # GET OLD AWS VOLUME TAGS

  old_vol_tags=$(aws ec2 describe-volumes --volume-ids $old_vol_id | jq -c .Volumes[0].Tags)
  echo "Old Volume Tags: $old_vol_tags"
  echo

  # UPDATE NEW AWS VOLUME TAGS

  new_vol_tags=$(echo $old_vol_tags | sed -e "s/$1/$2/g")
  echo "New Volume Tags: $new_vol_tags"
  echo

  aws ec2 create-tags --resources $new_vol_id --tags $new_vol_tags
  echo "New Volume Tags Updated"
done
