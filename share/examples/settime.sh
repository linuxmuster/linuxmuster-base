#!/bin/bash

/etc/init.d/ntp-server stop
/etc/init.d/ntpdate restart
/etc/init.d/ntp-server start
