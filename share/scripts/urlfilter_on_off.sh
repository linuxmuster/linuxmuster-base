#!/bin/bash
#
# add|remove ips to|from urlfilter
#
# Thomas Schmitt <tschmitt@linuxmuster.de>
# 24.11.2008
#

# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1

# source helperfunctions
. $HELPERFUNCTIONS || exit 1

# parsing parameters
getopt $*

usage() {
  echo
  echo "Usage: urlfilter_on_off.sh --trigger=<on|off>"
  echo "                           --hostlist=<host1,host2,...,hostn>"
  echo
  echo "  trigger:  trigger on or off"
  echo "  hostlist: comma separated list of hostnames"
  echo
  exit 1
}

# test parameters
[[ "$trigger" != "on" && "$trigger" != "off" ]] && usage
[[ -z "$hostlist" ]] && usage

# check if task is locked
checklock || exit 1

# check if urlfilter is active at all
check_urlfilter || cancel "Urlfilter is not active!"

# parse hostlist
n=0
OIFS=$IFS
IFS=","
for i in $hostlist; do
  host[$n]=$i
  let n+=1
done
IFS=$OIFS
nr_of_hosts=$n
[[ $nr_of_hosts -eq 0 ]] && cancel "No hostnames found!"

# get ips
n=0; m=0
while [[ $n -lt $nr_of_hosts ]]; do
  get_ip ${host[$n]} || cancel "Read failure! Cannot determine ip address!"
  if validip $RET; then
    ip[$m]=$RET
    let m+=1
  fi
  let n+=1
done
nr_of_ips=$m
[[ $nr_of_ips -eq 0 ]] && cancel "No ip addresses found!"

# get urlfilter configuration
[ -e "$CACHEDIR/urlfilter.settings" ] && rm -f $CACHEDIR/urlfilter.settings
get_ipcop /var/ipcop/urlfilter/settings $CACHEDIR/urlfilter.settings &> /dev/null || cancel "Download of urlfilter settings failed!"
. $CACHEDIR/urlfilter.settings &> /dev/null || cancel "Cannot read urlfilter settings!"
IPLIST="$UNFILTERED_CLIENTS"

# strip ip from $IPLIST
strip_ip() {

  [ -z "$IPLIST" ] && return 0
  local IPLIST_NEW=""
  local i
  for i in $IPLIST; do
    if [ "$i" != "$1" ]; then
      if [ -z "$IPLIST_NEW" ]; then
        IPLIST_NEW="$i"
      else
        IPLIST_NEW="$IPLIST_NEW $i"
      fi
    fi
  done
  IPLIST="$IPLIST_NEW"

} # strip_ip

# add ips to list
if [ "$trigger" = "off" ]; then

  n=0
  while [[ $n -lt $nr_of_ips ]]; do
    if ! echo "$IPLIST" | grep -wq "${ip[$n]}"; then
      if [ -z "$IPLIST" ]; then
	IPLIST="${ip[$n]}"
      else
	IPLIST="$IPLIST ${ip[$n]}"
      fi
    fi
    let n+=1
  done

else # remove ips from list

  n=0
  while [[ $n -lt $nr_of_ips ]]; do
    echo "$IPLIST" | grep -wq "${ip[$n]}" && strip_ip "${ip[$n]}"
    let n+=1
  done

fi

# remove serverip from ip list
strip_ip "$serverip"

# uploading new iplist and restarting proxy
exec_ipcop /var/linuxmuster/linuxmuster-unfilter.pl "$serverip $IPLIST" || cancel "IP upload to IPCop failed!"

# renew list of unfiltered hosts
# delete old list
if [ -e "$UNFILTEREDHOSTS" ]; then
  rm -f $UNFILTEREDHOSTS || cancel "Cannot delete $UNFILTEREDHOSTS!"
fi
touch $UNFILTEREDHOSTS || cancel "Cannot create $UNFILTEREDHOSTS!"

# create new list
if [ -n "$IPLIST" ]; then
  for i in $IPLIST; do
    get_mac $i || cancel "Read failure! Cannot determine mac address!"
    if [ -n "$RET" ]; then
      echo $RET >> $UNFILTEREDHOSTS || cancel "Cannot write $UNFILTEREDHOSTS!"
    fi
  done
fi

# end, delete lockfile and cache files
rm -f $CACHEDIR/urlfilter.settings
rm -f $lockflag || exit 1

echo "Success!"

