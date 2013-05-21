#!/bin/bash
#
# blocking intranet access
#
# thomas@linuxmuster.net
# 21.05.2013
# GPL v3
#

#set -x

# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1

# source helperfunctions
. $HELPERFUNCTIONS || exit 1

# source internal interface
. /etc/default/linuxmuster-base || exit 1

# exit if internal firewall is not active
if [ "$START_LINUXMUSTER" != "yes" ]; then
 echo "Internal Firewall is deactivated! Aborting!"
 exit 1
fi

# parsing parameters
getopt $*

usage() {
  echo
  echo "Usage: intranet_on_off.sh --trigger=<on|off>"
  echo "                          --hostlist=<host1,host2,...,hostn>"
  echo "                          --maclist=<mac1,mac2,...,macn>"
  echo "                          --help"
  echo
  echo "  trigger:  trigger on or off"
  echo "  maclist:  comma separated list of mac addresses"
  echo "  hostlist: comma separated list of hostnames or ip adresses"
  echo "  help:     shows this help"
  echo
  exit 1
}

# test parameters
[ -n "$help" ] && usage
[ "$trigger" != "on" -a "$trigger" != "off" ] && usage
[ -z "$maclist" -a -z "$hostlist" ] && usage
[ -n "$maclist" -a -n "$hostlist" ] && usage

# check if task is locked
checklock || exit 1

# create a list of ip addresses
for i in ${maclist//,/ } ${hostlist//,/ }; do
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

# create a blocked hosts file if not there
if [ ! -e "$BLOCKEDHOSTSINTRANET" ]; then
 touch $BLOCKEDHOSTSINTRANET || cancel "Cannot create $BLOCKEDHOSTSINTRANET!"
fi

# test for writability
[ -w "$BLOCKEDHOSTSINTRANET" ] || cancel "Cannot write to $BLOCKEDHOSTSINTRANET!"

# iterate over commandline given ips and write ips not already in blocked hosts file
for i in $IPS_TO_PROCESS; do

 # add ips to blocked hosts file
 if [ "$trigger" = "off" ]; then

  grep -qw "$i" $BLOCKEDHOSTSINTRANET && continue
  echo "$i" >> $BLOCKEDHOSTSINTRANET

 else # remove ips from blocked hosts file

  sed "/^\($i\)$/d" -i $BLOCKEDHOSTSINTRANET

 fi

done

# restart interal firewall
/etc/init.d/linuxmuster-base restart ; RC="$?"

# delete lock
rm -f $lockflag || RC=1

[ "$RC" = "0" ] && echo "Success!"

exit "$RC"
