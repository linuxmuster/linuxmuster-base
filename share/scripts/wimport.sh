# workstation import for paedML Linux
#
# Thomas Schmitt <schmitt@lmz-bw.de>
# $Id$
#
# GPL v3
#

WDATATMP=/var/tmp/workstations.$$
[ -e "$WDATATMP" ] && rm -rf $WDATATMP

MACHINE_PASSWORD=12345678
HOST_PASSWORD=`pwgen -s 8 1`
QUOTA=`grep ^'\$use_quota' $SOPHOMORIXCONF | awk -F\" '{ print $2 }' | tr A-Z a-z`

# get host and machine accounts
echo -n "Reading account data ."
HOSTS_DB="$(hosts_db)"
echo -n .
HOSTS_LDAP="$(hosts_ldap)"
echo -n .
MACHINES_DB="$(machines_db)"
echo -n .
MACHINES_LDAP="$(machines_ldap)"
echo -n .
ACCOUNTS_DB="$(accounts_db)"
echo -n .
ACCOUNTS_LDAP="$(accounts_ldap)"
echo " Done!"
echo

RC=0

# functions
# check for unique entry
check_unique() {
 local found=""
 local s
 for s in $2; do
  if [ "$s" = "$1" ]; then
   [ -n "$found" ] && return 1
   found=yes
  fi
 done
 return 0
}

# cancel with message
exitmsg() {
 echo "$1"
 rm $WDATATMP
 rm -f $locker
 RC=1
 exit $RC
}

# checking for valid host/machine account
check_account() {
 echo "$HOSTS_LDAP" | grep -qw "$hostname" || return 1
 echo "$MACHINES_LDAP" | grep -qw "${hostname}\\$" || return 1
 echo "$HOSTS_DB" | grep -qw "$hostname" || return 1
 echo "$MACHINES_DB" | grep -qw "${hostname}\\$" || return 1
 return 0
}

# create workstation and machine accounts
create_account() {
 # check if hostname exists already as a user account
 if echo "$ACCOUNTS_LDAP" | grep -qw "$hostname"; then
  echo "  > ERROR: $hostname is already a ldap user account! Skipping!"
  echo
  return 1
 fi
 if echo "$ACCOUNTS_DB" | grep -qw "$hostname"; then
  echo "  > ERROR: $hostname is already a postgresql user account! Skipping!"
  echo
  return 1
 fi
 if grep -q ^"${hostname}"\: /etc/passwd; then
  echo "  > ERROR: $hostname is already a system account! Skipping!"
  echo
  return 1
 fi
 if [ -e "$SOPHOMORIXLOCK" ]; then
  echo "  > Fatal! Sophomorix lockfile $SOPHOMORIXLOCK detected!"
  return 1
 fi
 echo -n "  * Creating exam account $hostname ... "
 if sophomorix-useradd --examaccount $hostname --unix-group $room 2>> $TMPLOG 1>> $TMPLOG; then
  echo "Ok!"
 else
  echo "sophomorix error!"
 return 1
 fi
 if ! sophomorix-passwd -u $hostname --pass $HOST_PASSWORD 2>> $TMPLOG 1>> $TMPLOG; then
  echo "  > Error: Cannot set password for $hostname!"
  return 1
 fi
 [ -d "$WSHOME/$room/$hostname" ] || mkdir -p $WSHOME/$room/$hostname
 chown $hostname:$TEACHERSGROUP $WSHOME/$room/$hostname
 chmod 775 $WSHOME/$room/$hostname
 if [ "$QUOTA" = "yes" ]; then
  echo -n "  * Setting quota for $hostname ... "
  if sophomorix-quota -u $hostname 2>> $TMPLOG 1>> $TMPLOG; then
   echo "Ok!"
  else
   echo "sophomorix error!"
   return 1
  fi
 fi
 echo -n "  * Creating machine account ${hostname}$ ... "
 if sophomorix-useradd --computer ${hostname}$ 2>> $TMPLOG 1>> $TMPLOG; then
  echo "Ok!"
 else
  echo "sophomorix error!"
  return 1
 fi
}

# remove workstation and machine accounts
remove_account() {
 if ! check_account $hostname; then
  echo "  > Fatal! $hostname is no computer account! Not removing!"
  return 1
 fi
 if [ -e "$SOPHOMORIXLOCK" ]; then
  echo "  > Fatal! Sophomorix lockfile $SOPHOMORIXLOCK detected!"
  return 1
 fi
 echo -n "  * Removing exam account $hostname ... "
 if sophomorix-kill --killuser $hostname 2>> $TMPLOG 1>> $TMPLOG; then
  [ -d "$i" ] && rm -rf $i 2>> $TMPLOG 1>> $TMPLOG
  echo "Ok!"
 else
  echo "sophomorix error!"
  return 1
 fi
 echo -n "  * Removing machine account ${hostname}$ ... "
 if sophomorix-kill --killuser ${hostname}$ 2>> $TMPLOG 1>> $TMPLOG; then
  echo "Ok!"
 else
  echo "sophomorix error!"
  return 1
 fi
}

# remove room or host from $PRINTERS
remove_printeraccess() {
 local toremove=$1
 local PRINTERSTMP=/var/tmp/printers.$$
 [ -e "$PRINTERSTMP" ] && rm -rf $PRINTERSTMP
 echo "  * Removing $toremove from $PRINTERS ..."
 while read line; do
  if [ "${line:0:1}" = "#" ]; then
   echo "$line" >> $PRINTERSTMP
   continue
  fi
  if ! echo "$line" | grep -qw $toremove; then
   echo "$line" >> $PRINTERSTMP
   continue
  fi
  printer=`echo $line | awk '{ print $1 }'`
  [ -z "$printer" ] && continue
  roomlist=`echo $line | awk '{ print $2 }'`
  [ -z "$roomlist" ] && continue
  hostlist=`echo $line | awk '{ print $3 }'`
  roomlist=${roomlist/$toremove/}
  roomlist=${roomlist//,,/,}
  roomlist=${roomlist%,}
  roomlist=${roomlist#,}
  [ -z "$roomlist" ] && roomlist="-"
  hostlist=${hostlist/$toremove/}
  hostlist=${hostlist//,,/,}
  hostlist=${hostlist%,}
  hostlist=${hostlist#,}
  [ -z "$hostlist" ] && hostlist="-"
  echo -e "$printer\t$roomlist\t$hostlist" >> $PRINTERSTMP
 done <$PRINTERS
 mv $PRINTERSTMP $PRINTERS
 update_printers="yes"
}

# remove deleted rooms or hosts from $ROOMDEFAULTS
remove_defaults() {
 local toremove=$1
 local RC_REMOVE=0
 echo -n "  * Removing $toremove from $ROOMDEFAULTS ... "
 backup_roomdefaults=yes
 grep -v ^$toremove[[:space:]] $ROOMDEFAULTS > $ROOMDEFAULTS.tmp; RC_REMOVE=$?
 mv $ROOMDEFAULTS.tmp $ROOMDEFAULTS; RC_REMOVE=$?
 if [ $RC_REMOVE -ne 0 ]; then
  echo "Error!"
  return 1
 else
  echo "Ok!"
  return 0
 fi
}


if [ "$imaging" = "linbo" ]; then
 # adding new host entries from LINBO's registration
 if ls $LINBODIR/*.new 2>> $TMPLOG 1>> $TMPLOG; then
  for i in $LINBODIR/*.new; do
   echo "Adding new host data:"
   cat $i
   echo
   cat $i >> $WIMPORTDATA
   rm $i
  done
 fi
fi


# filter out bad workstation data
touch $WDATATMP
if [ -s "$WIMPORTDATA" ]; then

 # create a clean workstation data file
 RC_LINE=0
 echo "Checking workstation data:"
 while read line; do

  # skip comment lines
  [ "${line:0:1}" = "#" ] && continue

  # strip spaces and skip empty lines
  line=${line// /}
  [ -z "$line" ] && continue

  room=`echo $line | awk -F\; '{ print $1 }'`
  if ! validname "$room"; then
   [ -z "$room" ] && room="<empty>"
   echo "  > $room is no valid room name! Skipping."
   RC_LINE=1
   continue
  fi

  hostname=`echo $line | awk -F\; '{ print $2 }'`
  tolower $hostname
  hostname=$RET
  if ! validhostname "$hostname"; then
   [ -z "$hostname" ] && hostname="<empty>"
   echo "  > $hostname is no valid hostname! Skipping."
   RC_LINE=1
   continue
  fi

  hostgroup=`echo $line | awk -F\; '{ print $3 }'`
  if ! validname "$hostgroup"; then
   [ -z "$hostgroup" ] && hostgroup="<empty>"
   echo "  > $hostgroup is no valid group name! Skipping $hostname."
   RC_LINE=1
   continue
  fi

  mac=`echo $line | awk -F\; '{ print $4 }'`
  toupper $mac
  mac=$RET
  if ! validmac "$mac"; then
   [ -z "$mac" ] && mac="<empty>"
   echo "  > $mac is no valid mac address! Skipping $hostname."
   RC_LINE=1
   continue
  fi

  ip=`echo $line | awk -F\; '{ print $5 }'`
  if ! validip "$ip"; then
   [ -z "$ip" ] && ip="<empty>"
   echo "  > $ip is no valid ip address! Skipping $hostname."
   RC_LINE=1
   continue
  fi

  pxe=`echo $line | awk -F\; '{ print $11 }'`
  if [ -z "$pxe" ]; then
   echo "  > PXE-Flag is not set! Skipping $hostname."
   RC_LINE=1
   continue
  fi

  echo "$room;$hostname;$hostgroup;$mac;$ip;$internmask;1;1;1;1;$pxe" >> $WDATATMP

 done <$WIMPORTDATA

fi

# check for repeated hostnames, macs and ips
if [ -s "$WDATATMP" ]; then

 # check hostnames
 hostnames=`awk -F\; '{ print $2 }' $WDATATMP`
 for i in $hostnames; do
  check_unique "$i" "$hostnames" || exitmsg "Hostname $i is not unique!"
 done

 # check macs
 macs=`awk -F\; '{ print $4 }' $WDATATMP`
 for i in $macs; do
  check_unique "$i" "$macs" || exitmsg "MAC address $i is not unique!"
 done

 # check ips
 ips=`awk -F\; '{ print $5 }' $WDATATMP`
 for i in $ips; do
  check_unique "$i" "$ips" || exitmsg "IP address $i is not unique!"
 done

fi

# evaluate workstation data checks
[ "$RC_LINE" = "0" -a -s "$WDATATMP" ] && echo "  * Workstation data are Ok! :-)"
if [ "$RC_LINE" != "0" ]; then
 RC=1
 echo "  > Workstation data with errors! :-("
fi
[ -s "$WDATATMP" ] || echo "  * No valid workstation data found! Skipping workstation import!"

echo

# check dhcp stuff
[ -z "$DHCPDCONF" ] && exitmsg "Variable DHCPDCONF is not set!"
if [ -e "$DHCPDCONF" -a -s "$DHCPDCONF" ]; then
 backup_file $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to backup $DHCPDCONF!"
 rm -rf $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to delete $DHCPDCONF!"
fi
touch $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to create $DHCPDCONF!"

# read in rooms
rooms=`ls $WSHOME/`


# Check if workstation data file is empty
if [ -s "$WDATATMP" ]; then

 # write configuration files and create host accounts
 while read line; do

  RC_LINE=0

  # read in host data
  room=`echo $line | awk -F\; '{ print $1 }'`
  tolower $room
  room=$RET
  hostname=`echo $line | awk -F\; '{ print $2 }'`
  hostgroup=`echo $line | awk -F\; '{ print $3 }'`
  [ "$imaging" = "rembo" ] || hostgroup=`echo $hostgroup | awk -F\, '{ print $1 }'`
  mac=`echo $line | awk -F\; '{ print $4 }'`
  ip=`echo $line | awk -F\; '{ print $5 }'`
  pxe=`echo $line | awk -F\; '{ print $11 }'`
  echo "Processing host $hostname:"

  # create workstation and machine accounts
  if check_account; then
   get_pgroup $hostname
   strip_spaces $RET
   pgroup=$RET
   if [ "$pgroup" != "$room" ]; then
    echo "  * Host $hostname is moving from room $pgroup to $room!"
    remove_account; RC_LINE=$?
    if [ $RC_LINE -eq 0 ]; then
     create_account; RC_LINE=$?
    fi
   fi
  else
   create_account; RC_LINE=$?
  fi

  if [ $RC_LINE -ne 0 ]; then
   RC=$RC_LINE
   continue
  else
   if ! sophomorix-passwd --force -u ${hostname}$ --pass $MACHINE_PASSWORD 2>> $TMPLOG 1>> $TMPLOG; then
    echo "  > Error: Cannot set machine password for ${hostname}$!"
    RC=1
    continue
   fi
   # disable password change
   smbldap-usermod -A0 -B0 ${hostname}$
  fi

  # linbo stuff, only if pxe host
  if [[ "$pxe" != "0" && "$imaging" = "linbo" ]]; then

   # use the default start.conf if there is none for this group
   if [ ! -e "$LINBODIR/start.conf.$hostgroup" ]; then
    echo -n "  * LINBO: Creating new start.conf.$hostgroup in $LINBODIR ... "
    if cp $LINBODEFAULTCONF $LINBODIR/start.conf.$hostgroup; then
     sed -e "s/^Server.*/Server = $serverip/
             s/^Description.*/Description = Windows XP/
             s/^Image.*/Image =/
             s/^BaseImage.*/BaseImage = winxp-$hostgroup.cloop/" -i $LINBODIR/start.conf.$hostgroup
     echo "Ok!"
    else
     echo "Error!"
     RC=1
    fi
   fi

   echo -n "  * LINBO: Linking IP $ip to hostgroup $hostgroup ... "

   # remove start.conf links but preserve start.conf file for this ip
   if [[ -e "$LINBODIR/start.conf-$ip" && -L "$LINBODIR/start.conf-$ip" ]]; then
    rm $LINBODIR/start.conf-$ip
   fi

   # create start.conf link if there is no file for this ip
   if [ ! -e "$LINBODIR/start.conf-$ip" ]; then
    ln -sf start.conf.$hostgroup $LINBODIR/start.conf-$ip
   fi

   # if there is no pxelinux boot file for the group
   if [ ! -s "$LINBODIR/pxelinux.cfg/$hostgroup" ]; then
    # create one
    sed -e "s/initrd=linbofs.gz/initrd=linbofs.$hostgroup.gz/g" $PXELINUXCFG > $LINBODIR/pxelinux.cfg/$hostgroup
   fi

   echo "Ok!"

  fi

  # write dhcpd.conf entry
  echo -n "  * DHCP: Writing entry for $hostname ... "
  echo "host $hostname {" >> $DHCPDCONF
  echo "  hardware ethernet $mac;" >> $DHCPDCONF
  echo "  fixed-address $ip;" >> $DHCPDCONF
  echo "  option host-name \"$hostname\";" >> $DHCPDCONF
  if [[ "$pxe" != "0" && "$imaging" = "linbo" ]]; then
   # assign group specific pxelinux config
   echo "  option pxelinux.configfile \"pxelinux.cfg/$hostgroup\";" >> $DHCPDCONF
  fi
  echo "}" >> $DHCPDCONF

  echo "Ok!"
  echo

 done <$WDATATMP

fi


# creating/updating group specific linbofs
if [ "$imaging" = "linbo" -a -e "$LINBOUPDATE" ]; then
 $LINBOUPDATE; RC_LINE=$?
 [ $RC_LINE -ne 0 ] && RC=1
fi


# myshn groups
if [ "$imaging" = "rembo" ]; then
 echo "Processing mySHN groups:"
 FOUND=0
 for i in `awk -F\; '{ print $3 " " $11 }' $WDATATMP | grep -v -w 0 | awk '{ print $1 }' | sort -u`; do
  OIFS="$IFS"
  IFS=","
  for g in $i; do
   if [ ! -e "$MYSHNDIR/groups/$g/config" ]; then
    echo -n "  * Copying default config for group $g ... "
    FOUND=1; RC_LINE=0
    if [ ! -d "$MYSHNDIR/groups/$g" ]; then
     mkdir -p $MYSHNDIR/groups/$g 2>> $TMPLOG 1>> $TMPLOG
    fi
    cp $MYSHNCONFIG $MYSHNDIR/groups/$g/config 2>> $TMPLOG 1>> $TMPLOG; RC_LINE="$?"
    if [ $RC_LINE -eq 0 ]; then
     echo "Ok!"
    else
     echo "failed!"
     RC=1
    fi
   fi
  done
  IFS="$OIFS"
 done
 [ "$FOUND" = "0" ] && echo "  * Nothing to do!"
fi

echo
backup_file $PRINTERS &> /dev/null
backup_file $CLASSROOMS &> /dev/null
backup_file $ROOMDEFAULTS &> /dev/null


# check for non-existing hosts
FOUND=0
echo "Checking for obsolete hosts:"
if ls $WSHOME/*/* &> /dev/null; then

 for i in $WSHOME/*/*; do

  hostname=${i##*/}
  if ! awk -F\; '{ print "X"$2"X" }' $WDATATMP | grep -q X${hostname}X; then
   FOUND=1
   remove_account ; RC_LINE="$?"
   [ $RC_LINE -eq 0 ] || RC=1
   if grep -v ^# $PRINTERS | grep -qw $hostname; then
    remove_printeraccess $hostname ; RC_LINE="$?"
    [ $RC_LINE -eq 0 ] || RC=1
   fi

   if grep -q ^$hostname[[:space:]] $ROOMDEFAULTS; then
    remove_defaults $hostname ; RC_LINE="$?"
    [ $RC_LINE -eq 0 ] || RC=1
   fi
  fi

 done

fi
[ "$FOUND" = "0" ] && echo "  * Nothing to do!"

# check for obsolete rooms
FOUND=0
echo
echo "Checking for obsolete rooms:"
for room in $rooms; do

 if ! awk -F\; '{ print "X"$1"X" }' $WDATATMP | grep -q X${room}X; then
  FOUND=1
  echo -n "  * Removing room: $room ... "
  if sophomorix-groupdel --room $room 2>> $TMPLOG 1>> $TMPLOG; then
   echo "Ok!"
  else
   echo "sophomorix error!"
   RC=1
  fi

  if grep -qw ^$room $CLASSROOMS; then
   echo -n "  * Removing $room from $CLASSROOMS ... "
   backup_classrooms=yes
   grep -wv ^$room $CLASSROOMS > $CLASSROOMS.tmp
   mv $CLASSROOMS.tmp $CLASSROOMS
   echo "Ok!"
  fi

  grep -q ^$room[[:space:]] $ROOMDEFAULTS && remove_defaults $room

  if grep -v ^# $PRINTERS | grep -qw $room; then
   remove_printeraccess $room ; RC_LINE="$?"
   [ $RC_LINE -eq 0 ] || RC=1
  fi
 fi

done
[ "$FOUND" = "0" ] && echo "  * Nothing to do!"

[ -z "$backup_classrooms" ] && rm ${BACKUPDIR}${CLASSROOMS}-${DATETIME}.gz
[ -z "$backup_roomdefaults" ] && rm ${BACKUPDIR}${ROOMDEFAULTS}-${DATETIME}.gz
[ -z "$update_printers" ] && rm ${BACKUPDIR}${PRINTERS}-${DATETIME}.gz


# reload necessary services
echo
/etc/init.d/linuxmuster-base reload
/etc/init.d/dhcp3-server force-reload
[ "$imaging" = "rembo" ] && /etc/init.d/rembo reload
[ -n "$update_printers" ] && import_printers

# delete tmp files
rm $WDATATMP
[ -n "$PRINTERSTMP" ] && [ -e "$PRINTERSTMP" ] && rm -rf $PRINTERSTMP

# exit with return code
exit $RC

