#!/bin/sh
# create ssl certificate
# für Linux Musterlösung 3.0
# 29.03.05 Thomas Schmitt <linuxmuster@schmitt.mine.nu>

[ -z "$SSLDIR" ] && SSLDir=/etc/ssl/private
SSLCertificateFile=$SSLDir/server.crt
SSLCertificateKeyFile=$SSLDir/server.key
SSLCertificateCSRFile=$SSLDir/server.csr
SSLPemFile=$SSLDir/server.pem
Days=3650

country="DE"
state="BW"
location="Plochingen"
schoolname="Schmitt-Schule"
section="Linux-Musterloesung"
[ -z "$myname" ] && myname="server.linuxmuster.local"
mymail="nwberater@linuxmuster.local"

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
openssl x509 -req -days $Days -in $SSLCertificateCSRFile -signkey $SSLCertificateKeyFile -out $SSLCertificateFile
mv -f $SSLPemFile $SSLPemFile.old 2> /dev/null 1>/dev/null 
cp $SSLCertificateKeyFile $SSLPemFile 
cat $SSLCertificateFile >> $SSLPemFile 
chmod 640 $SSLPemFile
chown root:sasl $SSLPemFile
chmod 750 $SSLDir
chown root:sasl $SSLDir
[ -f /server.key ] && rm /server.*
echo
echo "ssl certificate was created in $SSLDir and is $Days valid."
echo

exit 0
