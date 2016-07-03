<?php
$conf['use_ssl'] = 2;
$conf['server']['name'] = $_SERVER['SERVER_NAME'];
$conf['cookie']['domain'] = $_SERVER['SERVER_NAME'];
$conf['cookie']['path'] = '/horde';
$conf['testdisable'] = true;

// YOU SHOULDN'T CHANGE ANTHING BELOW THIS LINE.
$conf['debug_level'] = E_ALL & ~E_NOTICE;
$conf['umask'] = 077;
$conf['compress_pages'] = true;
$conf['max_exec_time'] = 0;
$conf['session']['name'] = 'Horde';
$conf['session']['cache_limiter'] = 'nocache';
$conf['session']['max_time'] = 72000;
$conf['session']['timeout'] = 0;
$conf['auth']['admins'] = array('wwwadmin');
$conf['auth']['driver'] = 'auto';
$conf['auth']['params'] = array('username' => 'Administrator');
$conf['prefs']['driver'] = 'Sql';
$conf['portal']['fixed_blocks'] = array();
$conf['imsp']['enabled'] = false;
$conf['kolab']['enabled'] = false;
$conf['log']['priority'] = 'INFO';
$conf['log']['ident'] = 'HORDE';
$conf['log']['name'] = LOG_USER;
$conf['log']['type'] = 'syslog';
$conf['log']['enabled'] = true;

$conf['log']['name'] = '/var/log/horde/horde.log';
