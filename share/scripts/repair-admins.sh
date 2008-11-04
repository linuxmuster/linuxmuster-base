#!/bin/bash
#
# repair admin accounts and groupmappings
#
# Thomas Schmitt
# 02.11.2008
# <schmitt@lmz-bw.de>
#

# read linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf

# tmpdir
tmpdir=/var/tmp/repair-admins.$$
mkdir -p $tmpdir || exit 1
tmpfile=$tmpdir/userdata

# check if necessary services are running
if ! ps ax | grep slapd | grep -q -v grep; then
    echo "LDAP-Server is not running!"
    exit
fi
if ! ps ax | grep /usr/lib/postgresql/8.1/bin/postmaster | grep -q -v grep; then
    echo "Postgresql-Server is not running!"
    exit
fi

# lock process
locker=/tmp/.repair-admins.lock
lockfile -l 60 $locker

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
#if net groupmap list | grep -q "Web Administrators"; then
#	echo "Removing groupmapping for Web Administrators ..."
#	net groupmap delete ntgroup="Web Administrators"
#fi

# repair admin accounts
groupsid=${sambasid}-512
uid=996
for username in $DOMADMIN $WWWADMIN $ADMINISTRATOR $PGMADMIN; do
	echo "Checking $username ($uid) account ..."
	usersid=${sambasid}-${uid}
	GROUP=$DOMADMINS
	GID=512
	if [ "$username" = "$WWWADMIN" ]; then
	    GROUP=$ADMINGROUP
	    GID=544
	fi
	SECGROUPS=""
	[ "$username" = "$ADMINISTRATOR" ] && SECGROUPS="-G $ADMINGROUP,$PRINTERADMINS,$TEACHERSGROUP"
	[ "$username" = "$PGMADMIN" ] && SECGROUPS="-G $TEACHERSGROUP"
	USERSHELL="/bin/false"
	[ "$username" = "$ADMINISTRATOR" ] && USERSHELL="/bin/bash"
	USERHOME=$ADMINSHOME/$username
	[ "$username" = "$DOMADMIN" ] && USERHOME=/dev/null
	case $username in
	    $DOMADMIN) GECOS="Domain Admin" ;;
	    $WWWADMIN) GECOS="Web Admin" ;;
	    $PGMADMIN) GECOS="Programm Admin" ;;
	    $ADMINISTRATOR) GECOS="Administrator" ;;
	esac
	if ! smbldap-usershow $username > $tmpfile.$username; then
	    echo "Trying to add missing $username account ..."
	    sophomorix-useradd --unix-group $GROUP --administrator $i
	    smbldap-useradd -a -u $uid -g $GID -d $USERHOME $SECGROUPS -s $USERSHELL -c "$GECOS" -N $username -m -A 0 -B 0 $username
	    smbldap-usershow $username > $tmpfile.$username ; RC=$?
	    if [ "$RC" = "0" ]; then
		if [ -n "$accounts_created" ]; then
		    accounts_created="$accounts_created $username"
		else
		    accounts_created=$username
		fi
	    fi
	fi
	current_groupsid=`grep sambaPrimaryGroupSID $tmpfile.$username | cut -f2 -d" "`
	current_usersid=`grep sambaSID $tmpfile.$username | cut -f2 -d" "`
	[ "$current_groupsid" = "$groupsid" ] || modify=yes
	[ "$current_usersid" = "$usersid" ] || modify=yes
	if [ -n "$modify" ]; then
		echo "Reparing sambaSID for user $username ..."
		pdbedit -r -U $usersid -G $groupsid $username &> /dev/null
	fi
	unset modify

	# activate or deactivate accounts
	ACTFLAG="-J"
	[ "$username" = "$DOMADMIN" -o "$username" = "$WWWADMIN" ] && ACTFLAG="-I"
	smbldap-usermod $ACTFLAG $username

	let uid+=1
done

# remove obsolete wwwadmin group
sophomorix-groupdel wwwadmin &> /dev/null

# put administrator and pgmadmin in teachersgroup, if necessary
for i in $ADMINISTRATOR $PGMADMIN; do
    GROUPS=""
    [ "$i" = "$ADMINISTRATOR" ] && GROUPS="-G $ADMINGROUP,$PRINTERADMINS,$TEACHERSGROUP"
    [ "$i" = "$PGMADMIN" ] && GROUPS="-G $TEACHERSGROUP"
    if ! smbldap-groupshow $TEACHERSGROUP | grep memberUid: | grep -qw $i; then
	echo "Adding $i to group $TEACHERSGROUP ..."
	smbldap-usermod $GROUPS $i
    fi
done

rm -f $locker
rm -rf $tmpdir

if [ -n "$accounts_created" ]; then
    echo
    echo "IMPORTANT!"
    echo "The following accounts have been recreated: $accounts_created."
    echo "It is recommended to set new passwords for them with sophomorix-passwd!"
    echo
    sleep 5
fi
