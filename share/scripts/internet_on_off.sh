#!/bin/sh
#
# blocking web access on firewall
#
# thomas@linuxmuster.net
# 25.01.2013
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
  echo
  echo "  trigger:  trigger on or off"
  echo "  maclist:  comma separated list of mac addresses"
  echo "  hostlist: comma separated list of hostnames"
  echo
  echo "  Invokation without parameters just updates and reloads the external firewall."
  exit 1
}


# test parameters
[ -z "$maclist" ] && maclist="$hostlist"
[ -n "$trigger" -a -z "$maclist" ] && usage
[ -z "$trigger" -a -n "$maclist" ] && usage


# test fwtype
fwtype="$(get_fwtype)"
[ "$fwtype" != "ipfire" -a "$fwtype" != "ipcop" ] && cancel "None or custom firewall!"
[ "$fwtype" != "$fwconfig" ] && cancel "Misconfigured firewall!"


# test valid macaddresses, change hosts to macs
if [ -n "$maclist" ]; then
 MACS_TO_PROCESS="$(test_maclist "$maclist")"
 [ -n "$MACS_TO_PROCESS" ] || cancel "Maclist contains no valid macaddresses!"
fi


# check if task is locked
checklock || exit 1


##########################
### common stuff begin ###
##########################

# get all client mac addresses from system and write them to file
ALLOWEDMACS="$CACHEDIR/allowedmacs"
grep -v ^# $WIMPORTDATA | awk -F\; '{ print $4 }' | tr a-z A-Z > "$ALLOWEDMACS" || cancel "Cannot write to $ALLOWEDMACS!"
 
# remove orphaned macs from blocked hosts internet list
touch "$BLOCKEDHOSTSINTERNET"
if [ -s "$BLOCKEDHOSTSINTERNET" ]; then
 for m in $(cat $BLOCKEDHOSTSINTERNET); do
  grep -q "$m" "$ALLOWEDMACS" || sed "/$m/d" -i "$BLOCKEDHOSTSINTERNET"
 done
fi


# update blocked macs list
case "$trigger" in
 
 on) # remove macs
  for m in "$MACS_TO_PROCESS"; do
   sed "/$m/d" -i "$BLOCKEDHOSTSINTERNET" || cancel "Cannot write to $BLOCKEDHOSTSINTERNET!"
  done
  ;;
  
 off) # add macs
  for m in "$MACS_TO_PROCESS"; do
   if ! grep -q "$m" "$BLOCKEDHOSTSINTERNET"; then
    # write new macs to ban file
    echo "$m" >> "$BLOCKEDHOSTSINTERNET" || cancel "Cannot write to $BLOCKEDHOSTSINTERNET!"
   fi
  done
  ;;
  
 *) ;;
 
esac
  
# upload updated blocked mac list
put_ipcop "$BLOCKEDHOSTSINTERNET" /var/$fwtype/proxy/advanced/acls/src_banned_mac.acl &> /dev/null || cancel "Upload of src_banned_mac.acl failed!"

########################
### common stuff end ###
########################


#########################
### IPCop stuff begin ###
#########################

# default variables used for IPCop
searchstr="Host with MAC @@mac@@ is blocked"
blockrule="RULE,FORWARD,on,std,defaultSrcNet,Green,off,textSrcAdrmac,@@mac@@,off,-,off,colorDestNet,GREEN_COLOR,off,defaultDstIP,Any,off,-,-,off,log,average,10/minute,off,-,-,reject,off,$searchstr."

# add block rules to ipcop's bot
bot_ipcop_off(){
 found=0
 # iterate over rules file
 while read line; do
  # find forward rules
  if [ "${line:0:12}" = "RULE,FORWARD" -a $found -eq 0 ]; then
   found=1
   # iterate over macs
   for m in "$MACS_TO_PROCESS"; do
    tsearchstr=`echo $searchstr | sed -e "s/@@mac@@/$m/"`
    # if no block rule for this mac exists yet create one
    if ! grep -q "$tsearchstr" $CACHEDIR/fwrules.config; then
     tblockrule=`echo $blockrule | sed -e "s/@@mac@@/$m/g"`
     echo $tblockrule >> $CACHEDIR/fwrules.config.new || cancel "Cannot write $CACHEDIR/fwrules.config.new!"
    fi
   done
  fi
  echo $line >> $CACHEDIR/fwrules.config.new || cancel "Cannot write $CACHEDIR/fwrules.config.new!"
 done <$CACHEDIR/fwrules.config
} # bot_ipcop_off


# remove block rules from ipcop's bot
bot_ipcop_on(){
 cp -f $CACHEDIR/fwrules.config $CACHEDIR/fwrules.config.new || cancel "Cannot write $CACHEDIR/fwrules.config.new!"
 for m in "$MACS_TO_PROCESS"; do
  tsearchstr=`echo $searchstr | sed -e "s/@@mac@@/$m/"`
  if grep -q "$tsearchstr" $CACHEDIR/fwrules.config; then
   grep -v "$tsearchstr" $CACHEDIR/fwrules.config > $CACHEDIR/fwrules.config.new
   [ -e "$CACHEDIR/fwrules.config.new" ] || cancel "Cannot write $CACHEDIR/fwrules.config.new!"
   cp -f $CACHEDIR/fwrules.config.new $CACHEDIR/fwrules.config || cancel "Cannot write $CACHEDIR/fwrules.config!"
  fi
 done
} # bot_ipcop_on


# fw update for ipcop
ipcop_update(){
 fwname="IPCop"

 # clean up
 rm -f $CACHEDIR/squid.conf*
 rm -f $CACHEDIR/fwrules.config*

 # squid.conf update
 # get squid.conf from firewall
 get_ipcop /var/$fwconfig/proxy/squid.conf $CACHEDIR &> /dev/null || cancel "Download of squid.conf failed!"
 # test if banned_mac statement is already there
 grep -q ${fwname}_banned_mac $CACHEDIR/squid.conf && squid_off=yes

 # add acls to squid.conf
 if [ -s "$CACHEDIR/src_banned_mac.acl.new" -a -z "$squid_off" ]; then
  while read line; do
   if [ "$line" = "acl CONNECT method CONNECT" ]; then
    echo "acl ${fwname}_banned_mac       arp \"/var/$fwtype/proxy/advanced/acls/src_banned_mac.acl\"" >> $CACHEDIR/squid.conf.new || cancel "Cannot write to $CACHEDIR/squid.conf.new!"
   fi
   echo $line >> $CACHEDIR/squid.conf.new || cancel "Cannot access $CACHEDIR!"
   if [ "$line" = "#Set custom configured ACLs" ]; then
    echo "http_access deny  ${fwname}_banned_mac" >> $CACHEDIR/squid.conf.new || cancel "Cannot write to $CACHEDIR/squid.conf.new!!"
   fi
  done <$CACHEDIR/squid.conf
 fi

 # remove acls from squid.conf
 if [ ! -s "$CACHEDIR/src_banned_mac.acl.new" -a -n "$squid_off" ]; then
  grep -v ${fwname}_banned_mac $CACHEDIR/squid.conf > $CACHEDIR/squid.conf.new || cancel "Cannot write to $CACHEDIR/squid.conf.new!"
 fi

 # upload files to firewall
 if [ -s "$CACHEDIR/squid.conf.new" ]; then
  put_ipcop $CACHEDIR/squid.conf.new /var/$fwtype/proxy/squid.conf &> /dev/null || cancel "Upload of squid.conf failed!"
 fi

 # reload proxy
 exec_ipcop /usr/sbin/squid -k reconfigure &> /dev/null || cancel "Restarting of firewall proxy failed!"

 # bot stuff only if maclist is given on commandline
 if [ -n "$maclist" ]; then
  # get bot config
  get_ipcop /var/$fwtype/fwrules/config $CACHEDIR/fwrules.config &> /dev/null || cancel "Download of fwrules.config failed!"
  # update bot
  bot_ipcop_$trigger
  # upload new bot rules to ipcop
  put_ipcop $CACHEDIR/fwrules.config.new /var/$fwtype/fwrules/config &> /dev/null || cancel "Upload of fwrules.config failed!"
   
  # reload bot/outgoing rules
  exec_ipcop /var/linuxmuster/reloadbot.sh || cancel "Reloading BOT/Outgoing rules failed!"
 fi

 # clean up
 rm -f $CACHEDIR/squid.conf*
 rm -f $CACHEDIR/fwrules.config*
}

#######################
### IPCop stuff end ###
#######################


##########################
### IPFire stuff begin ###
##########################

# fw update for ipfire
ipfire_update(){
 # update allowed list
 local remotefile="/var/$fwtype/outgoing/groups/macgroups/allowedmacs"
 # if there are banned macs
 if [ -s "$BLOCKEDHOSTSINTERNET" ]; then
  for m in $(cat $BLOCKEDHOSTSINTERNET); do
   # remove them from list of allowed macs
   sed "/$m/d" -i "$ALLOWEDMACS"
  done
 fi
 
 # upload allowd mac list for outgoing fw
 put_ipcop "$ALLOWEDMACS" "$remotefile" &> /dev/null || cancel "Upload of $localfile failed!"

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
