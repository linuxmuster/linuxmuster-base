<?php
/**
 * $Horde: ingo/config/backends.php.dist,v 1.20.8.4 2006/02/02 22:57:31 jan Exp $
 *
 * Ingo works purely on a preferred mechanism for server selection. There are
 * a number of properties that you can set for each backend:
 *
 * driver:       The Ingo_Driver driver to use to get the script to the
 *               backend server. Valid options:
 *                   'null'       --  No backend server
 *                   'timsieved'  --  Cyrus timsieved server
 *                   'vfs'        --  Use Horde VFS
 *
 * preferred:    This is the field that is used to choose which server is
 *               used. The value for this field may be a single string or an
 *               array of strings containing the hostnames to use with this
 *               server.
 *
 * hordeauth:    Ingo uses the current logged in username and password. If
 *               you want the full username@realm to be used to connect then
 *               set this to 'full' otherwise set this to true and just the
 *               username will be used to connect to the driver.
 *
 * params:       An array containing any additional information that the
 *               Ingo_Driver class needs.
 *
 * script:       The type of Ingo_Script driver this server uses.
 *               Valid options:
 *                   'imap'      --  IMAP client side filtering
 *                   'maildrop'  --  Maildrop scripts
 *                   'procmail'  --  Procmail scripts
 *                   'sieve'     --  Sieve scripts
 *
 * scriptparams: An array containing any additional information that the
 *               Ingo_Script driver needs.
 */

/* Sieve configuration for linuxmuster.net */
/* 16.03.2013 thomas@linuxmuster.net */
$backends['sieve'] = array(
    'driver' => 'timsieved',
    'preferred' => 'localhost',
    'hordeauth' => true,
    'params' => array(
        // Hostname of the timsieved server
        'hostspec' => 'localhost',
        // Login type of the server
        'logintype' => 'PLAIN',
        // Port number of the timsieved server
        'port' => 4190,
        // Name of the sieve script
        'scriptname' => 'ingo',
        // The following settings can be used to specify an administration
        // user to update all users' scripts.
        // 'admin' => 'cyrus',
        // 'password' => '*****',
        // 'username' => Auth::getAuth(),
    ),
    'script' => 'sieve',
    'scriptparams' => array()
);
