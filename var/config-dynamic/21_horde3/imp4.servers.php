<?php
/**
 * $Horde: imp/config/servers.php.dist,v 1.50.2.1 2005/01/18 23:29:54 jan Exp $
 *
 * This file is where you specify what mail servers people using your
 * installation of IMP can log in to.
 *
 * Properties that can be set for each server:
 *
 * name: This is the plaintext, english name that you want displayed
 *       to people if you are using the drop down server list.
 *
 * server: The hostname of the mail server to connect to.
 *
 * hordeauth: If this parameter is present and true, then IMP will attempt
 *            to use the user's existing credentials (the username/password
 *            they used to log in to Horde) to log in to this source. If this
 *            parameter is 'full', the username will be used unmodified;
 *            otherwise everything after and including the first @ in the
 *            username will be stripped off before attempting authentication.
 *
 * protocol: One of 'imap/notls' (or only 'imap' if you have a c-client
 *           version 2000c or older), 'pop3', 'imap/ssl', or 'pop3/ssl'.
 *           If using pop3 you will connect to a POP3 mail server instead of
 *           of IMAP and all folder options will be automatically turned
 *           turned off (POP3 does not support folders).
 *
 *           The two ssl options will only work if you've compiled PHP
 *           against a SSL-enabled version of c-client, used the
 *           --with-imap-ssl flag compiling PHP, and you have a mail server
 *           server which supports SSL.
 *
 *           NOTE - If you are using a self-signed server certificate with
 *           either imap/ssl or pop3/ssl, you MUST add '/novalidate-cert' to
 *           the end of the protocol string. For imap, this would be
 *           'imap/ssl/novalidate-cert', and for pop3 it would be
 *           'pop3/ssl/novalidate-cert'. This is necessary to tell c-client
 *           not to complain about the lack of a valid CA on the
 *           certificate.
 *
 * port: The port that the mail service/protocol you selected runs on.
 *       Default values:
 *         'pop3'    110
 *         'pop3s'   995
 *         'imap'    143
 *         'imaps'   993
 *
 * folders: The folder path for the IMAP server.
 *          Common values:
 *            UW-IMAP               'mail/'  (note the trailing slash)
 *            Cyrus, Courier-IMAP   'INBOX.' (note the trailing dot)
 *            dovecot               ''
 *
 *          IMPORTANT: Use this only if you want to restrict users to this
 *          subfolder. If you set this to 'INBOX.' with Cyrus or
 *          Courier-IMAP, then users will not be able to use any shared
 *          folders - nothing outside of 'INBOX.' will be visible (except
 *          INBOX, which is always visible). If you simply want to mask out
 *          the 'INBOX.' (or another) prefix for display purposes, use the
 *          'namespace' attribute (see below).
 *
 *          *** If you use this option, DO NOT SET 'namespace' ALSO! ***
 *
 * namespace: This is where you put any paths that you want stripped out
 *            for presentation purposes (i.e. you don't want your users to
 *            have to know that their personal folders are actually
 *            subfolders of their INBOX). A common value for this with
 *            Cyrus/Courier-IMAP servers is 'INBOX.'.
 *
 *            NOTE: If you have shared folders, using this may create
 *            confusion between shared folders and personal folders if users
 *            have folders with the same name as a shared folder.
 *
 *            *** If you use this option, DO NOT SET 'folders' ALSO! ***
 *
 * maildomain: What to put after the @ when sending mail. i.e. if you want
 *             all mail to look like 'From: user@example.com' set
 *             maildomain to 'example.com'. It is generally useful when
 *             the IMAP host is different from the mail receiving host. This
 *             will also be used to complete unqualified addresses when
 *             composing mail.
 *
 * smtphost: If specified, and $conf['mailer']['type'] is set to 'smtp',
 *           IMP will use this host for outbound SMTP connections.  This
 *           value overrides any existing $conf['mailer']['params']['host']
 *           value at runtime.
 *
 * smtpport: If specified, and $conf['mailer']['type'] is set to 'smtp',
 *           IMP will use this port for outbound SMTP connections.  This value
 *           overrides any existing $conf['mailer']['params']['port'] value at
 *           runtime.
 *
 * realm: ONLY USE REALM IF YOU ARE USING IMP FOR HORDE AUTHENTICATION,
 *        AND YOU HAVE MULTIPLE SERVERS AND USERNAMES OVERLAP BETWEEN
 *        THOSE SERVERS. If you only have one server, or have multiple
 *        servers with no username clashes, or have full user@example.com
 *        usernames, you DO NOT need a realm setting. If you set one, an
 *        '@' symbol plus the realm will be appended to the username that
 *        users log in to IMP with to create the username that Horde treats
 *        the user as. So with a realm of 'example.com', the username
 *        'jane' would be treated by Horde (NOT your IMAP server) as
 *        'jane@example.com', and the username 'jane@example.com' would be
 *        treated as 'jane@example.com@example.com' - an occasion where you
 *        probably don't need a realm setting.
 *
 * preferred: Only useful if you want to use the same servers.php file
 *            for different machines: if the hostname of the IMP machine is
 *            identical to one of those in the preferred list, then the
 *            corresponding option in the select box will include SELECTED
 *            (i.e. it is selected per default). Otherwise the first entry
 *            in the list is selected.
 *
 * quota: Use this if you want to display a users quota status on various
 *        IMP pages. Set 'driver' equal to the mailserver and 'params'
 *        equal to any extra parameters needed by the driver (see the
 *        comments located at the top of imp/lib/Quota/[quotadriver].php
 *        for the parameters needed for each driver).
 *
 *        Currently available drivers:
 *          false        --  Disable quota checking (DEFAULT)
 *
 *          'command'    --  Use the UNIX quota command to determine quotas
 *          'courier'    --  Use the Courier-IMAP server to handle quotas
 *                           You must be connecting to a Courier-IMAP server
 *                           to use this driver
 *          'cyrus'      --  Use the Cyrus IMAP server to handle quotas
 *                           You must be connecting to a Cyrus IMAP server
 *                           to use this driver
 *          'logfile'    --  Allow quotas on servers where IMAP Quota
 *                           commands are not supported, but quota info
 *                           appears in the servers messages log for the IMAP
 *                           server.
 *          'mdaemon'    --  Use Mdaemon servers to handle quotas
 *          'mercury32'  --  Use Mercury/32 servers to handle quotas
 *
 * admin: Use this if you want to enable mailbox management for administrators
 *        via Horde's user administration interface.  The mailbox management
 *        gets enabled if you let IMP handle the Horde authentication with the
 *        'application' authentication driver.  Your IMAP server needs to
 *        support mailbox management via IMAP commands.
 *        Do not define this value if you do not want mailbox management.
 *
 * acl: Use this if you want to use Access Control Lists (folder sharing)
 *      Set 'driver' equal to the type of ACL your server supports and
 *      'params' to an array containing any additional parameters the
 *      driver needs. Not all IMAP servers currently support this
 *      feature.
 *
 *      At present the only driver supported is 'rfc2086', which does not
 *      require any parameters.
 *
 *      SECURTIY NOTE: If you do not have the PEAR Auth_SASL module
 *      installed, the 'rfc2086' driver will send user passwords to the
 *      IMAP server in plain text when retrieving ACLs.
 *
 * dotfiles: Should files that begin with a '.' be shown in the folder lists?
 *           This should be either true or false.
 *
 * hierarchies: Should we enable any folder hierarchies that aren't shown by
 *              default? For instance, UW can be configured to serve out
 *              folder hierarchies. This entry must be an array.
 *              Example folder hierarchies: #shared/, #news/, #ftp/, $public/
 */

/* Any entries whose key value ('foo' in $servers['foo']) begin with '_'
 * (an underscore character) will be treated as prompts, and you won't be
 * able to log in to them. The only property these entries need is 'name'.
 * This lets you put labels in the list, like this example: */
$servers['_prompt'] = array(
    'name' => _("Choose a mail server:")
);

/* Example configurations: */

$servers['cyrus'] = array(
    'name' => 'Cyrus IMAP Server',
    'server' => '@@servername@@.@@domainname@@',
    'hordeauth' => true,
    'protocol' => 'imap/notls',
    'port' => 143,
    'maildomain' => '@@domainname@@',
    'smtphost' => '@@servername@@.@@domainname@@',
    'smtpport' => 25,
    'realm' => '',
    'preferred' => '',
    'admin' => array(
        'params' => array(
            'login' => 'cyrus',
            'password' => '@@cyradmpw@@',
            // The 'userhierarchy' parameter defaults to 'user.'
            // If you are using a nonstandard hierarchy for personal
            // mailboxes, you will need to set it here.
            'userhierarchy' => 'user.',
            // Although these defaults are normally all that is required,
            // you can modify the following parameters from their default
            // values.
            'protocol' => 'imap/notls',
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
