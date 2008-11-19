#!/bin/sh
#
# handling of ipcop's openvpn client certificates
# Thomas Schmitt <schmitt@lmz-bw.de>
#
# 02.07.2008

# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1

# source helperfunctions
. $HELPERFUNCTIONS || exit 1


# parsing parameters
getopt $*


usage() {
  echo "Tool to manage OpenVPN client certificates"
  echo
  echo "Usage: linuxmuster-ovpn    <--check --username=login>"
  echo "                           <--create --username=login --password=password>"
  echo "                           <--download --username=login>"
  echo "                           <--show --username=login>"
  echo "                           <--activate [--username=login|--group=groupname]>"
  echo "                           <--deactivate [--username=login|--group=groupname]>"
  echo "                           <--purge [--username=login|--group=groupname]>"
  echo "                           <--cleanup>"
  echo "                           <--list>"
  echo "                           <--purgeallstudentcerts>"
  echo
  exit 1
}


# test options
[[ -n "$create" && -n "$check" ]] && usage
[[ -n "$create" && -n "$download" ]] && usage
[[ -n "$check" && -n "$download" ]] && usage
if [ -n "$create" ]; then
	[ -z "$username" ] && usage
	if [ -z "$password" ]; then
		# pw length at least 6 characters
		echo -n "Password (at least 6 characters): "
		read password
	fi
	len=${#password}
	if [ $len -lt 6 ]; then
		echo "Password too short! Six characters at least!"
		exit 2
	fi
elif [[ -n "$check" || -n "$download" || -n "$show" ]]; then
	[ -z "$username" ] && usage
elif [[ -n "$purge" || -n "$activate" || -n "$deactivate" ]]; then
	[[ -z "$username" && -z "$group" ]] && usage
	[[ -n "$username" && -n "$group" ]] && usage
else
	[[ -z "$cleanup" && -z "$purgeallstudentcerts" && -z "$list" ]] && usage
fi


# check user db connection
check_id $ADMINISTRATOR || exit 1


# default values for certificate validity
# period for admins, default 10 years
admins_certperiod=3650
# period for teachers, default 10 years
teachers_certperiod=3650
# period for others, default 1 year
others_certperiod=365
# read clientcert.conf
[ -e /etc/linuxmuster/clientcert.conf ] && . /etc/linuxmuster/clientcert.conf


# compute common name for cert
get_commonname() {

	if [ -z "$username" ]; then
		unset cn
		return
	fi

	get_realname $username
	if [ -z "$RET" ]; then
		unset cn
		return
	fi
	strip_spaces "$RET"
	cn="${username} - $RET"

}


if [ -n "$username" ]; then

	# administrator is valid
	if [ "$username" != "$ADMINISTRATOR" ]; then

	    # valid user check
	    uidnr=`id -ru $username`
	    if [[ -z "$uidnr" || "$uidnr" -lt 10000 ]]; then

		echo "No valid username!"
		exit 1

	    fi

	fi

	# determine common name
	get_commonname

	# check for certificate
	cert_status=1; msg=no
	exec_ipcop /bin/ls /var/ipcop/ovpn/certs/${username}.p12 && cert_status=0 && msg=an

fi


# check if group has members and get primary group members
if [ -n "$group" ]; then

	get_pgroup_members $group

	if [ -z "$RET" ]; then

		echo "Group $group has no members!"
		exit 1

	fi
	strip_spaces "$RET"
	groupmembers="$RET"

fi


if [ -n "$check" ] || [[ -n "$purge" && -n "$username" && "$msg" = "no" ]]; then
	echo "There is $msg OpenVPN certificate for user $username!"
	exit $cert_status
fi


# write client config
write_config() {

	configfile=$1
	remote=$2

	echo "#OpenVPN Server conf" > $configfile
	echo "tls-client" >> $configfile
	echo "client" >> $configfile
	echo "dev $DDEVICE" >> $configfile
	echo "proto $DPROTOCOL" >> $configfile
	echo "$DDEVICE-mtu $DMTU" >> $configfile
	echo "remote $remote $DDEST_PORT" >> $configfile
	echo "pkcs12 ${username}.p12" >> $configfile
	echo "cipher $DCIPHER" >> $configfile
	[ "$DCOMPLZO" = "on" ] && echo "comp-lzo" >> $configfile
	echo "verb 3" >> $configfile
	echo "ns-cert-type server" >> $configfile

}


# download certificate function
download_cert() {

	tmpdir=/var/tmp/download_cert.$$
	mkdir -p $tmpdir
        checklock || exit 1

	get_ipcop /var/ipcop/ovpn/certs/${username}.p12 $tmpdir/${username}.p12 || cancel "Certificate download for user $username failed!"
	get_ipcop /var/ipcop/ovpn/settings $tmpdir/settings || cancel "OpenVPN settings download failed!"
	. $tmpdir/settings

	write_config $tmpdir/${username}-TO-IPCop-RED.ovpn $VPN_IP
	[ "$ENABLED_BLUE" = "on" ] && write_config $tmpdir/${username}-TO-IPCop-BLUE.ovpn ${ipcopblue}.254
	[ "$ENABLED_ORANGE" = "on" ] && write_config $tmpdir/${username}-TO-IPCop-ORANGE.ovpn ${ipcoporange}.254

	get_homedir $username
	strip_spaces "$RET"
	homedir="$RET"
	if ! echo $homedir | grep -q ^/home; then
		cancel "Invalid home directory for user $username!"
	fi
	[ -d "$homedir/OpenVPN" ] && rm -rf $homedir/OpenVPN
	mkdir -p $homedir/OpenVPN || cancel "Cannot create $homedir/OpenVPN!"
	mv $tmpdir/${username}.p12 $homedir/OpenVPN
	mv $tmpdir/*.ovpn $homedir/OpenVPN

	rm -f $lockflag
	rm -rf $tmpdir
	echo " Certificate for user $username successfully downloaded"
	echo " to $homedir/OpenVPN! :-)"

}

# create certificate function
create_cert() {

	commonname=${cn// /_}

	tmpdir=/var/tmp/create_cert.$$
	mkdir -p $tmpdir
	chmod 700 $tmpdir

	echo "$password" > $tmpdir/$username.cred
	chmod 600 $tmpdir/$username.cred

	# check for admins or teachers
	if check_admin $username; then
		days=$admins_certperiod
	elif check_teacher $username; then
		days=$teachers_certperiod
	else
		days=$others_certperiod
	fi

	echo "Creating openvpn certificate for user $username ..."
        # check if task is locked
        checklock || exit 1
	if ! put_ipcop $tmpdir/$username.cred /tmp/$username.cred; then
		rm -rf $tmpdir
		cancel "Upload of certificate data failed!"
	fi
	rm -rf $tmpdir
	if ! exec_ipcop /var/linuxmuster/create-client-cert $username $commonname $days; then
		cancel "Certificate creation for user $username failed!"
	fi
	rm -f $lockflag
	echo " OpenVPN certificate for user $username successfully created! :-)"

}


# mail to admin about certificate creation
mail_admin() {

	mail -s "OpenVPN-Zertifikat fuer Benutzer $cn erstellt" ${ADMINISTRATOR}@localhost <<EOF
Benutzer $cn hat sich erfolgreich ein OpenVPN-Zertifikat erstellt.
Das Zertifikat muss jedoch noch durch den Administrator freigeschaltet werden.
Siehe https://ipcop:445/cgi-bin/ovpnmain.cgi

EOF

}

# create certificate
if [ -n "$create" ]; then

	# create only if there is no cert
	if [ $cert_status -eq 0 ]; then
		echo "User $username has already a certificate! Skipping creation!"
	else
		create_cert
	fi

	download_cert
	mail_admin

	exit 0

fi # create certificate


# download cert only
if [ -n "$download" ]; then

	if [ $cert_status -eq 0 ]; then

		download_cert $username

	else

		echo " There is no certificate for user $username!"
		exit 1
	fi

	exit 0

fi


# show user certificate information
if [ -n "$show" ]; then

	tmpdir=/var/tmp/show_cert.$$
	mkdir -p $tmpdir || exit 1

	get_ipcop /var/ipcop/ovpn/certs/${username}cert.pem $tmpdir
	openssl x509 -text -in $tmpdir/${username}cert.pem

	rm -rf $tmpdir

	exit 0

fi


# activate certificate
cert_on() {

	if grep -q ",off,$certuser," $tmpdir/ovpnconfig; then
		echo " Activating OpenVPN certificate for $certuser!"
		sed -e "s/,off,$certuser,/,on,$certuser,/" -i $tmpdir/ovpnconfig
		changed=yes
	else
		echo " OpenVPN certificate for $certuser is already activated!"
	fi

}


# deactivate certificate
cert_off() {

	if grep -q ",on,$certuser," $tmpdir/ovpnconfig; then
		echo " Deactivating OpenVPN certificate for $certuser!"
		sed -e "s/,on,$certuser,/,off,$certuser,/" -i $tmpdir/ovpnconfig
		changed=yes
	else
		echo " OpenVPN certificate for $certuser is already deactivated!"
	fi

}


# cleaning OpenVPN folder in user's homedir
home_purge() {

	local user="$1"
	get_homedir $user
	strip_spaces "$RET"
	[[ -n "$RET" && -e "$RET/OpenVPN" ]] && rm -rf $RET/OpenVPN

}


# purge certiticate
cert_purge() {

	local user="$1"
	echo " Purging OpenVPN certificate for $user!"
	grep -v ",$user," $tmpdir/ovpnconfig > $tmpdir/ovpnconfig.tmp
	mv $tmpdir/ovpnconfig.tmp $tmpdir/ovpnconfig
	grep -v "CN=$user - " $tmpdir/index.txt > $tmpdir/index.txt.tmp
	mv $tmpdir/index.txt.tmp $tmpdir/index.txt
	exec_ipcop /bin/rm /var/ipcop/ovpn/certs/${user}cert.pem
	exec_ipcop /bin/rm /var/ipcop/ovpn/certs/${user}.p12
	home_purge "$user"
	changed="yes"

}


# set lockfile
checklock || exit 1


# temp dir
tmpdir=/var/tmp/purge_cert.$$
mkdir -p $tmpdir || cancel "Cannot create $tmpdir!"
chmod 700 $tmpdir


# deactivate web access to openvpn
if ! exec_ipcop /bin/chown root:root /var/ipcop/ovpn/ovpnconfig; then
	rm -rf $tmpdir
	cancel "IPCop access failed!"
fi


# fetch relevant files
get_ipcop /var/ipcop/ovpn/ovpnconfig $tmpdir
get_ipcop /var/ipcop/ovpn/certs/index.txt $tmpdir
if [[ ! -s "$tmpdir/ovpnconfig" || ! -s "$tmpdir/index.txt" ]]; then

	exec_ipcop /bin/chown nobody:nobody /var/ipcop/ovpn/ovpnconfig
	rm -rf $tmpdir
	cancel "Download of certificate information from IPCop failed!"

fi


# listing user certificates
if [ -n "$list" ]; then


		for certuser in `sort -n $tmpdir/ovpnconfig | awk -F, '{ print $3 }'`; do

			# filter users not created by this script
			grep -q ",$certuser,$certuser - " $tmpdir/ovpnconfig || continue

			get_pgroup $certuser
			strip_spaces "$RET"
			group="$RET"
			nr=`grep ",$certuser," $tmpdir/ovpnconfig | awk -F, '{ print $1 }'`
			status=`grep ",$certuser," $tmpdir/ovpnconfig | awk -F, '{ print $2 }'`
			cn=`grep ",$certuser," $tmpdir/ovpnconfig | awk -F, '{ print $4 }'`

			echo -e "$nr\t$status\t$cn ($group)"

		done

fi


[ -n "$list" ] || echo "Starting linuxmuster-ovpn on `date`"


[ -n "$username" ] && groupmembers=$username


# activating or deactivating user certificate
if [[ -n "$activate" || -n "$deactivate" ]]; then

	for username in $groupmembers; do

		for certuser in `awk -F, '{ print $3 }' $tmpdir/ovpnconfig`; do

			# filter users not created by this script
			grep -q ",$certuser,$certuser - " $tmpdir/ovpnconfig || continue

			if [ "$username" = "$certuser" ]; then
				echo "Found certificate for user $username."
				found=yes
				if [ -n "$activate" ]; then
					cert_on
				else
					cert_off
				fi
			fi

		done

		if [ -z "$found" ]; then
			echo "There is no certificate for $username!"
		else
			unset found
		fi

	done # groupmembers

fi


# purging user certificate
if [ -n "$purge" ]; then

		for username in $groupmembers; do

			if grep -q ",$username - " $tmpdir/ovpnconfig; then
				cert_purge $username
			else
				echo "There is no certificate for $username!"
			fi

		done # groupmembers

fi


# certs cleanup, purges or deactivates client certs of users, who are deleted or moved in the attic
if [[ -n "$cleanup" || -n "$purgeallstudentcerts" ]]; then

	if [ -n "$purgeallstudentcerts" ]; then
		echo "Caution! This will purge all student certificates!"
		echo "The process will start in 5 seconds. Press CRTL-C to cancel."
		n=0
		while [ $n -lt 5 ]; do
			echo -n .
			sleep 1
			let n=n+1
		done
		echo
	fi

	for certuser in `awk -F, '{ print $3 }' $tmpdir/ovpnconfig`; do
		
		# filter users not created by this script
		grep -q ",$certuser,$certuser - " $tmpdir/ovpnconfig || continue

		echo "Found certificate for $certuser."

		if [ -n "$cleanup" ]; then

			if check_id $certuser; then
				get_pgroup $certuser
				strip_spaces "$RET"
				if [ "$RET" = "attic" ]; then
					echo " $certuser is in the attic!"
					cert_off
				fi
			else
				echo " $certuser is deleted!"
				cert_purge "$certuser"
			fi

		else

			if get_homedir $certuser; then
				if stringinstring $STUDENTSHOME $RET; then
					echo " $certuser is a student!"
				cert_purge "$certuser"
				fi
			fi

		fi

	done

fi


# apply changes to IPcop
if [ -n "$changed" ]; then

	touch $tmpdir/ovpnconfig
	echo "Executing certificate configuration update ..."
	put_ipcop $tmpdir/ovpnconfig /var/ipcop/ovpn/ovpnconfig
	put_ipcop $tmpdir/index.txt /var/ipcop/ovpn/certs/index.txt
	exec_ipcop /usr/local/bin/openvpnctrl -r

fi


# all done
exec_ipcop /bin/chown nobody:nobody /var/ipcop/ovpn/ovpnconfig
exec_ipcop /bin/chown nobody:nobody /var/ipcop/ovpn/certs/index.txt
rm -f $lockflag
rm -rf $tmpdir

[ -n "$list" ] || echo "Finished linuxmuster-ovpn on `date`"
