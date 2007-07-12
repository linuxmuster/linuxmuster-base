#!/bin/bash
#
# repair admin accounts and groupmappings
#
# Thomas Schmitt
# 11.07.2007
# <schmitt@lmz-bw.de>
#

# read linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf

# fetch sambasid from debconf
sambasid=`debconf-show linuxmuster-base | grep sambasid | cut -f2 -d:`
sambasid=${sambasid// /}
[ -z "$sambasid" ] && exit 1


# checking if sambasid is valid
if ! net getlocalsid | grep -q $sambasid; then
	echo "There is something wrong with your sambaSID!"
	exit 1
fi


# repair groupmapping for admin groups
for i in "512 $DOMADMINS" "513 domusers" "514 domguests" "515 domcomputers"; do
	gid=`echo $i | cut -f1 -d" "`
	gname=`echo $i | cut -f2 -d" "`
	current_groupsid=`smbldap-groupshow $gname | grep sambaSID | cut -f2 -d" "`
	groupsid=${sambasid}-${gid}
	if [ "$current_groupsid" != "$groupsid" ]; then
		echo "Repairing sambaSID for group $gname ..."
		smbldap-groupmod -s $groupsid $gname
	fi
done

for i in "544 $ADMINGROUP" "548 accountoperators" "550 printoperators" "551 backupoperators" "552 replicators"; do
	gid=`echo $i | cut -f1 -d" "`
	gname=`echo $i | cut -f2 -d" "`
	current_groupsid=`smbldap-groupshow $gname | grep sambaSID | cut -f2 -d" "`
	groupsid=S-1-5-32-${gid}
	if [ "$current_groupsid" != "$groupsid" ]; then
		echo "Repairing sambaSID for group $gname ..."
		smbldap-groupmod -s $groupsid $gname
	fi
done


# delete unnecessary groupmapping
if net groupmap list | grep -q "Web Administrators"; then
	net groupmap delete ntgroup="Web Administrators"
fi


# repair admin accounts
groupsid=${sambasid}-512
for i in "996 $DOMADMIN" "998 $ADMINISTRATOR" "999 $PGMADMIN"; do
	uid=`echo $i | cut -f1 -d" "`
	username=`echo $i | cut -f2 -d" "`
	usersid=${sambasid}-${uid}
	current_groupsid=`smbldap-usershow $username | grep sambaPrimaryGroupSID | cut -f2 -d" "`
	current_usersid=`smbldap-usershow $username | grep sambaSID | cut -f2 -d" "`
	[ "$current_groupsid" = "$groupsid" ] || modify=yes
	[ "$current_usersid" = "$usersid" ] || modify=yes
	if [ -n "$modify" ]; then
		echo "Reparing sambaSID for user $username ..."
		pdbedit -r -U $usersid -G $groupsid $username &> /dev/null
	fi
	unset modify
done


# put administrator in teachersgroup, if necessary
smbldap-groupshow $TEACHERSGROUP | grep memberUid: | grep -qw $ADMINISTRATOR || smbldap-usermod -G $ADMINGROUP,$PRINTERADMINS,$TEACHERSGROUP $ADMINISTRATOR
