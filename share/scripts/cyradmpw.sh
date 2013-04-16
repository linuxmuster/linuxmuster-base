#!/bin/bash
#
# sets a new random password for cyrus user
#
# <thomas@linuxmuster.net>
# 16.04.2013
# GPL v3
#

cyradmpw=`pwgen -s 24 1`
echo "$cyradmpw" | saslpasswd2 -p -c cyrus
echo "cyrus:$cyradmpw" | chpasswd
echo "$cyradmpw" > /etc/imap.secret
chmod 600 /etc/imap.secret
