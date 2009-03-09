#
# upgrade paedML 3.0 to 4.0
# main script
#
# 09.03.2009
# 
# Thomas Schmitt
# <schmitt@lmz-bw.de>
# GPL V3
#

PKGCACHE=/var/cache/apt/archives
KDESPACE=300000


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


echo "Aktualisiere Paketlisten ..."
aptitude update &> /dev/null
aptitude update 2>> $LOGFILE 1>> $LOGFILE
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
echo "Pruefe Tasks:"
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


# backup nagios2 configuration
if [ -s "$nagiosbackup" ]; then
	echo "Nagios2-Sicherung gefunden. ueberspringe Sicherung!"
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


# vmware related
[ -e /usr/X11R6/bin/X.BeforeVMwareToolsInstall ] && rm /usr/X11R6/bin/X.BeforeVMwareToolsInstall


# kill ntpd if not stopped
killall ntpd &> /dev/null


# purge nagios
aptitude -y purge nagios2 nagios2-common
[ -d /etc/nagios2 ] && rm -rf /etc/nagios2
echo


# several configuration issues
echo "Fuehre Konfigurationsanpassungen durch ..."
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


# backup apt config
cd /etc/apt
for i in preferences apt.conf sources.list; do
	if [ -e "$i" -a ! -e "$i.paedml30" ]; then
		mv $i $i.paedml30
	elif [ -e "$i" ]; then
		rm  $i
	fi
done

# update apt config for cdrom use without online sources
cp /etc/apt/apt.conf.etch /etc/apt/apt.conf
echo "deb file:///cdrom etch main contrib non-free" > /etc/apt/sources.list
echo >> /etc/apt/sources.list
cat /etc/apt/sources.list.etch >> /etc/apt/sources.list

# remove bin files from cache
rm /var/cache/apt/*.bin

# update package lists
echo -n "Aktualisiere Paketlisten ... "
aptitude update  &> /dev/null
if ! aptitude update 2>> $LOGFILE 1>> $LOGFILE; then
	rollback "Fehler!"
fi
echo "Ok!"
echo


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
echo 'APT::Get::AllowUnauthenticated "true";' >> /etc/apt/apt.conf.d/99upgrade
reinstall "apt-utils tasksel debian-archive-keyring dpkg locales"
echo
echo "Aktualisiere Paketlisten ... "
aptitude update &> /dev/null
aptitude update 2>> $LOGFILE 1>> $LOGFILE
echo


# update slapd, postgresql etc. before server task is reinstalled
echo "Installiere OpenLDAP, Postgresql, Cyrus, Postfix ..."
echo -e "Ja\nJa\n" | aptitude -y install slapd postgresql cyrus-common-2.2 postfix
reinstall "slapd postgresql cyrus-common-2.2 postfix"
echo


# add cyrus and postfix user to group ssl-cert
echo "Aktualisiere Systembenutzer ..."
for i in cyrus postfix openldap; do
	addgroup $i ssl-cert
done
chown root:ssl-cert /etc/ssl/private -R
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


# install nonfree or free components
basetpl=linuxmuster-schulkonsole-templates-base
paedmltpl=linuxmuster-schulkonsole-templates-paedml
if [ -n "$(aptitude search $paedmltpl)" ]; then
	# check if base-template is installed and remove it
	if dpkg -L $basetpl &> /dev/null; then
		echo "Deinstalliere $basetpl ..."
		dpkg -r --force-all $basetpl &> /dev/null
	fi
	echo "Installiere $paedmltpl ..."
	echo -e "Ja\nJa\n" | aptitude -y install $paedmltpl
	reinstall $paedmltpl
	checkpackages=$paedmltpl
else
	echo -e "Ja\nJa\n" | aptitude -y install $basetpl
	reinstall $basetpl
	checkpackages=$basetpl
fi
indexpage=linuxmuster-indexpage
if [ -n "$(aptitude search $indexpage)" ]; then
	echo "Installiere $indexpage ..."
	echo -e "Ja\nJa\n" | aptitude -y install $indexpage
	reinstall $indexpage
	checkpackages="$checkpackages $indexpage"
fi


# install the paedml release key
echo -n "Installiere paedML-Release-Schluessel ... "
apt-key add /cdrom/paedml-release.asc
echo


# remove cdrom source from sources.list
echo "Aktualisiere APT-Konfiguration ..."
cp /etc/apt/sources.list.etch /etc/apt/sources.list
rm -f /etc/apt/*.paedml40
aptitude update &> /dev/null
aptitude update 2>> $LOGFILE 1>> $LOGFILE
echo

# install desktop task
if [ -n "$KDE" ]; then
	if check_free_space $PKGCACHE $KDESPACE; then
		echo "Aktualisiere Desktop-Software ..."
		echo -e "Ja\nJa\n" | aptitude -y install $desktoptask
		reinstall "$desktoptask"
		echo
	else
		echo "Ueberspringe Desktop-Aktualisierung!"
	fi
	checkpackages="$commontask $servertask $checkpackages $imagingtask $desktoptask"
else
	checkpackages="$commontask $servertask $checkpackages $imagingtask"
fi


# finally do a dist-upgrade again
echo "Fuehre dist-upgrade durch ..."
echo -e "Ja\nJa\n" | aptitude -y dist-upgrade
echo


# check if all packages are installed
RC=0 ; failed_packages=""
echo "ueberpruefe installierte Pakete:"
for i in $checkpackages; do
	if [ "$i" = "rembo" -o "$i" = "myshn" ]; then
		[ "$imaging" = "rembo" ] || continue
	fi
	if [ "$i" = "linuxmuster-linbo" ]; then
		[ "$imaging" = "linbo" ] || continue
	fi
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


# restore apache's default index.html
indexhtml=/var/www/apache2-default/index.html
if grep -q "paedML" $indexhtml; then
	echo -n "<html><body><h1>It works!</h1></body></html>" > $indexhtml
fi


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


# fix running atftpd if imaging=rembo
if [ "$imaging" = "rembo" -a -e /etc/default/atftpd ]; then
	echo "Deactivating atftpd because imaging is rembo ..."
	sed -e 's|^USE_INETD=.*|USE_INETD=true|' -i /etc/default/atftpd
fi


# deny client-updates
if grep -q ^"ignore client-updates" /etc/dhcp3/dhcpd.conf; then
	echo "Updating dhcp-server configuration to deny client updates ..."
	[ -z "$dhcp_backup" ] && backup_file /etc/dhcp3/dhcpd.conf
	sed -e "s/^ignore client-updates/deny client-updates/" -i /etc/dhcp3/dhcpd.conf
fi

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

# php settings
[ -e /etc/php5/conf.d/paedml.ini ] || cp $STATICTPLDIR/etc/php5/conf.d/paedml.ini /etc/php5/conf.d


# restore nagios2 configuration
echo "Stelle Nagios2-Konfiguration wieder her ..."
# test
#rm -rf /etc/nagios2
tar xzf $nagiosbackup -C /
# move probably obsolete config files out of the way
mkdir -p /etc/nagios2/conf.d_backup
for i in /etc/nagios2/conf.d/*.cfg; do
	echo $i | grep -q linuxmuster || mv $i /etc/nagios2/conf.d_backup
done
[ -e /etc/nagios2/resource.cfg ] || echo "# dummy config file created by paedML's etch-upgrade script" > /etc/nagios2/resource.cfg
backup_file /etc/nagios2/apache2.conf
sed -e "s/@@serverip@@/$serverip/
	s/@@basedn@@/$basedn/" $DYNTPLDIR/22_nagios/apache2.conf > /etc/nagios2/apache2.conf
backup_file /etc/linuxmuster/nagios.conf
sed -e "s/PaedML 3.0/$(getdistname) $DISTMAJORVERSION/g" -i /etc/linuxmuster/nagios.conf
backup_file /etc/nagios2/conf.d/linuxmuster_main.cfg
sed -e "s/PaedML 3.0/$(getdistname) $DISTMAJORVERSION/g" -i /etc/nagios2/conf.d/linuxmuster_main.cfg
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


# reparing ipcop's timezone
[ "$(LANG=C file -b /etc/timezone)" = "ASCII text" ] && timezone="$(cat /etc/timezone)"
if [ -n "$timezone" ]; then
	if exec_ipcop /bin/ls /usr/share/zoneinfo/posix/$timezone; then
		echo "Repariere IPCop Zeitzone: $timezone ..."
		exec_ipcop /bin/rm /etc/localtime
		exec_ipcop /bin/cp /usr/share/zoneinfo/posix/$timezone /etc/localtime
		exec_ipcop /usr/local/bin/restartntpd
	fi
fi

# update release information
echo "$(getdistname) $DISTFULLVERSION / Codename $CODENAME" > /etc/issue
cp /etc/issue /etc/issue.net
cat /etc/issue
echo

# update kdm greetstring
if [ -e /etc/kde/kdm/kdmrc ]; then
	greetstr="`cat /etc/issue` auf %n"
	sed -e "s|^GreetString=.*|GreetString=$greetstr|" -i /etc/kde/kdm/kdmrc 
fi

# finally start necessary services and do a reconfigure to fix things which are not yet fixed
ps -e | grep -q slapd || /etc/init.d/slapd start
ps -e | grep -q smbd || /etc/init.d/samba start
ps ax | grep postgresql/8.1 | grep -qv grep || /etc/init.d/postgresql-8.1 start
dpkg-reconfigure linuxmuster-base
echo

echo "Jetzt muss der Server neu gestartet werden!"
#[ -n "$cdrom" ] && echo "Fuehren Sie nach dem Neustart eine Systemaktualisierung durch!"

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

