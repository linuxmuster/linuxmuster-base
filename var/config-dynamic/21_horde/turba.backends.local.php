<?php
/**
 * A local address book in an SQL database. This implements a private
 */
$cfgSources['localsql'] = array(
    'disabled' => false,
    'title' => _("Mein Adressbuch"),
);

/**
 * A local address book in an LDAP directory. This implements a public
 * (shared) address book.
 */
$cfgSources['localldap'] = array(
    'disabled' => false,
    'title' => _("@@schoolname@@ Adressbuch"),
    'params' => array(
        'server' => 'localhost',
        'port' => 389,
        'tls' => false,
        'root' => 'ou=accounts,@@basedn@@',
        'sizelimit' => 200,
        'dn' => array('cn'),
        'objectclass' => array('top',
                               'posixAccount',
                               'sambaSamAccount',
                               'inetOrgPerson'
        ),
    ),
    'map' => array(
        '__key' => 'dn',
        '__uid' => 'uid',
        'name' => 'cn',
        'email' => 'mail'
    ),
    'search' => array(
        'name',
        'email'
    ),
    'strict' => array(
        'dn'
    ),
    'approximate' => array(
        'cn',
    ),
    'readonly' => true,
    'export' => false,
    'browse' => true
);
