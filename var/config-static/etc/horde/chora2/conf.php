<?php
/* CONFIG START. DO NOT CHANGE ANYTHING IN OR AFTER THIS LINE. */
// $Horde: chora/config/conf.xml,v 1.8.10.2 2005/09/22 12:56:37 jan Exp $
$conf['paths']['ci'] = '/usr/bin/ci';
$conf['paths']['co'] = '/usr/bin/co';
$conf['paths']['rcs'] = '/usr/bin/rcs';
$conf['paths']['rcsdiff'] = '/usr/bin/rcsdiff';
$conf['paths']['rlog'] = '/usr/bin/rlog';
$conf['paths']['cvs'] = '/usr/bin/cvs';
$conf['paths']['diff'] = '/usr/bin/diff';
$conf['paths']['svn'] = '/usr/bin/svn';
$conf['paths']['cvsps_home'] = '/tmp';
$conf['paths']['cvsgraph_conf'] = dirname(__FILE__) . '/cvsgraph.conf';
$conf['options']['adminName'] = '';
$conf['options']['adminEmail'] = '';
$conf['options']['shortLogLength'] = 75;
$conf['options']['defaultsort'] = 'VC_SORT_NAME';
$conf['options']['urls'] = 'get';
$conf['restrictions'] = array();
$conf['hide_restricted'] = true;
$conf['menu']['apps'] = array();
/* CONFIG END. DO NOT CHANGE ANYTHING IN OR BEFORE THIS LINE. */
