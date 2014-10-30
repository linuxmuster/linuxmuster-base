#!/bin/bash
#
# create and remove a remote administrator
#
# Thomas Schmitt
# <tschmitt@linuxmuster.de>
# GPL v3
# 
# $Id: remoteadmin.sh 1334 2012-07-20 12:03:39Z tschmitt $
#

# source linxmuster environment
. /usr/share/linuxmuster/config/dist.conf
. $HELPERFUNCTIONS

# check if task is locked
locker=/tmp/.remoteadmin.lock
lockfile -l 60 $locker

tmpdir=/var/tmp/${REMOTEADMIN}.$$
mkdir -p $tmpdir

tmpaddfile=/etc/sudoers.${REMOTEADMIN}.backup.add
tmpdelfile=/etc/sudoers.${REMOTEADMIN}.backup.remove

# strings placed in /etc/sudoers
sudoerstr[0]="## begin linuxmuster $REMOTEADMIN ## DO NOT EDIT! ##"
sudoerstr[1]="$REMOTEADMIN ALL=(ALL) ALL ## DO NOT EDIT! ##"
sudoerstr[2]="## end linuxmuster $REMOTEADMIN ## DO NOT EDIT! ##"

remove_quota_entry() {
 # remove old entry if there is one
 for i in $QUOTACONF $MAILQUOTACONF; do
  if grep -qw ^$REMOTEADMIN $i; then
   grep -vw $REMOTEADMIN $i > $tmpdir/quota.tmp
   mv $tmpdir/quota.tmp $i
  fi
 done
}

add_to_sudoers() {
 cp /etc/sudoers $tmpaddfile
 for i in 0 1 2; do
  echo "${sudoerstr[$i]}" >> /etc/sudoers
 done
 chown root:root /etc/sudoers $tmpaddfile $tmpdelfile
 chmod 440 /etc/sudoers $tmpaddfile $tmpdelfile
}

remove_from_nagios() {
 [ -d /etc/nagios2 ] || return 0
 if [ -e /etc/nagios2/cgi.cfg ]; then
  if grep -q $REMOTEADMIN /etc/nagios2/cgi.cfg; then
   cp /etc/nagios2/cgi.cfg /etc/nagios2/cgi.cfg.${REMOTEADMIN}.backup.remove
   sed -e "s/=${REMOTEADMIN},/=/g" -i /etc/nagios2/cgi.cfg
   chmod 755 /etc/nagios2/cgi.cfg
   [ -e /etc/init.d/nagios2 ] && /etc/init.d/nagios2 restart
  fi
 fi
 if [ -e /etc/nagios2/apache2.conf ]; then
  if grep -q $REMOTEADMIN /etc/nagios2/apache2.conf; then
   cp /etc/nagios2/apache2.conf /etc/nagios2/apache2.conf.${REMOTEADMIN}.backup.remove
   sed -e "s/ ${REMOTEADMIN}//g" -i /etc/nagios2/apache2.conf
   /etc/init.d/apache2 restart
  fi
 fi
}

remove_from_sudoers() {
 cp /etc/sudoers $tmpdelfile
 for i in 0 1 2; do
  grep -v "${sudoerstr[$i]}" /etc/sudoers > $tmpdir/sudoers
  mv $tmpdir/sudoers /etc
 done
 chown root:root /etc/sudoers $tmpaddfile $tmpdelfile
 chmod 440 /etc/sudoers $tmpaddfile $tmpdelfile
}

remove_from_webmin() {
 if grep -q $REMOTEADMIN /etc/webmin/webmin.acl; then
  cp /etc/webmin/webmin.acl /etc/webmin/webmin.acl.${REMOTEADMIN}.backup.remove
  grep -v ${REMOTEADMIN} /etc/webmin/webmin.acl > $tmpdir/webmin.acl
  mv $tmpdir/webmin.acl /etc/webmin
  webmin_restart=yes
 fi
 if grep -q $REMOTEADMIN /etc/webmin/miniserv.users; then
  cp /etc/webmin/miniserv.users /etc/webmin/miniserv.users.${REMOTEADMIN}.backup.remove
  grep -v ${REMOTEADMIN} /etc/webmin/miniserv.users > $tmpdir/miniserv.users
  mv $tmpdir/miniserv.users /etc/webmin
  chown root:shadow /etc/webmin/miniserv.users*
  chmod 750 /etc/webmin/miniserv.users*
  webmin_restart=yes
 fi
 [ "$webmin_restart" = "yes" ] && /etc/init.d/webmin restart &> /dev/null
}

do_accessconf() {
 allowed=`grep ^"-:ALL EXCEPT" /etc/security/access.conf`
 allowed=${allowed#-:ALL EXCEPT }
 allowed=${allowed%:ALL}
 allowed=${allowed/$REMOTEADMIN/}
 if [ "$1" = "add" ]; then
  allowed="$allowed $REMOTEADMIN"
  cp /etc/security/access.conf /etc/security/access.conf.${REMOTEADMIN}.backup.add
 else
  cp /etc/security/access.conf /etc/security/access.conf.${REMOTEADMIN}.backup.remove
 fi
 allowed=${allowed//  / }
 allowed=${allowed% }
 sedstr="-:ALL EXCEPT ${allowed}:ALL"
 sedstr=${sedstr//  / }
 sed -e "s/^-:ALL EXCEPT.*/$sedstr/" -i /etc/security/access.conf
}

create_account() {
 delgroup $REMOTEADMIN &> /dev/null
 if addgroup --system $REMOTEADMIN; then
  useradd -c "Remote Admin" -g $REMOTEADMIN -d $ADMINSHOME/$REMOTEADMIN -r -s /bin/bash $REMOTEADMIN
  mkdir -p $ADMINSHOME/$REMOTEADMIN
  chown $REMOTEADMIN:$REMOTEADMIN $ADMINSHOME/$REMOTEADMIN -R
  chmod 700 $ADMINSHOME/$REMOTEADMIN
  [ "$NOPASSWD" = "yes" ] || passwd $REMOTEADMIN
  add_to_sudoers
  do_accessconf add
 else
  echo "Failed to create system group $REMOTEADMIN!"
  return 1
 fi
}

remove_account() {
 remove_from_nagios
 remove_from_sudoers
 remove_from_webmin
 do_accessconf
 if check_id $REMOTEADMIN; then
  sophomorix-kill --killuser $REMOTEADMIN &> /dev/null
  remove_quota_entry
 else
  id $REMOTEADMIN &> /dev/null && deluser $REMOTEADMIN
  delgroup $REMOTEADMIN &> /dev/null
 fi
 rm -rf $ADMINSHOME/$REMOTEADMIN
}

cat /etc/issue

case $1 in
 --create)
  if id $REMOTEADMIN &> /dev/null; then
   echo "There is already an account for $REMOTEADMIN!"
   status=1
  else
   echo "Creating account for $REMOTEADMIN ..."
   create_account
   if id $REMOTEADMIN &> /dev/null; then
    echo "Account for $REMOTEADMIN successfully created!"
    status=0
   else
    echo "Failed to create account for $REMOTEADMIN!"
    remove_account
    status=1
   fi
  fi
 ;;
 --remove)
  if ! id $REMOTEADMIN &> /dev/null; then
   echo "There is no user $REMOTEADMIN!"
   status=1
  else
   echo "Removing account for $REMOTEADMIN ..."
   linuxmuster-ovpn --check --username=$REMOTEADMIN &> /dev/null && linuxmuster-ovpn --purge --username=$REMOTEADMIN
   remove_account
   if id $REMOTEADMIN &> /dev/null; then
    echo "Failed to remove account for $REMOTEADMIN!"
    status=1
   else
    echo "Account for $REMOTEADMIN successfully removed!"
    status=0
   fi
  fi
 ;;
 *)
  echo "Usage: $0 [--create|--remove]"
 ;;
esac

# remove lock and tmpdir
rm -rf $tmpdir
rm -f $locker

exit $status

