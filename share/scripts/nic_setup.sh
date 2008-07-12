#!/bin/sh

# Source debconf library.
. /usr/share/debconf/confmodule

db_version 2.0
db_title "paedML Linux 4.0"

PRIORITY="critical"

# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1

# source helperfunctions
. $HELPERFUNCTIONS || exit 1

# read fwconfig from debconf
db_get linuxmuster-base/fwconfig || true
fwconfig=$RET
if [ -z "$fwconfig" ]; then
	echo "Cannot determine firewall type. Aborting!"
	exit 1
fi

# assign nics with extern, intern, wlan, dmz interfaces
assign_nics

# important: close debconf database
db_stop

# write macs to network.settings
grep -v ^mac_ $NETWORKSETTINGS > $NETWORKSETTINGS.tmp
mv $NETWORKSETTINGS.tmp $NETWORKSETTINGS
echo "mac_extern=$mac_extern" >> $NETWORKSETTINGS
echo "mac_intern=$mac_intern" >> $NETWORKSETTINGS
echo "mac_wlan=$mac_wlan" >> $NETWORKSETTINGS
echo "mac_dmz=$mac_dmz" >> $NETWORKSETTINGS
chmod 755 $NETWORKSETTINGS
