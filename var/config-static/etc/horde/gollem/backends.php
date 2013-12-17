<?php
/**
 * $Horde: gollem/config/backends.php.dist,v 1.41.2.6 2006/02/22 06:48:37 slusarz Exp $
 *
 * This file is where you specify what backends people using your
 * installation of Gollem can log in to. There are a number of properties
 * that you can set for each backend:
 *
 * name: This is the plaintext name that you want displayed if you are using
 *       the drop down server list.
 *
 * driver: The VFS (Virtual File System) driver to use to connect.
 *         Valid options:
 *           'file'  --  Work with a local file system.
 *           'ftp'   --  Connect to a FTP server.
 *           'sql'   --  Connect to VFS filesystem stored in SQL database.
 *
 * preferred: This is only useful if you want to use the same backend.php
 *            file for different machines: if the hostname of the Gollem
 *            machine is identical to one of those in the preferred list,
 *            then the corresponding option in the select box will include
 *            SELECTED, i.e. it is selected by default. Otherwise the
 *            first entry in the list is selected.
 *
 * hordeauth: If this parameter is present and true, then Gollem will attempt
 *            to use the user's existing credentials (the username/password
 *            they used to log in to Horde) to log in to this source. If this
 *            parameter is 'full', the username will be used unmodified;
 *            otherwise, everything after and including the first @ in the
 *            username will be stripped before attempting authentication.
 *
 * params: A parameters array containing any additional information that the
 *         VFS driver needs.
 *
 * loginparams: A list of parameters that can be changed by the user on the
 *              login screen.  The key is the parameter name that can be
 *              changed, the value is the text that will be displayed next to
 *              the entry box on the login screen.
 *
 * root: The directory that will be the "top" or "root" directory, being the
 *       topmost directory where users can change to. This is in addition to
 *       a vfsroot parameter set in the params array.
 *
 * home: The directory that will be used as home directory for the user.
 *       This parameter will overrule a home parameter in the params array.
 *       If empty, this will default to the active working directory
 *       immediately after logging into the VFS backend (i.e. for ftp,
 *       this will most likely be ~user, for SQL based VFS backends,
 *       this will probably be the root directory).
 *
 * createhome: If this parameter is set to true, and the home directory does
 *             not exist, attempt to create the home directory on login.
 *
 * permissions: The default permissions to set for newly created folders
 *              and files. This parameter will only take affect if the VFS
 *              backend supports file permissions. If empty, the permissions
 *              will be set by default by the VFS backend.
 *
 * filter: If set, all files that match the regex will be hidden in the
 *         folder view.  The regex must be in pcre syntax (See
 *         http://www.php.net/pcre).
 *
 * quota: If set, turn on VFS quota checking for the backend if it supports
 *        it.  The entry must be in the following format:
 *          size [metric]
 *        metric = B (bytes), KB (kilobytes), MB (megabytes), GB (gigabytes)
 *        If no metric is given, bytes are assumed.
 *        Examples: "2 MB", "2048 B", "1.5 GB"
 *        If false or not set, quota support is disabled.
 *
 *        ** For quotas to work, you must be using a version of Horde **
 *        ** that contains VFS quota support.                         **
 *
 * clipboard: If set, allows the user to cut/copy/paste files. Since not all
 *            VFS backends have support for the necessary commands, and there
 *            is no way to auto-detect which backends do have support, this
 *            option must be manually set. True enables clipboard support,
 *            false (the default) disables support. In the examples below,
 *            clipboard has been enabled in all VFS backends that have
 *            cut/copy/paste support since the initial release of Horde 3.0.
 *            For all other backends, you will have to manually check and
 *            see if your current VFS version/backend supports the necessary
 *            commands.
 *
 * attributes: The list of attributes that the driver supports. Available
 *             attributes:
 *               'download'
 *               'group'
 *               'modified'
 *               'name'
 *               'owner'
 *               'permission'
 *               'size'
 *               'type'
 */

// SMB Example
// ** For the SMB backend to work, you must be using a version of Horde
// ** that contains the SMB VFS driver.  See the test.php script to determine
// ** whether the SMB driver is present on your system.
// $backends['smb'] = array(
//      'name' => 'SMB Server',
//      'driver' => 'smb',
//      'preferred' => '',
//      'hordeauth' => true,
//      'params' => array(
//          'hostspec' => 'localhost',
//          'port' => 139,
//          'share' => 'homes',
//          // Path to the smbclient executable.
//          'smbclient' => '/usr/bin/smbclient',
//          // IP address of server (only needed if hostname is different from
//          // NetBIOS name).
//          'ipaddress' => '127.0.0.1',
//      ),
//     'loginparams' => array(
//         // Allow the user to change to Samba server.
//         // 'hostspec' => 'Hostname',
//         // Allow the user to change the Samba port.
//         // 'port' => 'Port',
//         // Allow the user to change the Samba share.
//         // 'share' => 'Share',
//     ),
//     // 'root' => '',
//     // 'home' => '',
//     // 'createhome' => false,
//     // 'permissions' => '750',
//     // 'filter' => '^regex$',
//     // 'quota' => false,
//      'clipboard' => true,
//      'attributes' => array('type', 'name', 'download', 'modified', 'size')
// );

/**
 * thomas@linuxmuster.net
 * smb share definitions for gollem
 * 17.12.2013
 */

$backends['smb-home'] = array(
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
     'filter' => '^[a-z]',
     'clipboard' => true,
     'attributes' => array('type', 'name', 'download', 'modified', 'size')
);
$backends['smb-tasks'] = array(
     'name' => 'Vorlagen',
     'driver' => 'smb',
     'preferred' => '',
     'hordeauth' => true,
     'params' => array(
         'hostspec' => 'localhost',
         'port' => 139,
         'share' => 'tasks',
         'smbclient' => '/usr/bin/smbclient',
     ),
     'filter' => '^[a-z]',
     'clipboard' => true,
     'attributes' => array('type', 'name', 'download', 'modified', 'size')
);
