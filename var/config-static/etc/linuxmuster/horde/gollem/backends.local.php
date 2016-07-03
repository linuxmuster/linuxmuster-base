<?php

$backends['smb-home'] = array(
     'disabled' => false,
     'name' => 'Home',
     'driver' => 'smb',
     'preferred' => '',
     'hordeauth' => true,
     'params' => array(
         'hostspec' => 'localhost',
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
         'hostspec' => 'localhost',
         'port' => 139,
         'share' => 'shares',
         'smbclient' => '/usr/bin/smbclient',
     ),
     'filter' => '^classes$|^exams$|^projects$|^school$|^subclasses$|^teachers$',
     'clipboard' => true,
     'attributes' => array('type', 'name', 'download', 'modified', 'size')
);
