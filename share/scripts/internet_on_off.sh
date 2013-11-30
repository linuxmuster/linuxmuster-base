#!/bin/sh
#
# blocking web access on firewall
#
# thomas@linuxmuster.net
# 30.11.2013
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
  echo "Usage: internet_on_off.sh --trigger=<on|off>"
  echo "                          --maclist=<mac1,mac2,...,macn>"
  echo "                          --hostlist=<host1,host2,...,hostn>"
  echo "                          --nofirewall"
  echo "                          --help"
  echo
  echo "  trigger:    trigger on or off"
  echo "  maclist:    comma separated list of mac addresses"
  echo "  hostlist:   comma separated list of hostnames or ip adresses"
  echo "  nofirewall: omit firewall update, create only allowed ips file"
  echo "  help:       shows this help"
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

# create a list of ip addresses from commandline
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

# file definitions
ALLOWEDIPS_FW="/var/$fwtype/outgoing/groups/ipgroups/allowedips"

# get imported client ip addresses from system and write them to file
grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F\; '{ print $5 }' > "$ALLOWEDIPS" || cancel "Cannot write to $ALLOWEDIPS 1!"

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
sed '/^$/d' -i "$BLOCKEDHOSTSINTERNET" || cancel "Cannot write to $BLOCKEDHOSTSINTERNET!"


# update allowed list

# handle allowed subnets
if [ "$subnetting" = "true" ]; then
 ALLOWEDNETS="$(get_allowed_subnets extern)"
 if [ -n "$ALLOWEDNETS" ]; then
  # remove ips which match allowed subnets from allowed ips
  for i in $(cat $ALLOWEDIPS); do
   if ipsubmatch "$i" "$ALLOWEDNETS"; then
    sed "/^\($i\)$/d" -i "$ALLOWEDIPS" || cancel "Cannot write to $ALLOWEDIPS 3!"
   fi
  done
  # add allowed subnets to allowed ip list
  for i in $ALLOWEDNETS; do
   echo "$i" >> "$ALLOWEDIPS" || cancel "Cannot write to $ALLOWEDIPS 4!"
  done
 fi # ALLOWEDNETS
fi # subnetting

# remove empty lines
sed '/^$/d' -i "$ALLOWEDIPS" || cancel "Cannot write to $ALLOWEDIPS 5!"

# remove blocked ips
for i in $(cat $BLOCKEDHOSTSINTERNET); do
 sed "/^\($i\)$/d" -i "$ALLOWEDIPS" || cancel "Cannot write to $ALLOWEDIPS 6!"
done

# omit firewall update if set
if [ -z "$nofirewall" ]; then

 # upload ip lists to ipfire
 put_ipcop "$ALLOWEDIPS" "$ALLOWEDIPS_FW" &> /dev/null || cancel "Upload of $ALLOWEDIPS failed!"

 # reload proxy, doing the squid.conf stuff on ipfire
 exec_ipcop /var/linuxmuster/reload_proxy.sh || cancel "Reloading of firewall proxy failed!"

 # reload outgoing rules
 exec_ipcop /var/linuxmuster/reload_outgoing.sh || cancel "Reloading of outgoing fw failed!"

fi # noreload

# end, delete lockfile and cache files
rm -f $lockflag || exit 1

echo "Success!"

exit 0
