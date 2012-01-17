#!/bin/bash
# assign specific nic to lan
# $Id$

# Source debconf library.
. /usr/share/debconf/confmodule

db_version 2.0

PRIORITY="critical"

# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1

# source helperfunctions
. $HELPERFUNCTIONS || exit 1

db_title "$(getdistname) $DISTFULLVERSION"

assign_nics

# important: close debconf database
db_stop

