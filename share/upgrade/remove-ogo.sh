#!/bin/sh
#
# removing OpenGroupware from paedML Linux
#

. /usr/share/linuxmuster/config/dist.conf
. $HELPERFUNCTIONS

# removing init script
/etc/init.d/opengroupware.org stop
update-rc.d -f opengroupware.org remove

# removing packages
aptitude -y remove opengroupware.org libapache2-mod-ngobjweb opengroupware.org-environment opengroupware.org-webmail-tools opengroupware.org-skyaptnotify opengroupware.org1.0-webui-i18n-de opengroupware.org1.0-webui-theme opengroupware.org1.0-webui-theme-blue opengroupware.org1.0-webui-theme-kde opengroupware.org1.0-webui-theme-ooo opengroupware.org1.0-webui-theme-orange opengroupware.org-misc-tools opengroupware.org1.0-database opengroupware.org1.0-nhsd opengroupware.org1.0-webui-app opengroupware.org1.0-webui-contact opengroupware.org1.0-webui-core opengroupware.org1.0-webui-job opengroupware.org1.0-webui-mailer opengroupware.org1.0-webui-news opengroupware.org1.0-webui-project opengroupware.org1.0-webui-scheduler opengroupware.org1.0a-epoz

# removing apache configuration
[ -e /etc/apache2/conf.d/mod_ngobjweb-ogo.conf ] && rm /etc/apache2/conf.d/mod_ngobjweb-ogo.conf

# removing link from index.html
if grep -q OpenGroupware /var/www/apache2-default/index.html && grep -q paedML_style.css /var/www/apache2-default/index.html; then
	backup_file /var/www/apache2-default/index.html
	grep -v OpenGroupware /var/www/apache2-default/index.html > /var/tmp/index.html
	mv /var/tmp/index.html /var/www/apache2-default
fi

/etc/init.d/apache2 restart

touch $REMOVED_OGO
