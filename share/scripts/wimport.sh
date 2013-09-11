# workstation import for linuxmuster.net
#
# Thomas Schmitt <thomas@linuxmuster.net>
# 11.09.2013
# GPL v3
#

DB10TMP=/var/tmp/db10.$$
DBREVTMP=/var/tmp/dbrev.$$

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
 rm -f $locker
 RC=1
 echo
 exit $RC
}


# remove room or host from $PRINTERS
remove_printeraccess() {
 local toremove=$1
 local PRINTERSTMP=/var/tmp/printers.$$
 [ -e "$PRINTERSTMP" ] && rm -rf $PRINTERSTMP
 echo -n " * Removing $toremove from $PRINTERS ... "
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
 echo "Ok!"
}


# remove deleted rooms or hosts from $ROOMDEFAULTS
remove_defaults() {
 local toremove=$1
 local RC=0
 echo -n " * Removing $toremove from $ROOMDEFAULTS ... "
 backup_roomdefaults=yes
 grep -v ^$toremove[[:space:]] $ROOMDEFAULTS > $ROOMDEFAULTS.tmp; RC=$?
 mv $ROOMDEFAULTS.tmp $ROOMDEFAULTS; RC=$?
 if [ $RC -ne 0 ]; then
  echo "Error!"
  return 1
 else
  echo "Ok!"
  return 0
 fi
}


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


# only if there are any workstation data
if [ -s "$WIMPORTDATA" ]; then

 # check for bad workstation data and cancel processing if necessary
 echo "Checking workstation data:"
 while read line; do

  echo "$line" | grep -q ^[a-zA-Z0-9] || continue

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
   exitmsg "Host $hostname: $mac_orig is no valid mac address!"
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

 done <$WIMPORTDATA

 # check hostnames
 hostnames="$(grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F\; '{ print $2 }' | tr A-Z a-z)"
 for i in $hostnames; do
  check_unique "$i" "$hostnames" || exitmsg "Hostname $i is not unique!"
 done

 # check macs
 macs="$(grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F\; '{ print $4 }' | tr a-z A-Z)"
 for i in $macs; do
  check_unique "$i" "$macs" || exitmsg "MAC address $i is not unique!"
 done
 
 # check ips
 ips="$(grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F\; '{ print $5 }')"
 for i in $ips; do
  check_unique "$i" "$ips" || exitmsg "IP address $i is not unique!"
 done

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

 echo " * Workstation data are Ok!"
 echo

else

 echo " * No valid workstation data found! Skipping workstation import!"
 echo

fi # [ -s "$WIMPORTDATA" ]

# check dhcp stuff
[ -z "$DHCPDCONF" ] && exitmsg "Variable DHCPDCONF is not set!"
if [ -e "$DHCPDCONF" ]; then
 backup_file $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to backup $DHCPDCONF!"
 rm -rf $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to delete $DHCPDCONF!"
fi
touch $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to create $DHCPDCONF!"


# sync host accounts
echo "Sophomorix syncs accounts (may take a while):"
sophomorix-workstation --sync-accounts | grep ^[KA][id][ld] 2>> $TMPLOG ; RC_LINE="${PIPESTATUS[0]}"
if [ "$RC_LINE" = "0" ]; then
 echo "Done!"
 echo
else
 RC="$RC_LINE"
 echo "sophomorix-workstation exits with error!"
 echo
 rm -f $locker
 exit "$RC"
fi # sync host accounts


# remove host entries from bind config
backup_file $DB10 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to backup $DB10!"
backup_file $DBREV 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to backup $DBREV!"
echo >> $TMPLOG
removefrom_file $DB10 "$BEGINSTR" "$ENDSTR"
removefrom_file $DBREV "$BEGINSTR" "$ENDSTR"
echo ";$BEGINSTR" > $DB10TMP
echo ";$BEGINSTR" > $DBREVTMP


 # if there are any workstation data
if [ -s "$WIMPORTDATA" ]; then

 # remove old links
 echo -n "Removing old start.conf links ... "
 find "$LINBODIR" -name "start.conf-*" -type l -exec rm '{}' \;
 echo "Done!"
 echo

 # write configuration files
 while read line; do

  echo "$line" | grep -q ^[a-zA-Z0-9] || continue
  
  # read in host data
  room=`echo $line | awk -F\; '{ print $1 }'`
  tolower $room
  room=$RET
  hostname=`echo $line | awk -F\; '{ print $2 }'`
  hostgroup=`echo $line | awk -F\; '{ print $3 }'`
  hostgroup=`echo $hostgroup | awk -F\, '{ print $1 }'`
  mac=`echo $line | awk -F\; '{ print $4 }'`
  ip=`echo $line | awk -F\; '{ print $5 }'`
  pxe=`echo $line | awk -F\; '{ print $11 }'`
  echo "Processing host $hostname:"

  # only if pxe host
  if [ "$pxe" != "0" ]; then

   # use the default start.conf if there is none for this group
   if [ ! -e "$LINBODIR/start.conf.$hostgroup" ]; then
    echo -n " * LINBO: Creating new start.conf.$hostgroup in $LINBODIR ... "
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

   echo -n " * LINBO: Linking $ip to group $hostgroup ... "
   ln -sf start.conf.$hostgroup $LINBODIR/start.conf-$ip

   echo "Ok!"

  fi # only if pxe host

  # write dhcpd.conf entry
  echo -n " * DHCP/BIND: Writing config ... "
  echo "host $hostname {" >> $DHCPDCONF
  echo "  hardware ethernet $mac;" >> $DHCPDCONF
  echo "  fixed-address $ip;" >> $DHCPDCONF
  echo "  option host-name \"$hostname\";" >> $DHCPDCONF
  if [ "$pxe" != "0" ]; then
   # assign group specific pxelinux config
   echo "  option extensions-path \"${hostgroup}\";" >> $DHCPDCONF
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

 done <$WIMPORTDATA

fi # if there are any workstation data


# finalize bind config
echo ";$ENDSTR" >> $DB10TMP
echo ";$ENDSTR" >> $DBREVTMP
addto_file "$DB10" "$DB10TMP" "$fwconfig"
addto_file "$DBREV" "$DBREVTMP" "$fwconfig"
rm $DB10TMP
rm $DBREVTMP


# creating/updating group specific linbofs
if [ -e "$LINBOUPDATE" ]; then
 $LINBOUPDATE; RC_LINE=$?
 [ $RC_LINE -ne 0 ] && RC=1
fi


# backup config files to be modified
#echo
backup_file $PRINTERS &> /dev/null
backup_file $CLASSROOMS &> /dev/null
backup_file $ROOMDEFAULTS &> /dev/null


# remove hosts which are no more defined in workstations file
FOUND=0
echo
echo "Checking for obsolete hosts:"
# room_defaults
hosts="$(grep ^[a-z0-9] $ROOMDEFAULTS | awk '{ print $1 }' | tr A-Z a-z)"
for hostname in $hosts; do
 # skip default settings
 [ "$hostname" = "default" ] && continue
 # skip rooms
 grep -q ^$hostname\; $WIMPORTDATA && continue
 if ! awk -F\; '{ print $2 }' $WIMPORTDATA | sort -u | grep -qw $hostname; then
  FOUND=1
  remove_defaults $hostname ; RC_LINE="$?"
  [ $RC_LINE -eq 0 ] || RC=1
 fi
done
# printers
hosts="$(grep ^[a-zA-Z0-9] $PRINTERS | awk '{ print $3 }' | grep ^[a-z0-9] | sed -e 's|,| |g')"
for hostname in $hosts; do
 if ! awk -F\; '{ print $2 }' $WIMPORTDATA | sort -u | grep -qw $hostname; then
  FOUND=1
  remove_printeraccess $hostname
 fi
done
[ "$FOUND" = "0" ] && echo " * Nothing to do!"


# remove rooms which are no more defined in workstations file
FOUND=0
echo
echo "Checking for obsolete rooms:"
# classrooms
rooms="$(grep ^[a-z0-9] $CLASSROOMS | awk '{ print $1 }' | tr A-Z a-z)"
for room in $rooms; do
 if ! grep -q ^${room}\; $WIMPORTDATA; then
  FOUND=1
  echo -n " * Removing $room from $CLASSROOMS ... "
  backup_classrooms=yes
  grep -wv ^$room $CLASSROOMS > $CLASSROOMS.tmp
  mv $CLASSROOMS.tmp $CLASSROOMS
  echo "Ok!"
 fi
done
# room_defaults
rooms="$(grep ^[a-z0-9] $ROOMDEFAULTS | awk '{ print $1 }' | tr A-Z a-z)"
for room in $rooms; do
 [ "$room" = "default" ] && continue
 if ! awk -F\; '{ print $1 }' $WIMPORTDATA | sort -u | grep -qw $room; then
  FOUND=1
  remove_defaults $room ; RC_LINE="$?"
  [ $RC_LINE -eq 0 ] || RC=1
 fi
done
# printers
rooms="$(grep ^[a-zA-Z0-9] $PRINTERS | awk '{ print $2 }' | grep ^[a-z0-9] | sed -e 's|,| |g')"
for room in $rooms; do
 if ! awk -F\; '{ print $1 }' $WIMPORTDATA | sort -u | grep -qw $room; then
  FOUND=1
  remove_printeraccess $room
 fi
done
[ "$FOUND" = "0" ] && echo " * Nothing to do!"


# remove backup files if nothing was changed
[ -z "$backup_classrooms" ] && rm ${BACKUPDIR}${CLASSROOMS}-${DATETIME}.gz
[ -z "$backup_roomdefaults" ] && rm ${BACKUPDIR}${ROOMDEFAULTS}-${DATETIME}.gz
[ -z "$update_printers" ] && rm ${BACKUPDIR}${PRINTERS}-${DATETIME}.gz


# reload necessary services
echo

echo " * Reloading firewall."
if restart-fw --int --ext 1> /dev/null; then
 echo "   ...done."
else
 echo "   failed!"
 RC=1
fi

/etc/init.d/bind9 force-reload || RC=1

[ -n "$update_printers" ] && import_printers


# delete tmp files
[ -n "$PRINTERSTMP" ] && [ -e "$PRINTERSTMP" ] && rm -rf $PRINTERSTMP


# exit with return code
exit $RC

