#!/bin/bash
#
# thomas@linuxmuster.net
# 28.05.2014
#
#

. /usr/share/linuxmuster/config/dist.conf || exit 1

usage(){
 echo "Usage: `basename $0` [--allow|--deny]"
 echo
 echo "Allows/denies access for rooms on $SHAREHOME."
 echo
 exit 1
}

remove_acls(){
 local RC=0
 # remove previously set acls
 sed -e 's|:---|:|g' -i "$ROOM_SHARE_ACLS"
 setfacl -X "$ROOM_SHARE_ACLS" "$SHAREHOME" || RC=1
 rm -rf "$ROOM_SHARE_ACLS"
 touch "$ROOM_SHARE_ACLS"
 return $RC
}

set_acls(){
 if [ -s "$ROOM_SHARE_ACLS" ]; then
  remove_acls || return 1
 fi
 grep ^[a-zA-Z0-9] "$WIMPORTDATA" | awk -F\; '{ print $1 }' | sort -u | awk '{ print "g:" $1 ":---" }' > "$ROOM_SHARE_ACLS" || return 1
 setfacl -M "$ROOM_SHARE_ACLS" "$SHAREHOME" || return 1
}

RC=0

case "$1" in

 --allow)
  if [ ! -s "$ROOM_SHARE_ACLS" ]; then
   echo "No acl file found. Nothing to allow!"
   exit 0
  fi
  echo "Granting access rights for rooms on $SHAREHOME."
  remove_acls || RC=1 ;;

 --deny)
  echo "Removing access rights for rooms on $SHAREHOME."
  set_acls || RC=1 ;;

 *) usage ;;

esac

if [ "$RC" = "0" ]; then
 echo "Success!"
else
 rm -rf "$ROOM_SHARE_ACLS"
 touch "$ROOM_SHARE_ACLS"
 echo "Error!"
fi

exit $RC
