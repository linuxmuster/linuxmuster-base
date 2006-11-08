#!/bin/sh
# add|remove ips to|from urlfilter

#set -x

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

# add ips to unfiltered clients
if [ "$trigger" = "off" ]; then

  n=0
  while [[ $n -lt $nr_of_ips ]]; do
    stringinstring "${ip[$n]}" "$UNFILTERED_CLIENTS" || UNFILTERED_CLIENTS="$UNFILTERED_CLIENTS ${ip[$n]}"
    let n+=1
  done

else # remove ip from list

  n=0
  while [[ $n -lt $nr_of_ips ]]; do
    UNFILTERED_CLIENTS="${UNFILTERED_CLIENTS/${ip[$n]}/}"
    let n+=1
  done

fi

# remove serverip from ip list
UNFILTERED_CLIENTS="${UNFILTERED_CLIENTS/$serverip/}"

# stripping spaces
UNFILTERED_CLIENTS="${UNFILTERED_CLIENTS//  / }"
strip_spaces "$UNFILTERED_CLIENTS"
UNFILTERED_CLIENTS="$RET"

# uploading new iplist and restarting proxy
exec_ipcop /var/linuxmuster/linuxmuster-unfilter.pl "$serverip $UNFILTERED_CLIENTS" || cancel "IP upload to IPCop failed!"

# renew list of unfiltered hosts
# delete old list
if [ -e "$UNFILTEREDHOSTS" ]; then
  rm -f $UNFILTEREDHOSTS || cancel "Cannot delete $UNFILTEREDHOSTS!"
fi
touch $UNFILTEREDHOSTS || cancel "Cannot create $UNFILTEREDHOSTS!"

# create new list
if [ -n "$UNFILTERED_CLIENTS" ]; then
  for i in $UNFILTERED_CLIENTS; do
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

exit 0
