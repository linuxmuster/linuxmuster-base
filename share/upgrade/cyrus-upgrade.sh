#!/bin/bash
#
# cyrus upgrade 2.1 -> 2.2
# Thomas Schmitt <schmitt@lmz-bw.de>
# thanks to Thomas Hoth

# check for installed cyrus version
if ! dpkg -l | grep -q "ii  cyrus21-common"; then
	echo "cyrus has already been upgraded!"
	exit 0
fi

# checking internet connection
if ! ping -c2 www.backports.org &> /dev/null; then
	echo "No connection to www.backports.org! Aborting!"
	exit 1
fi

# stopping cyrmaster
/etc/init.d/cyrus21 stop

# rollback
rollback() {

	echo "Error! Restoring cyrus backup and exiting!"
	tar xjf /var/backup/linuxmuster/cyrus21-backup.tar.bz2 -C /
	exit

}

# backing up cyrus stuff
echo "Backing up cyrus stuff to /var/backup/linuxmuster/cyrus21-backup.tar.bz2 ..."
tar cjf /var/backup/linuxmuster/cyrus21-backup.tar.bz2 /etc/imapd.conf /etc/cyrus.conf /var/spool/cyrus /var/lib/cyrus || exit 1

# updating
aptitude update || exit 1
aptitude -y dist-upgrade || exit 1
aptitude -y install cyrus22-admin cyrus22-common cyrus22-imapd cyrus22-pop3d libcyrus-imap-perl22 || exit 1

# reconstruct user mailboxes
su cyrus "/usr/sbin/cyrreconstruct -r user.*" || rollback

# convert cyrus databases
[ -e /var/lib/cyrus/tls_sessions.db ] && rm /var/lib/cyrus/tls_sessions.db
su cyrus "/usr/bin/db4.2_upgrade /var/lib/cyrus/deliver.db" || rollback
su cyrus "find /var/spool/cyrus/mail/ -name \*.seen -exec /usr/sbin/cvt_cyrusdb \{\} flat \{\}.new skiplist \; -exec mv \{\}.new \{\} \;" || rollback

# updating cyrus.conf
cp -f /var/lib/linuxmuster/config-static/etc/cyrus.conf /etc

# reconfigure cyrus
[ -e /usr/lib/cyrus/cyrus-db-types.active ] && rm /usr/lib/cyrus/cyrus-db-types.active
dpkg-reconfigure cyrus-common-2.2

echo "Done! :-)"
