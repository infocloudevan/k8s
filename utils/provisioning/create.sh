#!/bin/bash

set -e

kubectl config use-context appliances

scratch=$(mktemp -d)

function cleanup {
  echo -e "\nCleaning up!\n"
  rm -rf "$scratch"
}

# $1 should be comma-separated list of DNS servers
# $2 should be file to replace {{DNS}} in
function replace_dns() {
  IFS=',' read -ra ADDRS <<< "$1"
  for i in "${!ADDRS[@]}"; do
    DNS[$i]="DNS=${ADDRS[$i]}"
  done

  printf -v setting "%s\n" "${DNS[@]}"
  setting="$(echo "${setting%?}" | sed ':a;N;$!ba;s/\n/\\n/g')"

  sed -i -e 's~{{DNS}}~'"${setting}"'~' $2
}

path=./templates/appliance-rbac.yml.tmpl

sonly=false
iface=enp6s0
sensor=default
static=false
inline=false
cloud=false
sensors=false

read -p "What is the company name? : " company

if [ -z "$company" ]; then
  echo -e "No company name provided. Must provide the company name.\n" >&2
  exit 255
fi

PS3='What is the company size? '
sizeopt=("Small: up to $9 Million in revenue" "Medium: $10 Million to $1 Billion in revenue" "Large: over $1 Billion in revenue")
select szopt in "${sizeopt[@]}"
do
  case $szopt in
    "Small: up to $9 Million in revenue")
      size="Small"
      break
      ;;
    "Medium: $10 Million to $1 Billion in revenue")
      size="Medium"
      break
      ;;
    "Large: over $1 Billion in revenue")
      size="Large"
      break
      ;;
    *) echo invalid option;;
  esac
done

PS3='Please enter your choice: '
sectopt=("Finance & Banking" "Energy & Utilities" "Retail & Entertainment" "Food & Agriculture" "Government" "Academia" "Professional Services" "Information Technology & Services" "Health Care" "Nonprofit")
select scopt in "${sectopt[@]}"
do
    case $scopt in
        "Finance & Banking")
            sector="Finance & Banking"
            break
            ;;
        "Energy & Utilities")
            sector="Energy & Utilities"
            break
            ;;
        "Retail & Entertainment")
            sector="Retail & Entertainment"
            break
            ;;
        "Food & Agriculture")
            sector="Food & Agriculture"
            break
            ;;
        "Government")
            sector="Government"
            break
            ;;
        "Academia")
            sector="Academia"
            break
            ;;
        "Professional Services")
            sector="Professional Services"
            break
            ;;
        "Information Technology & Services")
            sector="Information Technology & Services"
            break
            ;;
        "Health Care")
            sector="Health Care"
            break
            ;;
        "Nonprofit")
            sector="Nonprofit"
            break
            ;;
        *) echo invalid option;;
    esac
done

read -p "What is the namespace for the appliance? : " namespace

if [ -z "$namespace" ]; then
  echo -e "No namespace name provided. Must provide the namespace name.\n" >&2
  exit 255
fi

read -p "What is the nodename for the appliance? : " appliance

if [ -z "$appliance" ]; then
  echo -e "No appliance nodename provided. Must provide the appliance nodename.\n" >&2
  exit 255
fi

read -p "What is the appliance sensor name (the default is $sensor)? : " sensor

read -p "What is the appliance interface name (the default is $iface, syslog is usually at enp4s0)? : " iface

read -p "Do you have a cloud-config already in cloud-config directory? (yes/NO): " havecloud

havecloud=${havecloud:-"n"}

if [[ $havecloud =~ ^([yY][eE][sS]|[yY])$ ]]; then
  cloud=true
fi

read -p "Is this an inline blocking appliance? (yes/NO): " isinline

isinline=${isinline:-"n"}

if [[ $isinline =~ ^([yY][eE][sS]|[yY])$ ]]; then
  inline=true
fi

read -p "Are there downstream collectors reporting into this appliance? (yes/NO): " havesensor

havesensor=${havesensor:-"n"}

if [[ $havesensor =~ ^([yY][eE][sS]|[yY])$ ]]; then
  sensors=true
fi

read -p "Do you need to configure the appliance with static IP address? (yes/NO): " needstatic

needstatic=${needstatic:-"n"}

if [[ $needstatic =~ ^([yY][eE][sS]|[yY])$ ]]; then
  static=true
  read -p "What is the static IP address for the appliance?: " ip
  read -p "What is the gateway address?: " gateway
  read -p "What is the DNS address (can be comma-separated list, no spaces)?: " dns
  read -p "What interface do you want to assign the address to?: " statiface
fi

echo "We are ready to provision an appliance with the following values: "
echo "Company:        "$company
echo "Size:           "$size
echo "Sector:         "$sector
echo "Namespace:      "$namespace
echo "Nodename:       "$appliance
echo "Sensor name:    "$sensor
echo "Interface name: "$iface

if [ "$cloud" = true ]; then
  echo "Already have cloud-config "
elif [ "$inline" = true ]; then
  echo "Is an inline blocking appliance "
elif [ "$sensors" = true ]; then
  echo "Has downstream collectors "
elif [ "$static" = true ]; then
  echo "Requires a static IP "
fi

echo ""
echo "We are ready to provision the appliance with the above information. "
read -p "Are you sure you want to proceed? (yes/NO): " proceed

proceed=${proceed:-"n"}

if [[ $proceed =~ ^([yY][eE][sS]|[yY])$ ]]; then

  echo ""
  echo "Will get started with the k8s stuff ... "
  echo ""

  trap cleanup EXIT

  url=logs.$namespace.darkcubed.net

  cp $path $scratch/rbac-$appliance.yml

  sed -i "s~{{APPLIANCE}}~$appliance~; s~{{NAMESPACE}}~$namespace~" $scratch/rbac-$appliance.yml

  cp ./templates/appliance-node.yml.tmpl $scratch/appliance-node.yml

  sed -i "s~{{APPLIANCE}}~$appliance~" $scratch/appliance-node.yml

  cp ./templates/status-object.yml.tmpl $scratch/status-object.yml

  sed -i "s~{{APPLIANCE}}~$appliance~; s~{{NAMESPACE}}~$namespace~" $scratch/status-object.yml

  cp ./templates/quay.io.yml.tmpl $scratch/quay.io-$appliance.yml

  sed -i "s~{{NAMESPACE}}~$namespace~" $scratch/quay.io-$appliance.yml

  cp ./templates/redis-config.yml.tmpl $scratch/$namespace-redis-config.yml

  sed -i -e "s~{{NAMESPACE}}~$namespace~" $scratch/$namespace-redis-config.yml
  
  kubectl create namespace $namespace || true

  default_secret=$(kubectl --namespace=$namespace get secrets | grep default-token | awk '{print $1}')
  token=$(kubectl --namespace=$namespace get secret $default_secret -o json | jq -r '.data.token' | base64 -d)

  kubectl create -f $scratch/appliance-node.yml
  kubectl create -f $scratch/status-object.yml
  kubectl create -f $scratch/rbac-$appliance.yml || true
  kubectl create -f $scratch/quay.io-$appliance.yml || true
  kubectl create -f $scratch/$namespace-redis-config.yml || true

  mkdir -p ./cloud-configs
  
  if [ "$static" = true ]; then

    cp ./templates/cloud-config-static.yml.tmpl ./cloud-configs/$appliance-cloud-config.yaml
    sed -i -e "s~{{IP}}~$ip~; s~{{GATEWAY}}~$gateway~; s~{{INTERFACE}}~$iface~" ./cloud-configs/$appliance-cloud-config.yaml
    replace_dns $dns ./cloud-configs/$appliance-cloud-config.yaml

  elif [ "$blocking" = true ]; then

    cp ./templates/cloud-config-blocking.yml.tmpl ./cloud-configs/$appliance-cloud-config.yaml

  elif [ "$inline" = true ]; then

    cp ./templates/cloud-config-inline.yml.tmpl ./cloud-configs/$appliance-cloud-config.yaml

  elif [ "$cloud" = false ]; then

    cp ./templates/cloud-config.yml.tmpl ./cloud-configs/$appliance-cloud-config.yaml

  fi

  sed -i -e "s~{{APPLIANCE}}~$appliance~; s~{{NAMESPACE}}~$namespace~; s~{{CUSTOMER_TOKEN}}~$token~" ./cloud-configs/$appliance-cloud-config.yaml

  echo "The cloud-config for nodename $appliance is saved at ./cloud-configs/$appliance-cloud-config.yaml "
  
  kubectl --namespace $namespace delete configmap $appliance-cloud-config || true
  kubectl --namespace $namespace create configmap $appliance-cloud-config --from-file=cloud-config.yml=./cloud-configs/$appliance-cloud-config.yaml --from-literal=version=v1.9.6-0

  echo ""
  echo "We will now create the secrets setting config and main deployments for the appliance ... "
  echo ""
  
  mkdir -p ../../$namespace/deployments/
  mkdir -p ../../$namespace/utilities/
  mkdir -p ../../$namespace/secrets/
  
  dark-secrets --name $appliance-scoreboard-config --namespace $namespace -n "$company" -s "$size" -r "$sector" --user admin > ../../$namespace/secrets/$appliance-config.json
  
  read -p "Is this a sensor only deployment? (yes/NO): " sonlyquest
  
  sonlyquest=${sonlyquest:-"n"}
  
  if [[ $sonlyquest =~ ^([yY][eE][sS]|[yY])$ ]]; then
    read -p "Is this a saas appliance sensor? (YES/no): " batboy
    
    batboy=${batboy:-"y"}
    
    if [[ $batboy =~ ^([yY][eE][sS]|[yY])$ ]]; then
    
      cp ./templates/master-sensor-batboy.yml.tmpl ../../$namespace/deployments/$appliance-sensor.yml
      
    else

      cp ./templates/master-sensor-only.yml.tmpl ../../$namespace/deployments/$appliance-sensor.yml
    
    fi

    read -p "Do you want to use $url as the URL for the collector? (YES/no): " newurl
    
    newurl=${newurl:-"y"}
    
    if [[ $newurl =~ ^([nN][oO]|[nN])$ ]]; then
    
      read -p "What is the new URL (IP or domain; e.g., $url)? : " url
      
    fi

    sed -i -e "s~{{NAMESPACE}}~$namespace~; s~{{APPLIANCE}}~$appliance~; s~{{IFACE}}~$iface~; s~{{SENSOR}}~$sensor~; s~{{URL}}~$url~" ../../$namespace/deployments/$appliance-sensor.yml

    read -p "Is this SPAN deployment? (YES/no): " input

    input=${input:-"y"}

    if [[ $input =~ ^([yY][eE][sS]|[yY])$ ]]; then

      sed -i "s~{{INPUTS}}~INPUTS_D3_LIVE~" ../../$namespace/deployments/$appliance-sensor.yml

    else

      sed -i "s~{{INPUTS}}~INPUTS_D3_SYSLOG~" ../../$namespace/deployments/$appliance-sensor.yml

    fi

  else
  
    cp ./templates/master.yml.tmpl ../../$namespace/deployments/$appliance.yml
  
    sed -i -e "s~{{NAMESPACE}}~$namespace~; s~{{APPLIANCE}}~$appliance~" ../../$namespace/deployments/$appliance.yml
  
    cp ./templates/master-workers.yml.tmpl ../../$namespace/deployments/$appliance-workers.yml
  
    sed -i -e "s~{{NAMESPACE}}~$namespace~; s~{{APPLIANCE}}~$appliance~" ../../$namespace/deployments/$appliance-workers.yml
  
    cp ./templates/master-sensor.yml.tmpl ../../$namespace/deployments/$appliance-sensor.yml
  
    sed -i -e "s~{{NAMESPACE}}~$namespace~; s~{{APPLIANCE}}~$appliance~; s~{{IFACE}}~$iface~; s~{{SENSOR}}~$sensor~" ../../$namespace/deployments/$appliance-sensor.yml

    read -p "Is this SPAN deployment? (YES/no): " input

    input=${input:-"y"}

    if [[ $input =~ ^([yY][eE][sS]|[yY])$ ]]; then

      sed -i "s~{{INPUTS}}~INPUTS_D3_LIVE~" ../../$namespace/deployments/$appliance-sensor.yml

    else

      sed -i "s~{{INPUTS}}~INPUTS_D3_SYSLOG~" ../../$namespace/deployments/$appliance-sensor.yml

    fi

  fi

  cp ./templates/ssh-access.yml.tmpl ../../$namespace/utilities/ssh-access-$namespace.yml

  sed -i -e "s~{{NAMESPACE}}~$namespace~; s~{{APPLIANCE}}~$appliance~" ../../$namespace/utilities/ssh-access-$namespace.yml

  echo "Deployments have been created at ../../$namespace/deployments/."

  read -p "Do you want to create the deployments in the appliances cluster? (YES/no): " deploy

  deploy=${deploy:-"y"}

  if [[ $deploy =~ ^([yY][eE][sS]|[yY])$ ]]; then

    kubectl create -f ../../$namespace/secrets/
    kubectl create -f ../../$namespace/deployments/
    kubectl create -f ../../$namespace/utilities/
  
  fi

  echo
  echo "Copy the namespace token for the spreadsheet: "
  echo $token
  echo

  echo
  echo "Here is the status of the namespace $namespace: "
  echo
  
  kubectl --namespace $namespace get po,deploy,rc,secrets,job,cm 

  if [[ $batboy =~ ^([yY][eE][sS]|[yY])$ ]]; then
  
    echo
    echo "Creating the secret settings file in calops too: "

    kubectl config use-context calops
    kubectl create -f ../../$namespace/secrets/
    kubectl config use-context appliances
  
  fi

else

  echo -e "We will stop the process then.\n" >&2
  exit 255
  
fi
