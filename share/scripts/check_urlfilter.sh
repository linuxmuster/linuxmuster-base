#!/bin/sh
# check if urlfilter is active

#set -x

# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1

# source helperfunctions
. $HELPERFUNCTIONS || exit 1

# check if task is locked
locker=/tmp/.check_urlfilter.lock
lockfile -l 60 $locker

if check_urlfilter; then
  echo "Urlfilter is active!"
  status=0
else
  echo "Urlfilter is not active!"
  status=1
fi

rm -f $locker

exit $status
