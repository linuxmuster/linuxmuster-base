<?php
$backends['imap'] = array(
    // ENABLED by default
    'disabled' => true,
);

$backends['sieve'] = array(
    'disabled' => false,
    'transport' => array(
        Ingo::RULE_ALL => array(
            'driver' => 'timsieved',
            'params' => array(
                // Hostname of the timsieved server
                'hostspec' => 'localhost',
                // Login type of the server
                'logintype' => 'PLAIN',
                // Enable/disable TLS encryption
                'usetls' => true,
                // Port number of the timsieved server
                'port' => 4190,
                // Name of the sieve script
                'scriptname' => 'ingo',
                // Enable debugging. The sieve protocol communication is logged
                // with the DEBUG level.
                'debug' => false,
            ),
        ),
    ),
    'script' => array(
        Ingo::RULE_ALL => array(
            'driver' => 'sieve',
            'params' => array(
                // If using Dovecot or any other Sieve implementation that
                // requires folder names to be UTF-8 encoded, set this
                // parameter to true.
                'utf8' => true,
             ),
        ),
    ),
    'shares' => false
);
