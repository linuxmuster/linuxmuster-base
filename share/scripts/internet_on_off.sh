#!/bin/sh
#
# blocking web access on firewall
#
# thomas@linuxmuster.net
# 25.05.2013
# GPL v3
#

#set -x


# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1


# source helperfunctions
. $HELPERFUNCTIONS || exit 1


# parsing parameters
getopt $*


usage() {
  echo
  echo "Usage: internet_on_off.sh --trigger=<on|off>"
  echo "                          --maclist=<mac1,mac2,...,macn>"
  echo "                          --hostlist=<host1,host2,...,hostn>"
  echo "                          --help"
  echo
  echo "  trigger:  trigger on or off"
  echo "  maclist:  comma separated list of mac addresses"
  echo "  hostlist: comma separated list of hostnames or ip adresses"
  echo "  help:     shows this help"
  echo
  echo "  Invokation without parameters just updates and reloads the external firewall."
  exit 1
}

# test parameters
[ -n "$help" ] && usage
[ -z "$maclist" ] && maclist="$hostlist"
[ -n "$trigger" -a -z "$maclist" ] && usage
[ -z "$trigger" -a -n "$maclist" ] && usage

# check if task is locked
checklock || exit 1

# test fwtype
fwtype="$(get_fwtype)"
[ "$fwtype" = "ipfire" ] || cancel "Only ipfire is supported by this script!"
[ "$fwtype" != "$fwconfig" ] && cancel "Misconfigured firewall! Check your setup!"

# create a list of ip addresses
if [ -n "$maclist" ]; then
 for i in ${maclist//,/ }; do
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
fi


##########################
### common stuff begin ###
##########################

# get imported client ip addresses from system and write them to file
ALLOWEDIPS="$CACHEDIR/allowedips"
grep -v ^# $WIMPORTDATA | awk -F\; '{ print $5 }' > "$ALLOWEDIPS" || cancel "Cannot write to $ALLOWEDIPS!"

# add guest ips if internet access is allowed
if grep -q "### GUEST EXTERNAL ON" /etc/dhcp/dhcpd.conf; then
 update_guestiplist ; RC="$?"
 cat "$GUESTIPLIST" >> "$ALLOWEDIPS"
fi

# remove empty lines
sed '/^$/d' -i "$ALLOWEDIPS"


# remove orphaned ips from blocked hosts internet list
touch "$BLOCKEDHOSTSINTERNET"
if [ -s "$BLOCKEDHOSTSINTERNET" ]; then
 for i in $(cat $BLOCKEDHOSTSINTERNET); do
  grep -qw "$i" "$ALLOWEDIPS" || sed "/^\($i\)$/d" -i "$BLOCKEDHOSTSINTERNET"
 done
fi


# update blocked ips list
case "$trigger" in
 
 on) # remove ips
  for i in $IPS_TO_PROCESS; do
   sed "/^\($i\)$/d" -i "$BLOCKEDHOSTSINTERNET" || cancel "Cannot write to $BLOCKEDHOSTSINTERNET!"
  done
  ;;
  
 off) # add ips
  for i in $IPS_TO_PROCESS; do
   if ! grep -qw "$i" "$BLOCKEDHOSTSINTERNET"; then
    # write new ips to ban file
     echo "$i" >> "$BLOCKEDHOSTSINTERNET" || cancel "Cannot write to $BLOCKEDHOSTSINTERNET!"
   fi
  done
  ;;

 *) ;;

esac

# remove empty lines
sed '/^$/d' -i "$BLOCKEDHOSTSINTERNET"

########################
### common stuff end ###
########################


##########################
### IPFire stuff begin ###
##########################

# fw update for ipfire
ipfire_update(){
 # update allowed list
 local remotefile="/var/$fwtype/outgoing/groups/ipgroups/allowedips"
 # if there are banned ips
 if [ -s "$BLOCKEDHOSTSINTERNET" ]; then
  for i in $(cat $BLOCKEDHOSTSINTERNET); do
   # remove them from list of allowed ips
   sed "/^\($i\)$/d" -i "$ALLOWEDIPS"
  done
 fi

 # upload allowd mac list for outgoing fw
 put_ipcop "$ALLOWEDIPS" "$remotefile" &> /dev/null || cancel "Upload of $ALLOWEDIPS failed!"

 # reload proxy, doing the squid.conf stuff on ipfire
 exec_ipcop /var/linuxmuster/reload_proxy.sh || cancel "Reloading of firewall proxy failed!"

 # reload bot/outgoing rules
 exec_ipcop /var/linuxmuster/reload_outgoing.sh || cancel "Reloading of outgoing fw failed!"
}

########################
### IPFire stuff end ###
########################


# invoke fw specific part
${fwconfig}_update


# end, delete lockfile and cache files
rm -f $lockflag || exit 1

echo "Success!"

exit 0
