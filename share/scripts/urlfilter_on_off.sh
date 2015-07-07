#!/bin/bash
#
# add|remove ips to|from urlfilter
#
# thomas@linuxmuster.net
# 09.11.2013
# GPL v3
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
  echo "  hostlist: comma separated list of hostnames or ip adresses"
  echo
  exit 1
}

# test parameters
[ "$trigger" != "on" -a "$trigger" != "off" ] && usage
[ -z "$hostlist" ] && usage

# check if task is locked
checklock || exit 1

# test passwordless ssh connection
test_pwless_fw || exit 1
 
# check if urlfilter is active at all
check_urlfilter || cancel "Urlfilter is not active!"

# test fwtype
fwtype="$(get_fwtype)"
[ "$fwtype" = "ipfire" ] || cancel "Only ipfire is supported by this script!"
[ "$fwtype" != "$fwconfig" ] && cancel "Misconfigured firewall! Check your setup!"

# create a list of ip addresses
for i in ${hostlist//,/ }; do
 if validip $i; then
  IPS_TO_PROCESS="$IPS_TO_PROCESS $i"
 else
  get_ip $i
  validip $RET && IPS_TO_PROCESS="$IPS_TO_PROCESS $RET"
 fi
done
strip_spaces "$IPS_TO_PROCESS"
if [ -n "$RET" ]; then
 IPS_TO_PROCESS="$RET"
else
 cancel "No valid ip addresses!"
fi

# get urlfilter configuration
[ -e "$CACHEDIR/urlfilter.settings" ] && rm -f $CACHEDIR/urlfilter.settings
get_ipcop /var/$fwtype/urlfilter/settings $CACHEDIR/urlfilter.settings &> /dev/null || cancel "Download of urlfilter settings failed!"
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

 for i in $IPS_TO_PROCESS; do
  if ! echo "$IPLIST" | grep -wq "$i"; then
   if [ -z "$IPLIST" ]; then
    IPLIST="$i"
   else
    IPLIST="$IPLIST $i"
   fi
  fi
 done

else # remove ips from list

 for i in $IPS_TO_PROCESS; do
  echo "$IPLIST" | grep -wq "$i" && strip_ip "$i"
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
  echo $i >> $UNFILTEREDHOSTS || cancel "Cannot write $UNFILTEREDHOSTS!"
 done
fi

# end, delete lockfile and cache files
rm -f $CACHEDIR/urlfilter.settings
rm -f $lockflag || exit 1

echo "Success!"

