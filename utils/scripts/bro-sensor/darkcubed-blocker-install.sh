#!/usr/bin/env bash

# 1. Install ipset
# 2. Install cron job for updating ipset

# To support uninstalling, we track whether or not we had to install
# ipset. If we did, then we will purge it as part of the uninstall.

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

# default uninstall to false (!0)
uninstall=1

# default dry-run to false (!0)
dryrun=1

# default experimental to false (!0)
experimental=1

usage="usage: $(basename "$0") [-h] [-n] [-u] [-d] [-e] -b <blocklist url>

This script will install and configure ipset and iptables to block
network traffic using the provided blocklist URL.

If ipset is not installed, this script will install it via Aptitude.
This script then adds Dark Cubed iptables rules to apply the ipset. This
script will also install a cron job to pull from the blocklist URL every
5 minutes and update the Dark Cubed IP set.

This script requires the user to provide the blocklist URL for their
sensor. To obtain this URL, view the sensor details in the Dark Cubed UI
and click 'Copy' on the 'Blocklist URL'.

This script is idempotent, and thus can be run multiple times without
harm. The -u option can also be used to uninstall the Dark Cubed blocker.

Note that as of 28 SEP 2018 this script has only been designed for and tested
on Ubuntu 16.04+. Users can opt to try the installation on non-Ubuntu (but
Debian-based) operating systems with the -e option.

where:
    -n                    disable colored output text to screen
    -u                    uninstall a previously installed sensor
    -d                    dry-run (don't actually change system)
                          dry-run is ignored when uninstalling
    -e                    experimental OS support (run on non-Ubuntu hosts)
    -b blocklist URL      Dark Cubed blocklist URL to monitor
    -h                    show this help text"
    
# assume help is needed if no args are passed
if [ "$#" -eq 0 ]; then
    echo -e "$usage"
    exit
fi

# loop through positional options/arguments
while getopts ':nudeb:i:a:s:h' option; do
    case "$option" in
        n)  RED=$RESET; GREEN=$RESET  ;;
        u)  uninstall=0               ;;
        d)  dryrun=0                  ;;
        e)  experimental=0            ;;
				b)  blocklist="$OPTARG"       ;;
        h)  echo -e "$usage"; exit    ;;
        \?) echo -e "illegale option: -$OPTARG\n" >$2
            echo -e "$usage" >&2
            exit 1 ;;
    esac
done

# check if we're uninstalling. if so, short-circuit everything else
if ((uninstall == 0)); then
  # check if we're running as root
  if ((EUID != 0)); then
    echo -e "${RED}This script must be run as root${RESET}\n"
    exit 1
  fi

  echo -e "${GREEN}Removing Dark Cubed blocking configs${RESET}\n"

  while [ -f /opt/darkcubed/.block-script-running ]; do
    echo -e "${RED}Waiting for block script to finish before uninstalling${RESET}"
    sleep 1
  done

  rm -f /etc/cron.d/darkcubed-blocklist
  rm -f /opt/darkcubed/block.sh

  /sbin/iptables -D INPUT -m set --match-set darkcubedblocklist src -j DROP
  /sbin/iptables -D INPUT -m set --match-set darkcubedblocklist dst -j DROP

  /sbin/ipset flush darkcubedblocklist
  /sbin/ipset destroy darkcubedblocklist

  if [ -e /opt/darkcubed/ipset-installed ]; then
    echo -e "${GREEN}Uninstalling ipset${RESET}\n"

    if apt purge -y ipset; then
      apt autoremove -y
      rm    /opt/darkcubed/ipset-installed
      rmdir /opt/darkcubed &> /dev/null || true
    else
      echo -e "${RED}Error uninstalling ipset${RESET}\n"
      exit 1
    fi
  else
    if dpkg -l ipset &> /dev/null; then
      echo -e "${GREEN}ipset was installed prior -- not uninstalling${RESET}\n"
    fi
  fi

  exit 0
fi

# check of length of blocklist URL string is 0
if [ -z $blocklist ]; then
    echo -e "${RED}Must provide blocklist URL${RESET}\n"
    echo -e "$usage"
    exit 1
fi

# check if the blocklist URL ends in /ip. if not, add it.
if [[ ! $blocklist =~ /ip$ ]]; then
  blocklist="$blocklist/ip"
fi

if ((dryrun != 0)); then
  # check if we're running as root
  if ((EUID != 0)); then
    echo -e "${RED}This script must be run as root${RESET}\n"
    exit 1
  fi
fi

# simple test for Ubuntu
if ! cat /etc/os-release | grep "[U|u]buntu" > /dev/null 2>&1; then
  echo -e "${RED}This script has only been tested on Ubuntu${RESET}\n"

  if ((experimental == 0)); then
    echo -e "${GREEN}Experimental OS support selected -- attempting installation anyway${RESET}\n"
  else
    exit 1
  fi
fi

if ((dryrun == 0)); then
  echo -e "${GREEN}Running a dry run of this script${RESET}\n"
fi

# check if ipset is installed
if ! dpkg -l ipset &> /dev/null; then
  echo -e "${GREEN}ipset is not currently installed -- installing now${RESET}\n"

  if ((dryrun == 0)); then
    if ! apt install -y --dry-run ipset; then
      echo -e "${RED}Error installing ipset -- aborting${RESET}\n"
      exit 1
    fi
  else
    if ! apt update; then
      echo -e "${RED}Error updating Apt repositories -- aborting${RESET}\n"
      exit 1
    fi

    if apt install -y ipset; then
      mkdir -p /opt/darkcubed
      echo "true" > /opt/darkcubed/ipset-installed
    else
      echo -e "${RED}Error installing ipset -- aborting${RESET}\n"
      exit 1
    fi
  fi

  echo
fi

# Script to monitor blockist and update IP set
BLOCKSCRIPT=$(cat << EOC
#!/bin/bash

# This is used by the uninstaller to detect if the block script is
# running when an uninstall is scheduled.
touch /opt/darkcubed/.block-script-running

# Temp file for storing the blocklist.
blocklist=\$(mktemp darkcubed-blocklist.XXXXX)

function cleanup {
  # Delete temp file created above.
  rm -f "\$blocklist"

  # Delete runfile for block script.
  rm -f /opt/darkcubed/.block-script-running
  
}

# Trap the EXIT pseudo-signal to run the cleanup function above when
# this script exits for any reason.
trap cleanup EXIT

# Pull sensor-specific blocklist via URL and write to temp file.
if /usr/bin/curl -s {{BLOCKLIST}} > \$blocklist; then
  # Flush the Dark Cubed IP set.
  /sbin/ipset flush darkcubedblocklist

  # Add each IP from the blocklist to the IP set
  while read threat; do
    /sbin/ipset add darkcubedblocklist \$threat
  done <\$blocklist
fi
EOC
)

# Cron job to run blockist script script
BLOCKCRON=$(cat << EOC
# /etc/cron.d/darkcubed-blocklist
 
# Run the Dark Cubed block script every 5 minutes.
*/5 * * * * root /bin/bash /opt/darkcubed/block.sh &> /dev/null
EOC
)

if ((dryrun == 0)); then
  echo -e "${GREEN}The following ipset will be created${RESET}\n"
  echo "ipset create darkcubedblocklist hash:ip hashsize 4096"
  echo

  echo -e "${GREEN}The following iptables rules would be created${RESET}\n"
  echo "iptables -I INPUT -m set --match-set darkcubedblocklist src -j DROP"
  echo "iptables -I INPUT -m set --match-set darkcubedblocklist dst -j DROP"
  echo

  echo -e "${GREEN}The following block script would be written to /opt/darkcubed/block.sh${RESET}\n"
  # run script template through sed to pipulate blocklist setting
  echo "$BLOCKSCRIPT" | sed "s~{{BLOCKLIST}}~$blocklist~"
  echo

  echo -e "${GREEN}The following cron job would be written to /etc/cron.d/darkcubed-blocklist${RESET}\n"
  echo "$BLOCKCRON"
  echo
else
  echo -e "${GREEN}Creating Dark Cubed blocklist ipset${RESET}\n"
  /sbin/ipset create darkcubedblocklist hash:ip hashsize 4096 &> /dev/null

  echo -e "${GREEN}Creating iptables rules for Dark Cubed IP set${RESET}\n"
  /sbin/iptables -I INPUT -m set --match-set darkcubedblocklist src -j DROP
  /sbin/iptables -I INPUT -m set --match-set darkcubedblocklist dst -j DROP

  echo -e "${GREEN}Writing Dark Cubed block script to /opt/darkcubed/block.sh${RESET}\n"
  # run script template through sed to pipulate blocklist setting
  echo "$BLOCKSCRIPT" | sed "s~{{BLOCKLIST}}~$blocklist~" > /opt/darkcubed/block.sh

  echo -e "${GREEN}Writing cron job for blocklist monitoring to /etc/cron.d/darkcubed-blocklist${RESET}\n"
  echo "$BLOCKCRON" > /etc/cron.d/darkcubed-blocklist

  echo -e "${GREEN}Doing an initial run of the Dark Cubed block script${RESET}\n"
  /bin/bash /opt/darkcubed/block.sh &> /dev/null
fi

echo -e "${GREEN}Done configuring the Dark Cubed blocker${RESET}\n"
