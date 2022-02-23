#!/usr/bin/env bash

# 1. Install Bro (and SystemD service)
# 2. Install Rsyslog (includes SystemD service)
# 3. Install Rsyslog config for Dark Cubed

# To support uninstalling, we track whether or not we had to install
# Bro. If we did, then we will purge it as part of the uninstall.

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

# default uninstall to false (!0)
uninstall=1

# default dry-run to false (!0)
dryrun=1

# default experimental to false (!0)
experimental=1

# default iface to interface providing default route
iface=$(ip route | grep default | cut -d' ' -f5)

usage="usage: $(basename "$0") [-h] [-n] [-u] [-d] [-e] -i <iface> -a <address> -s <sensor>

This script will install and configure Bro IDS and Rsyslog to capture
network traffic and ship the resultant traffic metadata to the Dark
Cubed Cloud Platform.

If Bro is not installed, this script will install it via Aptitude. This
script then creates a custom local site config for Dark Cubed and a
darkcubed-bro SystemD service that starts Bro with the custom local site
config without impacting any other instance(s) of Bro that may already
be running (if installed previously). This script also creates a custom
Rsyslog config for Dark Cubed and restarts the Rsyslog service to load
the new custom config (Rsyslog should be installed already since it's
part of the ubuntu-minimal package).

This script requires the user to provide the Syslog Address to send logs
to and the structured data ID (SD-ID) of the sensor to associate the
logs with. To obtain these values for use in this script, create a new
sensor in Dark Cubed and click 'Copy' on the 'Syslog Address' and
'SD-ID' fields.

By default, Bro will listen on the host interface that provides the
default route. This can be changed with the -i option.

${GREEN}IMPORTANT: if the interface Bro is listening on has a public IP address,
it's highly suggested that you add the IP address to the list of
Internal Networks on the user's Profile Page in the Dark Cubed UI.
Doing so will allow connection details to be accurately tracked and
displayed in the UI. If installing on multiple servers that have IP
addresses in a public CIDR block, the CIDR block can be added to the
list of Internal Networks instead of the individual IP addresses.${RESET}

This script is idempotent, and thus can be run multiple times without
harm. The -u option can also be used to uninstall the Dark Cubed sensor.

Note that as of 18 SEP 2018 this script has only been designed for and tested
on Ubuntu 16.04+. Users can opt to try the installation on non-Ubuntu (but
Debian-based) operating systems with the -e option.

where:
    -n                    disable colored output text to screen
    -u                    uninstall a previously installed sensor
    -d                    dry-run (don't actually change system)
                          dry-run is ignored when uninstalling
    -e                    experimental OS support (run on non-Ubuntu hosts)
    -i iface              interface for Bro to listen on (default: $iface)
    -a Syslog Address     address to send logs to
    -s sensor SD-ID       sensor ID to associate logs with
    -h                    show this help text"
    
# assume help is needed if no args are passed
if [ "$#" -eq 0 ]; then
    echo -e "$usage"
    exit
fi

# loop through positional options/arguments
while getopts ':nudei:a:s:h' option; do
    case "$option" in
        n)  RED=$RESET; GREEN=$RESET  ;;
        u)  uninstall=0               ;;
        d)  dryrun=0                  ;;
        e)  experimental=0            ;;
        i)  iface="$OPTARG"           ;;
        a)  address="$OPTARG"         ;;
        s)  sensor="$OPTARG"          ;;
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

  echo -e "${GREEN}Removing Dark Cubed Rsyslog config${RESET}\n"

  rm -f /etc/rsyslog.d/25-darkcubed.conf
  systemctl restart rsyslog

  echo -e "${GREEN}Removing Dark Cubed Bro configs${RESET}\n"

  systemctl stop darkcubed-bro > /dev/null 2>&1 || true
  rm -f  /etc/systemd/system/darkcubed-bro.service
  rm -f  /etc/default/bro-darkcubed
  rm -f  /etc/bro/site/local-darkcubed.bro
  rm -f  /etc/cron.daily/darkcubed-bro-cleanup
  rm -rf /var/spool/bro/darkcubed
  rmdir  /var/spool/bro > /dev/null 2>&1 || true
  systemctl daemon-reload > /dev/null 2>&1 || true

  if [ -e /opt/darkcubed/bro-installed ]; then
    echo -e "${GREEN}Uninstalling Bro${RESET}\n"

    if apt purge -y bro; then
      apt autoremove -y
      rm -rf /etc/bro
      rm     /opt/darkcubed/bro-installed
      rmdir  /opt/darkcubed > /dev/null 2>&1 || true
    else
      echo -e "${RED}Error uninstalling Bro${RESET}\n"
      exit 1
    fi
  else
    if dpkg -l bro > /dev/null 2>&1; then
      echo -e "${GREEN}Bro was installed prior -- not uninstalling${RESET}\n"
    fi
  fi

  exit 0
fi

# check of length of iface string is 0
if [ -z $iface ]; then
    echo -e "${RED}Must provide interface name${RESET}\n"
    echo -e "$usage"
    exit 1
fi

# check of length of address string is 0
if [ -z $address ]; then
    echo -e "${RED}Must provide Syslog address${RESET}\n"
    echo -e "$usage"
    exit 1
fi

#check of length of sensor ID string is 0
if [ -z $sensor ]; then
    echo -e "${RED}Must provide sensor SD-ID${RESET}\n"
    echo -e "$usage"
    exit 1
fi

# split Syslog address to get addr (domain name) and port
addr=$(echo $address | cut -d':' -f1 -s)
port=$(echo $address | cut -d':' -f2 -s)

#check of length of addr string is 0
if [ -z $addr ]; then
    echo -e "${RED}Syslog address must include address and port number${RESET}\n"
    echo -e "$usage"
    exit 1
fi

#check of length of port string is 0
if [ -z $port ]; then
    echo -e "${RED}Syslog address must include address and port number${RESET}\n"
    echo -e "$usage"
    exit 1
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

# check if bro is installed
if ! dpkg -l bro > /dev/null 2>&1; then
  echo -e "${GREEN}Bro is not currently installed -- installing now${RESET}\n"

  if ((dryrun == 0)); then
    if ! apt install -y --dry-run bro; then
      echo -e "${RED}Error installing Bro -- aborting${RESET}\n"
      exit 1
    fi
  else
    if ! apt update; then
      echo -e "${RED}Error updating Apt repositories -- aborting${RESET}\n"
      exit 1
    fi

    if apt install -y bro; then
      mkdir -p /opt/darkcubed
      echo "true" > /opt/darkcubed/bro-installed
    else
      echo -e "${RED}Error installing Bro -- aborting${RESET}\n"
      exit 1
    fi
  fi

  echo
fi

# Custom Dark Cubed Bro local site config
BROCONF=$(cat << EOC
# This script logs which scripts were loaded during each run.
@load misc/loaded-scripts

# Apply the default tuning scripts for common tuning settings.
@load tuning/defaults

# Estimate and log capture loss.
@load misc/capture-loss

# Enable logging of memory, packet and lag statistics.
@load misc/stats

# Support cases where checksumming is offloaded to the NIC.
redef ignore_checksums = T;

# Needed for orig/resp_ip_bytes values in conn log.
redef use_conn_size_analyzer = T;

# Ensure all generated log files get rotated.
redef Log::default_rotation_interval = 30 min;

# Don't write metadata to log files. This avoids unnecessary logs from
# being sent to the Dark Cubed Cloud Platform.
redef LogAscii::include_meta = F;

event bro_init()
{
  # Disable all but the Conn and DNS streams.
  for (id in Log::active_streams) {
    if (id == Conn::LOG || id == DNS::LOG) next;
    Log::disable_stream(id);
  }

  # Remove the default Conn and DNS log filters.
  Log::remove_default_filter(Conn::LOG);
  Log::remove_default_filter(DNS::LOG);

  # Add Dark Cubed Conn log filter.
  Log::add_filter(Conn::LOG, [
    \$name    = "D3-conn",
    \$path    = "D3_conn",
    \$include = set("ts", "id.orig_h", "id.orig_p", "id.resp_h", "id.resp_p", "proto", "orig_ip_bytes", "resp_ip_bytes")
  ]);

  # Add Dark Cubed DNS log filter.
  Log::add_filter(DNS::LOG, [
    \$name    = "D3-dns",
    \$path    = "D3_dns",
    \$include = set("ts", "id.orig_h", "id.orig_p", "id.resp_h", "id.resp_p", "query", "qtype_name", "answers")
  ]);
}
EOC
)

if ((dryrun == 0)); then
  echo -e "${GREEN}The following Bro site config would be written to /etc/bro/site/local-darkcubed.bro${RESET}\n"
  echo "$BROCONF"
  echo
else
  echo -e "${GREEN}Writing Bro local site config for Dark Cubed to /etc/bro/site/local-darkcubed.bro${RESET}\n"
  echo "$BROCONF" > /etc/bro/site/local-darkcubed.bro
fi

BROARGS="BRO_ARGS=-i $iface local-darkcubed"

if ((dryrun == 0)); then
  echo -e "${GREEN}The following Bro args would be written to /etc/default/bro-darkcubed${RESET}\n"
  echo "$BROARGS"
  echo
else
  echo -e "${GREEN}Writing Bro command line args to /etc/default/bro-darkcubed${RESET}\n"
  echo "$BROARGS" > /etc/default/bro-darkcubed
fi

# Dark Cubed Bro SystemD service unit
BROUNIT=$(cat << EOC
[Unit]
Description=Dark Cubed Bro
After=network.target
[Service]
Type=simple
WorkingDirectory=/var/spool/bro/darkcubed
EnvironmentFile=/etc/default/bro-darkcubed
ExecStart=/usr/bin/bro \$BRO_ARGS
Restart=on-failure
RestartSec=10s
[Install]
WantedBy=multi-user.target
EOC
)

if ((dryrun == 0)); then
  echo -e "${GREEN}The following SystemD service unit would be installed${RESET}\n"
  echo "$BROUNIT"
  echo
else
  mkdir -p /var/spool/bro/darkcubed

  echo -e "${GREEN}Writing Bro SystemD service unit to /etc/systemd/system/darkcubed-bro.service${RESET}\n"
  echo "$BROUNIT" > /etc/systemd/system/darkcubed-bro.service

  echo -e "${GREEN}Loading Dark Cubed Bro service unit into SystemD${RESET}\n"

  if ! systemctl daemon-reload; then
    echo -e "${RED}Error loading Dark Cubed Bro service${RESET}\n"
    exit 1
  fi

  echo -e "${GREEN}Starting Dark Cubed Bro service unit (darkcubed-bro)${RESET}\n"

  if ! systemctl start darkcubed-bro; then
    echo -e "${RED}Error starting Dark Cubed Bro service${RESET}\n"
    exit 1
  fi
fi

# Cron job to clean up old Dark Cubed Bro logs daily
BROCRON=$(cat << EOC
#!/bin/bash
#
# darkcubed-bro-cleanup cron daily
 
# Remove any logs the Dark Cubed Bro instance has rotated. Dark Cubed
# Bro logs are written to the /var/spool/bro/darkcubed directory.
rm -rf /var/spool/bro/darkcubed/*.*.log > /dev/null 2>&1
EOC
)

if ((dryrun == 0)); then
  echo -e "${GREEN}The following cron job would be written to /etc/cron.daily/darkcubed-bro-cleanup${RESET}\n"
  echo "$BROCRON"
  echo
else
  echo -e "${GREEN}Writing cron job for log clean up to /etc/cron.daily/darkcubed-bro-cleanup${RESET}\n"
  echo "$BROCRON" > /etc/cron.daily/darkcubed-bro-cleanup
  chmod +x /etc/cron.daily/darkcubed-bro-cleanup
fi

echo -e "${GREEN}Done configuring Bro${RESET}\n"

# ensure Rsyslog is installed
if ! dpkg -l rsyslog > /dev/null 2>&1; then
  # Rsyslog is part of ubuntu-minimal, so it *should* be installed
  echo -e "Rsyslog is not currently installed -- this is unexpected -- aborting\n"
  exit 1
fi

# template used for Rsyslog config
CONF=$(cat << EOC
template(
  name="DarkCubedBroFormat"
  type="string"
  string="<%pri%>%protocol-version% %timestamp:::date-rfc3339% %HOSTNAME% bro-ids %procid% %msgid% [{{SDID}} type=\"%app-name%\"] %msg%\n"
) 

module(load="imfile" Mode="inotify")

input(type="imfile" File="/var/spool/bro/darkcubed/D3_conn.log" Tag="d3_bro_conn" PersistStateInterval="500")
input(type="imfile" File="/var/spool/bro/darkcubed/D3_dns.log"  Tag="d3_bro_dns"  PersistStateInterval="500")

# Send messages to Dark Cubed over UDP using the template.
if \$syslogtag == "d3_bro_conn" or \$syslogtag == "d3_bro_dns" then {
  action(type="omfwd" protocol="udp" target="{{ADDR}}" port="{{PORT}}" template="DarkCubedBroFormat")
}
EOC
)

if ((dryrun == 0)); then
  echo -e "${GREEN}The following Rsyslog config would be written to /etc/rsyslog.d/25-darkcubed.conf${RESET}\n"
  # run config template through sed to pipulate SD-ID addr and port settings
  echo "$CONF" | sed "s~{{SDID}}~$sensor~; s~{{ADDR}}~$addr~; s~{{PORT}}~$port~"
  echo
else
  echo -e "${GREEN}Writing Dark Cubed Rsyslog config to /etc/rsyslog.d/25-darkcubed.conf${RESET}\n"
  # run config template through sed to pipulate SD-ID addr and port settings
  echo "$CONF" | sed "s~{{SDID}}~$sensor~; s~{{ADDR}}~$addr~; s~{{PORT}}~$port~" > /etc/rsyslog.d/25-darkcubed.conf

  # ensure these exist just in case Bro hasn't written to them yet
  # before Rsyslog restarts
	touch /var/spool/bro/darkcubed/D3_conn.log
	touch /var/spool/bro/darkcubed/D3_dns.log

  echo -e "${GREEN}Restarting Rsyslog to load the Dark Cubed config${RESET}\n"
  systemctl restart rsyslog
fi
