#!/bin/sh
#
# blocking web access on firewall
#
# thomas@linuxmuster.net
# 28.05.2013
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

# create an ipfire compatible customgroups file
grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F \; '{ print "@,allowedhosts,,host " $5 ",Custom Host" }' | awk 'sub(/@/,++c)' > "$ALLOWEDHOSTS" || cancel "Cannot write to $ALLOWEDHOSTS!"

# remove orphaned ips from blocked hosts internet list
touch "$BLOCKEDHOSTSINTERNET"
if [ -s "$BLOCKEDHOSTSINTERNET" ]; then
 for i in $(cat $BLOCKEDHOSTSINTERNET); do
  grep -qw "$i" "$ALLOWEDHOSTS" || sed "/^\($i\)$/d" -i "$BLOCKEDHOSTSINTERNET"
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


# create and upload custom firewall stuff if not there
if [ ! -e "$FWCUSTOMHOSTS" ]; then
 fw_do_custom || cancel "Upload of custom stuff to firewall failed!"
fi


# update allowed list

# handle allowed subnets
if [ "$subnetting" = "true" ]; then

 # create and upload custom firewall stuff if not there
 if [ ! -e "$FWCUSTOMNETWORKS" ]; then
  fw_do_custom omit_hosts || cancel "Upload of custom networks to firewall failed!"
 fi

 # get all subnets with allowed internet access
 networks="$(get_allowed_subnets extern)"

 # are there any subnets?
 if [ -n "$networks" ]; then

  # remove ips which match allowed subnets from allowed hosts
  for i in $(awk -F\, '{ print $4}' $ALLOWEDHOSTS | sed -e 's|host ||g'); do
   if ipsubmatch "$i" "$networks"; then
    sed "/,host $i,/d" -i "$ALLOWEDHOSTS" || cancel "Cannot write to $ALLOWEDHOSTS 3!"
   fi
  done

  # add allowed subnets to allowed networks list
  c=1
  rm -f "$ALLOWEDNETWORKS"
  for i in $networks; do
   netname="$(echo $i | awk -F\/ '{ print $1 }')"
   echo "$c,allowednetworks,,net $netname,Custom Network" >> "$ALLOWEDNETWORKS" || cancel "Cannot write to $ALLOWEDNETWORKS!"
   c="$(( $c + 1 ))"
  done
  touch "$ALLOWEDNETWORKS"

 fi # networks

fi # subnetting

# remove empty lines
sed '/^$/d' -i "$ALLOWEDHOSTS" || cancel "Cannot write to $ALLOWEDHOSTS 4!"

# remove blocked ips
for i in $(cat $BLOCKEDHOSTSINTERNET); do
 sed "/,host $i,/d" -i "$ALLOWEDHOSTS" || cancel "Cannot write to $ALLOWEDHOSTS 5!"
done

# create allowed ips file for proxy
ALLOWEDIPS="$CACHEDIR/allowedips"
awk -F\, '{ print $4 }' "$ALLOWEDHOSTS" | sed -e 's|host ||g' > "$ALLOWEDIPS"
[ -n "$networks" ] && echo $networks | sed -e 's| |\n|g' >> "$ALLOWEDIPS"

# omit firewall update if set
if [ -z "$nofirewall" ]; then

 # upload allowed lists to ipfire
 ULPATH="/var/$fwtype"
 ALLOWEDHOSTS_FW="$ULPATH/fwhosts/allowedhosts"
 put_ipcop "$ALLOWEDHOSTS" "$ALLOWEDHOSTS_FW" &> /dev/null || cancel "Upload of $ALLOWEDHOSTS failed!"
 if [ "$subnetting" = "true" ]; then
  ALLOWEDNETWORKS_FW="$ULPATH/fwhosts/allowednetworks"
  put_ipcop "$ALLOWEDNETWORKS" "$ALLOWEDNETWORKS_FW" &> /dev/null || cancel "Upload of $ALLOWEDNETWORKS failed!"
 fi
 ALLOWEDIPS_FW="$ULPATH/proxy/advanced/acls/src_allowed_ip.acl"
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
