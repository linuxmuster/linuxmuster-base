#!/bin/bash
#
# removes insecure web services
# 01.03.2008
# Thomas Schmitt <schmitt@lmz-bw.de>
#

echo "This script removes obsolete and insecure services from paedML."
echo "The process will start in 5 seconds. Press CRTL-C to cancel."
n=0
while [ $n -lt 5 ]; do
	echo -n .
	sleep 1
	let n=n+1
done
echo
echo "Let's go! :-)"
echo

. /usr/share/linuxmuster/config/dist.conf || exit 1
. $HELPERFUNCTIONS || exit 1

packages="subversion subversion-tools websvn libapache2-svn chora2"
echo "Deinstallation of obsolete packages ..."
aptitude -y remove $packages || exit 1

if [ -d /var/www/people ]; then
	echo -n "Deactivating /var/www/people ..."
	chmod 700 /var/www/people
	echo " done."
fi

configs="/etc/apache2/mods-available/userdir.conf /etc/apache2/sites-available/default"
for i in $configs; do
	if ! grep -q "# modified by linuxmuster-base-1.3.1" $i; then
		echo -n "Updating $i ..."
		cp $i $i.obsolete
		cp -f /var/lib/linuxmuster/config-static$i $i
		apache_reload=yes
		echo " done."
	fi
done


# checking for link to /etc/apache2/sites-enabled/000-default
echo -n "Checking if /etc/apache2/sites-enabled/000-default is a link ..."
if [ -L /etc/apache2/sites-enabled/000-default ]; then
	echo " done."
else
	echo
	if [ -e /etc/apache2/sites-enabled/000-default ]; then
		backup_file /etc/apache2/sites-enabled/000-default
		rm /etc/apache2/sites-enabled/000-default
	fi
	echo -n "Linking /etc/apache2/sites-available/default to /etc/apache2/sites-enabled/000-default ..."
	ln -s /etc/apache2/sites-available/default /etc/apache2/sites-enabled/000-default
	apache_reload=yes
	echo " done."
fi


if ls /etc/apache2/mods-enabled/dav* &> /dev/null; then
	echo -n "Removing webdav configuration ..."
	rm /etc/apache2/mods-enabled/dav*
	apache_reload=yes
	echo " done."
fi

if [ -e /etc/apache2/conf.d/websvn ]; then
	echo -n "Removing websvn configuration ..."
	rm /etc/apache2/conf.d/websvn
	apache_reload=yes
	echo " done."
fi

if grep -q ^"Include /etc/apache2/repositories" /etc/apache2/apache2.conf; then
	echo -n "Removing svn repositories configuration ..."
	cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.obsolete
	grep -v "# Include subversion repository configurations" /etc/apache2/apache2.conf > /var/tmp/apache2.conf
	grep -v ^"Include /etc/apache2/repositories" /var/tmp/apache2.conf > /etc/apache2/apache2.conf
	rm /var/tmp/apache2.conf
	apache_reload=yes
	echo " done."
fi

[ -n "$apache_reload" ] && /etc/init.d/apache2 reload

touch $DISABLED_INSECURE

