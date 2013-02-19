<?php

/**
 * linuxmuster.net configuration for turba
 * thomas@linuxmuster.net
 * 18.02.2013
 */
 
/**
 * A local address book in an SQL database. This implements a private
 * per-user address book. Sharing of this source with other users may be
 * accomplished by enabling Horde_Share for this source by setting
 * 'use_shares' => true.
 *
 * Be sure to create a turba_objects table in your Horde database from the
 * schema in turba/scripts/db/turba.sql if you use this source.
 */
$cfgSources['localsql'] = array(
    'title' => _("Mein Adressbuch"),
    'type' => 'sql',
    // The default connection details are pulled from the Horde-wide
    // SQL connection configuration.
    'params' => array_merge($conf['sql'], array('table' => 'turba_objects')),
    'map' => array(
        '__key' => 'object_id',
        '__owner' => 'owner_id',
        '__type' => 'object_type',
        '__members' => 'object_members',
        '__uid' => 'object_uid',
        'name' => 'object_name',
        'email' => 'object_email',
        'alias' => 'object_alias',
        'homeAddress' => 'object_homeaddress',
        'workAddress' => 'object_workaddress',
        'homePhone' => 'object_homephone',
        'workPhone' => 'object_workphone',
        'cellPhone' => 'object_cellphone',
        'fax' => 'object_fax',
        'title' => 'object_title',
        'company' => 'object_company',
        'notes' => 'object_notes',
        'pgpPublicKey' => 'object_pgppublickey',
        'smimePublicKey' => 'object_smimepublickey',
        'freebusyUrl' => 'object_freebusyurl'
    ),
    'search' => array(
        'name',
        'email'
    ),
    'strict' => array(
        'object_id',
        'owner_id',
        'object_type',
    ),
    'public' => false,
    'readonly' => false,
    'admin' => array(),
    'export' => true,
    'browse' => true
);

/**
 * A local address book in an LDAP directory. This implements a public
 * (shared) address book.
 */
$cfgSources['localldap'] = array(
    'title' => _("@@schoolname@@ Adressbuch"),
    'type' => 'ldap',
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
        'scope' => 'one',
        'charset' => 'iso-8859-1',
        // Consult the LDAP schema to verify that all required attributes for
        // an entry are set and add them if needed.
        'checkrequired' => false,
        // Value used to fill in missing required attributes.
        'checkrequired_string' => ' ',
        // Check LDAP schema for valid syntax. If this is false an address
        // field is assumed to have postalAddress syntax; otherwise the schema
        // is consulted for the syntax to use.
        'checksyntax' => false,
        'version' => 3
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
    'strict' => array('dn'),
    'approximate' => array('cn'),
    'readonly' => true,
    'export' => false,
    'browse' => true
);