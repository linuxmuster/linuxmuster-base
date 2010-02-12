#
# paedML upgrade from 4.0 to 4.1
# main script
# 
# Thomas Schmitt
# <schmitt@lmz-bw.de>
# GPL V3
#
# 2010-02-03 11:31:40 
#

# environment variables
. /usr/share/linuxmuster/config/dist.conf || exit 1
. $HELPERFUNCTIONS || exit 1
DHCPDYNTPLDIR=$DYNTPLDIR/03_dhcp3-server
BINDDYNTPLDIR=$DYNTPLDIR/04_bind9
LDAPDYNTPLDIR=$DYNTPLDIR/15_ldap
SOPHOPKGS=`dpkg -l | grep sophomorix | grep ^i | awk '{ print $2 }'`
PKGSTOREMOVE="linux-image-server mindi mondo $SOPHOPKGS="
PKGREPOS="ftp.de.debian.org/debian/ \
          ftp.de.debian.org/debian-volatile/ \
          security.debian.org \
          pkg.lml.support-netz.de/paedml41-updates/"

# messages for config file headers
message1="##### Do not change this file! It will be overwritten!"
message2="##### This configuration file was automatically created by paedml41-upgrade!"
message3="##### Last Modification: `date`"

echo
echo "####################################################################"
echo "# paedML/openML Linux Distributions-Upgrade auf Debian 5.0.3 Lenny #"
echo "####################################################################"
echo
echo "Startzeit: `date`"
echo

echo "Teste Internetverbindung:"
cd /tmp
for i in $PKGREPOS; do
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
for i in servername domainname internmask internsubrange imaging sambasid workgroup; do
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
echo "  * sambasid=$sambasid"
echo "  * workgroup=$workgroup"

#######
# apt #
#######

cp /etc/apt/sources.list /etc/apt/sources.list.lenny-upgrade
mv /etc/apt/apt.conf /etc/apt/apt.conf.lenny-upgrade
cp $STATICTPLDIR/etc/apt/sources.list /etc/apt
rm -f /etc/apt/sources.list.d/paedml40.list

# force apt to do an unattended upgrade
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
export DEBCONF_TERSE=yes
export DEBCONF_NOWARNINGS=yes
echo 'DPkg::Options {"--force-confold";"--force-confdef";"--force-bad-verify";"--force-overwrite";};' > /etc/apt/apt.conf.d/99upgrade
echo 'APT::Get::AllowUnauthenticated "true";' >> /etc/apt/apt.conf.d/99upgrade
echo
echo "Aktualisiere Paketlisten ..."
aptitude update

#################
# configuration #
#################

echo
echo "Aktualisiere Konfiguration ..."

# ipcop: no more skas kernel
CONF=/etc/default/linuxmuster-ipcop
cp $CONF $CONF.lenny-upgrade
sed -e 's|^SKAS_KERNEL=.*|SKAS_KERNEL=no|' -i $CONF

# uml utilities
echo " uml-utilities ..."
CONF=/etc/default/uml-utilities
cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF

# slapd
echo " slapd ..."
for i in /etc/ldap/slapd.conf /etc/default/slapd /var/lib/ldap/DB_CONFIG; do
 cp $i $i.lenny-upgrade
 if stringinstring slapd.conf $i; then
  ldapadminpw=`grep ^rootpw $i | awk '{ print $2 }'`
  sed -e "s/@@message1@@/${message1}/
	         s/@@message2@@/${message2}/
	         s/@@message3@@/${message3}/
	         s/@@basedn@@/${basedn}/g
	         s/@@ldappassword@@/${ldapadminpw}/" $LDAPDYNTPLDIR/`basename $i` > $i
 else
  cp $STATICTPLDIR/$i $i
 fi
done
chown root:openldap /etc/ldap/slapd.conf*
chmod 640 /etc/ldap/slapd.conf*
chown openldap:openldap /var/lib/ldap -R
chmod 700 /var/lib/ldap
chmod 600 /var/lib/ldap/*

# smbldap-tools
echo " smbldap-tools ..."
CONF=/etc/smbldap-tools/smbldap.conf
cp $CONF $CONF.lenny-upgrade
sed -e "s/@@sambasid@@/${sambasid}/
	       s/@@workgroup@@/${workgroup}/
	       s/@@basedn@@/${basedn}/" $LDAPDYNTPLDIR/`basename $CONF` > $CONF
CONF=/etc/smbldap-tools/smbldap_bind.conf
cp $CONF $CONF.lenny-upgrade
sed -e "s/@@message1@@/${message1}/
	       s/@@message2@@/${message2}/
	       s/@@message3@@/${message3}/
	       s/@@basedn@@/${basedn}/g
	       s/@@ldappassword@@/${ldapadminpw}/g" $LDAPDYNTPLDIR/`basename $CONF` > $CONF
chmod 600 ${CONF}*

# apache2
echo " apache2 ..."
CONF=/etc/apache2/apache2.conf
cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF

# saslauthd
echo " saslauthd ..."
CONF=/etc/default/saslauthd
cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF

# dhcp
echo " dhcp ..."
CONF=/etc/dhcp3/dhcpd.conf
cp $CONF $CONF.lenny-upgrade
sed -e "s/@@servername@@/${servername}/g
        s/@@domainname@@/${domainname}/g
        s/@@serverip@@/${serverip}/g
        s/@@ipcopip@@/${ipcopip}/g
        s/@@broadcast@@/${broadcast}/g
        s/@@internmask@@/${internmask}/g
        s/@@internsub@@/${internsub}/g
        s/@@internalnet@@/${internalnet}/g" $DHCPDYNTPLDIR/`basename $CONF`.$imaging > $CONF

# bind9
echo " bind9 ..."
for i in db.10 db.linuxmuster named.conf.linuxmuster; do
 CONF=/etc/bind/$i
 cp $CONF $CONF.lenny-upgrade
 sed -e "s/@@servername@@/${servername}/g
         s/@@domainname@@/${domainname}/g
         s/@@serverip@@/${serverip}/g
         s/@@ipcopip@@/${ipcopip}/g
         s/@@internsub@@/${internsub}/g" $BINDDYNTPLDIR/$i > $CONF
done
rm -f /etc/bind/*.jnl

# php5.ini
echo " php5 ..."
CONF=/etc/php5/conf.d/paedml.ini
cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF

# mindi
echo " mindi ..."
CONF=/etc/mindi/mindi.conf
cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF

# fixing backup.conf
echo " backup ..."
CONF=/etc/linuxmuster/backup.conf
cp $CONF $CONF.lenny-upgrade
sed -e 's|postgresql-8.1|postgresql-8.3|g
        s|nagios2|nagios3|g' -i $CONF

################
# dist-upgrade #
################

echo
echo "DIST-UPGRADE ..."
# first remove stuff
echo -e "\n\n" | aptitude -y remove $PKGSTOREMOVE
echo -e "\n\n" | aptitude -y install apt-utils tasksel debian-archive-keyring dpkg locales
aptitude update
echo -e "\n\n" | aptitude -y install postgresql postgresql-8.3 postgresql-client-8.3
# handle postgresql update
if ps ax | grep -q postgresql/8.3; then
 /etc/init.d/postgresql-8.3 stop
 pg_dropcluster 8.3 main
fi
if ! ps ax | grep -q postgresql/8.1; then
 /etc/init.d/postgresql-8.1 start
fi
pg_upgradecluster 8.1 main
/etc/init.d/postgresql-8.1 stop
update-rc.d -f postgresql-7.4 remove
update-rc.d -f postgresql-8.1 remove
# first safe-upgrade
echo -e "\n\n" | aptitude -y safe-upgrade
# then dist-upgrade
echo -e "\n\n" | aptitude -y dist-upgrade
echo -e "\n\n" | aptitude -y dist-upgrade
echo -e "\n\n" | aptitude -y purge avahi-daemon
# install tasks to be sure to have all necessary pkgs installed
linuxmuster-task --unattended --install=common
linuxmuster-task --unattended --install=server
linuxmuster-task --unattended --install=imaging-$imaging
aptitude -y install $SOPHOPKGS
# handle slapd upgrade
/etc/init.d/slapd stop
rm -rf /etc/ldap/slapd.d
mkdir -p /etc/ldap/slapd.d
slaptest -f /etc/ldap/slapd.conf -F /etc/ldap/slapd.d
chown -R openldap:openldap /etc/ldap/slapd.d
/etc/init.d/slapd start

##########
# horde3 #
##########

$DATADIR/upgrade/horde3-upgrade.sh

# webmin
CONF=/etc/webmin/config
cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF
/etc/init.d/webmin restart

# remove stuff only needed for upgrade
rm -f /etc/apt/apt.conf.d/99upgrade

# final stuff
dpkg-reconfigure linuxmuster-base
. /etc/default/linuxmuster-base
[ "$START_LINUXMUSTER" = "[Yy][Ee][Ss]" ] && sed -e 's|^START_LINUXMUSTER=.*|START_LINUXMUSTER=no|' -i /etc/default/linuxmuster-base
import_workstations
[ "$START_LINUXMUSTER" = "[Yy][Ee][Ss]" ] && sed -e 's|^START_LINUXMUSTER=.*|START_LINUXMUSTER=yes|' -i /etc/default/linuxmuster-base

echo
echo "Beendet um `date`!"
echo "Starten Sie den Server neu!"

