#!/bin/bash
#
# allowing wlan access
#
# fschuett@gymnasium-himmelsthuer.de
# 06.08.2014
# GPL v3
#

#set -x

# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1

# source helperfunctions
. $HELPERFUNCTIONS || exit 1

# radius users config
RADIUSCFG='/etc/freeradius/users'

RADIUSCFGSTART='# linuxmuster.net -- automatic entries below this line'
RADIUSCFGLASTLINE1="DEFAULT Auth-Type := REJECT"
RADIUSCFGREPLY='Reply-Message ='
RADIUSCFGLASTLINE2='    Reply-Message = "Sie dürfen momentan nicht auf das WLAN zugreifen."'
RADIUSCFGEND='# linuxmuster.net -- automatic entries above this line'

# parsing parameters
getopt $*

usage() {
  echo
  echo "Usage: wlan_on_off.sh --trigger=<on|off>"
  echo "                      --grouplist=<group1,group2,...,groupn>"
  echo "                      --help"
  echo
  echo "  trigger:  trigger on or off"
  echo "  maclist:  comma separated list of group names"
  echo "  help:     shows this help"
  echo
  exit 1
}

# test parameters
[ -n "$help" ] && usage
[ "$trigger" != "on" -a "$trigger" != "off" ] && usage
[ -z "$grouplist" ] && usage


# check if task is locked
checklock || exit 1

# create a list of group names
for i in ${grouplist//,/ }; do
 GROUPS_TO_PROCESS="$GROUPS_TO_PROCESS $i"
done
strip_spaces "$GROUPS_TO_PROCESS"
if [ -n "$RET" ]; then
 GROUPS_TO_PROCESS="$RET"
else
 cancel "No valid group names!"
fi

# create a allowed groups file if not there
if [ ! -e "$RADIUSCFG" ]; then
 touch $RADIUSCFG || cancel "Cannot create $RADIUSCFG!"
fi

# test for writability
[ -w "$RADIUSCFG" ] || cancel "Cannot write to $RADIUSCFG!"

# iterate over commandline given groups and write groups not already in allowed groups file
bereich=false
writegroups=
while read line; do
 if echo $line | grep -q "$RADIUSCFGSTART"; then
  echo $line;
  bereich=true
 elif echo $line | grep -q "$RADIUSCFGREPLY"; then
  continue;
 elif [ "$line" = "$RADIUSCFGEND" ]; then
  continue;
 elif [ $bereich = true ]; then
  if echo $line | grep -q "$RADIUSCFGLASTLINE1"; then
   bereich=false
   # alles schreiben
   if [ "$trigger" = "on" ]; then
    for group in $GROUPS_TO_PROCESS; do
     mgroup=\\b$group\\b
     if [[ ! $writegroups =~ $mgroup ]]; then
      writegroups="$writegroups $group"
     fi
    done;
   fi
   for group in $writegroups; do
    echo "DEFAULT Ldap-Group == $group";
   done;
   echo $RADIUSCFGLASTLINE1;
   echo "$RADIUSCFGLASTLINE2";
   echo $RADIUSCFGEND;
  else
   # alte Eintraege ueberpruefen
   group=$(echo $line | sed 's@DEFAULT Ldap-Group == @@')
   mgroup=\\b$group\\b
   if [ "$trigger" = "on" ]; then
    writegroups="$writegroups $group"
   elif [[ ! $GROUPS_TO_PROCESS =~ $mgroup ]]; then
    writegroups="$writegroups $group"
   fi
  fi
 else
  echo $line;
 fi
done < $RADIUSCFG >/etc/freeradius/users.neu
mv /etc/freeradius/users.neu $RADIUSCFG

# restart radius server
service freeradius restart || exit 1

# delete lock
rm -f $lockflag || exit 2

echo "Success!"

exit 0
