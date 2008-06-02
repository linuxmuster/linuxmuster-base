#!/bin/bash

/etc/init.d/openntpd stop
/usr/sbin/ntpdate pool.ntp.org
/etc/init.d/openntpd start
