#!/bin/sh
# create ssl certificate script
# for paedML Linux 4.0
# 12.04.07 Thomas Schmitt <schmitt@lmz-bw.de>

# modify this to your needs
days=3650
country="@@country@@"
state="@@state@@"
location="@@location@@"
schoolname="@@schoolname@@"
section="@@distro@@"
[ -z "$myname" ] && myname="@@servername@@.@@domainname@@"
mymail="@@administrator@@@@@domainname@@"

# from here on nothing has to be modified
[ -z "$SSLDir" ] && SSLDir=/etc/ssl/private
SSLCertificateFile=$SSLDir/server.crt
SSLCertificateKeyFile=$SSLDir/server.key
SSLCertificateCSRFile=$SSLDir/server.csr
SSLPemFile=$SSLDir/server.pem

echo
echo "################################################################"
echo "############## creating selfsigned certificate #################"
echo "################################################################"
echo
echo "Enter your fully qualified ServerName at the Common Name prompt."
echo
openssl genrsa -out $SSLCertificateKeyFile 1024 
chmod 600 $SSLCertificateKeyFile
echo -e "$country\n$state\n$location\n$schoolname\n$section\n$myname\n$mymail\n\n\n" | openssl req -new -key $SSLCertificateKeyFile -out $SSLCertificateCSRFile
openssl x509 -req -days $days -in $SSLCertificateCSRFile -signkey $SSLCertificateKeyFile -out $SSLCertificateFile
mv -f $SSLPemFile $SSLPemFile.old 2> /dev/null 1>/dev/null
cp $SSLCertificateKeyFile $SSLPemFile
cat $SSLCertificateFile >> $SSLPemFile
if [ "$SSLDir" = "/etc/ssl/private" ]; then
  chmod 640 $SSLPemFile
  chown root:sasl $SSLPemFile
  chmod 750 $SSLDir
  chown root:sasl $SSLDir
fi
echo
echo "ssl certificate was created in $SSLDir and is $days days valid."
echo

exit 0
