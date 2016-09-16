# workstation import for linuxmuster.net
#
# Thomas Schmitt <thomas@linuxmuster.net>
# 13.06.2016
# GPL v3
#

DB10TMP=/var/tmp/db10.$$
DBREVTMP=/var/tmp/dbrev.$$
SERVERNET="${srvnetip}/${SUBNETBITMASK}"
SRVNETLINE="$SERVERNET;$srvnetgw;;;0;0"

RC=0


### functions begin ###

# check for unique entry: check_unique <item1 item2 ...>
check_unique() {
 printf '%s\n' $1 | sort | uniq -c -d
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


# write subnet definition to dhcp configuration
# write_dhcp_subnet <network ip> <bitmask> <subnet data line> <room>
write_dhcp_subnet(){
 local vnetid="$1"
 local vnetpre="$2"
 local line="$3"
 local msg="Subnet $vnetid/$vnetpre"
 local vrouter="$(echo $line | awk -F\; '{ print $2 }')"
 local vfirstip="$(echo $line | awk -F\; '{ print $3 }')"
 local vlastip="$(echo $line | awk -F\; '{ print $4 }')"
 local vnetmask="$(ipcalc -b "$vnetid/$vnetpre" | grep ^Netmask | awk '{ print $2 }')"
 local vbroadcast="$(ipcalc -b "$vnetid/$vnetpre" | grep ^Broadcast | awk '{ print $2 }')"
 # write new subnet in DHCP-configuration
 echo "# $msg"
 echo "subnet $vnetid netmask $vnetmask {"
 echo "  option routers $vrouter;"
 echo "  option subnet-mask $vnetmask;"
 echo "  option broadcast-address $vbroadcast;"
 echo "  option netbios-name-servers $serverip;"
 [ -n "$vfirstip" -a -n "$vlastip" ] && echo "  range $vfirstip $vlastip;"
 echo "  option host-name "pxeclient";"
 echo "}"
}


# test for subnet defined in $SUBNETDATA
# if no subnet for an ip is defined add it to $SUBNETDATA
test_subnet(){
 local ip="$1"
 local testonly="$2"
 local line
 local netid
 local vnetwork
 local vnetid
 local vnetpre
 local vgateway
 local conf
 # handle servernet
 vnetwork="$(ipcalc -b "$ip"/"$SUBNETBITMASK" | grep ^Network | awk '{ print $2 }')"
 if [ "$vnetwork" = "$SERVERNET" ]; then
  vnetid="$(echo $vnetwork | awk -F\/ '{ print $1 }')"
  conf="$DHCPDCACHE/subnet_$vnetid"
  [ "$testonly" = "1" ] || write_dhcp_subnet "$srvnetip" "$SUBNETBITMASK" "$SRVNETLINE" "$room" > "$conf"
  echo "$vnetwork"
  return
 fi
 for line in `sort -b -d -t';' -k1 $SUBNETDATA | grep ^[a-zA-Z0-9]`; do
  vnetwork="$(echo $line | awk -F\; '{ print $1 }')"
  vnetid="$(echo $vnetwork | awk -F\/ '{ print $1 }')"
  vnetpre="$(echo $vnetwork | awk -F\/ '{ print $2 }')"
  netid="$(ipcalc -b "$ip"/"$vnetpre" | grep ^Network | awk '{ print $2 }' | awk -F\/ '{ print $1 }')"
  if [ "$netid" = "$vnetid" ]; then
   conf="$DHCPDCACHE/subnet_$vnetid"
   # subnet definition exists
   [ "$testonly" = "1" ] || write_dhcp_subnet "$vnetid" "$vnetpre" "$line" "$room" > "$conf"
   echo "$vnetwork"
   return
  fi
 done
 if [ "$testonly" != "1" ]; then
  # subnet definition does not yet exist
  vnetid="$(ipcalc -b "$ip"/"$SUBNETBITMASK" | grep ^Network | awk '{ print $2 }' | awk -F\/ '{ print $1 }')"
  vgateway="$(ipcalc -b "$ip"/"$SUBNETBITMASK" | grep ^HostMax | awk '{ print $2 }' | awk -F\/ '{ print $1 }')"
  vnetwork="$vnetid/$SUBNETBITMASK"
  line="$vnetwork;$vgateway;;;0;0"
  conf="$DHCPDCACHE/subnet_$vnetid"
  write_dhcp_subnet "$vnetid" "$SUBNETBITMASK" "$line" > "$conf"
  echo "$vnetwork"
  # write subnet definition to $SUBNETDATA (if it is not the servernet)
  if [ "$SERVERNET" != "$vnetwork" ]; then
   echo "# Subnet $room" >> "$SUBNETDATA"
   echo "$line" >> "$SUBNETDATA"
  fi
  return
 fi
}


# sets serverip in start.conf
set_serverip(){
 local conf="$LINBODIR/start.conf.$1"
 local serverip="$2"
 local RC="0"
 grep -qi ^"server = $serverip" $conf && return "$RC"
 if grep -qwi ^server $conf; then
  sed -e "s/^[Ss][Ee][Rr][Vv][Ee][Rr].*/Server = $serverip/" -i $conf || RC="1"
 else
  sed -e "/^\[LINBO\]/a\
Server = $serverip" -i $conf || RC="1"
 fi
 return "$RC"
}


# sets group in start.conf
set_group(){
 local group="$1"
 local conf="$LINBODIR/start.conf.$group"
 local RC="0"
 grep -qi ^"Group = $group" $conf && return "$RC"
 if grep -qwi ^group $conf; then
  sed -e "s/^[Gg][Rr][Oo][Uu][Pp].*/Group = $group/" -i $conf || RC="1"
 else
  sed -e "/^Server/a\
Group = $group" -i $conf || RC="1"
 fi
 return "$RC"
}

# get systemtype from start.conf
get_systemtype(){
 local group="$1"
 local conf="$LINBODIR/start.conf.$group"
 [ -e "$conf" ] || return 1
 grep -iw ^systemtype "$conf" | tail -1 | awk -F\= '{ print $2 }' | awk '{ print $1 }'
}

# deprecated because of grub2
# get reboot option from start.conf
#get_reboot(){
# local conf="$LINBODIR/start.conf.$1"
# if [ -e "$conf" ]; then
#  grep -iw ^kernel "$conf" | grep -qiw reboot && return 0
# fi
# return 1
#}

# compute and print grub2 compliant disk name
# args: partition
grubdisk(){
 local partition="$1"
 local partnr="$(echo "$partition" | sed -e 's|/dev/[hsv]d[abcdefgh]||' -e 's|/dev/xvd[abcdefgh]||' -e 's|/dev/mmcblk[0-9]p||')"
 case "$partition" in
  /dev/mmcblk*) local disknr="$(echo "$partition" | sed 's|/dev/mmcblk\([0-9]\)p[1-9]|\1|')" ;;
  *:*|*//*|*\\\\*) echo "nocache" ; return 0 ;; # remote cache, no local cache, no cache partition
  *)
   local ord="$(printf "$(echo $partition | sed 's|/dev/*[hsv]d\([a-z]\)[0-9]|\1|')" | od -A n -t d1)"
   local disknr=$(( $ord - 97 ))
   ;;
 esac
 echo "(hd${disknr},${partnr})"
}

# sets pxe config file, params: group kopts
set_pxeconfig(){
 local group="$1"
 local kopts="$2"
 local RC="0"
 local startconf="$LINBODIR/start.conf.$group"
 local targetconf="$LINBODIR/boot/grub/$group.cfg"
 local globaltpl="$LINBOTPLDIR/grub.cfg.global"
 local cache="$(grep -i ^cache /$startconf | tail -1 | awk -F\= '{ print $2 }' | awk '{ print $1 }' 2> /dev/null)"
 local cacheroot="$(grubdisk "$cache" "$group")"
 local ostpl
 local ostype
 if ([ -s "$targetconf" ] && ! grep -q "$MANAGEDSTR" "$targetconf"); then
  echo -e "\tkeeping pxe config."
  return 0
 fi

 # create gobal part for group cfg
 echo -e "\twriting pxe config."
 sed -e "s|@@group@@|$group|g
         s|@@cacheroot@@|$cacheroot|g
         s|@@kopts@@|$kopts|g" "$globaltpl" > "$targetconf" || RC="1"

 # collect boot parameters from start.conf and write os parts for group cfg
 local line
 local partnr
 local root
 local name
 local osroot
 local kernel
 local initrd
 local append
 local ostpl="$LINBOTPLDIR/grub.cfg.os"
 local osnr=0
 echo "[EOF]" | cat "$startconf" - | grep -v '^$\|^\s*\#' | awk -F\# '{ print $1 }' | sed -e 's|^ *||g' -e 's| *$||g' -e 's| =|=|g' -e 's|= |=|g' | while read line; do
  if [ "${line:0:1}" = "[" ]; then
   if [ -n "$kernel" ]; then
    osnr=$((osnr + 1))
    if [ "$kernel" = "reboot" ]; then
     kernel="nokernel_placeholder"
    else
     kernel="$(echo $kernel | sed 's|^\/||')"
    fi
    if [ -z "$initrd" ]; then
     initrd="noinitrd_placeholder"
    else
     initrd="$(echo $initrd | sed 's|^\/||')"
    fi
    # convert partition to grub syntax
    osroot="$(grubdisk "$root" "$group")"
    # computer partition number from start.conf
    partnr="$(grep -i ^dev "$startconf" | grep -n "$root" | awk -F\: '{ print $1 }')"
    # get ostype from osname
    case "$(echo "$name" | tr A-Z a-z)" in
     *windows*) ostype="win" ;;
     *kubuntu*) ostype="kubuntu" ;;
     *lubuntu*) ostype="lubuntu" ;;
     *xubuntu*) ostype="xubuntu" ;;
     *ubuntu*|*trusty*|*wily*) ostype="ubuntu" ;;
     *centos*) ostype="centos" ;;
     *arch*) ostype="arch" ;;
     *linuxmint*) ostype="linuxmint" ;;
     *fedora*) ostype="fedora" ;;
     *gentoo*) ostype="gentoo" ;;
     *debian*) ostype="debian" ;;
     *suse*) ostype="opensuse" ;;
     *linux*) ostype="linux" ;;
     *) ostype="unknown" ;;
    esac
    # create config from template
    sed -e "s|@@osnr@@|$osnr|g
            s|@@kernel@@|$kernel|g
            s|@@initrd@@|$initrd|g
            s|@@append@@|$append|g
            s|@@partition@@|$root|g
            s|@@partnr@@|$partnr|g
            s|@@osroot@@|$osroot|g
            s|@@osname@@|$name|g
            s|@@ostype@@|$ostype|g
            s|@@group@@|$group|g
            s|@@cacheroot@@|$cacheroot|g
            s|@@kopts@@|$kopts|g" "$ostpl" >> "$targetconf" || RC="1"
   fi
   name=""; root=""; kernel=""; initrd=""; append=""; osroot=""; ostype=""
   continue
  fi
  case "$line" in
   [Nn][Aa][Mm][Ee]=*) name="$(echo $line | awk -F\= '{ print $2 }')" ;;
   [Aa][Pp][Pp][Ee][Nn][Dd]=*) append="$(echo $line | sed s'|^[Aa][Pp][Pp][Ee][Nn][Dd]=||')" ;;
   [Rr][Oo][Oo][Tt]=*|[Kk][Ee][Rr][Nn][Ee][Ll]=*|[Ii][Nn][Ii][Tt][Rr][Dd]=*) eval "$(echo $line | tr A-Z a-z)" ;;
  esac
 done

 return "$RC"
}


# process configs for pxe hosts
do_pxe(){
 local group="$1"
 local ip="$2"
 local RC="0"
 local server=""
 local kopts=""
 # copy default start.conf if there is none for this group
 if [ ! -e "$LINBODIR/start.conf.$group" ]; then
  echo "    Creating new linbo group $group."
  cp "$LINBODEFAULTCONF" "$LINBODIR/start.conf.$group" || RC="2"
 fi

 # process start.conf and pxelinux configfile for group
 if ! echo "$groups_processed" | grep -qwi "#${group}#"; then
  echo -en " * LINBO-Group\t$group"
  groups_processed="$groups_processed #${group}#"
  # get kernel options from start.conf
  kopts="$(linbo_kopts "$LINBODIR/start.conf.$group")"
  # get custom serverip from kernel opts if set
  if echo "$kopts" | grep -qw server; then
   for i in $kopts; do eval "$i" &> /dev/null; done
  fi
  # set custom server ip in start.conf if defined in kernel opts
  if validip "$server"; then
   set_serverip "$group" "$server" || RC="2"
  else # set default server ip
   set_serverip "$group" "$serverip" || RC="2"
  fi
  # set group in start.conf
  set_group "$group" || RC="2"
  # provide grub2 pxe configfile for group
  set_pxeconfig "$group" "$kopts" || RC="2"
 fi

 # create start.conf link for host
 ln -sf "start.conf.$group" "$LINBODIR/start.conf-$ip" || RC="1"
 # deprecated because of grub2
 # create pxelinux cfg link for host
# local hostip="$(gethostip -x "$ip")" || RC="1"
# if [ -n "$hostip" ]; then
#  ln -sf "$group" "$PXECFGDIR/$hostip" || RC="1"
# fi
 case "$RC" in
  1) echo "   ERROR in pxe host configuration!" ;;
  2) echo "   ERROR in pxe group configuration!" ;;
  *) ;;
 esac
 return "$RC"
}

# write dhcpd.conf file for host
write_dhcp_host() {
 local hostname="$1"
 local hostgroup="$2"
 local ip="$3"
 local mac="$4"
 local pxe="$5"
 echo "host $ip {"
 echo "  hardware ethernet $mac;"
 echo "  fixed-address $ip;"
 echo "  option host-name \"$hostname\";"
 # do not evaluate opsi pxe boot if opsiip is not set
 [ "$pxe" = "3" -a -z "$opsiip" ] && pxe="1"
 case "$pxe" in
  1|2|22)
   # inform grub about hostgroup
   echo "  option extensions-path \"${hostgroup}\";"
   # bootfiles for efi netboot
   local systemtype="$(get_systemtype "$hostgroup")"
   if [ "$systemtype" = "efi64" ]; then
    echo "  filename \"boot/grub/x86_64-efi/core.efi\";"
   elif [ "$systemtype" = "efi32" ]; then
    echo "  filename \"boot/grub/i386-efi/core.efi\";"
   fi
  ;;
  3)
   echo "  next-server $opsiip;"
   echo "  filename \"$OPSIPXEFILE\";"
  ;;
  *) ;;
 esac
 echo "}"
}

### functions end ###


# adding new host entries from LINBO's registration
if ls $LINBODIR/*.new &> /dev/null; then
 for i in $LINBODIR/*.new; do
  if [ -s "$i" ]; then
   hostname="$(basename "$i" | sed 's|.new||')"
   echo "Importing new host $hostname:"
   cat $i
   echo
   cat $i >> $WIMPORTDATA
  fi
  rm -f $i
 done
fi


# case repair for workstation data
# all to lower case, macs to upper case
sed -e 's/\(^[A-Za-z0-9].*\)/\L\1/
        s/\([a-fA-F0-9]\{2\}[:][a-fA-F0-9]\{2\}[:][a-fA-F0-9]\{2\}[:][a-fA-F0-9]\{2\}[:][a-fA-F0-9]\{2\}[:][a-fA-F0-9]\{2\}\)/\U\1/g' -i "$WIMPORTDATA"


# check workstation data
echo "Checking workstation data ..."
# rooms
rooms="$(grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F\; '{ print $1 }' | sort -u)"
for i in $rooms; do
 check_string "$i" || exitmsg "$i is no valid room name!"
done
# rooms;ips
roomsips="$(grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F\; '{ print $1";"gensub(".[[:digit:]]+","",4,$5) }' | sort -u)"
for i in $roomsips; do
 r=$(echo $i|awk -F\; '{ print $1 }')
 n=$(echo $roomsips|tr ' ' '\n'|grep ^"$r;" | wc -l)
 ips=$(echo $roomsips|tr ' ' '\n'|grep ^"$r;"| cut -d\; -f2| tr '\n' ' ')
 [ $n -eq 1 ] || echo "WARNING: room $r has multiple ip ranges $ips!"
done

# hostgroups
hostgroups="$(grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F\; '{ print "#"$3"#" }' | sort -u)"
echo "$hostgroups" | grep -q "##" && exitmsg "Empty hostgroup found! Check your data!"
hostgroups="${hostgroups//#/}"
for i in $hostgroups; do
 check_string "$i" || exitmsg "$i is no valid hostgroup name!"
done

# hostnames, one host can have two entries with different macs (wired and wlan)
hostnames="$(grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F\; '{ print "#"$2"#" }')"
echo "$hostnames" | grep -q "##" && exitmsg "Empty hostname found! Check your data!"
hostnames="${hostnames//#/}"
for i in $hostnames; do
 validhostname "$i" || exitmsg "$i is no valid hostname!"
done
check_unique "$hostnames" | while read line; do
 i="$(echo $line | awk '{ print $2 }')"
 # check ips for hostname
 get_ip "$i"
 [ -n "$(check_unique "$RET")" ] && exitmsg "Ips for host $i are not unique: $RET!"
 # check macs for hostname
 get_mac "$i"
 [ -n "$(check_unique "$RET")" ] && exitmsg "Macs for host $i are not unique: $RET!"
done

# macs
macs="$(grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F\; '{ print "#"$4"#" }')"
echo "$macs" | grep -q "##" && exitmsg "Empty mac address found! Check your data!"
macs="${macs//#/}"
for i in $macs; do
 validmac "$i" || exitmsg "$i is no valid mac address!"
done
RET="$(check_unique "$macs")"
[ -n "$RET" ] && exitmsg "Not unique mac(s) detected: $RET!"

# ips
ips="$(grep ^[a-zA-Z0-9] $WIMPORTDATA | awk -F\; '{ print "#"$5"#" }')"
echo "$ips" | grep -q "##" && exitmsg "Empty ip address found! Check your data!"
ips="${ips//#/}"
for i in $ips; do
 validip "$i" || exitmsg "$i is no valid host ip address!"
done
RET="$(check_unique "$ips")"
[ -n "$RET" ] && exitmsg "Not unique ip(s) detected: $RET!"


# tests are done
echo " Ok!"
echo

# check subnet data
if [ "$subnetting" = "true" ]; then
 echo "Checking subnet data."
 for line in `grep ^[a-zA-Z0-9] $SUBNETDATA`; do
  vnetwork="$(echo $line | awk -F\; '{ print $1 }')"
  vnetreal="$(ipcalc -b $vnetwork | grep ^Network | awk '{ print $2}')"
  vnetpre="$(echo $vnetreal | awk -F\/ '{ print $2 }')"
  # if network matches servernet warn and comment out subnet declaration
  if [ "$vnetreal" = "$(ipcalc -b ${serverip}/${vnetpre} | grep ^Network | awk '{ print $2}')" ]; then
   echo " * WARNING: Subnet $vnetwork matches server subnet!"
   sed -e "s|^$vnetwork|### NOT SUPPORTED ###${vnetwork}|" -i "$SUBNETDATA"
   subwarn=yes
   continue
  fi
  # test if gateway address matches subnet
  vnetgw="$(echo $line | awk -F\; '{ print $2 }')"
  if [ "$vnetreal" != "$(ipcalc -b ${vnetgw}/${vnetpre} | grep ^Network | awk '{ print $2}')" ]; then
   echo " * WARNING: Subnet gateway $vnetgw does not match subnet $vnetwork!"
   sed -e "s|^$vnetwork|### NOT SUPPORTED ###${vnetwork}|" -i "$SUBNETDATA"
   subwarn=yes
   continue
  fi
  # test if first range address matches subnet
  vnetfirst="$(echo $line | awk -F\; '{ print $3 }')"
  if [ -n "$vnetfirst" -a "$vnetreal" != "$(ipcalc -b ${vnetfirst}/${vnetpre} | grep ^Network | awk '{ print $2}')" ]; then
   echo " * WARNING: First range address $vnetfirst does not match subnet $vnetwork!"
   sed -e "s|^$vnetwork|### NOT SUPPORTED ###${vnetwork}|" -i "$SUBNETDATA"
   subwarn=yes
   continue
  fi
  # test if last range address matches subnet
  vnetlast="$(echo $line | awk -F\; '{ print $4 }')"
  if [ -n "$vnetlast" -a "$vnetreal" != "$(ipcalc -b ${vnetlast}/${vnetpre} | grep ^Network | awk '{ print $2}')" ]; then
   echo " * WARNING: Last range address $vnetlast does not match subnet $vnetwork!"
   sed -e "s|^$vnetwork|### NOT SUPPORTED ###${vnetwork}|" -i "$SUBNETDATA"
   subwarn=yes
   continue
  fi
 done
 if [ -z "$subwarn" ]; then
  echo " * Subnet data are Ok!"
 else
  echo " * Note: One or more subnet declarations have been deactivated!"
  RC="1"
 fi
 echo
fi

# restore acls for room groups (exam accounts) on $SHAREHOME
"$SCRIPTSDIR/room_share_acl.sh" --allow || RC="1"
echo

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


# withdraw access rights for rooms (exam accounts) on $SHAREHOME
echo
"$SCRIPTSDIR/room_share_acl.sh" --deny || RC="1"
echo


# remove host entries from bind config
backup_file $DB10 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to backup $DB10!"
backup_file $DBREV 2>> $TMPLOG 1>> $TMPLOG || exitmsg "Unable to backup $DBREV!"
echo >> $TMPLOG
removefrom_file $DB10 "$BEGINSTR" "$ENDSTR"
removefrom_file $DBREV "$BEGINSTR" "$ENDSTR"
echo ";$BEGINSTR" > $DB10TMP
echo ";$BEGINSTR" > $DBREVTMP


# remove linbo/pxe links
echo -n "Removing old links under $LINBODIR ... "
find "$LINBODIR" -name "start.conf-*" -type l -exec rm '{}' \;
# deprecated because of grub2
#for i in $PXECFGDIR/*; do
# if [ -L "$i" ] && [[ "$(basename $i)" =~ [A-F0-9]{4} ]]; then rm "$i"; fi
#done
echo "Done!"
echo


# test for dhcp conf cache dir and clean it up
[ -e "$DHCPDCACHE" -a ! -d "$DHCPDCACHE" ] && rm -rf "$DHCPDCACHE"
mkdir -p "$DHCPDCACHE"
[ -d "$DHCPDCACHE" ] || exitmsg "Missing directory $DHCPDCACHE!"
rm -rf "$DHCPDCACHE"/*


# process host and subnet data at least
[ "$subnetting" = "true" ] && subnetmsg=" and subnet"
echo "Processing workstation${subnetmsg} data:"
vnetwork=""
groups_processed=""
sort -b -d -t';' -k5 $WIMPORTDATA | grep ^[a-z0-9] | while read line; do

 # get data from line
 room="$(echo "$line" | awk -F\; '{ print $1 }')"
 hostname="$(echo "$line" | awk -F\; '{ print $2 }')"
 hostgroup="$(echo "$line" | awk -F\; '{ print $3 }')"
 hostgroup="$(echo "$hostgroup" | awk -F\, '{ print $1 }')"
 mac="$(echo "$line" | awk -F\; '{ print $4 }')"
 ip="$(echo "$line" | awk -F\; '{ print $5 }')"
 pxe="$(echo "$line" | awk -F\; '{ print $11 }')"

 # if subnetting is set handle subnet dhcp entries
 if [ "$subnetting" = "true" -a "$vnetwork" != "$(test_subnet "$ip" 1)" ]; then
  # assign changed vnet id
  vnetwork="$(test_subnet "$ip")"
  echo -e " * Subnet\t$vnetwork."
 fi

 # write dhcpd.conf entries for hosts
 case "$pxe" in
  1|2|3|22)
   # process linbo pxe configs
   do_pxe "$hostgroup" "$ip" || RC="1"
   echo -en " * PXE" ;;
  *) echo -en " * IP" ;;
 esac
 conf="$DHCPDCACHE/host_$ip"
 write_dhcp_host "$hostname" "$hostgroup" "$ip" "$mac" "$pxe" > "$conf"
 echo -e "-Host\t$ip\t$hostname."

 # write bind config
 okt2="$(echo $ip | awk -F. '{ print $2 }')"
 okt3="$(echo $ip | awk -F. '{ print $3 }')"
 okt4="$(echo $ip | awk -F. '{ print $4 }')"
 echo "$okt4.$okt3.$okt2 PTR $hostname.`dnsdomainname`." >> $DB10TMP
 echo "$hostname A $ip" >> $DBREVTMP

done

# finalize bind config
echo ";$ENDSTR" >> $DB10TMP
echo ";$ENDSTR" >> $DBREVTMP
cat "$DB10TMP" >> "$DB10"
cat "$DBREVTMP" >> "$DBREV"
rm $DB10TMP
rm $DBREVTMP


# finalize subnets and concenate cached dhcpd conf files
rm -f "$DHCPDCONF"
touch "$DHCPDCONF"
if [ "$subnetting" = "true" ]; then
 # do subnets not handled yet (incl. servernet)
 for line in `grep ^[a-zA-Z0-9] $SUBNETDATA` "$SRVNETLINE"; do
  vnetwork="$(echo $line | awk -F\; '{ print $1 }')"
  vnetid="$(echo $vnetwork | awk -F\/ '{ print $1 }')"
  vnetpre="$(echo $vnetwork | awk -F\/ '{ print $2 }')"
  conf="$DHCPDCACHE/subnet_$vnetid"
  if [ ! -e "$conf" ]; then
   echo -e " * Subnet\t${vnetwork}."
   write_dhcp_subnet "$vnetid" "$vnetpre" "$line" > "$conf"
  fi
 done
 # concenate subnet definitions
 ls "$DHCPDCACHE"/subnet_* &> /dev/null && cat "$DHCPDCACHE"/subnet_* > "$DHCPDCONF"
fi
# concenate host definitions
ls "$DHCPDCACHE"/host_* &> /dev/null && cat "$DHCPDCACHE"/host_* >> "$DHCPDCONF"
echo


# backup config files to be modified
#echo
backup_file $PRINTERS &> /dev/null
backup_file $CLASSROOMS &> /dev/null
backup_file $ROOMDEFAULTS &> /dev/null


# remove hosts which are no more defined in workstations file
FOUND=0
echo "Looking for orphaned host entries:"
# room_defaults
hosts="$(grep ^[a-zA-Z0-9] $ROOMDEFAULTS | awk '{ print $1 }' | tr A-Z a-z)"
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
echo "Looking for orphaned room entries:"
# classrooms
rooms="$(grep ^[a-zA-Z0-9] $CLASSROOMS | awk '{ print $1 }' | tr A-Z a-z)"
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
rooms="$(grep ^[a-zA-Z0-9] $ROOMDEFAULTS | awk '{ print $1 }' | tr A-Z a-z)"
for room in $rooms; do
 # skip default
 [ "$room" = "default" ] && continue
 # skip other entries which are not rooms
 grep ^[a-zA-Z0-9] $WIMPORTDATA | grep -q \;$room\; && continue
 if ! awk -F\; '{ print $1 }' $WIMPORTDATA | sort -u | grep ^[a-zA-Z0-9] | grep -qw "${room}"; then
  FOUND=1
  remove_defaults $room ; RC_LINE="$?"
  [ $RC_LINE -eq 0 ] || RC=1
 fi
done
# printers
rooms="$(grep ^[a-zA-Z0-9] $PRINTERS | awk '{ print $2 }' | grep ^[a-z0-9] | sed -e 's|,| |g')"
for room in $rooms; do
 if ! awk -F\; '{ print $1 }' $WIMPORTDATA | sort -u | grep -qw "${room}"; then
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
echo " * Reloading internal firewall ..."
if restart-fw --int 1> /dev/null; then
 echo "   ...done."
else
 echo "   ...failed!"
 RC=1
fi

echo " * Reloading external firewall ..."
# first create and upload custom firewall stuff
if ! fw_do_custom; then
 echo "   ...failed!"
 RC=1
else # update external fw
 if restart-fw --ext 1> /dev/null; then
  echo "   ...done."
 else
  echo "   ...failed!"
  RC=1
 fi
fi

# name service at least
/etc/init.d/bind9 force-reload || RC=1

# opsi stuff (do not during migration)
if [ -n "$opsiip" -a ! -e /tmp/.migration ]; then
 linuxmuster-opsi --wsimport --quiet || RC=1
fi

# printer stuff
[ -n "$update_printers" ] && import_printers
[ -n "$PRINTERSTMP" -a -e "$PRINTERSTMP" ] && rm -rf "$PRINTERSTMP"


# exit with return code
exit $RC

