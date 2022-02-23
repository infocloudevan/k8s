#!/bin/bash

usage="$(basename "$0") -a <appliance name>

where:
    -h show this help text
    -a appliance or sensor name"

while getopts ':ha:' option; do
    case "$option" in
      h)  echo -e "$usage\n"
          exit                ;;
      a)  appliance="$OPTARG" ;;
      \?) echo -e "illegal option: -$OPTARG\n" >&2
          echo -e "$usage\n" >&2
          exit 255            ;;
    esac
done

if [ -z "$appliance" ]; then
    echo -e "No appliance or sensor name provided. Must provide the -a option.\n" >&2
    echo -e "$usage\n" >&2
    exit 255
fi

wget -O ./apps/coreos-install https://raw.github.com/coreos/init/master/bin/coreos-install

chmod +x ./apps/coreos-install

sudo ./apps/coreos-install -d /dev/sda -C stable -c /media/mint/D3/cloud-configs/$appliance-cloud-config.yaml

rm ./apps/coreos-install

echo ""
echo "SUCCESS!! The D3 Appliance installation is complete."
echo ""

read -p "Do you want to shutdown the appliance (yes/no)?: " shutdown

shutdown=${shutdown:-"y"}

if [[ $shutdown =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo shutdown now
else
    exit 1
fi