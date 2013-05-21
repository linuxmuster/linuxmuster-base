#!/bin/bash
#
# creates horde database
#
# <thomas@linuxmuster.net>
# 16.04.2013
# GPL v3
#

. /usr/share/linuxmuster/config/dist.conf
. $HELPERFUNCTIONS


# drop horde db on first time install
if mysqlshow | grep -qw horde; then

  echo "Dropping old horde database!"
  if ! mysqladmin -f drop horde; then

    cancel "Cannot drop old horde database!"

  fi

fi


# create a random password
echo "Creating a new horde database password ..."
hordepw=`pwgen -s 24 1`


# create user and db
echo "Creating a horde user and database ..."
if ! zcat /usr/share/doc/horde3/examples/scripts/sql/create.mysql.sql.gz | sed -e "s/PASSWORD(.*/PASSWORD('$hordepw')/" | mysql; then

  cancel "Fatal: Cannot create horde database!"

fi


# patch horde config.php with passwords, admin account
echo "Patching horde configuration ..."
sed -e "s/\$conf\['sql'\]\['password'\] =.*/\$conf\['sql'\]\['password'\] = '$hordepw';/" /etc/horde/horde3/conf.php > /etc/horde/horde3/conf.php.tmp
cp -f /etc/horde/horde3/conf.php.tmp /etc/horde/horde3/conf.php && rm -f /etc/horde/horde3/conf.php.tmp


# unset random password
unset hordepw


# create turba tables
echo "Creating turba tables ..."
mysql horde < /usr/share/doc/turba2/examples/scripts/sql/turba.sql


# create kronolith tables
echo "Creating kronolith tables ..."
mysql horde < /usr/share/doc/kronolith2/examples/scripts/sql/kronolith.mysql.sql


# create mnemo tables
echo "Creating mnemo tables ..."
mysql horde < /usr/share/doc/mnemo2/examples/scripts/sql/mnemo.sql


# create nag tables
echo "Creating nag tables ..."
mysql horde < /usr/share/doc/nag2/examples/scripts/sql/nag.sql


echo "Done!"

exit 0
