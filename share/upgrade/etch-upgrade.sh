echo
echo "##########################################################"
echo "# paedML Linux Distributions-Upgrade auf Debian 4.0 Etch #"
echo "##########################################################"
echo
echo "Startzeit: `date`"
echo

echo "Teste Internetverbindung:"
for i in ftp.de.debian.org ftp2.de.debian.org security.debian.org pkg.lml.support-netz.de; do
	echo -n "  * $i ... "
	ping -c2 $i &> /dev/null; RC="$?"
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
    echo "  * $i=$RET"
    if [ -z "$RET" ]; then
	echo "    Fatal! $i ist nicht gesetzt!"
	exit 1
    fi
    eval $i=$RET
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
echo -n " ${available}kb sind verfügbar ... "
if [ $available -ge 800000 ]; then
	echo "Ok!"
	echo
else
	echo "zu wenig! Sie benötigen mindestens 800000kb!"
	exit 1
fi

releasenr=rc1
releasename="paedML Linux 4.0"
codename=Griffelschbitzer
oldrelease="paedML Linux 3.0"

export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
export DEBCONF_TERSE=yes
export DEBCONF_NOWARNINGS=yes

# stopping internal firewall
/etc/init.d/linuxmuster-base stop
echo

# check if kde is installed
if dpkg -L kdebase &> /dev/null; then
	KDE=yes
	echo "KDE-Installation gefunden!"
	echo
fi

# unlocking sophomorix
if [ -e "$SOPHOMORIXLOCK" ]; then
	sophomorix-check --unlock
	echo
fi

# remove obsolete stuff
if [ ! -e "$DISABLED_INSECURE" ]; then
	echo "Entferne unsichere Webdienste ..."
	/usr/share/linuxmuster/upgrade/disable-insecure-services.sh --force
	echo
fi
if [ ! -e "$REMOVED_OGO" ]; then
	echo "Entferne OpenGroupware ..."
	/usr/share/linuxmuster/upgrade/remove-ogo.sh
	echo
fi

# backup nagios2 configuration
if [ -s /var/tmp/nagios2.tar.gz ]; then
	echo "Nagios2-Sicherung gefunden. Überspringe Backup!"
else
	echo "Sichere Nagios-Konfiguration ..."
	tar czf /var/tmp/nagios2.tar.gz /etc/nagios2
fi
# remove nagios2's apache2.conf
[ -e /etc/apache2/conf.d/nagios2.conf ] && rm /etc/apache2/conf.d/nagios2.conf
echo

# remove other stuff, some will be reinstalled again later
echo "Entferne Software-Pakete ..."
toremove="webmin moodle xlibmesa-glu cupsys cupsys-client cupsys-common libcupsimage2 \
          libcupsys2 libcupsys2-gnutls10 cups-pdf kronolith2 gollem1 php-file \
          php-net-ftp php-soap libapache2-mod-auth-pam libapache2-mod-auth-sys-group"
aptitude -y remove $toremove
aptitude -y purge nagios2 nagios2-common
[ -d /etc/nagios2 ] && rm -rf /etc/nagios2
update-rc.d -f webmin remove
echo

# update apt configuration
echo "Aktualisiere Paketquellen ..."
if [ -e /etc/apt/preferences ]; then
	backup_file /etc/apt/preferences
	rm /etc/apt/preferences*
fi
backup_file /etc/apt/apt.conf
cp $STATICTPLDIR/etc/apt/apt.conf /etc/apt
backup_file /etc/apt/sources.list
cp $STATICTPLDIR/etc/apt/sources.list.online /etc/apt/sources.list
aptitude update &> /dev/null
if ! aptitude update; then
	echo
	echo "Konnte Paketlisten nicht aktualisieren!"
	echo "Bitte beheben Sie den Fehler und starten Sie das Upgrade nochmal!"
	exit 1
fi
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
# update locales configuration
cp $STATICTPLDIR/etc/locale.gen /etc
cp $STATICTPLDIR/etc/environment /etc
echo

# first update apt-utils
echo "Aktualisiere apt ..."
aptitude -y install apt-utils tasksel debian-archive-keyring dpkg locales
# force apt to do ugly things during upgrade
echo 'DPkg::Options {"--force-confold";"--force-confdef";"--force-bad-verify";"--force-overwrite";};' > /etc/apt/apt.conf.d/99upgrade
echo

# get and install the paedml release key
echo "Lade paedML-Release-Schlüssel herunter ..."
cd ~
wget http://pkg.lml.support-netz.de/paedml-release.asc
echo
echo "Installiere paedML-Release-Schlüssel ..."
apt-key add paedml-release.asc
rm paedml-release.asc
echo

# update again with authentication enabled
echo "Aktualisiere Paketlisten ..."
aptitude update
echo

# download all needed packages
echo "Lade Software-Pakete herunter ..."
aptitude -y -d dist-upgrade
commontask=`tasksel --task-packages linuxmuster-common`
aptitude -y -d install $commontask
servertask=`tasksel --task-packages linuxmuster-server`
aptitude -y -d install $servertask
imagingtask=`tasksel --task-packages linuxmuster-imaging-$imaging`
aptitude -y -d install $imagingtask
aptitude -y -d install linux-image-server
if [ -n "$KDE" ]; then
	desktoptask=`tasksel --task-packages linuxmuster-desktop`
	aptitude -y -d install $desktoptask
fi
echo

# update slapd before server task is reinstalled
echo "Installiere OpenLDAP ..."
aptitude -y install slapd
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
aptitude -y install apache2-mpm-prefork nagios2 nagios2-common
echo

# enable apache2's ldap authentication
echo "Konfiguriere Apache2 fuer LDAP-Authentifizierung ..."
for i in ldap.load authnz_ldap.load; do
	[ -e "/etc/apache2/mods-enabled/$i" ] || ln -sf /etc/apache2/mods-available/$i /etc/apache2/mods-enabled/$i
done
echo

# perform dist-upgrade
echo "Fuehre dist-upgrade durch ..."
aptitude -y dist-upgrade
echo

# install common task
echo "Aktualisiere allgemeine Software-Pakete ..."
aptitude -y install $commontask
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
aptitude -y install $servertask
echo

# restore nagios2 configuration
echo "Stelle Nagios2-Konfiguration wieder her ..."
rm -rf /etc/nagios2
tar xzf /var/tmp/nagios2.tar.gz -C /
[ -e /etc/nagios2/resource.cfg ] || echo "# dummy config file created by paedML's etch-upgrade script" > /etc/nagios2/resource.cfg
sed -e "s/@@serverip@@/$serverip/
	s/@@basedn@@/$basedn/" $DYNTPLDIR/22_nagios/apache2.conf > /etc/nagios2/apache2.conf
cp /etc/nagios2/apache2.conf /var/lib/linuxmuster-nagios/config/nagios2
ln -sf /etc/nagios2/apache2.conf /etc/apache2/conf.d/nagios2.conf
echo

# enable apache2's and nagios2's init scripts again
echo "Aktiviere Apache2- und Nagios2-Startskripte ..."
for i in apache2 nagios2; do
	mv /etc/init.d/$i.etch-upgrade /etc/init.d/$i
done
echo

# install imaging task
echo "Aktualisiere Imaging-Software ..."
aptitude -y install $imagingtask
echo

# install kernel
echo "Installiere neuen Kernel ..."
aptitude -y install linux-image-server
echo

# install desktop task
if [ -n "$KDE" ]; then
	echo "Aktualisiere Desktop-Software ..."
	aptitude -y install $desktoptask
	update-rc.d -f xprint remove
	echo
fi

# to be sure all packages are upgraded
echo "Nochmal dist-upgrade ..."
aptitude -y dist-upgrade
echo

# we don't need that anymore
rm /etc/apt/apt.conf.d/99upgrade

# remove obsolete services
echo "Bereinige Runlevel ..."
for i in uml-utilities ntp-server postgresql-7.4; do
	update-rc.d -f $i remove
done
echo

# install german keymap
echo "Installiere deutsche Tastaturbelegung ..."
install-keymap /usr/share/keymaps/i386/qwertz/de-latin1-nodeadkeys.kmap.gz
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

# update LINBO's dhcpd.conf
if [ "$imaging" = "linbo" ]; then
	if ! grep -q ^next-server /etc/dhcp3/dhcpd.conf; then
		echo "Updating dhcp-server configuration ..."
		backup_file /etc/dhcp3/dhcpd.conf
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
fi

# add cyrus and postfix user to group ssl-cert
echo "Aktualisiere Systembenutzer ..."
for i in cyrus postfix; do
	addgroup $i ssl-cert
done
echo

# clean up old cron jobs
echo "Entferne alte cron jobs ..."
for i in kronolith2 php4; do
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

# finally update release information
if grep -q "$oldrelease" /etc/issue; then
	buildnr=`cat /etc/issue | cut -f9 -d" "`
	echo "$releasename / Release $releasenr / Build $buildnr / Codename $codename" > /etc/issue
	cp /etc/issue /etc/issue.net
	cat /etc/issue
	echo
fi


echo "Beendet um `date`!"
echo "Jetzt muss der Server neu gestartet werden!"
echo