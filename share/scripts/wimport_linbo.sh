# workstation import for LINBO
#
# Thomas Schmitt <schmitt@lmz-bw.de>
# 04.10.2007
#

WIMPORTDATA=/etc/linuxmuster/workstations
WDATATMP=/var/tmp/workstations.$$
[ -e "$WDATATMP" ] && rm -rf $WDATATMP

MACHINE_PASSWORD=12345678
HOST_PASSWORD=`pwgen -s 8 1`

# functions
# check for unique entry
check_unique() {
	n=`grep -cw $1 $WDATATMP`
	[ $n -ne 1 ] && return 1
	return 0
}

# cancel with message
exitmsg() {
	echo "$1"
	rm $WDATATMP
	rm -f $locker
	exit 1
}

# create workstation and machine accounts
create_account() {
	echo "  * Creating exam account: $hostname"
	sophomorix-useradd --examaccount $hostname --unix-group $room &> /dev/null
	if ! id $hostname &> /dev/null; then
	    sophomorix-kill --killuser $hostname &> /dev/null
	    sophomorix-useradd --examaccount $hostname --unix-group $room &> /dev/null
	fi
	sophomorix-passwd -u $hostname --pass $HOST_PASSWORD &> /dev/null
	[ -d "$WSHOME/$room/$hostname" ] || mkdir -p $WSHOME/$room/$hostname
	chown $hostname:$TEACHERSGROUP $WSHOME/$room/$hostname
	chmod 775 $WSHOME/$room/$hostname
	echo "  * Setting quota: $hostname"
	sophomorix-quota -u $hostname &> /dev/null
	echo "  * Creating machine account: ${hostname}$"
	sophomorix-useradd --computer ${hostname}$ &> /dev/null
	sophomorix-passwd --force -u ${hostname}$ --pass $MACHINE_PASSWORD &> /dev/null
}

# remove workstation and machine accounts
remove_account() {
	echo "  * Removing exam account: $hostname"
	sophomorix-kill --killuser $hostname &> /dev/null
	echo "  * Removing machine account: ${hostname}$"
	sophomorix-kill --killuser ${hostname}$ &> /dev/null
}

# remove room or host from $PRINTERS
remove_printeraccess() {
	toremove=$1
	PRINTERSTMP=/var/tmp/printers.$$
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


# Check if workstation data file is empty
if [ -s "$WIMPORTDATA" ]; then

	# create a clean workstation data file
	echo "Reading $WIMPORTDATA and checking for valid data ..."
	while read line; do

		[ "${line:0:1}" = "#" ] && continue

		room=`echo $line | awk -F\; '{ print $1 }'`
		[ -z "$room" ] && continue

		hostname=`echo $line | awk -F\; '{ print $2 }'`
		tolower $hostname
		hostname=$RET
		[ -z "$hostname" ] && continue

		hostgroup=`echo $line | awk -F\; '{ print $3 }'`
		[ -z "$hostgroup" ] && continue

		mac=`echo $line | awk -F\; '{ print $4 }'`
		toupper $mac
		mac=$RET
		[ -z "$mac" ] && continue

		ip=`echo $line | awk -F\; '{ print $5 }'`
		[ -z "$ip" ] && continue

		pxe=`echo $line | awk -F\; '{ print $11 }'`
		[ -z "$pxe" ] && continue

		echo "$room;$hostname;$hostgroup;$mac;$ip;$internmask;1;1;1;1;$pxe" >> $WDATATMP

	done <$WIMPORTDATA

	# check hostnames
	hostnames=`awk -F\; '{ print $2 }' $WDATATMP`
	for i in $hostnames; do
		case $i in
			*[!a-z0-9-]*)
				exitmsg "Invalid Hostname: $i!"
				;;
			*)
				;;
		esac
		check_unique $i || exitmsg "Hostname $i is not unique!"
	done

	# check macs
	macs=`awk -F\; '{ print $4 }' $WDATATMP`
	for i in $macs; do
		validmac $i || exitmsg "Invalid MAC address: $i!"
		check_unique $i || exitmsg "MAC address $i is not unique!"
	done

	# check ips
	ips=`awk -F\; '{ print $5 }' $WDATATMP`
	for i in $ips; do
		validip $i || exitmsg "Invalid IP address: $i!"
		check_unique $i || exitmsg "IP address $i is not unique!"
	done

	echo "  * Workstation data are OK! :-)"

else

	touch $WDATATMP
	echo "  * No workstation data found! Skipping workstation import!"

fi
echo

# check, if LINBO ist installed
linbo=yes
[ -z "$LINBODIR" ] && linbo=no
[ -d "$LINBODIR" ] || linbo=no
[ -z "$LINBODEFAULTCONF" ] && linbo=no
[ -e "$LINBODEFAULTCONF" ] || linbo=no

# check dhcp stuff
[ -z "$DHCPDCONF" ] && exitmsg "Variable DHCPDCONF is not set!"
if [ -e "$DHCPDCONF" ]; then
	backup_file $DHCPDCONF || exitmsg "Unable to backup $DHCPDCONF!"
	rm -rf $DHCPDCONF || exitmsg "Unable to delete $DHCPDCONF!"
fi
touch $DHCPDCONF || exitmsg "Unable to create $DHCPDCONF!"

# read in rooms
rooms=`ls $WSHOME/`


# Check if workstation data file is empty
if [ -s "$WIMPORTDATA" ]; then

	# write configuration files and create host accounts
	echo
	while read line; do

		# read in host data
		room=`echo $line | awk -F\; '{ print $1 }'`
		tolower $room
		room=$RET
		hostname=`echo $line | awk -F\; '{ print $2 }'`
		hostgroup=`echo $line | awk -F\; '{ print $3 }'`
		mac=`echo $line | awk -F\; '{ print $4 }'`
		ip=`echo $line | awk -F\; '{ print $5 }'`
		pxe=`echo $line | awk -F\; '{ print $11 }'`
		echo "Processing host $hostname ..."

		# write dhcpd.conf entry
		echo "  * DHCP: Writing entry for $hostname ..."
		echo "host $hostname {" >> $DHCPDCONF
		echo "  hardware ethernet $mac;" >> $DHCPDCONF
		echo "  fixed-address $ip;" >> $DHCPDCONF
		echo "  option host-name \"$hostname\";" >> $DHCPDCONF
		if [[ "$pxe" != "0" && "$imaging" = "linbo" ]]; then
			echo "  filename \"pxelinux.0\";" >> $DHCPDCONF
		fi
		echo "}" >> $DHCPDCONF

		# linbo stuff, only if pxe host
		if [[ "$pxe" != "0" && "$linbo" = "yes" && "$imaging" = "linbo" ]]; then
			if [ ! -e "$LINBODIR/start.conf.$hostgroup" ]; then
				echo "  * LINBO: Creating new configuration for hostgroup $hostgroup ..."
				cp $LINBODEFAULTCONF $LINBODIR/start.conf.$hostgroup
			fi
			echo "  * LINBO: Linking IP $ip to hostgroup $hostgroup ..."
			[ -e "$LINBODIR/start.conf-$ip" ] && rm -rf $LINBODIR/start.conf-$ip
			ln -sf start.conf.$hostgroup $LINBODIR/start.conf-$ip
		fi

		# create workstation and machine accounts
		if check_id $hostname; then
			get_pgroup $hostname
			strip_spaces $RET
			pgroup=$RET
			if [ "$pgroup" != "$room" ]; then
				echo "  * Host $hostname is moving from room $pgroup to $room!"
				remove_account
				create_account
			fi
		else
			create_account
		fi

		echo

	done <$WDATATMP

fi


backup_file $PRINTERS
backup_file $CLASSROOMS
echo

# check for non-existing hosts
echo "Checking for obsolete hosts ..."
for i in $WSHOME/*/*; do

	hostname=${i##*/}
	if ! grep -qw $hostname $WDATATMP; then
		remove_account

		if grep -v ^# $PRINTERS | grep -qw $hostname; then
			remove_printeraccess $hostname
		fi
	fi

done

# check for obsolete rooms
echo
echo "Checking for obsolete rooms ..."
for room in $rooms; do

	if ! grep -qw $room $WDATATMP; then
		echo "  * Removing room: $room"
		sophomorix-groupdel --room $room &> /dev/null

		if grep -qw ^$room $CLASSROOMS; then
			echo "  * Removing $room from $CLASSROOMS ..."
			backup_classrooms=yes
			grep -wv ^$room $CLASSROOMS > $CLASSROOMS.tmp
			mv $CLASSROOMS.tmp $CLASSROOMS
		fi

		if grep -v ^# $PRINTERS | grep -qw $room; then
			remove_printeraccess $room
		fi
	fi

done

[ -z "$backup_classrooms" ] && rm ${BACKUPDIR}${CLASSROOMS}-${DATETIME}.gz
[ -z "$update_printers" ] && rm ${BACKUPDIR}${PRINTERS}-${DATETIME}.gz

# reload necessary services
echo
/etc/init.d/linuxmuster-base reload
/etc/init.d/dhcp3-server force-reload
[ -n "$update_printers" ] && import_printers

# delete tmp files
rm $WDATATMP
[ -n "$PRINTERSTMP" ] && [ -e "$PRINTERSTMP" ] && rm -rf $PRINTERSTMP
