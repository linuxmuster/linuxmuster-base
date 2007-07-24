#!/bin/bash
#
# create and remove a remote administrator
#
# 24.06.2007
# Thomas Schmitt
# <schmitt@lmz-bw.de>
#

# source linxmuster environment
. /usr/share/linuxmuster/config/dist.conf
. $HELPERFUNCTIONS

# check if task is locked
locker=/tmp/.remoteadmin.lock
lockfile -l 60 $locker

tmpdir=/var/tmp/${REMOTEADMIN}.$$
mkdir -p $tmpdir

# strings placed in /etc/sudoers
sudoerstr[0]="## begin linuxmuster $REMOTEADMIN ## DO NOT EDIT! ##"
sudoerstr[1]="$REMOTEADMIN ALL=(ALL) ALL ## DO NOT EDIT! ##"
sudoerstr[2]="## end linuxmuster $REMOTEADMIN ## DO NOT EDIT! ##"

remove_quota_entry() {

	# remove old entry if there is one
	for i in $QUOTACONF $MAILQUOTACONF; do
		if grep -qw ^$REMOTEADMIN $i; then
			grep -vw $REMOTEADMIN $i > $tmpdir/quota.tmp
			mv $tmpdir/quota.tmp $i
		fi
	done

}

set_quota_entry() {

	remove_quota_entry

	for i in $QUOTACONF $MAILQUOTACONF; do

		# determine administrator quota
		unset quota_value
		quota_value=`grep -w ^$ADMINISTRATOR $i | awk '{ print $2 }'`

		# writing new quota value for remoteadmin
		[ -n "$quota_value" ] && echo "$REMOTEADMIN: $quota_value" >> $i

	done

}

create_account() {

	sophomorix-useradd --administrator $REMOTEADMIN --unix-group $DOMADMINS --shell /bin/sh --gecos "Remote Administrator" &> /dev/null
	sophomorix-passwd --interactive --user $REMOTEADMIN
	smbldap-usermod -H '[UX         ]' $REMOTEADMIN
	set_quota_entry
	$SCRIPTSDIR/cyrus-mbox -q $quota_value -c $REMOTEADMIN
	sophomorix-quota --force --set -u $REMOTEADMIN &> /dev/null

}

create_cert() {

	pwstatus=0
	while [ "$pwstatus" = "0" ]; do
		stty -echo
		read -p "Please enter certificate password (6 chars at least): " certpw; echo
		len=${#certpw}
		if [ $len -lt 6 ]; then
			stty echo
			echo "Password too short! Six (6) characters at least!"
		else
			read -p "Please confirm certificate password: " certpw_confirm; echo
			stty echo
			if [ "$certpw" = "$certpw_confirm" ]; then
				pwstatus=1
			else
				echo "Passwords do not match!"
			fi
		fi
	done

	linuxmuster-ovpn --create --username=$REMOTEADMIN --password="$certpw"
	linuxmuster-ovpn --activate --username=$REMOTEADMIN

}

remove_account() {

	sophomorix-kill --killuser $REMOTEADMIN  &> /dev/null
	remove_quota_entry

}

add_to_sudoers() {

	cp /etc/sudoers /etc/sudoers.${REMOTEADMIN}.backup.add
	for i in 0 1 2; do
		echo "${sudoerstr[$i]}" >> /etc/sudoers
	done
	chown root:root /etc/sudoers*
	chmod 440 /etc/sudoers*

}

remove_from_sudoers() {

	cp /etc/sudoers /etc/sudoers.${REMOTEADMIN}.backup.remove
	for i in 0 1 2; do
		grep -v "${sudoerstr[$i]}" /etc/sudoers > $tmpdir/sudoers
		mv $tmpdir/sudoers /etc
	done
	chown root:root /etc/sudoers*
	chmod 440 /etc/sudoers*

}

add_to_webmin() {

	cp /etc/webmin/webmin.acl /etc/webmin/webmin.acl.${REMOTEADMIN}.backup.add
	cp /etc/webmin/miniserv.users /etc/webmin/miniserv.users.${REMOTEADMIN}.backup.add
	echo "${REMOTEADMIN}: acl change-user servers webmin webminlog apache at custom cron fdisk init inittab man mount net pam passwd proc raid shell syslog time useradmin filemanager htaccess inetd logrotate mailboxes mysql postgresql software spamassassin status updown fetchmail grub lvm sshd webalizer" >> /etc/webmin/webmin.acl
	echo "${REMOTEADMIN}:x:0::" >> /etc/webmin/miniserv.users
	chown root:shadow /etc/webmin/miniserv.users*
	chmod 750 /etc/webmin/miniserv.users*

}

remove_from_webmin() {

	cp /etc/webmin/webmin.acl /etc/webmin/webmin.acl.${REMOTEADMIN}.backup.remove
	cp /etc/webmin/miniserv.users /etc/webmin/miniserv.users.${REMOTEADMIN}.backup.remove
	grep -v ${REMOTEADMIN} /etc/webmin/webmin.acl > $tmpdir/webmin.acl
	mv $tmpdir/webmin.acl /etc/webmin
	grep -v ${REMOTEADMIN} /etc/webmin/miniserv.users > $tmpdir/miniserv.users
	mv $tmpdir/miniserv.users /etc/webmin
	chown root:shadow /etc/webmin/miniserv.users*
	chmod 750 /etc/webmin/miniserv.users*

}

do_accessconf() {

	allowed=`grep ^"-:ALL EXCEPT" /etc/security/access.conf`
	allowed=${allowed#-:ALL EXCEPT }
	allowed=${allowed%:ALL}
	allowed=${allowed/$REMOTEADMIN/}
	if [ "$1" = "add" ]; then
		allowed="$allowed $REMOTEADMIN"
		cp /etc/security/access.conf /etc/security/access.conf.${REMOTEADMIN}.backup.add
	else
		cp /etc/security/access.conf /etc/security/access.conf.${REMOTEADMIN}.backup.remove
	fi
	allowed=${allowed//  / }
	allowed=${allowed% }
	sedstr="-:ALL EXCEPT ${allowed}:ALL"
	sedstr=${sedstr//  / }
	sed -e "s/^-:ALL EXCEPT.*/$sedstr/" /etc/security/access.conf > $tmpdir/access.conf
	mv $tmpdir/access.conf /etc/security

}

cat /etc/issue

case $1 in

	--create)
		echo "Creating account for $REMOTEADMIN ..."
		check_id $REMOTEADMIN && remove_account
		create_account
		linuxmuster-ovpn --check --username=$REMOTEADMIN && linuxmuster-ovpn --purge --username=$REMOTEADMIN
		create_cert
		grep -q $REMOTEADMIN /etc/sudoers && remove_from_sudoers
		add_to_sudoers
		do_accessconf add
		grep -q $REMOTEADMIN /etc/webmin/* && remove_from_webmin
		add_to_webmin
		/etc/init.d/webmin restart &> /dev/null
		if check_id $REMOTEADMIN; then
			echo "Account for $REMOTEADMIN successfully created!"
			status=0
		else
			echo "Failed to create account for $REMOTEADMIN!"
			remove_account
			grep -q $REMOTEADMIN /etc/sudoers && remove_from_sudoers
			do_accessconf
			status=1
		fi
		;;

	--remove)
		echo "Removing account for $REMOTEADMIN ..."
		linuxmuster-ovpn --check --username=$REMOTEADMIN && linuxmuster-ovpn --purge --username=$REMOTEADMIN
		check_id $REMOTEADMIN && remove_account
		grep -q $REMOTEADMIN /etc/sudoers && remove_from_sudoers
		do_accessconf
		grep -q $REMOTEADMIN /etc/webmin/* && remove_from_webmin
		/etc/init.d/webmin restart &> /dev/null
		if check_id $REMOTEADMIN; then
			echo "Failed to remove account for $REMOTEADMIN!"
			status=1
		else
			echo "Account for $REMOTEADMIN successfully removed!"
			status=0
		fi
		;;

	--activate)
		echo "Activating $REMOTEADMIN account ..."
		if check_id $REMOTEADMIN; then
			if sophomorix-passwd --interactive --user $REMOTEADMIN; then
				smbldap-usermod -H '[UX         ]' $REMOTEADMIN
				if linuxmuster-ovpn --check --username=$REMOTEADMIN; then
					linuxmuster-ovpn --activate --username=$REMOTEADMIN
				else
					create_cert
				fi
				grep -q $REMOTEADMIN /etc/sudoers && remove_from_sudoers
				add_to_sudoers
				do_accessconf add
				grep -q $REMOTEADMIN /etc/webmin/* && remove_from_webmin
				add_to_webmin
				/etc/init.d/webmin restart &> /dev/null
				echo "Account for $REMOTEADMIN successfully activated!"
				status=0
			else
				echo "Failed to activate account for $REMOTEADMIN!"
				status=1
			fi
		else
			echo "Account for $REMOTEADMIN does not exist!"
			status=1
		fi
		;;

	--deactivate)
		echo "Deactivating $REMOTEADMIN account ..."
		if check_id $REMOTEADMIN; then
			secret_passwd=`pwgen -s 8 1`
			if sophomorix-passwd --user $REMOTEADMIN --pass "$secret_passwd" &> /dev/null; then
				linuxmuster-ovpn --deactivate --username=$REMOTEADMIN
				smbldap-usermod -H '[DUX        ]' $REMOTEADMIN
				grep -q $REMOTEADMIN /etc/sudoers && remove_from_sudoers
				do_accessconf
				grep -q $REMOTEADMIN /etc/webmin/* && remove_from_webmin
				/etc/init.d/webmin restart &> /dev/null
				echo "Account for $REMOTEADMIN successfully deactivated!"
				status=0
			else
				echo "Failed to deactivate account for $REMOTEADMIN!"
				status=1
			fi
		else
			echo "Account for $REMOTEADMIN does not exist!"
			status=1
		fi
		;;

	*)
		echo "Usage: $0 [--create|--activate|--remove|--deactivate]"
		;;

esac

# remove lock and tmpdir
rm -rf $tmpdir
rm -f $locker

exit $status
