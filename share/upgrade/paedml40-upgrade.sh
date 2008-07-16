echo
echo "##########################################################"
echo "# paedML Linux Distributions-Upgrade auf Debian 4.0 Etch #"
echo "##########################################################"
echo
echo "Startzeit: `date`"
echo

echo "Teste Internetverbindung:"
cd /tmp
for i in ftp.de.debian.org/debian/ ftp.de.debian.org/debian-volatile/ security.debian.org pkg.lml.support-netz.de/paedml40-updates/; do
	echo -n "  * $i ... "
	wget -q http://$i ; RC="$?"
	rm index.html &> /dev/null
	if [ "$RC" = "0" ]; then
		echo "Ok!"
	else
		echo "keine Verbindung!"
		exit 1
	fi
done
echo

echo "Pruefe Setup-Variablen:"
for i in servername domainname internmask internsubrange imaging; do
    RET=`echo get linuxmuster-base/$i | debconf-communicate`
    RET=${RET#[0-9] }
    esc_spec_chars "$RET"
    if [ -z "$RET" ]; then
	if [ "$i" = "imaging" ]; then
		echo "set linuxmuster-base/imaging rembo" | debconf-communicate
		RET=rembo
		if grep -q ^imaging $NETWORKSETTINGS; then
			sed -e 's/^imaging=.*/imaging=rembo/' -i $NETWORKSETTINGS
		else
			echo "imaging=rembo" >> $NETWORKSETTINGS
		fi
	else
		echo "    Fatal! $i ist nicht gesetzt!"
		exit 1
	fi
    fi
    eval $i=$RET
    echo "  * $i=$RET"
    unset RET
done
internsub=`echo $internsubrange | cut -f1 -d"-"`
internbc=`echo $internsubrange | cut -f2 -d"-"`
serverip=10.$internsub.1.1
echo "  * serverip=$serverip"
if ! validip "$serverip"; then
	echo "    Fatal! serverip ist ungueltig!"
	exit 1
fi
ipcopip=10.$internsub.1.254
echo "  * ipcopip=$ipcopip"
if ! validip "$ipcopip"; then
	echo "    Fatal! ipcopip ist ungueltig!"
	exit 1
fi
broadcast=10.$internbc.255.255
echo "  * broadcast=$broadcast"
internalnet=10.$internsub.0.0
echo "  * internalnet=$internalnet"
basedn="dc=`echo $domainname|sed 's/\./,dc=/g'`"
echo "  * basedn=$basedn"
echo 

echo "Pruefe freien Platz unter /var/cache/apt/archives:"
available=`LANG=C df -P /var/cache/apt/archives | grep -v Filesystem | awk '{ print $4 }'`
echo -n "  * ${available}kb sind verfügbar ... "
if [ $available -ge 800000 ]; then
	echo "Ok!"
	echo
else
	echo "zu wenig! Sie benötigen mindestens 800000kb!"
	exit 1
fi

releasenr=RC4
releasename="paedML Linux 4.0.0"
codename=Griffelschbitzer
oldrelease="paedML Linux 3.0"

nagiosbackupdir=$BACKUPDIR/nagios
mkdir -p $nagiosbackupdir
nagiosbackup=$nagiosbackupdir/paedml40-upgrade.tar.gz

export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
export DEBCONF_TERSE=yes
export DEBCONF_NOWARNINGS=yes

# check if kde is installed
if dpkg -L kdebase &> /dev/null; then
	KDE=yes
	echo "KDE-Installation gefunden."
	echo
fi

# tasks
echo "Prüfe Tasks:"
cd /usr/share/linuxmuster/tasks
echo -n "  * common ... "
if [ -s common ]; then
	commontask=`cat common`
	echo "Ok!"
else
	echo "Fehler!"
	exit 1
fi
echo -n "  * server ... "
if [ -s server ]; then
	servertask=`cat server`
	echo "Ok!"
else
	echo "Fehler!"
	exit 1
fi
echo -n "  * imaging-$imaging ... "
if [ -s "imaging-$imaging" ]; then
	imagingtask=`cat imaging-$imaging`
	echo "Ok!"
else
	echo "Fehler!"
	exit 1
fi
echo -n "  * linuxmuster-desktop ... "
if [ -s desktop ]; then
	desktoptask=`cat desktop`
	echo "Ok!"
else
	echo "Fehler!"
	exit 1
fi
echo

# stopping internal firewall
/etc/init.d/linuxmuster-base stop &> /dev/null


# unlocking sophomorix
if [ -e "$SOPHOMORIXLOCK" ]; then
	sophomorix-check --unlock
	echo
fi

# remove obsolete stuff
if [ ! -e "$DISABLED_INSECURE" ]; then
	echo -n "Entferne unsichere Webdienste."
	/usr/share/linuxmuster/upgrade/disable-insecure-services.sh --force 2>> $LOGFILE 1>> $LOGFILE
	echo
fi
if [ ! -e "$REMOVED_OGO" ]; then
	echo "Entferne OpenGroupware."
	/usr/share/linuxmuster/upgrade/remove-ogo.sh 2>> $LOGFILE 1>> $LOGFILE
	echo
fi


# restore old apt config and cancel
rollback(){
	local msg=$1
	cd /etc/apt
	for i in *.paedml30; do
		mv $i ${i%.paedml30}
	done
	[ -e sources.list.before-upgrade ] && mv sources.list.before-upgrade sources.list
	echo "$msg"
	aptitude update &> /dev/null
	aptitude update &> /dev/null
	exit 1
}


# update apt configuration and online sources
echo -n "Aktualisiere Paketlisten ... "
cd /etc/apt
for i in preferences apt.conf sources.list; do
	if [ -e "$i" -a ! -e "$i.paedml30" ]; then
		mv $i $i.paedml30
	elif [ -e "$i" ]; then
		rm  $i
	fi
done
cp /etc/apt/apt.conf.etch /etc/apt/apt.conf
cp /etc/apt/sources.list.etch /etc/apt/sources.list
cat /etc/apt/sources.list.d/paedml40.list >> /etc/apt/sources.list
cp /usr/share/linuxmuster/upgrade/preferences /etc/apt
# add cdrom source if given
#if [ -n "$cdrom" ]; then
#	echo "deb file:///cdrom/ etch contrib main non-free" > /etc/apt/sources.list.tmp
#	grep -v paedml40 /etc/apt/sources.list >> /etc/apt/sources.list.tmp
#	mv /etc/apt/sources.list.tmp /etc/apt/sources.list
#fi
rm /var/cache/apt/*.bin
aptitude update  &> /dev/null
if ! aptitude update 2>> $LOGFILE 1>> $LOGFILE; then
	rollback "Fehler!"
fi
echo "Ok!"
echo


# compute packages to download
if [ -n "$cdrom" ]; then
	if [ "$KDE" = "yes" ]; then
		packages=`cat /usr/share/linuxmuster/tasks/upgrade40-kde`
	else
		packages=""
	fi
else
	if [ "$KDE" = "yes" ]; then
		packages="`cat /usr/share/linuxmuster/tasks/upgrade40` `cat /usr/share/linuxmuster/tasks/upgrade40-kde`"
	else
		packages=`cat /usr/share/linuxmuster/tasks/upgrade40`
	fi	
fi


# download all needed packages
if [ -n "$packages" ]; then
	if [ ! -e /var/cache/linuxmuster/.paedml40-upgrade ]; then
		touch /var/cache/linuxmuster/.paedml40-upgrade
		apt-get clean
	fi
	echo "Lade Software-Pakete herunter ..."
	cd /var/cache/apt/archives
	aptitude -y download $packages
	echo
	echo -n "Überprüfe Downloads ... "
	for i in $packages; do
		if ! ls ${i}_*.deb &> /dev/null; then
			rollback "Paket $i nicht vorhanden!"
		fi
	done
	echo "Ok!"
fi


# get the paedml release key
if [ ! -e /cdrom/paedml-release.asc ]; then
	echo -n "Lade paedML-Release-Schlüssel herunter ... "
	cd /tmp
	if ! wget http://pkg.lml.support-netz.de/paedml-release.asc 2>> $LOGFILE 1>> $LOGFILE; then
		rollback "Fehler!"
	fi
	echo "Ok!"
	echo
fi


# temporary rollback to paedml30 apt
echo -n "Aktualisiere Paketlisten ... "
cd /etc/apt
for i in apt.conf preferences sources.list; do
	mv $i $i.paedml40 &> /dev/null
done
for i in *.paedml30; do
	cp $i ${i%.paedml30}
done
aptitude update &> /dev/null
aptitude update 2>> $LOGFILE 1>> $LOGFILE
apt-cache gencaches 2>> $LOGFILE 1>> $LOGFILE
echo "Ok!"


# backup nagios2 configuration
if [ -s "$nagiosbackup" ]; then
	echo "Nagios2-Sicherung gefunden. Überspringe Sicherung!"
else
	echo "Sichere Nagios-Konfiguration."
	tar czf $nagiosbackup /etc/nagios2 2>> $LOGFILE 1>> $LOGFILE
fi
# remove nagios2's apache2.conf
[ -e /etc/apache2/conf.d/nagios2.conf ] && rm /etc/apache2/conf.d/nagios2.conf
echo

# update locales configuration
cp $STATICTPLDIR/etc/locale.gen /etc
cp $STATICTPLDIR/etc/environment /etc
cp $STATICTPLDIR/etc/default/locale /etc/default


# remove other stuff, some will be reinstalled again later
echo -n "Entferne Software-Pakete ..."
toremove="webmin webmin-sshd moodle xlibmesa-glu cupsys cupsys-client cupsys-common libcupsimage2 \
          webalizer libcupsys2 libcupsys2-gnutls10 cups-pdf kronolith2 gollem1 php-file \
          php-net-ftp php-soap libapache2-mod-auth-pam libapache2-mod-auth-sys-group hpijs \
          ntp ntp-simple ntp-server linuxmuster-tasks nagios2 nagios2-common"
aptitude -y remove $toremove
# check if all is removed
for i in $toremove; do
	if dpkg -s $i 2> /dev/null | grep -q ^"Status: install ok"; then
		aptitude -y remove $i 2> /dev/null
	fi
done
killall ntpd &> /dev/null
aptitude -y purge nagios2 nagios2-common
[ -d /etc/nagios2 ] && rm -rf /etc/nagios2
echo


echo "Führe Konfigurationsanpassungen durch ..."
# remove obsolete amavisd.conf
if [ -e /etc/amavis/amavisd.conf ]; then
	backup_file /etc/amavis/amavisd.conf
	/etc/init.d/amavis stop
	rm /etc/amavis/amavisd.conf
fi
# move gollem1 config dir to gollem
[ -d /etc/horde/gollem1 ] && mv /etc/horde/gollem1 /etc/horde/gollem
# tweaking cupsys
[ -d /usr/lib/cups/backend-available ] || mkdir -p /usr/lib/cups/backend-available
touch /usr/lib/cups/backend-available/dnssd
echo


if [ -n "$cdrom" ]; then
	echo "Kopiere Software-Pakete in den Cache ..."
	find /cdrom/pool/ -name \*.deb -exec cp '{}' /var/cache/apt/archives \;
	echo
fi


# back to paedml40 apt
echo -n "Aktualisiere Paketlisten ... "
cd /etc/apt
for i in *.paedml40; do
	cp $i ${i%.paedml40}
done
# remove online sources temporarily
#if [ -n "$cdrom" ]; then
#	grep -v "deb http" /etc/apt/sources.list > /etc/apt/sources.list.tmp
#	mv /etc/apt/sources.list.tmp /etc/apt/sources.list
#fi
aptitude update &> /dev/null
aptitude update 2>> $LOGFILE 1>> $LOGFILE
apt-cache gencaches 2>> $LOGFILE 1>> $LOGFILE
echo "Ok!"


reinstall() {
	local plist="$1"
	for i in $plist; do
		status=`dpkg -s $i | grep ^Status`
		if ! echo "$status" | grep -q "install ok installed"; then
			echo "Fehler bei Paket $i, versuche es erneut ..."
			echo -e "Ja\nJa\n" | aptitude -y install $i
		fi
	done
}

# first update apt-utils
echo "Aktualisiere apt ..."
aptitude -y install apt-utils tasksel debian-archive-keyring dpkg locales
# force apt to do ugly things during upgrade
echo 'DPkg::Options {"--force-confold";"--force-confdef";"--force-bad-verify";"--force-overwrite";};' > /etc/apt/apt.conf.d/99upgrade
reinstall "apt-utils tasksel debian-archive-keyring dpkg locales"
echo


# update again with authentication enabled
echo -n "Aktualisiere Paketlisten ..."
aptitude update 2>> $LOGFILE 1>> $LOGFILE
echo


# update slapd and old postgresql before server task is reinstalled
echo "Installiere OpenLDAP ..."
echo -e "Ja\nJa\n" | aptitude -y install slapd postgresql
reinstall "slapd postgresql"
echo


echo "Entferne obsolet gewordene Apache2-Module ..."
# remove obsolete apache2 modules
for i in php4.conf php4.load auth_pam.load auth_sys_group.load; do
	[ -e "/etc/apache2/mods-enabled/$i" ] && rm /etc/apache2/mods-enabled/$i
	[ -e "/etc/apache2/mods-available/$i" ] && rm /etc/apache2/mods-available/$i
done
echo


# update apache2 and install nagios2 before server task is reinstalled
echo "Installiere Apache2 und Nagios2 ..."
echo -e "Ja\nJa\n" | aptitude -y install apache2-mpm-prefork nagios2 nagios2-common
reinstall "apache2-mpm-prefork nagios2 nagios2-common"
echo


# enable apache2's ldap authentication
echo "Konfiguriere Apache2 fuer LDAP-Authentifizierung ..."
for i in ldap.load authnz_ldap.load; do
	[ -e "/etc/apache2/mods-enabled/$i" ] || ln -sf /etc/apache2/mods-available/$i /etc/apache2/mods-enabled/$i
done
echo


# perform dist-upgrade
echo "Fuehre dist-upgrade durch ..."
echo -e "Ja\nJa\n" | aptitude -y dist-upgrade
echo


# install common task
echo "Aktualisiere allgemeine Software-Pakete ..."
echo -e "Ja\nJa\n" | aptitude -y install $commontask
reinstall "$commontask"
echo


# disable apache2's and nagios2's init scripts
echo "Deaktiviere Apache2- und Nagios2-Startskripte ..."
for i in apache2 nagios2; do
	[ -e "/etc/init.d/$i.etch-upgrade" ] || mv /etc/init.d/$i /etc/init.d/$i.etch-upgrade
	echo '#!/bin/sh' > /etc/init.d/$i
	echo 'exit 0' >> /etc/init.d/$i
	chmod 755 /etc/init.d/$i
done


# install server task
echo "Aktualisiere Server bezogene Software-Pakete ..."
echo -e "Ja\nJa\n" | aptitude -y install $servertask
reinstall "$servertask"
echo


# install imaging task
echo "Aktualisiere Imaging-Software ..."
echo -e "Ja\nJa\n" | aptitude -y install $imagingtask
reinstall "$imagingtask"
echo


# install the paedml release key
echo -n "Installiere paedML-Release-Schlüssel ... "
for i in /cdrom/paedml-release.asc /tmp/paedml-release.asc; do
	if [ -e "$i" ]; then
		apt-key add $i
		break
	fi
done
echo


# restore correct apt configuration
cp /etc/apt/apt.conf.etch /etc/apt/apt.conf
cp /etc/apt/sources.list.etch /etc/apt/sources.list
rm /etc/apt/*.paedml40
rm /etc/apt/preferences
aptitude update 2>> $LOGFILE 1>> $LOGFILE


# install desktop task
if [ -n "$KDE" ]; then
	echo "Aktualisiere Desktop-Software ..."
	echo -e "Ja\nJa\n" | aptitude -y install $desktoptask
	reinstall "$desktoptask"
	echo
	checkpackages="$commontask $servertask $imagingtask $desktoptask"
else
	checkpackages="$commontask $servertask $imagingtask"
fi


# finally do a dist-upgrade again
echo "Fuehre dist-upgrade durch ..."
echo -e "Ja\nJa\n" | aptitude -y dist-upgrade
echo


# check if all packages are installed
RC=0 ; failed_packages=""
echo "Überprüfe installierte Pakete:"
for i in $checkpackages; do
	unset status
	status=`dpkg -s $i | grep ^Status`
	if echo "$status" | grep -q "install ok installed"; then
		echo "  * $i: Ok"
	else
		echo "  * $i: $status"
		RC=1
		failed_packages="$failed_packages $i"
	fi
done
echo


# we don't need that anymore
rm /etc/apt/apt.conf.d/99upgrade

# remove obsolete services
echo "Bereinige Runlevel ..."
for i in uml-utilities ntp-server postgresql-7.4 xprint; do
	[ -e /etc/init.d/$i ] && update-rc.d -f $i remove
done
echo

# install german keymap
echo "Installiere deutsche Tastaturbelegung ..."
install-keymap /usr/share/keymaps/i386/qwertz/de-latin1-nodeadkeys.kmap.gz
kmapmd5=`md5sum /etc/console-setup/boottime.kmap.gz | awk '{ print $1 }' 2> /dev/null`
sed -e "s/^BOOTTIME_KMAP_MD5=.*/BOOTTIME_KMAP_MD5=\"$kmapmd5\"/" $STATICTPLDIR/etc/default/console-setup > /etc/default/console-setup
if ! grep -q "export LANG" /etc/profile; then
	backup_file /etc/profile
	sed -e "/^export PATH/a\
export LANG" -i /etc/profile
fi
echo

# unlock sophomorix
if [ -e "$SOPHOMORIXLOCK" ]; then
	sophomorix-check --unlock
	echo
fi

# update horde's and moodle's apache.conf according to php5
echo "Aktualisiere Apache-Konfiguration ..."
for i in /etc/horde/apache.conf /etc/moodle/apache.conf; do
	if ! grep -q "IfModule mod_php5.c" $i; then
		backup_file $i
		cp $STATICTPLDIR$i $i
	fi
done
# enable default site
ln -sf ../sites-available/default /etc/apache2/sites-enabled/000-default
echo

# webmin
echo "Aktualisiere Webmin-Konfiguration ..."
for i in config miniserv.conf miniserv.users webmin.acl; do
	backup_file /etc/webmin/$i
	cp $STATICTPLDIR/etc/webmin/config /etc/webmin
	sed -e "s/^host=.*/host=$servername/" $STATICTPLDIR/etc/webmin/miniserv.conf > /etc/webmin/miniserv.conf
	for i in /etc/webmin/miniserv.users /etc/webmin/webmin.acl; do
		sedstr=`grep ^root: $STATICTPLDIR$i`
		sed -e "s/^root:.*/$sedstr/" -i $i
	done
	[ -d /var/log/webmin ] || mkdir -p /var/log/webmin
done
echo

# freshclam as daemon
echo "Aktualisiere Clamav-Konfiguration ..."
cp $STATICTPLDIR/etc/clamav/freshclam.conf /etc/clamav
update-rc.d clamav-freshclam defaults
rm /etc/network/if-up.d/clamav-freshclam* &> /dev/null
rm /etc/network/if-down.d/clamav-freshclam* &> /dev/null
rm /etc/cron.d/clamav-freshclam* &> /dev/null

# update LINBO's dhcpd.conf
if [ "$imaging" = "linbo" ]; then
	if ! grep -q ^next-server /etc/dhcp3/dhcpd.conf; then
		echo "Updating dhcp-server configuration for LINBO ..."
		backup_file /etc/dhcp3/dhcpd.conf
		dhcp_backup=yes
		sed -e "s/@@servername@@/${servername}/g
			s/@@domainname@@/${domainname}/g
			s/@@serverip@@/${serverip}/g
			s/@@ipcopip@@/${ipcopip}/g
			s/@@broadcast@@/${broadcast}/g
			s/@@internalnet@@/${internalnet}/g
			s/@@internsub@@/${internsub}/g
			s/@@internmask@@/${internmask}/g" $DYNTPLDIR/03_dhcp3-server/dhcpd.conf.linbo > /etc/dhcp3/dhcpd.conf
		echo
	fi
	if ! grep -q "$LINBODIR" /etc/default/atftpd; then
		echo "Updating atftpd configuration ..."
		cp $STATICTPLDIR/etc/default/atftpd /etc/default
	fi
		update-rc.d linbo-multicast defaults
fi

# deny client-updates
if grep -q ^"ignore client-updates" /etc/dhcp3/dhcpd.conf; then
	echo "Updating dhcp-server configuration to deny client updates ..."
	[ -z "$dhcp_backup" ] && backup_file /etc/dhcp3/dhcpd.conf
	sed -e "s/^ignore client-updates/deny client-updates/" -i /etc/dhcp3/dhcpd.conf
fi

# add cyrus and postfix user to group ssl-cert
echo "Aktualisiere Systembenutzer ..."
for i in cyrus postfix openldap; do
	addgroup $i ssl-cert
done
chown root:ssl-cert /etc/ssl/private -R
echo

# clean up old cron jobs
echo "Entferne alte cron jobs ..."
for i in kronolith2 php4 clamav-freshclam; do
	[ -e "/etc/cron.d/$i" ] && rm /etc/cron.d/$i
done
ls /etc/cron.d/*.dpkg-old &> /dev/null && rm /etc/cron.d/*.dpkg-old
echo

# tweak udev
echo "Deaktivere udev net-generator-rules ..."
cp -a $STATICTPLDIR/etc/udev /etc
echo

# deactivate avahi-daemon
if [ -e /etc/default/avahi-daemon ]; then
	echo "Deaktiviere avahi-daemon ..."
	sed -e 's/^AVAHI_DAEMON_START=.*/AVAHI_DAEMON_START=0/' -i /etc/default/avahi-daemon
	echo
fi

# create pam_ldap.secret link
ln -sf ldap.secret /etc/pam_ldap.secret


# enable apache2's and nagios2's init scripts again
echo "Aktiviere Apache2- und Nagios2-Startskripte ..."
for i in apache2 nagios2; do
	mv /etc/init.d/$i.etch-upgrade /etc/init.d/$i
done
echo


# repairing apache's index page 
[ -e /var/www/apache2-default/index.html ] && backup_file /var/www/apache2-default/index.html
sed -e "s/@@servername@@/$servername/g
	s/@@domainname@@/$domainname/g" /var/www/apache2-default/index.html.tpl > /var/www/apache2-default/index.html

# php settings
[ -e /etc/php5/conf.d/paedml.ini ] || cp $STATICTPLDIR/etc/php5/conf.d/paedml.ini /etc/php5/conf.d


# restore nagios2 configuration
echo "Stelle Nagios2-Konfiguration wieder her ..."
rm -rf /etc/nagios2
tar xzf $nagiosbackup -C /
[ -e /etc/nagios2/resource.cfg ] || echo "# dummy config file created by paedML's etch-upgrade script" > /etc/nagios2/resource.cfg
backup_file /etc/nagios2/apache2.conf
sed -e "s/@@serverip@@/$serverip/
	s/@@basedn@@/$basedn/" $DYNTPLDIR/22_nagios/apache2.conf > /etc/nagios2/apache2.conf
backup_file /etc/linuxmuster/nagios.conf
sed -e 's/PaedML 3.0/paedML 4.0.0/g' -i /etc/linuxmuster/nagios.conf
backup_file /etc/nagios2/conf.d/linuxmuster_main.cfg
sed -e 's/PaedML 3.0/paedML 4.0.0/g' -i /etc/nagios2/conf.d/linuxmuster_main.cfg
ln -sf /etc/nagios2/apache2.conf /etc/apache2/conf.d/nagios2.conf
linuxmuster-nagios-setup
echo


# openntpd
echo "Konfiguriere openntpd ..."
backup_file /etc/openntpd/ntpd.conf
sed -e "s/@@serverip@@/$serverip/" $DYNTPLDIR/99_start-services/ntpd.conf > /etc/openntpd/ntpd.conf


# moodle
if [ -e /etc/moodle/config.php ]; then
	if ! grep -q "\$CFG->wwwroot = '/moodle';" /etc/moodle/config.php; then
		cp /etc/moodle/config.php /etc/moodle/config.php.paedml30
		sed -e "s/\$CFG->wwwroot =.*/\$CFG->wwwroot = \'\/moodle\';/g" -i /etc/moodle/config.php
	fi
fi
if [ -d /usr/share/moodle ]; then
	[ -L /usr/share/moodle/moodle ] || ln -s . /usr/share/moodle/moodle
fi


# adding tls support to slapd.conf
slapdtpl=/usr/share/sophomorix/config-templates/ldap/slapd-standalone.conf.template
if ! grep -q ^TLS $slapdtpl || ! grep -q misc.schema $slapdtpl; then
	cp $slapdtpl $slapdtpl.dpkg-old
	cp $STATICTPLDIR$slapdtpl $slapdtpl
fi
[ -e /etc/ldap/slapd.conf.custom ] || cp $STATICTPLDIR/etc/ldap/slapd.conf.custom /etc/ldap
if ! grep -q ^TLS /etc/ldap/slapd.conf || ! grep -q misc.schema $slapdtpl; then
	echo "Updateing openldap configuration ..."
	backup_file /etc/ldap/slapd.conf
	backup_file /etc/default/slapd
	rootpw=`grep ^rootpw /etc/ldap/slapd.conf | awk '{ print $2 }'`
	sed -e "s/@@message1@@/${message1}/
		s/@@message2@@/${message2}/
		s/@@message3@@/${message3}/
		s/@@basedn@@/${basedn}/g
		s/@@ldappassword@@/${rootpw}/g" $slapdtpl > /etc/ldap/slapd.conf
	cp $STATICTPLDIR/etc/default/slapd /etc/default
fi


# finally update release information
buildnr=`cat /etc/issue | cut -f9 -d" "`
echo "$releasename / Release $releasenr / Build $buildnr / Codename $codename" > /etc/issue
cp /etc/issue /etc/issue.net
cat /etc/issue
echo

echo "Jetzt muss der Server neu gestartet werden!"
[ -n "$cdrom" ] && echo "Führen Sie nach dem Neustart eine Systemaktualisierung durch!"

if [ "$RC" != "0" ]; then
	echo
	echo "Fehler: Es konnten nicht alle Softwarepakete korrekt aktualisiert werden!"
	echo "Die betroffenen Pakete sind:"
	strip_spaces "$failed_packages"
	echo "$RET"
	echo
	echo "Schauen Sie in /var/log/linuxmuster/paedml40-upgrade.log nach und beheben"
	echo "Sie den Fehler oder kontaktieren den Support."
fi

echo
echo "Beendet um `date`!"
