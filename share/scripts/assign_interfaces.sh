#!/bin/sh
#
# creates a script to assign mac addresses to interfaces
# 07.03.2006
# Thomas Schmitt <schmitt@lmz-bw.de>

# source linuxmuster defaults
. /usr/share/linuxmuster/config/dist.conf || exit 1

# source helperfunctions
. $HELPERFUNCTIONS || exit 1

# parsing parameters
getopt $*

usage() {
  echo
  echo "Usage: assign_interfaces.sh --type=<integrated|dedicated>"
  echo "                            --outfile=<path_to_outfile>"
  echo
  exit 1
}

# test parameters
[[ "$type" != "integrated" && "$type" != "dedicated" ]] && usage
[[ -z "$outfile" ]] && usage
touch $outfile || cancel "Cannot write $outfile!"

# dialog defaults
backtitle="Linux-Musterloesung 3.0 - Installation"
title="Netzwerkkarten konfigurieren"
tstamp="$(date +%d.%m.%Y) $(date +%H:%M:%S)"
answer=/tmp/answer.$$

# discover ethernet interfaces
n=0
for i in /sys/class/net/eth* /sys/class/net/wlan* /sys/class/net/intern /sys/class/net/extern /sys/class/net/dmz; do
  [ -e $i/address ] || continue
  address[$n]=`head -1 $i/address` || continue
  if [ `expr length ${address[$n]}` -ne "17" ]; then
    continue
  else
    id=`ls -1 -d $i/device/driver/0000:* 2> /dev/null`
    id=`echo $id | awk '{ print $1 }' -`
    id=${id#$i/device/driver/}
    if [ -n "$id" ]; then
      tmodel=`lspci | grep $id | awk -F: '{ print $4 $5 }' -`
      tmodel=`expr "$tmodel" : '[[:space:]]*\(.*\)[[:space:]]*$'`
      tmodel=${tmodel// /_}
      model[$n]=${tmodel:0:38}
    else
      model[$n]="Unrecognized Ethernet Controller Device"
    fi
  fi
  let n+=1
done
nr_of_devices=$n

# cancel installation
cancel_assign() {
  dialog --clear \
         --backtitle "$title" \
         --title "Installation abbrechen" \
         --yesno "\nWollen Sie die Installation wirklich abbrechen?" 7 52

  retval=$?

  case $retval in
    1)
      return ;;
    *)
      exit 1 ;;
  esac
} # cancel

# dialog to assign devices and macs
assign_integrated() {
  n=`cat $answer`
  dialog --backtitle "$backtitle" \
         --title "$title" \
         --clear \
         --ok-label "Auswaehlen" \
         --cancel-label "Abbrechen" \
         --menu "\nWaehlen Sie fuer diese Netzwerkkarte den Netzwerk-Typ:\n\
${model[$n]} ${address[$n]}" 16 76 5 \
  "e" "extern (ROT)" \
  "i" "intern (GRUEN)" \
  "w" "wlan (BLAU)" \
  "d" "dmz (ORANGE)" \
  "x" "keine Zuordnung" 2> $answer
  retval=$?

  case $retval in
    0)
      a=`cat $answer`
      case $a in
        e)
          typ[$n]=extern ;;
        i)
          typ[$n]=intern ;;
        w)
          typ[$n]=wlan ;;
        d)
          typ[$n]=dmz ;;
        x)
          typ[$n]="" ;;
      esac
      ;;
    *)
      ;;
  esac
}

check_input_integrated() {
  # check double entries and if extern and intern devices are present
  # wlan and dmz are optional
  extern=no; intern=no
  for i in extern intern wlan; do
    n=0; c=0
    while [[ $n -lt $nr_of_devices ]]; do
      if [ "${typ[$n]}" = "$i" ]; then
        let c+=1
        [ "$i" = "extern" ] && extern=yes
        [ "$i" = "intern" ] && intern=yes
      fi
      [[ $c -eq 2 ]] && return
      let n+=1
    done
  done
  [ "$extern" = "yes" ] && [ "$intern" = "yes" ] && input_ok=0
}

menu_integrated() {
  input_ok=1
  while [ $input_ok -ne 0 ]; do
    dialog --backtitle "$backtitle" \
           --title "$title" \
           --ok-label "Aendern" \
           --cancel-label "Abbrechen" \
           --extra-button \
           --extra-label "Weiter" \
           --clear \
           --menu "\nAendern Sie die Zuordnung der Netzwerkkarten zu\n\
extern, intern und ggf. wlan und dmz.\n\
Es muessen mindestens ein externes und ein internes Device definiert sein." 16 76 $nr_of_devices \
$( n=0; while [[ $n -lt $nr_of_devices ]]; do echo -e "$n ${model[$n]}\\240${address[$n]}\\240${typ[$n]}"; n=$(( $n+1 )); done ) 2> $answer
    retval=$?

    case $retval in
      0)
        assign_integrated
        ;;
      3)
        check_input_integrated
        ;;
      *)
        cancel_assign
        ;;
    esac
  done
}

menu_dedicated() {
  # dialog to choose intern device
  dialog --backtitle "$backtitle" \
         --title "$title" \
         --ok-label "Auswaehlen" \
         --cancel-label "Abbrechen" \
         --menu "\nEs wurden mehrere Netzwerkkarten in Ihrem System gefunden.\n\
Waehlen Sie die Netzwerkkarte aus, die mit dem internen Schulnetz verbunden ist." 16 76 $nr_of_devices \
$( n=0; while [[ $n -lt $nr_of_devices ]]; do echo -e "$n ${model[$n]}\\240${address[$n]}"; n=$(( $n+1 )); done ) 2> $answer

  retval=$?

  case $retval in
    0)
      n=`cat $answer`
      rm -f $answer
      ;;
    *)
      echo $retval
      exit
      cancel_assign
      ;;
  esac
}

create_nameif_header() {
  # header
  echo "#!/bin/sh" > $outfile
  echo "# assigns mac addresses to interfaces" >> $outfile
  echo "# automagically created by linuxmuster-setup" >> $outfile
  echo "# $tstamp" >> $outfile
  echo >> $outfile

  echo "# first move all interfaces to temporary ones" >> $outfile
}

create_nameif_integrated() {
  # header
  create_nameif_header
  n=0
  while [[ $n -lt $nr_of_devices ]]; do
    echo "nameif eth_tmp$n ${address[$n]}" >> $outfile
    let n+=1
  done
  echo >> $outfile

  echo "# then make the real assignment" >> $outfile
  n=0; c=0
  while [[ $n -lt $nr_of_devices ]]; do
    case ${typ[$n]} in
      extern)
        echo "nameif extern ${address[$n]}" >> $outfile
        let c+=1
        ;;
      intern)
        echo "nameif intern ${address[$n]}" >> $outfile
        let c+=1
        ;;
      wlan)
        echo "nameif wlan ${address[$n]}" >> $outfile
        let c+=1
        ;;
      dmz)
        echo "nameif dmz ${address[$n]}" >> $outfile
        let c+=1
        ;;
      *) ;;
    esac
    let n+=1
  done
  echo >> $outfile

  # are there unassigned nics?
  # if yes assign them to free devices

  if [[ $nr_of_devices -gt $c ]]; then
    echo "# assign unused interfaces" >> $outfile
    n=0
    while [[ $n -lt $nr_of_devices ]]; do
      if [ "${typ[$n]}" = "" ]; then
        echo "nameif eth$c ${address[$n]}" >> $outfile
        let c+=1
      fi
      let n+=1
    done
  fi
}

create_nameif_dedicated() {
  # header
  create_nameif_header
  c=0
  while [[ $c -lt $nr_of_devices ]]; do
    echo "nameif eth_tmp$c ${address[$c]}" >> $outfile
    let c+=1
  done
  echo >> $outfile

  echo "# then make the real assignment" >> $outfile
  c=0
  while [[ $c -lt $nr_of_devices ]]; do
    if [[ $c -eq $n ]]; then
      echo "nameif intern ${address[$n]}" >> $outfile
    else
      echo "nameif eth$c ${address[$c]}" >> $outfile
    fi
    let c+=1
  done
}

# 
if [ "$type" = "integrated" ]; then

  menu_integrated
  create_nameif_integrated

else

  if [[ $nr_of_devices -gt 1 ]]; then
    menu_dedicated
  else
    n=0
  fi
  create_nameif_dedicated

fi

# make script executable
chmod 755 $outfile

# delete answer file
[ -e "$answer" ] && rm -f $answer

exit 0
