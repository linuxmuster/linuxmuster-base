#!/bin/sh
#
# blocking web access on firewall
#
# thomas@linuxmuster.net
# 21.01.2013
# GPL v3
#

#set -x


# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1


# source helperfunctions
. $HELPERFUNCTIONS || exit 1


# default variables
searchstr="Host with MAC @@mac@@ is blocked"
blockrule="RULE,FORWARD,on,std,defaultSrcNet,Green,off,textSrcAdrmac,@@mac@@,off,-,off,colorDestNet,GREEN_COLOR,off,defaultDstIP,Any,off,-,-,off,log,average,10/minute,off,-,-,reject,off,$searchstr."


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
  exit 1
}


# test parameters
[ "$trigger" != "on" -a "$trigger" != "off" ] && usage
[ -z "$maclist" -a -z "$hostlist" ] && usage


# check if task is locked
checklock || exit 1


# get maclist
get_maclist || cancel "Cannot get maclist!"


# test fwtype
fwtype="$(get_fwtype)"
[ "$fwtype" != "ipfire" -a "$fwtype" != "ipcop" ] && cancel "None or custom firewall!"
[ "$fwtype" != "$fwconfig" ] && cancel "Misconfigured firewall!"


# clean $CACHEDIR
rm -f $CACHEDIR/squid.conf* &> /dev/null
rm -f $CACHEDIR/src_banned_mac.acl* &> /dev/null
rm -f $CACHEDIR/fwrules.config* &> /dev/null


# get src_banned_mac.acl from firewall
get_ipcop /var/$fwtype/proxy/advanced/acls/src_banned_mac.acl $CACHEDIR &> /dev/null || cancel "Download of src_banned_mac.acl failed!"
cp -f $CACHEDIR/src_banned_mac.acl $CACHEDIR/src_banned_mac.acl.new || cancel "Cannot access $CACHEDIR!"


# get squid.conf from firewall
get_ipcop /var/$fwtype/proxy/squid.conf $CACHEDIR &> /dev/null || cancel "Download of squid.conf failed!"


# allow proxy access, remove macs from ban list
proxy_on(){
 # create new ban file
 touch $CACHEDIR/src_banned_mac.acl.new || cancel "Cannot create ban file in $CACHEDIR!"
 n=0
 # iterate over macs
 while [ $n -lt $nr_of_macs ]; do
  # remove mac from list
  sed "/${mac[$n]}/d" -i $CACHEDIR/src_banned_mac.acl.new
  let n+=1
 done
} # proxy_on


# deny proxy access
proxy_off(){
 n=0
 # iterate over macs
 while [ $n -lt $nr_of_macs ]; do
  if ! grep -q ${mac[$n]} $CACHEDIR/src_banned_mac.acl; then
   # write new macs to ban file
   echo ${mac[$n]} >> $CACHEDIR/src_banned_mac.acl.new || cancel "Cannot create ban file in $CACHEDIR!"
  fi
  let n+=1
 done
} # proxy_off


# add block rules to ipcop's bot
bot_ipcop_off(){
 n=0; found=0
 # iterate over rules file
 while read line; do
  # find forward rules
  if [ "${line:0:12}" = "RULE,FORWARD" -a $found -eq 0 ]; then
   found=1
   # iterate over macs
   while [ $n -lt $nr_of_macs ]; do
    tsearchstr=`echo $searchstr | sed -e "s/@@mac@@/${mac[$n]}/"`
    # if no block rule for this mac exists yet create one
    if ! grep -q "$tsearchstr" $CACHEDIR/fwrules.config; then
     tblockrule=`echo $blockrule | sed -e "s/@@mac@@/${mac[$n]}/g"`
     echo $tblockrule >> $CACHEDIR/fwrules.config.new || cancel "Cannot write $CACHEDIR/fwrules.config.new!"
    fi
    let n+=1
   done
  fi
  echo $line >> $CACHEDIR/fwrules.config.new || cancel "Cannot write $CACHEDIR/fwrules.config.new!"
 done <$CACHEDIR/fwrules.config
} # bot_ipcop_off


# remove block rules from ipcop's bot
bot_ipcop_on(){
 cp -f $CACHEDIR/fwrules.config $CACHEDIR/fwrules.config.new || cancel "Cannot write $CACHEDIR/fwrules.config.new!"
 n=0
 while [[ $n -lt $nr_of_macs  ]]; do
  tsearchstr=`echo $searchstr | sed -e "s/@@mac@@/${mac[$n]}/"`
  if grep -q "$tsearchstr" $CACHEDIR/fwrules.config; then
   grep -v "$tsearchstr" $CACHEDIR/fwrules.config > $CACHEDIR/fwrules.config.new
   [ -e "$CACHEDIR/fwrules.config.new" ] || cancel "Cannot write $CACHEDIR/fwrules.config.new!"
   cp -f $CACHEDIR/fwrules.config.new $CACHEDIR/fwrules.config || cancel "Cannot write $CACHEDIR/fwrules.config!"
  fi
  let n+=1
 done
} # bot_ipcop_on

# update allowed list
outgoing_ipfire_update(){
 local bannedmacs="$CACHEDIR/src_banned_mac.acl.new"
 local localfile="$CACHEDIR/allowedmacs"
 local remotefile="/var/$fwtype/outgoing/groups/macgroups/allowedmacs"
 rm -f "$localfile"
 grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F\; '{ print $4 }' | sort -u | tr a-z A-Z > "$localfile"
 # if there are banned macs
 if [ -s "$bannedmacs" ]; then
  for i in $(cat $bannedmacs); do
   # remove them from list of allowed macs
   sed "/$i/d" -i "$localfile"
  done
 fi
 touch "$localfile" || cancel "Cannot write to $localfile!"
 put_ipcop "$localfile" "$remotefile" &> /dev/null || cancel "Upload of $localfile failed!"
 rm -f "$localfile"
}


case $fwtype in

 ipfire)

  fwname="IPFire"
  # update proxy
  proxy_$trigger
  # update outgoing fw
  outgoing_ipfire_update

  ;;
 
 ipcop)

  fwname="IPCop"
  # update proxy
  proxy_$trigger
  # get bot config
  get_ipcop /var/$fwtype/fwrules/config $CACHEDIR/fwrules.config &> /dev/null || cancel "Download of fwrules.config failed!"
  # update bot
  bot_ipcop_$trigger
  # upload new bot rules to ipcop
  put_ipcop $CACHEDIR/fwrules.config.new /var/$fwtype/fwrules/config &> /dev/null || cancel "Upload of fwrules.config failed!"

 ;;
 
 *) ;;
 
esac


# squid.conf update
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
put_ipcop $CACHEDIR/src_banned_mac.acl.new /var/$fwtype/proxy/advanced/acls/src_banned_mac.acl &> /dev/null || cancel "Upload of src_banned_mac.acl failed!"


# reload proxy
exec_ipcop /usr/sbin/squid -k reconfigure &> /dev/null || cancel "Restarting of firewall proxy failed!"


# reload bot/outgoing rules
exec_ipcop /var/linuxmuster/reloadbot.sh || cancel "Reloading BOT/Outgoing rules failed!"


# renew list of internet blocked hosts
cp -f $CACHEDIR/src_banned_mac.acl.new $BLOCKEDHOSTSINTERNET || cancel "Cannot create $BLOCKEDHOSTSINTERNET!"


# end, delete lockfile and cache files
rm -f $CACHEDIR/squid.conf*
rm -f $CACHEDIR/src_banned_mac.acl*
rm -f $CACHEDIR/fwrules.config*
rm -f $lockflag || exit 1

echo "Success!"

exit 0
