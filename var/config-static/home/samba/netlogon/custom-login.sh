# custom-login.sh
#
# this script will be sourced by samba-userlog on user login
# you can place here custom things to be done when a user connects to his home share
#
# variables which come along:
# $username -> the current username
# $homedir -> the home directory of the user
# $hostname -> the host from which the user connects
#
# Thomas Schmitt
# <schmitt@lmz-bw.de>
# 02.10.2007
#
