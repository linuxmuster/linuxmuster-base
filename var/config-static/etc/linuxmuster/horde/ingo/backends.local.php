<?php
$backends['sieve'] = array(
    'disabled' => false,
    'driver' => 'timsieved',
    'preferred' => 'localhost',
    'hordeauth' => true,
    'params' => array(
        'hostspec' => 'localhost',
        'logintype' => 'PLAIN',
        'port' => 4190,
        'scriptname' => 'ingo',
        // The following settings can be used to specify an administration
        // user to update all users' scripts.
        // 'admin' => 'cyrus',
        // 'password' => '*****',
        // 'username' => Auth::getAuth(),
    ),
);
