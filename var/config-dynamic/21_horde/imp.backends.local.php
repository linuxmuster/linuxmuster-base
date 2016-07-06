<?php
$servers['imap'] = array(
    'disabled' => false,
    'name' => 'Cyrus IMAP Server',
    'hostspec' => '@@servername@@.@@domainname@@',
    'hordeauth' => true,
    'protocol' => 'imap',
    'port' => 143,
    'maildomain' => '@@domainname@@',
    'secure' => 'tls',
    'admin' => array(
        'params' => array(
            'login' => 'cyrus',
            'password' => '@@cyradmpw@@',
            'protocol' => 'imap',
            'hostspec' => 'localhost',
            'port' => 143
        )
    ),
    'quota' => array(
        'driver' => 'imap',
        'params' => array(),
    ),
    'acl' => array(
        'driver' => 'rfc2086',
    ),
);
