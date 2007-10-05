#!/bin/bash
#
# sets a new random password for cyrus user
#
# Thomas Schmitt
# <schmitt@lmz-bw.de>
#

cyradmpw=`pwgen -s 8 1`
echo "$cyradmpw" | saslpasswd2 -p -c cyrus
echo "cyrus:$cyradmpw" | chpasswd
echo $cyradmpw > /etc/imap.secret
chmod 600 /etc/imap.secret
