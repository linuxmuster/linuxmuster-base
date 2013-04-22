#!/bin/bash
#
# sets new random passwords for several system users
#
# <thomas@linuxmuster.net>
# 16.04.2013
# GPL v3
#

. /usr/share/linuxmuster/config/dist.conf || exit 1
. $HELPERFUNCTIONS || exit 1

# cyrus admin
$SCRIPTSDIR/cyradmpw.sh

# mysql root
myrootpw=`pwgen -s 24 1`
mysqladmin -u root password $myrootpw
(
cat <<EOF
[client]
user            = root
password        = $myrootpw
[mysqladmin]
user            = root
password        = $myrootpw
EOF
) > /root/.my.cnf
chmod 600 /root/.my.cnf

# horde user
hordepw=`pwgen -s 24 1`
conf=/etc/horde/horde3/conf.php
(
cat <<EOF
use mysql;
update user set password=PASSWORD("$hordepw") where User='horde';
flush privileges;
EOF
) | mysql
sed -e "s|^\$conf\\['sql'\\]\\['password'\\] = .*|\$conf\\['sql'\\]\\['password'\\] = \'$hordepw\'\;|" -i $conf
chown root:www-data $conf
chmod 440 $conf

# ldap postgres user
ldapdbpw=`pwgen -s 24 1`
conf=/etc/linuxmuster/schulkonsole/db.conf
psql -U postgres -d template1 -qc "ALTER USER ldap WITH PASSWORD '"$ldapdbpw"';"
sed -e "s|^Password=.*|Password=$ldapdbpw|" -i $conf
chmod 400 $conf
/etc/init.d/apache2 restart

# ldapadmin
newldappw=`pwgen -s 24 1`
oldldappw="$(cat /etc/ldap.secret)"
for i in ldap.secret freeradius/radiusd.conf ldap/slapd.conf smbldap-tools/smbldap_bind.conf; do
 conf=/etc/$i
 [ -e "$conf" ] && sed -e "s|$oldldappw|$newldappw|g" -i $conf
 chmod 400 $conf
done
for i in ldap/slapd.conf freeradius/radiusd.conf; do
 conf=/etc/$i
 [ -e "$conf" ] && chmod 640 $conf
done
for i in slapd freeradius; do
 /etc/init.d/$i restart
done
smbpasswd -w $newldappw
