#!/bin/bash
#
# blocking intranet access
#
# thomas@linuxmuster.net
# 23.01.2013
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
  echo
  echo "  trigger:  trigger on or off"
  echo "  maclist:  comma separated list of mac addresses"
  echo "  hostlist: comma separated list of hostnames"
  echo
  exit 1
}

# test parameters
[ "$trigger" != "on" -a "$trigger" != "off" ] && usage
[ -z "$maclist" -a -z "$hostlist" ] && usage

# check if task is locked
checklock || exit 1

# test valid macaddresses, change hosts to macs
[ -z "$maclist" ] && maclist="$hostlist"
MACS_TO_PROCESS="$(test_maclist "$maclist")"
[ -n "$MACS_TO_PROCESS" ] || cancel "Maclist contains no valid macaddresses!"

# create a blocked hosts file
if [ ! -e "$BLOCKEDHOSTSINTRANET" ]; then
 touch $BLOCKEDHOSTSINTRANET || cancel "Cannot create $BLOCKEDHOSTSINTRANET!"
fi

# get blocked macs
BLOCKED_MACS="$(cat $BLOCKEDHOSTSINTRANET)"

# save blocked hosts file
cp $BLOCKEDHOSTSINTRANET $BLOCKEDHOSTSINTRANET.new || cancel "Cannot create $BLOCKEDHOSTSINTRANET.new!"

# add macs to blocked hosts file
if [ "$trigger" = "off" ]; then

 # iterate over commandline given macs and write macs not already in blocked hosts file
 for m in $MACS_TO_PROCESS; do
  stringinstring "$m" "$BLOCKED_MACS" && continue
  echo "$m" >> $BLOCKEDHOSTSINTRANET.new
 done

else # remove macs from blocked hosts file

 # iterate over macs given on commandline
 for m in $MACS_TO_PROCESS; do
  # remove mac from file
  sed "/$m/d" -i $BLOCKEDHOSTSINTRANET.new
 done

fi

# move new file in place
mv $BLOCKEDHOSTSINTRANET.new $BLOCKEDHOSTSINTRANET || cancel "Cannot write $BLOCKEDHOSTSINTRANET!"

# restart interal firewall
/etc/init.d/linuxmuster-base restart ; RC="$?"

# delete lock
rm -f $lockflag || RC=1

[ "$RC" = "0" ] && echo "Success!"

exit "$RC"
