#!/bin/bash

/etc/init.d/openntpd stop
/usr/sbin/ntpdate pool.ntp.org
/sbin/hwclock --systohc
/etc/init.d/openntpd start

