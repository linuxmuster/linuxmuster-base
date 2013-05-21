#!/bin/bash
#
# Restarting all printer queues
#
# thomas@linuxmuster.net
# 04.04.2013
#

LPSTAT=/usr/bin/lpstat
AWK=/usr/bin/awk
ECHO=/bin/echo
DISABLE=/usr/sbin/cupsdisable
CANCEL=/usr/bin/cancel
REJECT=/usr/sbin/cupsreject
ACCEPT=/usr/sbin/cupsaccept
ENABLE=/usr/sbin/cupsenable
START=/sbin/start
STOP=/sbin/stop

$STOP cups
$START cups

for i in `$LPSTAT -p | grep ^printer | $AWK '{ print $2 }'`; do

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
