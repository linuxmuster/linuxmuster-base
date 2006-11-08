<?php
/* CONFIG START. DO NOT CHANGE ANYTHING IN OR AFTER THIS LINE. */
// $Horde: passwd/config/conf.xml,v 1.12 2005/10/09 14:48:58 jan Exp $
$conf['menu']['apps'] = array();
$conf['backend']['backend_list'] = 'hidden';
$conf['user']['change'] = true;
$conf['user']['refused'] = array('root', 'bin', 'daemon', 'adm', 'lp', 'shutdown', 'halt', 'uucp', 'ftp', 'anonymous', 'nobody', 'httpd', 'operator', 'guest', 'diginext', 'bind', 'cyrus', 'courier', 'games', 'kmem', 'mailnull', 'man', 'mysql', 'news', 'postfix', 'sshd', 'tty', 'www');
$conf['password']['strengthtests'] = false;
$conf['hooks']['full_name'] = true;
$conf['hooks']['default_username'] = false;
$conf['hooks']['username'] = false;
$conf['hooks']['userdn'] = false;
/* CONFIG END. DO NOT CHANGE ANYTHING IN OR BEFORE THIS LINE. */
