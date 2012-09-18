#!/bin/sh
#
# Restarting all printer queues
#
# Thomas Schmitt <tschmitt@linuxmuster.de>
# 19.04.2010

LPSTAT=/usr/bin/lpstat
AWK=/usr/bin/awk
ECHO=/bin/echo
DISABLE=/usr/sbin/cupsdisable
CANCEL=/usr/bin/cancel
REJECT=/usr/sbin/cupsreject
ACCEPT=/usr/sbin/cupsaccept
ENABLE=/usr/sbin/cupsenable
INIT=/etc/init.d/cups

$INIT stop
$INIT start

for i in `$LPSTAT -p | $AWK '{ print $2 }'`; do

    $ECHO "Deactivating printer $i ..."
    $DISABLE -c $i
    $CANCEL -a $i
    $REJECT $i

    $ECHO "Activating printer $i again ..."
    $ACCEPT $i
    $ENABLE $i

done

$ECHO
$ECHO "Done."
