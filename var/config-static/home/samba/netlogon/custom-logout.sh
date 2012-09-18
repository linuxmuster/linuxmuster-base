# custom-logout.sh
#
# this script will be sourced by samba-userlog on user logout
# you can place here custom things to be done when a user disconnects from his home share
#
# variables which come along:
# $username -> the current username
# $homedir -> the home directory of the user
# $hostname -> the host from which the user disconnects
#
# Thomas Schmitt
# <tschmitt@linuxmuster.de>
# 02.10.2007
#
