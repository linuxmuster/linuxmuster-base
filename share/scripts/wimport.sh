# workstation import for paedML Linux
#
# Thomas Schmitt <schmitt@lmz-bw.de>
# $Id: wimport.sh 1288 2012-02-18 13:52:16Z tschmitt $
# GPL v3
#

WDATATMP=/var/tmp/workstations.$$
[ -e "$WDATATMP" ] && rm -rf $WDATATMP

DB10TMP=/var/tmp/db10.$$
DBREVTMP=/var/tmp/dbrev.$$

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
 echo "  > $1"
 echo
 echo "An error ocurred and import_workstations will be cancelled!"
 echo "No modifications have been made to your system!"
 rm $WDATATMP
 rm -f $locker
 RC=1
 echo
 exit $RC
}

# checking for valid host/machine account, returns 0 if no account exists
check_host_account() {
 echo "$HOSTS_LDAP" | grep -qw "$hostname" || return 1
 echo "$MACHINES_LDAP" | grep -qw "${hostname}\\$" || return 1
 echo "$HOSTS_DB" | grep -qw "$hostname" || return 1
 echo "$MACHINES_DB" | grep -qw "${hostname}\\$" || return 1
 return 0
}

# checking for valid user account, returns 0 if no account exists
check_user_account() {
 if echo "$ACCOUNTS_LDAP" | grep -qw "$hostname"; then
  RET=ldap
  return 1
 fi
 if echo "$ACCOUNTS_DB" | grep -qw "$hostname"; then
  RET=postgresql
  return 1
 fi
 if grep -q ^"${hostname}"\: /etc/passwd; then
  RET=system
  return 1
 fi
 RET=""
 return 0
}

# create workstation and machine accounts
create_account() {
 if [ -e "$SOPHOMORIXLOCK" ]; then
  echo "  > Error: Sophomorix lockfile $SOPHOMORIXLOCK detected!"
  return 1
 fi
 echo -n "  * Creating exam account $hostname ... "
 if sophomorix-useradd --examaccount $hostname --unix-group $room 2>> $TMPLOG 1>> $TMPLOG; then
  echo "Ok!"
 else
  echo "sophomorix error!"
  return 1
 fi
 echo -n "  * Setting exam account password for ${hostname} ... "
 if sophomorix-passwd -u $hostname --pass $HOST_PASSWORD 2>> $TMPLOG 1>> $TMPLOG; then
  echo "Ok!"
 else
  echo "sophomorix error!"
  return 1
 fi
 local homedir="$WSHOME/$room/$hostname"
 if [ ! -d "$homedir" ]; then
  mkdir -p "$homedir"
  chown ${hostname}:${TEACHERSGROUP} "$homedir"
  chmod 775 "$homedir"
 fi
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
 echo -n "  * Setting machine account password for ${hostname}$ ... "
 if sophomorix-passwd --force -u ${hostname}$ --pass $MACHINE_PASSWORD 2>> $TMPLOG 1>> $TMPLOG; then
  echo "Ok!"
 else
  echo "sophomorix error!"
  return 1
 fi
 # disable password change
 smbldap-usermod -A0 -B0 ${hostname}$ 2>> $TMPLOG 1>> $TMPLOG
}

# remove workstation and machine accounts
remove_account() {
 if ! check_host_account $hostname; then
  if check_user_account; then
   echo "  * Removing orphaned computer account home directory: $hostdir."
   rm -rf $hostdir
   return 0
  fi
  echo "  > Error: $hostname is an existing $RET user account! Not removing!"
  return 1
 fi
 if [ -e "$SOPHOMORIXLOCK" ]; then
  echo "  > Error: Sophomorix lockfile $SOPHOMORIXLOCK detected!"
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
 if ls $LINBODIR/*.new &> /dev/null; then
  for i in $LINBODIR/*.new; do
   if [ -s "$i" ]; then
    hostname="$(basename "$i" | sed 's|.new||')"
    echo "Adding new data for $hostname:"
    cat $i
    echo
    cat $i >> $WIMPORTDATA
   fi
   rm -f $i
  done
 fi
fi


# check for bad workstation data and cancel processing if necessary
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

  room_orig=`echo $line | awk -F\; '{ print $1 }'`
  if ! check_string "$room_orig"; then
   [ -z "$room_orig" ] && room_orig="<empty>"
   exitmsg "$room_orig is no valid room name!"
  fi
  tolower $room_orig
  room=$RET
  # check for uppercase room names
  if [ "$room_orig" != "$room" ]; then
   rooms_to_be_converted="$rooms_to_be_converted $room_orig"
  fi

  hostname_orig=`echo $line | awk -F\; '{ print $2 }'`
  tolower $hostname_orig
  hostname=$RET
  if ! validhostname "$hostname"; then
   [ -z "$hostname" ] && hostname="<empty>"
   exitmsg "$hostname is no valid hostname!"
  fi
  # check if hostname exists already as a user account
  if ! check_user_account; then
   exitmsg "Hostname $hostname exists already as a $RET user account!"
  fi
  # check for uppercase hostnames
  if [ "$hostname_orig" != "$hostname" ]; then
   hostnames_to_be_converted="$hostnames_to_be_converted $hostname_orig"
  fi

  hostgroup=`echo $line | awk -F\; '{ print $3 }'`
  if ! check_string "$hostgroup"; then
   [ -z "$hostgroup" ] && hostgroup="<empty>"
   exitmsg "Host $hostname: $hostgroup is no valid group name!"
  fi

  mac_orig=`echo $line | awk -F\; '{ print $4 }'`
  if ! validmac "$mac_orig"; then
   [ -z "$mac_orig" ] && mac_orig="<empty>"
   echo "  > $mac_orig is no valid mac address! Skipping $hostname."
   RC_LINE=1
   continue
  fi
  toupper $mac_orig
  mac=$RET
  # check for lowercase macs
  if [ "$mac_orig" != "$mac" ]; then
   macs_to_be_converted="$macs_to_be_converted $mac_orig"
  fi

  ip=`echo $line | awk -F\; '{ print $5 }'`
  if ! validip "$ip"; then
   [ -z "$ip" ] && ip="<empty>"
   exitmsg "Host $hostname: $ip is no valid ip address!"
  fi

  pxe=`echo $line | awk -F\; '{ print $11 }'`
  if [ -z "$pxe" ]; then
   exitmsg "Host $hostname: PXE-Flag is not set!"
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

# convert lowercase macs
if [ -n "$macs_to_be_converted" ]; then
 for i in $macs_to_be_converted; do
  toupper $i
  sed -e "s|$i|$RET|g" -i "$WIMPORTDATA"
 done
fi

# convert uppercase room names
if [ -n "$rooms_to_be_converted" ]; then
 for i in $rooms_to_be_converted; do
  tolower $i
  sed -e "s|^$i\;|$RET\;|g
          s|^$i |$RET |g" -i "$WIMPORTDATA"
 done
fi

# convert uppercase hostnames
if [ -n "$hostnames_to_be_converted" ]; then
 for i in $hostnames_to_be_converted; do
  tolower $i
  sed -e "s|\;$i\;|\;$RET\;|g
          s|\;$i |\;$RET |g
          s| $i | $RET |g
          s| $i\;| $RET\;|g" -i "$WIMPORTDATA"
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
if [ -e "$DHCPDCONF" ]; then
 backup_file $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to backup $DHCPDCONF!"
 rm -rf $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to delete $DHCPDCONF!"
fi
touch $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to create $DHCPDCONF!"

# remove host entries from bind config
backup_file $DB10 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to backup $DB10!"
backup_file $DBREV 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to backup $DBREV!"
removefrom_file $DB10 "/\;$BEGINSTR/,/\;$ENDSTR/"
removefrom_file $DBREV "/\;$BEGINSTR/,/\;$ENDSTR/"
echo ";$BEGINSTR" > $DB10TMP
echo ";$BEGINSTR" > $DBREVTMP

# read in rooms
rooms=`ls $WSHOME/`


# only if workstation data file is filled
if [ -s "$WDATATMP" ]; then

 # remove old links
 echo -n "Removing old start.conf links ... "
 find "$LINBODIR" -name "start.conf-*" -type l -exec rm '{}' \;
 echo "Done!"
 echo

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
  if check_host_account; then
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
   echo
   RC=$RC_LINE
   continue
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

   echo -n "  * LINBO: Linking $ip to group $hostgroup ... "

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
  echo -n "  * DHCP/BIND: Writing config ... "
  echo "host $hostname {" >> $DHCPDCONF
  echo "  hardware ethernet $mac;" >> $DHCPDCONF
  echo "  fixed-address $ip;" >> $DHCPDCONF
  echo "  option host-name \"$hostname\";" >> $DHCPDCONF
  if [[ "$pxe" != "0" && "$imaging" = "linbo" ]]; then
   # assign group specific pxelinux config
   echo "  option pxelinux.configfile \"pxelinux.cfg/$hostgroup\";" >> $DHCPDCONF
  fi
  echo "}" >> $DHCPDCONF
		
  # write bind config
  okt2="$(echo $ip | awk -F. '{ print $2 }')"
  okt3="$(echo $ip | awk -F. '{ print $3 }')"
  okt4="$(echo $ip | awk -F. '{ print $4 }')"
  echo "$okt4.$okt3.$okt2 PTR $hostname.`dnsdomainname`." >> $DB10TMP
  echo "$hostname A $ip" >> $DBREVTMP

  echo "Ok!"
  echo

 done <$WDATATMP

fi

# finalize bind config
echo ";$ENDSTR" >> $DB10TMP
echo ";$ENDSTR" >> $DBREVTMP
addto_file "$DB10" "$DB10TMP" "ipcop"
addto_file "$DBREV" "$DBREVTMP" "ipcop"
rm $DB10TMP
rm $DBREVTMP

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

  hostdir=$i
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
/etc/init.d/bind9 force-reload
[ "$imaging" = "rembo" ] && /etc/init.d/rembo reload
[ -n "$update_printers" ] && import_printers

# delete tmp files
rm $WDATATMP
[ -n "$PRINTERSTMP" ] && [ -e "$PRINTERSTMP" ] && rm -rf $PRINTERSTMP

# exit with return code
exit $RC

