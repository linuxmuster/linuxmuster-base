# workstation import for paedML Linux
#
# Thomas Schmitt <schmitt@lmz-bw.de>
# 14.04.2008
#
# GPL v2
#

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
	RC=1
	exit $RC
}

# checking for valid host/machine account
check_account() {
	if [ "$1" = "--all" -o "$1" = "--host" ]; then
		check_id $hostname || return 1
		smbldap-usershow $hostname &> /dev/null || return 1
	fi
	if [ "$1" = "--all" -o "$1" = "--machine" ]; then
		check_id ${hostname}$ || return 1
		smbldap-usershow ${hostname}$ &> /dev/null || return 1
	fi
	return 0
}

# create workstation and machine accounts
create_account() {
	if [ -e "$SOPHOMORIXLOCK" ]; then
		echo "Fatal! Sophomorix lockfile $SOPHOMORIXLOCK detected!"
		return 1
	fi
	echo -n "  * Creating exam account $hostname ... "
	sophomorix-useradd --examaccount $hostname --unix-group $room 2>> $TMPLOG 1>> $TMPLOG
	if ! check_account --host 2>> $TMPLOG 1>> $TMPLOG; then
	    sophomorix-kill --killuser $hostname 2>> $TMPLOG 1>> $TMPLOG
	    sophomorix-useradd --examaccount $hostname --unix-group $room 2>> $TMPLOG 1>> $TMPLOG
	fi
	if check_account --host 2>> $TMPLOG 1>> $TMPLOG; then
		echo "Ok!"
	else
		echo "sophomorix error!"
		return 1
	fi
	echo -n "  * Setting random password for $hostname ... "
	if sophomorix-passwd -u $hostname --pass $HOST_PASSWORD 2>> $TMPLOG 1>> $TMPLOG; then
		echo "Ok!"
	else
		echo "sophomorix error!"
		return 1
	fi
	[ -d "$WSHOME/$room/$hostname" ] || mkdir -p $WSHOME/$room/$hostname
	chown $hostname:$TEACHERSGROUP $WSHOME/$room/$hostname
	chmod 775 $WSHOME/$room/$hostname
	echo -n "  * Setting quota for $hostname ... "
	if sophomorix-quota -u $hostname 2>> $TMPLOG 1>> $TMPLOG; then
		echo "Ok!"
	else
		echo "sophomorix error!"
		return 1
	fi
	echo -n "  * Creating machine account ${hostname}$ ... "
	sophomorix-useradd --computer ${hostname}$ 2>> $TMPLOG 1>> $TMPLOG
	if ! check_account --machine 2>> $TMPLOG 1>> $TMPLOG; then
	    sophomorix-kill --killuser ${hostname}$ 2>> $TMPLOG 1>> $TMPLOG
	    sophomorix-useradd --computer ${hostname}$ 2>> $TMPLOG 1>> $TMPLOG
	fi
	if check_account --machine 2>> $TMPLOG 1>> $TMPLOG; then
		echo "Ok!"
	else
		echo "sophomorix error!"
		return 1
	fi
	echo -n "  * Setting machine password for ${hostname}$ ... "
	if sophomorix-passwd --force -u ${hostname}$ --pass $MACHINE_PASSWORD 2>> $TMPLOG 1>> $TMPLOG; then
		echo "Ok!"
	else
		echo "sophomorix error!"
		return 1
	fi
}

# remove workstation and machine accounts
remove_account() {
	if [ -e "$SOPHOMORIXLOCK" ]; then
		echo "Fatal! Sophomorix lockfile $SOPHOMORIXLOCK detected!"
		return 1
	fi
	echo -n "  * Removing exam account $hostname ... "
	sophomorix-kill --killuser $hostname 2>> $TMPLOG 1>> $TMPLOG
	if check_account --host 2>> $TMPLOG 1>> $TMPLOG; then
	    sophomorix-kill --killuser $hostname 2>> $TMPLOG 1>> $TMPLOG
	fi
	if check_account --host 2>> $TMPLOG 1>> $TMPLOG; then
		echo "sophomorix error!"
		return 1
	else
		echo "Ok!"
	fi
	echo -n "  * Removing machine account ${hostname}$ ... "
	sophomorix-kill --killuser ${hostname}$ 2>> $TMPLOG 1>> $TMPLOG
	if check_account --machine 2>> $TMPLOG 1>> $TMPLOG; then
	    sophomorix-kill --killuser ${hostname}$ 2>> $TMPLOG 1>> $TMPLOG
	fi
	if check_account --machine 2>> $TMPLOG 1>> $TMPLOG; then
		echo "sophomorix error!"
		return 1
	else
		echo "Ok!"
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

	# check for correct serverip in /etc/linuxmuster/linbo/pxegrub.lst.default
	if ! grep -q $serverip $PXEGRUBCFG; then
		echo -n "Fixing server ip in $PXEGRUBCFG ... "
		backup_file $PXEGRUBCFG &> /dev/null
		if sed -e "s/server=\([0-9]\{1,3\}[.]\)\{3\}[0-9]\{1,3\}/server=$serverip/" -i $PXEGRUBCFG; then
			echo "Ok!"
		else
			echo "failed!"
			RC=1
		fi
	fi

fi


# Check if workstation data file is empty
if [ -s "$WIMPORTDATA" ]; then

	# create a clean workstation data file
	echo "Checking workstation data:"
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

	echo "  * Workstation data are Ok! :-)"

else

	touch $WDATATMP
	echo "  * No workstation data found! Skipping workstation import!"

fi
echo

# check dhcp stuff
[ -z "$DHCPDCONF" ] && exitmsg "Variable DHCPDCONF is not set!"
if [ -e "$DHCPDCONF" ]; then
	backup_file $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to backup $DHCPDCONF!"
	rm -rf $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to delete $DHCPDCONF!"
fi
touch $DHCPDCONF 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to create $DHCPDCONF!"

# read in rooms
rooms=`ls $WSHOME/`


# Check if workstation data file is empty
if [ -s "$WIMPORTDATA" ]; then

	# write configuration files and create host accounts
	while read line; do

		RC_LINE=0

		# read in host data
		room=`echo $line | awk -F\; '{ print $1 }'`
		tolower $room
		room=$RET
		hostname=`echo $line | awk -F\; '{ print $2 }'`
		hostgroup=`echo $line | awk -F\; '{ print $3 }'`
		mac=`echo $line | awk -F\; '{ print $4 }'`
		ip=`echo $line | awk -F\; '{ print $5 }'`
		pxe=`echo $line | awk -F\; '{ print $11 }'`
		echo "Processing host $hostname:"

		# create workstation and machine accounts
		if check_account --all; then
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
		fi

		# linbo stuff, only if pxe host
		if [[ "$pxe" != "0" && "$imaging" = "linbo" ]]; then

			# use the default start.conf if there is none for this group
			if [ ! -e "$LINBODIR/start.conf.$hostgroup" ]; then
				echo -n "  * LINBO: Creating new start.conf.$hostgroup in $LINBODIR ... "
				if cp $LINBODEFAULTCONF $LINBODIR/start.conf.$hostgroup; then
					echo "Ok!"
				else
					echo "Error!"
					RC=1
				fi
			fi

			RC_LINE=0
			echo -n "  * LINBO: Linking IP $ip to hostgroup $hostgroup ... "

			# remove start.conf links but preserve start.conf file for this ip
			if [[ -e "$LINBODIR/start.conf-$ip" && -L "$LINBODIR/start.conf-$ip" ]]; then
				rm -rf $LINBODIR/start.conf-$ip ; RC_LINE=$?
			fi

			# create start.conf link if there is no file for this ip
			if [ ! -e "$LINBODIR/start.conf-$ip" ]; then
				ln -sf start.conf.$hostgroup $LINBODIR/start.conf-$ip ; RC_LINE=$?
			fi

			# remove pxegrub.lst links but preserve pxegrub.lst file for this ip
			if [[ -e "$LINBODIR/pxegrub.lst-$ip" && -L "$LINBODIR/pxegrub.lst-$ip" ]]; then
				rm -rf $LINBODIR/pxegrub.lst-$ip ; RC_LINE=$?
			fi

			# if there is no pxegrub.lst file for the group
			if [ ! -e "$LINBODIR/pxegrub.lst.$hostgroup" ]; then
				# create one
				cp $PXEGRUBCFG $LINBODIR/pxegrub.lst.$hostgroup ; RC_LINE=$?
				sed -e "s/\/linbofs.*/\/linbofs.$hostgroup.gz/g" -i $LINBODIR/pxegrub.lst.$hostgroup ; RC_LINE=$?
			fi

			if [ $RC_LINE -ne 0 ]; then
				echo "Error!"
				RC=1
			else
				echo "Ok!"
			fi

		fi

		# write dhcpd.conf entry
		RC_LINE=0
		echo -n "  * DHCP: Writing entry for $hostname ... "
		echo "host $hostname {" >> $DHCPDCONF ; RC_LINE=$?
		echo "  hardware ethernet $mac;" >> $DHCPDCONF ; RC_LINE=$?
		echo "  fixed-address $ip;" >> $DHCPDCONF ; RC_LINE=$?
		echo "  option host-name \"$hostname\";" >> $DHCPDCONF ; RC_LINE=$?
		if [[ "$pxe" != "0" && "$imaging" = "linbo" ]]; then
			# assign pxelinux.0 to clients which use grub.exe
			if grep ^Kernel $LINBODIR/start.conf.$hostgroup | awk -F\= '{ print $2 }' | awk '{ print $1 }' | grep -q grub.exe; then
				echo "  filename \"pxelinux.0\";" >> $DHCPDCONF ; RC_LINE=$?
			else
				echo "  filename \"/pxegrub\";" >> $DHCPDCONF ; RC_LINE=$?
				# assign ip specific pxegrub.lst if present
				if [ -e "$LINBODIR/pxegrub.lst-$ip" ]; then
			    		echo "  option configfile \"/pxegrub.lst-$ip\";" >> $DHCPDCONF ; RC_LINE=$?
				else
			    		echo "  option configfile \"/pxegrub.lst.$hostgroup\";" >> $DHCPDCONF ; RC_LINE=$?
				fi
			fi
		fi
		echo "}" >> $DHCPDCONF ; RC_LINE=$?

		if [ $RC_LINE -ne 0 ]; then
			echo "Error!"
			RC=1
		else
			echo "Ok!"
		fi

		echo

	done <$WDATATMP

fi


# creating/updateing group specific linbofs
if [ "$imaging" = "linbo" ]; then
	if [ -e "$LINBODIR/linbofs.gz" ]; then
		FOUND=0; RC_LINE=0
		echo "Processing LINBO groups:"
		# md5sum of linbo password goes into ramdisk
		linbo_passwd=`grep ^linbo /etc/rsyncd.secrets | awk -F\: '{ print $2 }'`
		[ -n "$linbo_passwd" ] && linbo_md5passwd=`echo -n $linbo_passwd | md5sum | awk '{ print $1 }'`
		# temp dir for ramdisk
		tmpdir=/var/tmp/linbofs.$$
		curdir=`pwd`
		mkdir -p /var/tmp/linbofs.$$
		cd $tmpdir
		zcat $LINBODIR/linbofs.gz | cpio -i -d -H newc --no-absolute-filenames &> /dev/null ; RC_LINE=$?
		if [ $RC_LINE -eq 0 ]; then
			[ -n "$linbo_md5passwd" ] && echo -n "$linbo_md5passwd" > etc/linbo_passwd
			for i in `awk -F\; '{ print $3 }' $WDATATMP | sort -u`; do
				RC_LINE=0
				if [ -e "$LINBODIR/start.conf.$i" ]; then
					FOUND=1
					echo -n "  * $i ... "
					# adding group to start.conf
					if grep -q ^Group $LINBODIR/start.conf.$i; then
						sed -e "s/^Group.*/Group = $i/" -i $LINBODIR/start.conf.$i ; RC_LINE=$?
					else
						sed -e "/^Server/a\
Group = $i" -i $LINBODIR/start.conf.$i ; RC_LINE=$?
					fi
					cp -f $LINBODIR/start.conf.$i start.conf ; RC_LINE=$?
					find . | cpio --quiet -o -H newc | gzip -9c > $LINBODIR/linbofs.$i.gz ; RC_LINE=$?
					echo -e "[LINBOFS]\ntimestamp=`date +%Y\%m\%d\%H\%M`\nimagesize=`ls -l $LINBODIR/linbofs.$i.gz | awk '{print $5}'`" > $LINBODIR/linbofs.$i.gz.info ; RC_LINE=$?
					if [ $RC_LINE -ne 0 ]; then
						echo "Error!"
						RC=1
					else
						echo "Ok!"
					fi
				fi
			done
		else
			echo "  * Decompressing of $LINBODIR/linbofs.gz failed!"
			RC=1; FOUND=1
		fi
		cd $curdir
		rm -rf $tmpdir
		[ "$FOUND" = "0" ] && echo "  * Nothing to do!"
	else
		echo "Error: $LINBODIR/linbofs.gz not found!"
		RC=1
	fi
fi


# myshn groups
if [ "$imaging" = "rembo" ]; then
	echo "Processing mySHN groups:"
	FOUND=0
	for i in `awk -F\; '{ print $3 " " $11 }' $WDATATMP | grep -v -w 0 | awk '{ print $1 }' | sort -u`; do
		if [ ! -e "$MYSHNDIR/groups/$i/config" ]; then
			echo -n "  * Copying default config for group $i ... "
			FOUND=1; RC_LINE=0
			if [ ! -d "$MYSHNDIR/groups/$i" ]; then
				mkdir -p $MYSHNDIR/groups/$i 2>> $TMPLOG 1>> $TMPLOG; RC_LINE="$?"
			fi
			cp $MYSHNCONFIG $MYSHNDIR/groups/$i/config 2>> $TMPLOG 1>> $TMPLOG; RC_LINE="$?"
			if [ $RC_LINE -eq 0 ]; then
				echo "Ok!"
			else
				echo "failed!"
				RC=1
			fi
		fi
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
for i in $WSHOME/*/*; do

	RC_LINE=0

	hostname=${i##*/}
	if ! grep -qw $hostname $WDATATMP; then
		FOUND=1
		remove_account; RC_LINE="$?"
		[ $RC_LINE -ne 0 ] && RC=1

		if grep -v ^# $PRINTERS | grep -qw $hostname; then
			remove_printeraccess $hostname; RC_LINE="$?"
			[ $RC_LINE -ne 0 ] && RC=1
		fi

		if grep -q ^$hostname[[:space:]] $ROOMDEFAULTS; then
			remove_defaults $hostname; RC_LINE="$?"
			[ $RC_LINE -ne 0 ] && RC=1
		fi
	fi

done
[ "$FOUND" = "0" ] && echo "  * Nothing to do!"

# check for obsolete rooms
FOUND=0
echo
echo "Checking for obsolete rooms:"
for room in $rooms; do

	RC_LINE=0

	if ! grep -qw $room $WDATATMP; then
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
			grep -wv ^$room $CLASSROOMS > $CLASSROOMS.tmp; RC_LINE=$?
			mv $CLASSROOMS.tmp $CLASSROOMS; RC_LINE=$?
			if [ $RC_LINE -ne 0 ]; then
				echo "Error!"
				RC=1
			else
				echo "Ok!"
			fi
		fi

		grep -q ^$room[[:space:]] $ROOMDEFAULTS && remove_defaults $room

		if grep -v ^# $PRINTERS | grep -qw $room; then
			remove_printeraccess $room; RC_LINE="$?"
			[ $RC_LINE -ne 0 ] && RC=1
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
