#!/bin/sh

# read dist.conf
. /usr/share/linuxmuster/config/dist.conf
. $HELPERFUNCTIONS


# repair wwwadmin group
if ! smbldap-groupshow $WWWADMIN &> /dev/null; then

  smbldap-groupadd -g 997 $WWWADMIN

else

  gidnr=`smbldap-groupshow $WWWADMIN | grep gidNumber: | awk '{ print $2 }'`

  if [ "$gidnr" != "997" ]; then

    smbldap-groupmod -g 997 $WWWADMIN

  fi

fi


# rename Administrator to administrator
id=`psql -U ldap -d ldap -t -c "SELECT id,dn FROM ldap_entries;" | grep "uid=Administrator" | awk -F\| '{print $1}'`
if [ -n "$id" ]; then

    new_dn="uid=$ADMINISTRATOR,ou=accounts,$basedn"
    psql -U ldap -d ldap -c "UPDATE ldap_entries SET dn='$new_dn' WHERE id=$id;"
    id=`psql -U ldap -d ldap -t -c "SELECT id FROM posix_account WHERE uid = 'Administrator';"`

    if [ -n "$id" ]; then

       psql -U ldap -d ldap -c "UPDATE posix_account SET uid='$ADMINISTRATOR' WHERE id=$id;"
       psql -U ldap -d ldap -c "UPDATE posix_account SET homedirectory='$ADMINSHOME/$ADMINISTRATOR' WHERE id=$id;"

    fi

    [ -d $ADMINSHOME/Administrator ] && mv $ADMINSHOME/Administrator $ADMINSHOME/$ADMINISTRATOR

fi


# domain admin account
if ! id $DOMADMIN &> /dev/null; then
  smbldap-useradd -a -u 996 -g 512 -d /dev/null -s /bin/false -c "Domain Admin" $DOMADMIN
fi


# Administrator account
smbldap-usermod -u 998 $ADMINISTRATOR
smbldap-usermod -g 512 -G $ADMINGROUP,$PRINTERADMINS,$TEACHERSGROUP -H '[UX         ]' -d $ADMINSHOME/$ADMINISTRATOR -s /bin/bash $ADMINISTRATOR
[ -d "$ADMINSHOME/$ADMINISTRATOR/registry-patches" ] || cp -a /usr/share/doc/linuxmuster-base/registry-patches $ADMINSHOME/$ADMINISTRATOR
chown $ADMINISTRATOR:$DOMADMINS $ADMINSHOME/$ADMINISTRATOR/ -R
mailquota=`grep ^$ADMINISTRATOR $MAILQUOTACONF | awk -F: '{ print $2 }'`
if [ -d "/var/spool/cyrus/mail/${ADMINISTRATOR:0:1}/user/$ADMINISTRATOR" ]; then
  $SCRIPTSDIR/cyrus-mbox -q $mailquota -m $ADMINISTRATOR
else
  $SCRIPTSDIR/cyrus-mbox -q $mailquota -c $ADMINISTRATOR
fi
# remove mySHN link from home
[ -e "$ADMINSHOME/$ADMINISTRATOR/$MYSHNLINK" ] && rm $ADMINSHOME/$ADMINISTRATOR/$MYSHNLINK


# account for pgmadmin
smbldap-usermod -u 999 -g 512 $PGMADMIN
chown $PGMADMIN:$DOMADMINS $ADMINSHOME/$PGMADMIN/ -R
mailquota=`grep ^$PGMADMIN $MAILQUOTACONF | awk -F: '{ print $2 }'`
if [ -d "/var/spool/cyrus/mail/${PGMADMIN:0:1}/user/$PGMADMIN" ]; then
  $SCRIPTSDIR/cyrus-mbox -q $mailquota -m $PGMADMIN
else
  $SCRIPTSDIR/cyrus-mbox -q $mailquota -c $PGMADMIN
fi


# account for Webadmin
smbldap-usermod -u 997 -g 997 $WWWADMIN
chown $WWWADMIN:$WWWADMIN $ADMINSHOME/$WWWADMIN/ -R
mailquota=`grep ^$WWWADMIN $MAILQUOTACONF | awk -F: '{ print $2 }'`
if [ -d "/var/spool/cyrus/mail/${WWWADMIN:0:1}/user/$WWWADMIN" ]; then
  $SCRIPTSDIR/cyrus-mbox -q $mailquota -m $WWWADMIN
else
  $SCRIPTSDIR/cyrus-mbox -q $mailquota -c $WWWADMIN
fi


# repair permissions in /home/samba
chown $ADMINISTRATOR:$DOMADMINS $SAMBAHOME/*
chmod 775 $SAMBAHOME/*
