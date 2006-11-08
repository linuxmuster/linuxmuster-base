#!/bin/sh
# check if urlfilter is active

#set -x

# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1

# source helperfunctions
. $HELPERFUNCTIONS || exit 1

# check if task is locked
checklock || exit 1

if check_urlfilter; then
  echo "Urlfilter is active!"
  exit 0
else
  echo "Urlfilter is not active!"
  exit 1
fi
