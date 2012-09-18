#!/bin/bash
# assign specific nic to lan
# $Id: nic_setup.sh 1334 2012-07-20 12:03:39Z tschmitt $

# Source debconf library.
. /usr/share/debconf/confmodule

db_version 2.0

PRIORITY="critical"

# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1

# source helperfunctions
. $HELPERFUNCTIONS || exit 1

db_title "$DISTNAME $DISTFULLVERSION"

assign_nics

# important: close debconf database
db_stop

