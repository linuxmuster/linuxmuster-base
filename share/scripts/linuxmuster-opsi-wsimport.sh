#!/bin/bash
#
# sync workstations with opsi
# thomas@linuxmuster.net
# 11.02.2014
#

# environment
RUNDIR="/var/tmp/wsimport.$$"
[ -e "$RUNDIR" ] && rm -rf "$RUNDIR"
mkdir -p "$RUNDIR"
if [ ! -d "$RUNDIR" ]; then
 echo "Cannot create temporary directory $RUNDIR!"
 exit 1
fi
PCKEYS="/etc/opsi/pckeys"
INIDIR="/var/lib/opsi/config/clients"
DOMAINNAME="$(dnsdomainname)"
MYHOSTNAME="$(hostname -f)"
WIMPORTDATA="/etc/opsi/workstations.lmn"
RC="0"


# functions begin

# generates runfiles
generate_runfile(){
 local action="$1"
 local pcname="$2"
 local mac="$3"
 local ip="$4"
 local RC="0"
 local cmd
 local runfile
 case "$action" in
  create)
   cmd="opsi-admin -d method host_createOpsiClient $pcname.$DOMAINNAME null $pcname \"\" $mac $ip"
   runfile="$RUNDIR/01_${action}_$pcname" ;;
  remove)
   cmd="opsi-admin -d method host_delete $pcname.$DOMAINNAME"
   runfile="$RUNDIR/00_${action}_$pcname" ;;
  *) ;;
 esac
 [ -z "$cmd" -o -z "$runfile" ] && return
 echo -n "Generating $action runfile for $pcname ..."
 cat > "$runfile" <<EOF
#!/bin/sh
RC="0"
echo -n "Running $action opsi client $pcname.$DOMAINNAME ..."
$cmd || RC="1"
if [ "\$RC" = "0" ]; then echo " OK."; else echo " Failed!"; fi
exit "\$RC"
EOF
 RC="$?"
 chmod +x "$runfile" || RC="1"
 if [ "$RC" = "0" ]; then echo " OK."; else echo " Failed!"; fi
 return "$RC"
}

# functions end


# iterate over client names
grep ^[a-z0-9] "$WIMPORTDATA" | while read data; do

 # filter out clients not scheduled for opsi
 pxe="$(echo "$data" | awk -F\; '{ print $11 }')"
 [ "$pxe" = "2" -o "$pxe" = "3" ] || continue

 pcname="$(echo "$data" | awk -F\; '{ print $2 }')"

 # not the opsi server himself
 [ "$MYHOSTNAME" = "$pcname.$DOMAINNAME" ] && continue

 mac="$(echo "$data" | awk -F\; '{ print $4 }' | tr A-Z a-z)"
 ip="$(echo "$data" | awk -F\; '{ print $5 }' | tr A-Z a-z)"
 inifile="$INIDIR/$pcname.$DOMAINNAME.ini"
 # remove opsi clients whose mac or ip address has changed
 # note: this client has to be synchronized with linbo afterwards to get new key and current opsi status
 if [ -e "$inifile" ]; then
  RCTMP="0"
  CHANGED=""
  if ! grep ^hardwareaddress "$inifile" | grep -qi "$mac"; then
   echo "MAC address of client $pcname has changed!"
   CHANGED="yes"
  elif ! grep ^ipaddress "$inifile" | grep -q "$ip"; then
   echo "IP address of client $pcname has changed!"
   CHANGED="yes"
  fi
  if [ -n "$CHANGED" ]; then
   generate_runfile remove "$pcname" || RCTMP="1"
   generate_runfile create "$pcname" "$mac" "$ip" || RCTMP="1"
   [ "$RCTMP" = "0" ] || RC="1"
  fi
 fi

 # test for client not yet in opsi and generate a runfile if he has to be imported
 RCTMP="0"
 grep -qwi ^"$pcname" "$PCKEYS" || generate_runfile create "$pcname" "$mac" "$ip" ; RCTMP="$?"
 [ "$RCTMP" = "0" ] || RC="1"

done

# remove clients which are not in workstations file and generate runfiles for them
pcs=$(grep ^[a-zA-Z0-9] "$WIMPORTDATA" | awk -F\; '{ print $2, $11 }' | grep " [23]" | awk '{ print $1 }')
for pcname in $(grep ^[a-zA-Z0-9] "$PCKEYS" | awk -F \. '{ print $1 }' | tr A-Z a-z); do

 # again, do not process the opsi server himself
 [ "$MYHOSTNAME" = "$pcname.$DOMAINNAME" ] && continue

 RCTMP="0"
 echo "$pcs" | grep -qwi "$pcname" || generate_runfile remove "$pcname" ; RCTMP="$?"
 [ "$RCTMP" = "0" ] || RC="1"

done

# finally run generated scripts
if ls "$RUNDIR"/* &> /dev/null; then
 run-parts "$RUNDIR" || RC="1"
fi
rm -rf "$RUNDIR"

exit "$RC"
