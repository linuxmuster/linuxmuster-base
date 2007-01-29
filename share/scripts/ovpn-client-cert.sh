#!/bin/sh
#
# handling of ipcop's openvpn client certificates
# Thomas Schmitt <schmitt@lmz-bw.de>
#

#set -x

# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1

# source helperfunctions
. $HELPERFUNCTIONS || exit 1


# parsing parameters
getopt $*


usage() {
  echo
  echo "Usage: ovpn-client-cert.sh <--check --username=login>"
  echo "                           <--create --username=login --password=password>"
  echo "                           <--download --username=login>"
  echo
  exit 1
}


# test options
[[ -n "$create" && -n "$check" ]] && usage
[[ -n "$create" && -n "$download" ]] && usage
[[ -n "$check" && -n "$download" ]] && usage
if [ -n "$create" ]; then
	[[ -z "$username" || -z "$password" ]] && usage
	# pw length at least 6 characters
	len=${#password}
	if [ $len -lt 6 ]; then
		echo "Password too short! It needs at least 6 characters!"
		exit 2
	fi
elif [[ -n "$check" || -n "$download" ]]; then
	[ -z "$username" ] && usage
else
	usage
fi


# valid user check
uidnr=`id -ru $username`
if [[ -z "$uidnr" || "$uidnr" -lt 10000 ]]; then

	echo "No valid username!"
	exit 1

fi


# check for certificate
cert_status=1; msg=no
exec_ipcop /bin/ls /var/ipcop/ovpn/certs/${username}.p12 && cert_status=0 && msg=an
if [ -n "$check" ]; then
	echo "User $username has $msg openvpn certificate."
	exit $cert_status
fi


# write client config
write_config() {

	configfile=$1
	remote=$2
	username=$3

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

	username=$1

	tmpdir=/var/tmp/download_cert.$$
	mkdir -p $tmpdir
        checklock || exit 1
	get_ipcop /var/ipcop/ovpn/certs/${username}.p12 $tmpdir/${username}.p12 || cancel "Certificate download for user $username failed!"
	get_ipcop /var/ipcop/ovpn/settings $tmpdir/settings || cancel "Certificate download for user $username failed!"
	. $tmpdir/settings
	write_config $tmpdir/${username}-TO-IPCop-RED.ovpn $ROOTCERT_HOSTNAME $username
	[ "$ENABLED_BLUE" = "on" ] && write_config $tmpdir/${username}-TO-IPCop-BLUE.ovpn ${ipcopblue}.254 $username
	[ "$ENABLED_ORANGE" = "on" ] && write_config $tmpdir/${username}-TO-IPCop-ORANGE.ovpn ${ipcoporange}.254 $username
	homedir=`smbldap-usershow $username | grep ^homeDirectory: | cut -f2 -d" "`
	if ! echo $homedir | grep -q ^/home; then
		cancel "Invalid home directory for user $username!"
	fi
	[ -d "$homedir/OpenVPN" ] && rm -rf $homedir/OpenVPN
	mkdir -p $homedir/OpenVPN || cancel "Cannot create $homedir/OpenVPN!"
	mv $tmpdir/${username}.p12 $homedir/OpenVPN
	mv $tmpdir/*.ovpn $homedir/OpenVPN
	rm -f $lockflag
	rm -rf $tmpdir
	echo "Certificate for user $username successfully downloaded! :-)"

}

# create certificate function
create_cert() {

	username=$1
	password=$2

	echo "Creating openvpn certificate for user $username ..."
        # check if task is locked
        checklock || exit 1
	exec_ipcop /usr/local/bin/create-client-cert $username $password || cancel "Certificate creation for user $username failed!"
	rm -f $lockflag
	echo "openvpn certificate for user $username successfully created! :-)"

}


# mail to admin about certificate creation
mail_admin() {

	username=$1

	mail -s "OpenVPN-Zertifikat fuer Benutzer $username erstellt" ${ADMINISTRATOR}@localhost <<EOF
Benutzer $username hat sich erfolgreich ein OpenVPN-Zertifikat erstellt.
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
		create_cert $username $password
	fi

	download_cert $username
	mail_admin $username

fi # create certificate


# download cert only
if [ -n "$download" ]; then

	if [ $cert_status -eq 0 ]; then

		download_cert $username

	else

		echo "User $username has no certificate! Nothing to download!"
		exit 1
	fi

fi
