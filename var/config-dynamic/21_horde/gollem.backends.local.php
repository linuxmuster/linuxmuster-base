<?php

// disable FTP from example.
$backends['ftp'] = array(
    'disabled' => true,
    'name' => 'FTP Server',
    'driver' => 'ftp',
    'hordeauth' => false,
    'params' => array(
        'hostspec' => 'localhost',
        'port' => 21,
        'pasv' => false,
    ),
    'loginparams' => array(
        
    ),
    'attributes' => array(
        'type',
        'name',
        'edit',
        'download',
        'modified',
        'size',
        'permission',
        'owner',
        'group'
    )
);


$backends['smb-home'] = array(
     'disabled' => false,
     'name' => 'Home',
     'driver' => 'smb',
     'preferred' => '',
     'hordeauth' => true,
     'params' => array(
         'hostspec' => '@@serverip@@',
         'port' => 139,
         'share' => 'homes',
         'smbclient' => '/usr/bin/smbclient',
     ),
     'clipboard' => true,
     'attributes' => array('type', 'name', 'download', 'modified', 'size')
);

$backends['smb-shares'] = array(
     'disabled' => false,
     'name' => 'Tauschen',
     'driver' => 'smb',
     'preferred' => '',
     'hordeauth' => true,
     'params' => array(
         'hostspec' => '@@serverip@@',
         'port' => 139,
         'share' => 'shares',
         'smbclient' => '/usr/bin/smbclient',
     ),
     'filter' => '^classes$|^exams$|^projects$|^school$|^subclasses$|^teachers$',
     'clipboard' => true,
     'attributes' => array('type', 'name', 'download', 'modified', 'size')
);
