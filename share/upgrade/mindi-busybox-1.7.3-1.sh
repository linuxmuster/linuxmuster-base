#!/bin/sh

version=1.7.3-1
package=mindi-busybox

echo "###################################################"
echo "# Downgrade von $package auf Version $version #"
echo "###################################################"

aptitude update || exit 1

if ! apt-cache show $package | grep ^Version | grep -q $version; then
 echo "Paket $package ist in Version $version nicht verfügbar!"
 exit 1
fi

aptitude -y install ${package}=${version}

