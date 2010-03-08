#!/bin/bash
#
# update cached user logins
# GPL v3
# Thomas Schmitt <schmitt@lmz-bw.de>
#
# 2010-03-08
#

# print help message
case $1 in --help|-h) echo "Usage: $0 [room]" ; exit 0 ;; esac

# check for smbstatus executable
SMBSTATUS="$(which smbstatus)"
if [ ! -x "$SMBSTATUS" ]; then
 echo "smbstatus executable is missing!"
 exit 1
fi

# read in linuxmuster environment
. /usr/share/linuxmuster/config/dist.conf || exit 1

# check for cache dir
mkdir -p $LOGINCACHE
cd $LOGINCACHE || exit 1

# if no room is given, then process all rooms
if [ -z "$1" ]; then
 rooms="$(grep -v ^# $WIMPORTDATA | awk -F\; '{ print $1 }' | sort -u)"
else
 rooms="$1"
fi

# save samba status
status=$LOGINCACHE/.smbstatus.$$
$SMBSTATUS -b > $status

# process given rooms
for room in $rooms; do

 # determine the room's hosts from workstations file
 hosts="$(grep ^$room\; $WIMPORTDATA | awk -F\; '{ print $2 }' | sort)"

 if [ -n "$hosts" ]; then
  locker=/tmp/.update-logins.$room.lock
  lockfile -l 10 $locker
  rm -f $hosts
  msg=false
  # read smbstatus file and grep logins from it
  grep ^[1-9] $status | while read line; do
   machine="$(echo $line | awk '{ print $4 }')"
   echo $hosts | grep -qw $machine || continue
   if [ "$msg" = "false" ]; then
    echo "Login status for room $room:"
    msg=true
   fi
   username="$(echo $line | awk '{ print $2 }')"
   echo " $machine: $username"
   echo $username >> $machine
  done
  rm -f $locker
 fi

done

rm -f $status

