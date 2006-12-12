# linuxmuster shell helperfunctions

export PATH=/bin:/sbin:/usr/bin:/usr/sbin

# source network settings
[ -f "$NETWORKSETTINGS" ] && . $NETWORKSETTINGS

# lockfile
lockflag=/var/lock/.linuxmuster.lock

# date & time
[ -e /bin/date ] && DATETIME=`date +%y%m%d-%H%M%S`


####################
# common functions #
####################

# parse command line options
getopt() {
  until [ -z "$1" ]
  do
    if [ ${1:0:2} = "--" ]
    then
        tmp=${1:2}               # Strip off leading '--' . . .
        parameter=${tmp%%=*}     # Extract name.
        value=${tmp##*=}         # Extract value.
        eval $parameter=$value
#        [ -z "$parameter" ] && parameter=yes
    fi
    shift
  done
}

# cancel on error, $1 = Message, $2 logfile
cancel() {
  echo "$1"
  [ -e "$lockflag" ] && rm -f $lockflag
  [ -n "$2" ] && echo "$DATETIME: $1" >> $2
  exit 1
}

# check lockfiles, wait a minute whether it will be freed
checklock() {
  if [ -e "$lockflag" ]; then
    echo "Found lockfile!"
    n=0
    while [[ $n -lt $TIMEOUT ]]; do
      remaining=$(($(($TIMEOUT-$n))*10))
      echo "Remaining $remaining seconds to wait ..."
      sleep 1
      if [ ! -e "$lockflag" ]; then
        touch $lockflag || return 1
        echo "Lockfile released!"
        return 0
      fi
      let n+=1
    done
    echo "Timed out! Exiting!"
    return 1
  else
    touch $lockflag || return 1
  fi
  return 0
}


# test if variable is an integer
isinteger () {
  [ $# -eq 1 ] || return 1

  case $1 in
  *[!0-9]*|"") return 1;;
            *) return 0;;
  esac
} # isinteger


##########################
# check parameter values #
##########################

# check if user is teacher
check_teacher() {
  if `id $1 | grep -qw $TEACHERSGROUP`; then
    return 0
  else
    return 1
  fi
}

# check if user is teacher
check_admin() {
  if `id $1 | grep -qw $DOMADMINS`; then
    return 0
  else
    return 1
  fi
}

# check for valid group, group members and if teacher is set, for teacher membership
check_group() {
  unset RET
  group=$1
  teacher=$2

  gidnr=`smbldap-groupshow $group | grep gidNumber: | awk '{ print $2 }'`
  [ -z "$gidnr" ] && return 1
  [ "$gidnr" -lt 10000 ] && return 1

  # fetch group members
  if get_group_members $group; then
    members=$RET
  else
    return 1
  fi

  # cancel if group has no members
  [ -z "$members" ] && return 1

  # check if teacher is in group
  if [ -n "$teacher" ]; then
    if ! echo "$members" | grep -qw $teacher; then
      return 1
    fi
  fi

  return 0
}

# check valid domain name
validdomain() {
  if (expr match "$1" '\([a-z0-9-]\+\(\.[a-z0-9-]\+\)\+$\)') &> /dev/null; then
    return 0
  else
    return 1
  fi
}

# check valid ip
validip() {
  if (expr match "$1"  '\(\([1-9]\|[1-9][0-9]\|1[0-9]\{2\}\|2[0-4][0-9]\|25[0-4]\)\.\([0-9]\|[1-9][0-9]\|1[0-9]\{2\}\|2[0-4][0-9]\|25[0-4]\)\.\([0-9]\|[1-9][0-9]\|1[0-9]\{2\}\|2[0-4][0-9]\|25[0-4]\)\.\([1-9]\|[1-9][0-9]\|1[0-9]\{2\}\|2[0-4][0-9]\|25[0-4]\)$\)') &> /dev/null; then
    return 0
  else
    return 1
  fi
}

# test valid mac address syntax
validmac() {
  [ -z "$1" ] && return 1
  [ `expr length $1` -ne "17" ] && return 1
  if (expr match "$1" '\([a-fA-F0-9-][a-fA-F0-9-]\+\(\:[a-fA-F0-9-][a-fA-F0-9-]\+\)\+$\)') &> /dev/null; then
    return 0
  else
    return 1
  fi
}


#################
# mysql related #
#################

# create mysql database user
create_mysql_user() {
  username=$1
  password=$2
  mysql <<EOF
USE mysql;
REPLACE INTO user (host, user, password)
    VALUES (
        'localhost',
        '$username',
        PASSWORD('$password')
);
EOF
}

# removes a mysql user
drop_mysql_user() {
  username=$1
  mysql <<EOF
USE mysql;
DELETE FROM user WHERE user='$username';
DELETE FROM db WHERE user='$username';
DELETE FROM columns_priv WHERE user='$username';
DELETE FROM tables_priv WHERE user='$username';
FLUSH PRIVILEGES;
EOF
}

# create a mysql database
create_mysql_db() {
  if mysqladmin create $1; then
    return 0
  else
    return 1
  fi
}

# create a mysql database and grant privileges to a user
drop_mysql_db() {
  if mysqladmin -f drop $1; then
    return 0
  else
    return 1
  fi
}

# grant privileges to a database to a specified user
grant_mysql_privileges() {
  dbname=$1
  username=$2
  writeable=$3
  mysql <<EOF
USE mysql;
REPLACE INTO db (host, db, user, select_priv, insert_priv, update_priv, references_priv, lock_tables_priv,
                 delete_priv, create_priv, drop_priv, index_priv, alter_priv, create_tmp_table_priv)
    VALUES (
        'localhost',
        '$dbname',
        '$username',
        'Y', '$writeable', '$writeable', '$writeable', '$writeable', '$writeable',
        '$writeable', '$writeable', '$writeable', '$writeable', '$writeable'
);
FLUSH PRIVILEGES;
EOF
}

# returns 0 if $username is a mysql user
check_mysql_user() {
  username=$1
  get_dbusers || return 1
  if echo $RET | grep -qw $username; then
    return 0
  else
    return 1
  fi
}


#######################
# workstation related #
#######################

# extract ip address from file $WIMPORTDATA
get_ip() {
  unset RET
  [ -f "$WIMPORTDATA" ] || return 1
  RET=`grep -v ^# $WIMPORTDATA | grep -w -m1 $1 | awk -F\; '{ print $5 }' -` &> /dev/null
  return 0
}

# extract mac address from file $WIMPORTDATA
get_mac() {
  unset RET
  [ -f "$WIMPORTDATA" ] || return 1
  RET=`grep -v ^# $WIMPORTDATA | grep -w -m1 $1 | awk -F\; '{ print $4 }' -` &> /dev/null
  return 0
}

# extract hostname from file $WIMPORTDATA
get_hostname() {
  unset RET
  [ -f "$WIMPORTDATA" ] || return 1
  RET=`grep -v ^# $WIMPORTDATA | grep -w -m1 $1 | awk -F\; '{ print $2 }' -` &> /dev/null
  return 0
}

# extract hostname from file $WIMPORTDATA
get_room() {
  unset RET
  [ -f "$WIMPORTDATA" ] || return 1
  RET=`grep -v ^# $WIMPORTDATA | grep -m1 $1 | awk -F\; '{ print $1 }' -` &> /dev/null
  return 0
}

# needed by internet & intranet on off scripts
get_maclist() {
  # parse maclist
  if [ -n "$maclist" ]; then

    n=0
    OIFS=$IFS
    IFS=","
    for i in $maclist; do
      if validmac $i; then
        mac[$n]=$i
      else
        continue
      fi
      let n+=1
    done
    IFS=$OIFS
    nr_of_macs=$n
    [[ $nr_of_macs -eq 0 ]] && cancel "No valid mac addresses found!"

  else # parse hostlist

    n=0
    OIFS=$IFS
    IFS=","
    for i in $hostlist; do
      host[$n]=$i
      let n+=1
    done
    IFS=$OIFS
    nr_of_hosts=$n
    [[ $nr_of_hosts -eq 0 ]] && cancel "No hostnames found!"

    n=0; m=0
    while [[ $n -lt $nr_of_hosts ]]; do
      get_mac ${host[$n]} || cancel "Read failure! Cannot determine mac address!"
      if validmac $RET; then
        mac[$m]=$RET
        let m+=1
      fi
      let n+=1
    done
    nr_of_macs=$m
    [[ $nr_of_macs -eq 0 ]] && cancel "No mac addresses found!"

  fi

  return 0
}


#######################
# IPCop communication #
#######################

# check if urlfilter is active
check_urlfilter() {
  # get advanced proxy settings
  get_ipcop /var/ipcop/proxy/advanced/settings $CACHEDIR/proxy.advanced.settings || cancel "Cannot download proxy advanced settings!"
  . $CACHEDIR/proxy.advanced.settings || cancel "Cannot read $CACHEDIR/proxy.advanced.settings!"
  rm -f $CACHEDIR/proxy.advanced.settings
  [ "$ENABLE_FILTER" = "on" ] || return 1
  return 0
}

# execute a command on ipcop
exec_ipcop() {
  ssh -p 222 root@$ipcopip $* &> /dev/null || return 1
  return 0
}

# fetch file from ipcop
get_ipcop() {
  scp -P 222 root@$ipcopip:$1 $2 &> /dev/null || return 1
  return 0
}

# upload file to ipcop
put_ipcop() {
  scp -P 222 $1 root@$ipcopip:$2 &> /dev/null || return 1
  return 0
}


###############
# svn related #
###############

# create chora2 configuration
create_chora_conf() {
  check_empty_dir $SVNROOT
  if [ "$RET" = "0" ]; then
    rm -f $CHORASOURCES &> /dev/null
  else
    cd $SVNROOT
    echo "<?php" > $CHORASOURCES
    for i in *; do
      if [ -d "$i" ]; then
        echo "\$sourceroots['$i'] = array(" >> $CHORASOURCES
        echo "  'name' => '$i'," >> $CHORASOURCES
        echo "  'location' => 'file://$SVNROOT/$i'," >> $CHORASOURCES
        echo "  'title' => 'SVN Repository $i'," >> $CHORASOURCES
        echo "  'type' => 'svn'," >> $CHORASOURCES
        echo ");" >> $CHORASOURCES
      fi
    done
  fi
}


#################
# miscellanious #
#################

# get group members from ldab db
get_group_members() {
  unset RET
  group=$1
  RET=`psql -U ldap -d ldap -t -c "select uid from memberdata where adminclass = '$group' or gid = '$group';"`
}

# check if group is a project
check_project() {
  unset RET
  group=$1
  RET=`psql -U ldap -d ldap -t -c "select gid from projectdata where gid = '$group';"`
  strip_spaces $RET
  [ "$RET" = "$group" ] && return 0
  return 1
}

# stripping trailing and leading spaces
strip_spaces() {
  unset RET
  RET=`expr "$1" : '[[:space:]]*\(.*\)[[:space:]]*$'`
  return 0
}

# test if string is in string
stringinstring() {
  case "$2" in *$1*) return 0;; esac
  return 1
}

# checking if directory is empty, in that case it returns 0
check_empty_dir() {
  RET=$(ls -A1 $1 2>/dev/null | wc -l)
}

# check valid string without special characters
check_string() {
  if (expr match "$1" '\([a-z0-9-_]\+$\)') &> /dev/null; then
    return 0
  else
    return 1
  fi
}
