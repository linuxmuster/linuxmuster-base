#!/bin/sh
#
# blocking intranet access

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
else
	if ! iptables -L | grep -q "$FIREWALLTEST"; then
		echo "Internal Firewall is not running! Aborting!"
		exit 1
	fi
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
[[ "$trigger" != "on" && "$trigger" != "off" ]] && usage
[[ -z "$maclist" && -z "$hostlist" ]] && usage

# check if task is locked
checklock || exit 1

# get maclist
get_maclist || cancel "Cannot get maclist!"

# create blocked hosts file
if [ ! -e "$BLOCKEDHOSTSINTRANET" ]; then
  touch $BLOCKEDHOSTSINTRANET || cancel "Cannot create $BLOCKEDHOSTSINTRANET!"
fi

# save settings
cp -f $BLOCKEDHOSTSINTRANET $BLOCKEDHOSTSINTRANET.bak || cancel "Cannot backup $BLOCKEDHOSTSINTRANET!"
iptables-save > $CACHEDIR/iptables-save || cancel "Execution of iptables-save failed!"

# restore old settings by failure
rollback() {
  mv $BLOCKEDHOSTSINTRANET.bak $BLOCKEDHOSTSINTRANET || cancel "$1 Rollback of internal firewall rules failed!"
  cat $CACHEDIR/iptables-save | iptables-restore || cancel "$1 Rollback of internal firewall rules failed!"
  cancel "$1 Old firewall rules successfully restored!"
}


# delete rules for blocked mac
delete_rules() {
  [ -f "$BLOCKEDPORTS" ] || return
  while read proto portrange; do
    [ "${proto:0:1}" = "#" ] && continue
    [[ -z "$portrange" || -z "$proto" ]] && continue
    portrange=${portrange//,/ }
    for p in $portrange; do
      iptables -D IN-$IFACE -p $proto -m mac --mac-source ${mac[$n]} --dport $p -j ACCEPT
    done
  done <$BLOCKEDPORTS
}

# create rules for released macs
insert_rules() {
  [ -f "$BLOCKEDPORTS" ] || return
  insert_nr=`iptables -L IN-$IFACE --line-numbers | grep -m1 MAC | awk '{ print $1 }'`
  n=0
  while [[ $n -lt $nr_of_macs  ]]; do
    while read proto portrange; do
      [ "${proto:0:1}" = "#" ] && continue
      [[ -z "$portrange" || -z "$proto" ]] && continue
      portrange=${portrange//,/ }
      for p in $portrange; do
        iptables -I IN-$IFACE $insert_nr -p $proto -m mac --mac-source ${mac[$n]} --dport $p -j ACCEPT
      done
    done <$BLOCKEDPORTS
    let n+=1
  done
}

# add macs to blocked hosts file
if [ "$trigger" = "off" ]; then

  cp -f $BLOCKEDHOSTSINTRANET $BLOCKEDHOSTSINTRANET.new || rollback "Cannot create $BLOCKEDHOSTSINTRANET.new!"

  n=0
  while [[ $n -lt $nr_of_macs  ]]; do
    if ! grep -q ${mac[$n]} $BLOCKEDHOSTSINTRANET; then
      echo ${mac[$n]} >> $BLOCKEDHOSTSINTRANET.new || rollback "Cannot write $BLOCKEDHOSTSINTRANET.new!"
      delete_rules
    fi
    let n+=1
  done

else # remove macs from blocked hosts file

  if [ -e "$BLOCKEDHOSTSINTRANET.new" ]; then
    rm -f $BLOCKEDHOSTSINTRANET.new || rollback "Cannot delete $BLOCKEDHOSTSINTRANET.new!"
  fi
  touch $BLOCKEDHOSTSINTRANET.new || rollback "Cannot create $BLOCKEDHOSTSINTRANET!"
  while read line; do
    found=0; n=0
    while [[ $n -lt $nr_of_macs  ]]; do
      [ "$line" = "${mac[$n]}" ] && found=1
      let n+=1
    done
    if [[ $found -eq 0 ]]; then
      echo $line >> $BLOCKEDHOSTSINTRANET.new || rollback "Cannot write $BLOCKEDHOSTSINTRANET!"
    fi
  done <$BLOCKEDHOSTSINTRANET
  insert_rules

fi

mv $BLOCKEDHOSTSINTRANET.new $BLOCKEDHOSTSINTRANET || rollback "Cannot write $BLOCKEDHOSTSINTRANET!"

# delete files
rm -f $CACHEDIR/*.bak
rm -f $CACHEDIR/iptables-save
rm -f $lockflag || exit 1

echo "Success!"

exit 0
