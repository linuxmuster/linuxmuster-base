#!/bin/sh
#
# blocking web access on ipcop
#
# Thomas Schmitt <schmitt@lmz-bw.de>
# $Id$
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
[[ "$trigger" != "on" && "$trigger" != "off" ]] && usage
[[ -z "$maclist" && -z "$hostlist" ]] && usage


# check if task is locked
checklock || exit 1


# get maclist
get_maclist || cancel "Cannot get maclist!"


# clean $CACHEDIR
rm -f $CACHEDIR/squid.conf* &> /dev/null
rm -f $CACHEDIR/src_banned_mac.acl* &> /dev/null
rm -f $CACHEDIR/fwrules.config* &> /dev/null


# get src_banned_mac.acl from ipcop
get_ipcop /var/ipcop/proxy/advanced/acls/src_banned_mac.acl $CACHEDIR &> /dev/null || cancel "Download of src_banned_mac.acl failed!"
cp -f $CACHEDIR/src_banned_mac.acl $CACHEDIR/src_banned_mac.acl.new || cancel "Cannot access $CACHEDIR!"


# get squid.conf from ipcop
get_ipcop /var/ipcop/proxy/squid.conf $CACHEDIR &> /dev/null || cancel "Download of squid.conf failed!"


# get bot config from ipcop
get_ipcop /var/ipcop/fwrules/config $CACHEDIR/fwrules.config &> /dev/null || cancel "Download of fwrules.config failed!"
if [ -e "$CACHEDIR/fwrules.config.new" ]; then

  rm -f $CACHEDIR/fwrules.config.new || cancel "Cannot remove $CACHEDIR/fwrules.config.new!"

fi


# blocking internet access
if [ "$trigger" = "off" ]; then

  # web proxy
  n=0
  while [[ $n -lt $nr_of_macs  ]]; do

    if ! grep -q ${mac[$n]} $CACHEDIR/src_banned_mac.acl; then

      echo ${mac[$n]} >> $CACHEDIR/src_banned_mac.acl.new || cancel "Cannot access $CACHEDIR!"

    fi

    let n+=1
  done

  # bot config
  n=0; found=0
  while read line; do

    if [[ "${line:0:12}" = "RULE,FORWARD" && $found -eq 0 ]]; then

      found=1

      while [[ $n -lt $nr_of_macs ]]; do

        tsearchstr=`echo $searchstr | sed -e "s/@@mac@@/${mac[$n]}/"`

        if ! grep -q "$tsearchstr" $CACHEDIR/fwrules.config; then

          tblockrule=`echo $blockrule | sed -e "s/@@mac@@/${mac[$n]}/g"`
          echo $tblockrule >> $CACHEDIR/fwrules.config.new || cancel "Cannot write $CACHEDIR/fwrules.config.new!"

        fi

        let n+=1
      done

    fi

    echo $line >> $CACHEDIR/fwrules.config.new || cancel "Cannot write $CACHEDIR/fwrules.config.new!"

  done <$CACHEDIR/fwrules.config

else # allowing internet access

  # web proxy
  if [ -e "$CACHEDIR/src_banned_mac.acl.new" ]; then

    rm -f $CACHEDIR/src_banned_mac.acl.new || cancel "Cannot access $CACHEDIR!"

  fi

  touch $CACHEDIR/src_banned_mac.acl.new || cancel "Cannot access $CACHEDIR!"

  while read line; do

    found=0; n=0

    while [[ $n -lt $nr_of_macs  ]]; do

      [ "$line" = "${mac[$n]}" ] && found=1
      let n+=1

    done

    if [[ $found -eq 0 ]]; then

      echo $line >> $CACHEDIR/src_banned_mac.acl.new || cancel "Cannot access $CACHEDIR!"

    fi

  done <$CACHEDIR/src_banned_mac.acl

  # bot config
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

fi


# modify squid.conf
grep -q IPCop_banned_mac $CACHEDIR/squid.conf && squid_off=yes

if [[ -s "$CACHEDIR/src_banned_mac.acl.new" && -z "$squid_off" ]]; then
  # add acls to squid.conf

  while read line; do

    if [ "$line" = "acl CONNECT method CONNECT" ]; then

      echo 'acl IPCop_banned_mac       arp "/var/ipcop/proxy/advanced/acls/src_banned_mac.acl"' >> $CACHEDIR/squid.conf.new || cancel "Cannot write to $CACHEDIR/squid.conf.new!"

    fi

    echo $line >> $CACHEDIR/squid.conf.new || cancel "Cannot access $CACHEDIR!"

    if [ "$line" = "#Set custom configured ACLs" ]; then

      echo 'http_access deny  IPCop_banned_mac' >> $CACHEDIR/squid.conf.new || cancel "Cannot write to $CACHEDIR/squid.conf.new!!"

    fi

  done <$CACHEDIR/squid.conf

fi

if [[ ! -s "$CACHEDIR/src_banned_mac.acl.new" && -n "$squid_off" ]]; then
  # remove acls from squid.conf

  grep -v IPCop_banned_mac $CACHEDIR/squid.conf > $CACHEDIR/squid.conf.new || cancel "Cannot write to $CACHEDIR/squid.conf.new!"

fi


# uploading files to ipcop
if [ -s "$CACHEDIR/squid.conf.new" ]; then

  put_ipcop $CACHEDIR/squid.conf.new /var/ipcop/proxy/squid.conf &> /dev/null || cancel "Upload of squid.conf failed!"

fi

put_ipcop $CACHEDIR/src_banned_mac.acl.new /var/ipcop/proxy/advanced/acls/src_banned_mac.acl &> /dev/null || cancel "Upload of src_banned_mac.acl failed!"

put_ipcop $CACHEDIR/fwrules.config.new /var/ipcop/fwrules/config &> /dev/null || cancel "Upload of fwrules.config failed!"


# restarting proxy
exec_ipcop /usr/sbin/squid -k reconfigure &> /dev/null || cancel "Restarting of ipcop proxy failed!"


# reload bot rules
exec_ipcop /var/linuxmuster/reloadbot.sh || cancel "Reloading BOT rules failed!"


# renew list of internet blocked hosts
cp -f $CACHEDIR/src_banned_mac.acl.new $BLOCKEDHOSTSINTERNET || cancel "Cannot create $BLOCKEDHOSTSINTERNET!"


# end, delete lockfile and cache files
rm -f $CACHEDIR/squid.conf*
rm -f $CACHEDIR/src_banned_mac.acl*
rm -f $CACHEDIR/fwrules.config*
rm -f $lockflag || exit 1

echo "Success!"

exit 0
