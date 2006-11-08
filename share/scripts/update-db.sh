#!/bin/sh
# update user database with basedn and workgroup
# 04.02.2006
# Thomas Schmitt <schmitt@lmz-bw.de>

stringinstring(){
case "$2" in *$1*) return 0;; esac
return 1
}

# parameters are basedn, workgroup and schoolname
new_dn=$1
new_wg=$2
new_sn=$3

# probe parameters
[ -z "$new_dn" ] && exit 1
stringinstring "dc=" "$new_dn" || exit 1
[ -z "$new_wg" ] && exit 1
[ -z "$new_sn" ] && exit 1

# read ldap_entries and extract id and dn and modify basedn if necessary
sql="SELECT id,dn FROM ldap_entries;"
psql -U ldap -d ldap -t -c "$sql" | grep dc= | awk -F\| '{print $1 $2}' - | while read id dn; do

  # exit when id is not set
  [ -z $id ] && break
  [ -z $dn ] && break
  # id 1 is the basedn
  if [ "$id" = "1" ]; then
    # nothing to do if new dn is equal to old dn
    if [ "$dn" = "$new_dn" ]; then break; fi
  fi
  # set new cn
  new_cn=`echo $dn | sed -e "s/dc=.*/$new_dn/"`
  echo "Updating id $id in ldap_entries with dn=$new_cn"
  psql -U ldap -d ldap -c "UPDATE ldap_entries SET dn='$new_cn' WHERE id=$id;"

done

# now the workgroup
sql="SELECT id,dn FROM ldap_entries WHERE dn ~* 'sambaDomainName';"
psql -U ldap -d ldap -t -c "$sql" | grep dc= | awk -F\| '{print $1 $2}' - | while read id dn; do

  # exit when id is not set
  [ -z $id ] && break
  [ -z $dn ] && break

  # modify workgroup if necessary
  if ! stringinstring "$new_wg" "$dn"; then
    old_wg=`echo $dn | awk -F, '{ print $1 }' | awk -F= '{ print $2 }'`
    new_cn=`echo $dn | sed -e "s/$old_wg/$new_wg/"`
    echo "Updating id $id in ldap_entries with dn=$new_cn"
    psql -U ldap -d ldap -c "UPDATE ldap_entries SET dn='$new_cn' WHERE id=$id;"
  fi
done

# workgroup is also in table samba_domain
sql="SELECT id,sambadomainname FROM samba_domain;"
psql -U ldap -d ldap -t -c "$sql" | awk -F\| '{print $1 $2}' - | while read id sambadomainname; do

  # exit when id is not set
  [ -z $id ] && break
  [ -z $sambadomainname ] && break

  if [ "$new_wg" != "$sambadomainname" ]; then
    echo "Updating id $id in samba_domain with sambadomainname=$new_wg"
    psql -U ldap -d ldap -c "UPDATE samba_domain SET sambadomainname='$new_wg' WHERE id=$id;"
  fi

done

# update institute with schoolname
sql="UPDATE institutes SET name='$new_sn' WHERE id=1"
psql -U ldap -d ldap -t -c "$sql"

exit 0
