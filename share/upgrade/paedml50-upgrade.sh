#
# paedML upgrade from 4.0.x to 5.0.x
# main script
# 
# Thomas Schmitt
# <schmitt@lmz-bw.de>
# GPL V3
#
# $Id$ 
#

# environment variables
DHCPDYNTPLDIR=$DYNTPLDIR/03_dhcp3-server
BINDDYNTPLDIR=$DYNTPLDIR/04_bind9
LDAPDYNTPLDIR=$DYNTPLDIR/15_ldap
QUOTDYNTPLDIR=$DYNTPLDIR/18_quota
HORDDYNTPLDIR=$DYNTPLDIR/21_horde3
NAGIDYNTPLDIR=$DYNTPLDIR/22_nagios
FREEDYNTPLDIR=$DYNTPLDIR/55_freeradius
OPENML=`dpkg -l | grep "schulkonsole-templates-openlml" | grep ^i`
PYKOTA=`dpkg -l | grep "linuxmuster-pk " | grep ^i`
BITTORRENT=`dpkg -l | grep " bittorrent " | grep ^i`
FREERADIUS=`dpkg -l | grep linuxmuster-freeradius | grep ^i`
PHPMYADMIN=`dpkg -l | grep phpmyadmin | grep ^i`
PHPPGADMIN=`dpkg -l | grep phppgadmin | grep ^i`
COPSPOT=`dpkg -l | grep linuxmuster-ipcop-addon-copspot | grep ^i`
PKGSTOREMOVE="linuxmuster-freeradius linux-image-server phpmyadmin phppgadmin \
              linuxmuster-schulkonsole-templates-openlml mindi mondo nagios2 \
              linuxmuster-nagios-base postgresql-7.4 postgresql-8.1 samba \
              linuxmuster-pkpgcounter python-egenix-mxtools python-egenix-mxdatetime \
              linuxmuster-pykota linuxmuster-pk samba-common samba-common-bin \
              sophomorix2 sophomorix-base sophomorix-pgldap"
PKGREPOS="ftp.de.debian.org/debian/ \
          ftp.de.debian.org/debian-volatile/ \
          security.debian.org \
          pkg.lml.support-netz.de/paedml50-updates/"
NOW=`date`

# messages for config file headers
message1="##### Do not change this file! It will be overwritten!"
message2="##### This configuration file was automatically created by paedml50-upgrade!"
message3="##### Last Modification: $NOW"


echo
echo "####################################################################"
echo "# paedML/openML Linux Distributions-Upgrade auf Debian 5.0.3 Lenny #"
echo "# Startzeit: $NOW                         #"
echo "####################################################################"
echo


echo "######################"
echo "# Internetverbindung #"
echo "######################"
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


echo "#######################"
echo "# Umgebungs-Variablen #"
echo "#######################"
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
   echo "    Fehler! $i ist nicht gesetzt!"
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
 echo "    Fehler! serverip ist ungueltig!"
 exit 1
fi
ipcopip=10.$internsub.1.254
echo "  * ipcopip=$ipcopip"
if ! validip "$ipcopip"; then
 echo "    Fehler! ipcopip ist ungueltig!"
 exit 1
fi
broadcast=10.$internbc.255.255
echo "  * broadcast=$broadcast"
internalnet=10.$internsub.0.0
echo "  * internalnet=$internalnet"
basedn="dc=`echo $domainname|sed 's/\./,dc=/g'`"
echo "  * basedn=$basedn"
echo


echo "######################"
echo "# Postgres-DB-Backup #"
echo "######################"
for i in `psql -t -l -U postgres | awk '{ print $1 }'`; do
 case $i in
  postgres|template0|template1) continue ;;
 esac
 if [ -s "$BACKUPDIR/$i/$i.lenny-upgrade.pgsql.gz" ]; then
  echo "Sicherung von $i-Datenbank gefunden. Lasse $i aus!"
  continue
 fi
 echo "Sichere $i-Datenbank nach $BACKUPDIR/$i/$i.lenny-upgrade.pgsql.gz ..."
 RC=1
 pg_dump --encoding=UTF8 -U postgres $i > /var/tmp/$i.lenny-upgrade.pgsql ; RC="$?"
 if [ "$RC" != "0" ]; then
  echo "Fehler bei der Sicherung der $i-Datenbank!"
  rm -f /var/tmp/$i.lenny-upgrade.pgsql
  exit 1
 fi
 mkdir -p "$BACKUPDIR/$i"
 RC=1
 gzip -c9 /var/tmp/$i.lenny-upgrade.pgsql > $BACKUPDIR/$i/$i.lenny-upgrade.pgsql.gz ; RC="$?"
 if [ "$RC" != "0" ]; then
  echo "Fehler bei der Komprimierung der $i-Datenbank!"
  rm -f $BACKUPDIR/$i/$i.lenny-upgrade.pgsql.gz
  exit 1
 fi
done
echo


echo "#####################"
echo "# apt-Konfiguration #"
echo "#####################"
[ -e /etc/apt/sources.list.lenny-upgrade ] || cp /etc/apt/sources.list /etc/apt/sources.list.lenny-upgrade
[ -e /etc/apt/apt.conf ] && mv /etc/apt/apt.conf /etc/apt/apt.conf.lenny-upgrade
[ -d /etc/apt/sources.list.d.lenny-upgrade ] || mv /etc/apt/sources.list.d /etc/apt/sources.list.d.lenny-upgrade
cp -a $STATICTPLDIR/etc/apt/* /etc/apt

tweak_apt() {
 export DEBIAN_FRONTEND=noninteractive
 export DEBIAN_PRIORITY=critical
 export DEBCONF_TERSE=yes
 export DEBCONF_NOWARNINGS=yes
 echo 'DPkg::Options {"--force-configure-any";"--force-confmiss";"--force-confold";"--force-confdef";"--force-bad-verify";"--force-overwrite";};' > /etc/apt/apt.conf.d/99upgrade
 echo 'APT::Get::AllowUnauthenticated "true";' >> /etc/apt/apt.conf.d/99upgrade
}

# force apt to do an unattended upgrade
echo "Aktualisiere Paketlisten ..."
tweak_apt
if ! aptitude update; then
 echo
 echo "Fehler: Kann Paketlisten nicht aktualisieren."
 exit 1
fi
echo


echo "#########################"
echo "# Pakete deinstallieren #"
echo "#########################"
aptitude -y remove $PKGSTOREMOVE
echo


echo "###############################"
echo "# Konfiguration aktualisieren #"
echo "###############################"
# uml utilities
echo " uml-utilities ..."
CONF=/etc/default/uml-utilities
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF

# bootlogd
echo " bootlogd ..."
CONF=/etc/default/bootlogd
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF

# slapd
echo " slapd ..."
for i in /etc/ldap/slapd.conf /etc/default/slapd /var/lib/ldap/DB_CONFIG; do
 [ -e "$i.lenny-upgrade" ] || cp $i $i.lenny-upgrade
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
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
sed -e "s/@@sambasid@@/${sambasid}/
	       s/@@workgroup@@/${workgroup}/
	       s/@@basedn@@/${basedn}/" $LDAPDYNTPLDIR/`basename $CONF` > $CONF
CONF=/etc/smbldap-tools/smbldap_bind.conf
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
sed -e "s/@@message1@@/${message1}/
	       s/@@message2@@/${message2}/
	       s/@@message3@@/${message3}/
	       s/@@basedn@@/${basedn}/g
	       s/@@ldappassword@@/${ldapadminpw}/g" $LDAPDYNTPLDIR/`basename $CONF` > $CONF
chmod 600 ${CONF}*

# apache2
echo " apache2 ..."
CONF=/etc/apache2/apache2.conf
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF
rm -f /etc/apache2/mods-enabled/mime_magic.*

# nagios2
if [ -d /etc/nagios2 ]; then
 echo " nagios2 ..."
 CONF=/etc/nagios2/resource.cfg
 [ -e "$CONF" ] || touch $CONF
 CONF=/etc/apache2/conf.d/nagios2.conf
 if [ -e "$CONF" ]; then
  backup_file $CONF
  rm -f $CONF
 fi
fi

# saslauthd
echo " saslauthd ..."
CONF=/etc/default/saslauthd
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF

# dhcp
echo " dhcp ..."
CONF=/etc/dhcp3/dhcpd.conf
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
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
 [ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
 sed -e "s/@@servername@@/${servername}/g
         s/@@domainname@@/${domainname}/g
         s/@@serverip@@/${serverip}/g
         s/@@ipcopip@@/${ipcopip}/g
         s/@@internsub@@/${internsub}/g" $BINDDYNTPLDIR/$i > $CONF
done
rm -f /etc/bind/*.jnl

# horde 3
echo " horde3 ..."
CONF=/etc/horde/horde3/registry.php
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF
CONF=/etc/horde/horde3/conf.php
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
hordepw="$(grep "^\$conf\['sql'\]\['password'\]" $CONF | awk -F\' '{ print $6 }')"
sed -e "s/\$conf\['auth'\]\['admins'\] =.*/\$conf\['auth'\]\['admins'\] = array\('$WWWADMIN'\);/
        s/\$conf\['problems'\]\['email'\] =.*/\$conf\['problems'\]\['email'\] = '$WWWADMIN@$domainname';/
        s/\$conf\['mailer'\]\['params'\]\['localhost'\] =.*/\$conf\['mailer'\]\['params'\]\['localhost'\] = '$servername.$domainname';/
        s/\$conf\['problems'\]\['maildomain'\] =.*/\$conf\['problems'\]\['maildomain'\] = '$domainname';/
        s/\$conf\['sql'\]\['password'\] =.*/\$conf\['sql'\]\['password'\] = '$hordepw';/" $STATICTPLDIR/$CONF > $CONF
# imp
CONF=/etc/horde/imp4/conf.php
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF
CONF=/etc/horde/imp4/servers.php
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cyradmpw="$(cat /etc/imap.secret)"
sed -e "s/'@@servername@@.@@domainname@@'/'$servername.$domainname'/g
        s/'@@domainname@@'/'$domainname'/g
        s/'@@cyradmpw@@'/'$cyradmpw'/" $HORDDYNTPLDIR/imp4.`basename $CONF` > $CONF
# ingo
CONF=/etc/horde/ingo1/conf.php
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF
# kronolith
CONF=/etc/horde/kronolith2/conf.php
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
sed -e "s/\$conf\['storage'\]\['default_domain'\] =.*/\$conf\['storage'\]\['default_domain'\] = '$domainname';/
        s/\$conf\['reminder'\]\['server_name'\] =.*/\$conf\['reminder'\]\['server_name'\] = '$servername.$domainname';/
        s/\$conf\['reminder'\]\['from_addr'\] =.*/\$conf\['reminder'\]\['from_addr'\] = '$WWWADMIN@$domainname';/" $STATICTPLDIR/$CONF > $CONF
# mnemo
CONF=/etc/horde/mnemo2/conf.php
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF
# nag
CONF=/etc/horde/nag2/conf.php
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF
# turba
CONF=/etc/horde/turba2/conf.php
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF
# permissions
chown root:www-data /etc/horde -R
find /etc/horde -type f -exec chmod 440 '{}' \;

# php5
echo " php5 ..."
CONF=/etc/php5/conf.d/paedml.ini
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF
CONF=/etc/php5/apache2/php.ini
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF
CONF=/etc/php5/cli/php.ini
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF

# mindi
echo " mindi ..."
CONF=/etc/mindi/mindi.conf
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF

# warnquota
echo " warnquota ..."
CONF=/etc/warnquota.conf
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
sed -e "s|@@administrator@@|$ADMINISTRATOR|g
        s|@@domainname@@|$domainname|g" $QUOTDYNTPLDIR/$(basename $CONF) > $CONF

# webmin
echo " webmin ..."
CONF=/etc/webmin/config
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
cp $STATICTPLDIR/$CONF $CONF

# fixing backup.conf
echo " backup ..."
CONF=/etc/linuxmuster/backup.conf
[ -e "$CONF.lenny-upgrade" ] || cp $CONF $CONF.lenny-upgrade
sed -e 's|postgresql-8.1|postgresql-8.3|g
        s|nagios2|nagios3|g' -i $CONF

echo


echo "#########################"
echo "# Distributions-Upgrade #"
echo "#########################"
echo

echo "#############"
echo "# apt-utils #"
echo "#############"
aptitude -y install apt-utils tasksel debian-archive-keyring dpkg locales
tweak_apt
aptitude update
echo

echo "##############"
echo "# postgresql #"
echo "##############"
# tweaking kdm
CONF=/etc/init.d/kdm
if [ -e "$CONF" ]; then
 mv $CONF $CONF.lenny-upgrade
 echo "#!/bin/sh" > $CONF
 echo "exit 0" >> $CONF
 chmod 755 $CONF
fi
aptitude -y install postgresql
for i in postgresql postgresql-8.3 postgresql-client-8.3; do
 # check installed ok
 dpkg -s $i | grep -q ^"Status: install ok installed" || aptitude -y install $i
done
[ -e "$CONF.lenny-upgrade" ] && mv $CONF.lenny-upgrade $CONF
/etc/init.d/postgresql-8.3 stop
pg_dropcluster 8.3 main &> /dev/null
pg_createcluster 8.3 main
cp $STATICTPLDIR/etc/postgresql/8.3/main/* /etc/postgresql/8.3/main
/etc/init.d/postgresql-8.3 start
update-rc.d -f postgresql-7.4 remove
update-rc.d -f postgresql-8.1 remove
echo

# restore databases
for i in ldap moodle mrbs pykota; do
 if [ -e "/var/tmp/$i.lenny-upgrade.pgsql" ]; then
  dbuser=$i
  case $i in
   ldap) dbpw="$(grep ^Password /etc/linuxmuster/schulkonsole/db.conf | awk -F\= '{ print $2 }')" ;;
   moodle) dbpw="$(grep \$CFG\-\>dbpass /etc/moodle/config.php | awk -F\' '{ print $2 }')" ;;
   mrbs) dbuser=""
         for p in /var/www/apache2-default /etc/www; do
          if [ -e "$p/$i/config.inc.php" ]; then
           dbuser="$(grep ^\$db_login $p/$i/config.inc.php | awk -F\" '{ print $2 }')"
           [ -z "$dbuser" ] && dbuser="$(grep ^\$db_login $p/$i/config.inc.php | awk -F\' '{ print $2 }')"
           dbpw="$(grep ^\$db_password $p/$i/config.inc.php | awk -F\" '{ print $2 }')"
           [ -z "$dbpw" ] && dbpw="$(grep ^\$db_password $p/$i/config.inc.php | awk -F\' '{ print $2 }')"
          fi
         done ;;
   pykota) dbuser=pykotaadmin
           dbpw="$(grep -w ^storageadminpw /etc/pykota/pykotadmin.conf | awk -F\: '{ print $2 }' | awk '{ print $1 }')"
           pkuser=pykotauser
           pkpw="$(grep -w ^storageuserpw /etc/pykota/pykota.conf | awk -F\: '{ print $2 }' | awk '{ print $1 }')" ;;
   *) dbuser="" ;;
  esac
  if [ -z "$dbuser" ]; then
   echo "WARNUNG: Konnte Benutzer für Datenbank $i nicht bestimmen!"
   echo "Überspringe das Wiederanlegen von $i. Bitte legen Sie die Datenbank nach dem Upgrade von Hand selbst an."
   sleep 5
   continue
  fi
  dbname=$i
  [ "$i" = "mrbs" ] && dbname="mrbs  "
  echo "################################"
  echo "# Restauriere Datenbank $dbname #"
  echo "################################"
  createuser -U postgres -S -D -R $dbuser
  psql -U postgres -d template1 -qc "ALTER USER $dbuser WITH PASSWORD '"$dbpw"';"
  if [ "$i" = "pykota" ]; then
   createuser -U postgres -S -D -R $pkuser
   psql -U postgres -d template1 -qc "ALTER USER $pkuser WITH PASSWORD '"$pkpw"';"
   createdb -U postgres -O postgres $i
  else
   createdb -U postgres -O $dbuser $i
  fi
  psql -U postgres $i < /var/tmp/$i.lenny-upgrade.pgsql
 fi
 echo
done

echo "###############"
echo "# base-passwd #"
echo "###############"
tweak_apt
aptitude -y install passwd
# check for bittorrent user
id bittorrent &> /dev/null && BTUSER=yes
aptitude -y install base-passwd
# recreate bittorrent user removed by update-passwd
if [ -n "$BTUSER" ]; then
 if ! grep -q ^bittorrent: /etc/group; then
  groupadd -r bittorrent
 fi
 if ! grep -q ^bittorrent: /etc/passwd; then
  useradd -r -d /home/bittorrent -c "bittorrent user" -g bittorrent -s /bin/bash bittorrent
 fi 
fi
echo

if [ -n "$BITTORRENT" ]; then
 echo "##############"
 echo "# bittorrent #"
 echo "##############"
 aptitude -y install bittorrent
 chown bittorrent /var/log/bittorrent -R
 chown bittorrent /var/lib/bittorrent -R
 echo
fi

echo "################"
echo "# dist-upgrade #"
echo "################"
tweak_apt
aptitude -y safe-upgrade
aptitude -y dist-upgrade
aptitude -y dist-upgrade
aptitude -y purge avahi-daemon
echo

echo "##############"
echo "# sophomorix #"
echo "##############"
tweak_apt
rm $INSTALLED
aptitude -y install sophomorix2
touch $INSTALLED
echo

echo "###############"
echo "# common task #"
echo "###############"
tweak_apt
linuxmuster-task --unattended --install=common
echo

echo "###############"
echo "# server task #"
echo "###############"
tweak_apt
linuxmuster-task --unattended --install=server
echo

echo "############"
echo "# openldap #"
echo "############"
/etc/init.d/slapd stop
RC=1
slapcat > /var/tmp/ldap.ldif ; RC="$?"
if [ "RC" = "0" ]; then
 mkdir -p $BACKUPDIR/ldap
 gzip -c9 /var/tmp/ldap.ldif > $BACKUPDIR/ldap/ldap.lenny-upgrade.ldif.gz
 rm -rf /etc/ldap/slapd.d
 mkdir -p /etc/ldap/slapd.d
 chattr +i /var/lib/ldap/DB_CONFIG
 rm /var/lib/ldap/* &> /dev/null
 chattr -i /var/lib/ldap/DB_CONFIG
 slapadd < /var/tmp/ldap.ldif
 chown openldap:openldap /var/lib/ldap -R
 slaptest -f /etc/ldap/slapd.conf -F /etc/ldap/slapd.d
 chown -R openldap:openldap /etc/ldap/slapd.d
fi
/etc/init.d/slapd start
echo

echo "################"
echo "# imaging task #"
echo "################"
tweak_apt
linuxmuster-task --unattended --install=imaging-$imaging
echo

if [ -n "$FREERADIUS" ]; then
 echo "##########################"
 echo "# linuxmuster-freeradius #"
 echo "##########################"
 tweak_apt
 aptitude -y install freeradius freeradius-ldap
 aptitude -y install linuxmuster-freeradius
 CONF=/etc/freeradius/clients.conf
 if [ -s "$CONF" -a -d "$FREEDYNTPLDIR" -a ! -e "$CACHEDIR/.freeradius.upgrade50.done" ]; then
  echo "Aktualisiere freeradius ..."
  # fetch radiussecret
  found=false
  while read line; do
   if [ "$line" = "client $ipcopip {" ]; then
    found=true
    continue
   fi
   if [ "$found" = "true" -a "${line:0:6}" = "secret" ]; then
    radiussecret="$(echo "$line" | awk -F\= '{ print $2 }' | awk '{ print $1 }')"
   fi
   [ -n "$radiussecret" ] && break
  done <$CONF
  # patch configuration
  for i in $FREEDYNTPLDIR/*.target; do
   targetcfg=`cat $i`
   sourcetpl=`basename $targetcfg`
   [ -e "$targetcfg" ] && cp $targetcfg $targetcfg.lenny-upgrade
   sed -e "s|@@package@@|linuxmuster-freeradius|
           s|@@date@@|$NOW|
           s|@@radiussecret@@|$radiussecret|
           s|@@ipcopip@@|$ipcopip|
           s|@@ldappassword@@|$ldapadminpw|
           s|@@basedn@@|$basedn|" $FREEDYNTPLDIR/$sourcetpl > $targetcfg
   chmod 640 $targetcfg
   chown root:freerad $targetcfg
  done # targets
  touch $CACHEDIR/.freeradius.upgrade50.done
 fi
 echo
fi

if [ -n "$COPSPOT" ]; then
 echo "###########"
 echo "# copspot #"
 echo "###########"
 aptitude -y install linuxmuster-ipcop-addon-copspot
 echo
fi

if [ -n "$PYKOTA" ]; then
 echo "##################"
 echo "# linuxmuster-pk #"
 echo "##################"
 tweak_apt
 aptitude -y install linuxmuster-pk
 echo
fi

if [ -n "$PHPMYADMIN" ]; then
 echo "##############"
 echo "# phpmyadmin #"
 echo "##############"
 tweak_apt
 aptitude -y install phpmyadmin
 echo
fi

if [ -n "$PHPPGADMIN" ]; then
 echo "##############"
 echo "# phppgadmin #"
 echo "##############"
 tweak_apt
 aptitude -y install phppgadmin
 echo
fi

if [ -n "$OPENML" ]; then
 echo "##########"
 echo "# openML #"
 echo "##########"
 tweak_apt
 echo "deb http://www.linuxmuster.net/openlml-unsupported/ openlml/" > /etc/apt/sources.list.d/openml.list
 aptitude update
 aptitude -y install linuxmuster-schulkonsole-templates-openlml
 echo
fi

# horde3, db and pear upgrade
echo "##########"
echo "# horde3 #"
echo "##########"
HORDEUPGRADE=/usr/share/doc/horde3/examples/scripts/upgrades/3.1_to_3.2.mysql.sql
KRONOUPGRADE=/usr/share/doc/kronolith2/examples/scripts/upgrades/2.1_to_2.2.sql
MNEMOUPGRADE=/usr/share/doc/mnemo2/examples/scripts/upgrades/2.1_to_2.2.sql
NAGUPGRADE=/usr/share/doc/nag2/examples/scripts/upgrades/2.1_to_2.2.sql
TURBAUPGRADE=/usr/share/doc/turba2/examples/scripts/upgrades/2.1_to_2.2_add_sql_share_tables.sql
for i in $HORDEUPGRADE $KRONOUPGRADE $MNEMOUPGRADE $NAGUPGRADE $TURBAUPGRADE; do
 t="$(echo $i | awk -F\/ '{ print $5 }')"
 if [ -e "$CACHEDIR/.${t}.upgrade50.done" ]; then
  echo "$t wurde schon aktualisiert. Überspringe $t."
  continue
 elif [ ! -s "$i" ]; then
  echo " Fehler: $i nicht gefunden! Überspringe $t!"
  continue
 else
  echo " Aktualisiere $t ..."
 fi
 mysql horde < $i && touch $CACHEDIR/.${t}.upgrade50.done
done
echo

echo "#############"
echo "# Aufräumen #"
echo "#############"
# remove apt.conf stuff only needed for upgrade
rm -f /etc/apt/apt.conf.d/99upgrade
# final stuff
dpkg-reconfigure linuxmuster-base
linuxmuster-nagios-setup
echo

echo "######################"
echo "# Workstationsimport #"
echo "######################"
# temporarily deactivation of internal firewall
. /etc/default/linuxmuster-base
[ "$START_LINUXMUSTER" = "[Yy][Ee][Ss]" ] && sed -e 's|^START_LINUXMUSTER=.*|START_LINUXMUSTER=no|' -i /etc/default/linuxmuster-base
import_workstations
[ "$START_LINUXMUSTER" = "[Yy][Ee][Ss]" ] && sed -e 's|^START_LINUXMUSTER=.*|START_LINUXMUSTER=yes|' -i /etc/default/linuxmuster-base
echo

echo "#############################################"
echo "# Beendet um `date`. #"
echo "# Starten Sie den Server neu!               #"
echo "#############################################"
echo

