#!/bin/sh
#
# creates 20 test users
#

[ -s /etc/sophomorix/user/schueler.txt ] && exit
[ -s /etc/sophomorix/user/lehrer.txt ] && exit

cp /usr/share/linuxmuster/examples/schueler.txt /etc/sophomorix/user
cp /usr/share/linuxmuster/examples/lehrer.txt /etc/sophomorix/user
sophomorix-check
sophomorix-add
sophomorix-passwd -s -t --pass muster
