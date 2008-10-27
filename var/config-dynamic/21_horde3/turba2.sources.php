<?php
/**
 * $Horde: turba/config/sources.php.dist,v 1.97.6.3 2005/02/08 20:43:47 chuck Exp $
 *
 * This file is where you specify the sources of contacts available to users at
 * your installation.  It contains a large number of EXAMPLES.  Please remove
 * or comment out those examples that YOU DON'T NEED.
 * There are a number of properties that you can set for each server,
 * including:
 *
 * title:    This is the common (user-visible) name that you want displayed in
 *           the contact source drop-down box.
 *
 * type:     The types 'ldap', 'sql', 'imsp' and 'prefs' are currently
 *           supported.  Preferences-based addressbooks are not intended for
 *           production installs unless you really know what you're doing -
 *           they are not searchable, and they won't scale well if a user has a
 *           large number of entries.
 *
 * params:   These are the connection parameters specific to the contact
 *           source.  See below for examples of how to set these.
 *
 * Special params settings:
 *
 *   charset:  The character set that the backend stores data in. Many LDAP
 *             servers use utf-8. Database servers typically use iso-8859-1.
 *
 *   tls:      Only applies to LDAP servers. If true, then try to use a TLS
 *             connection to the server.
 *
 * map:      This is a list of mappings from the standard Turba attribute names
 *           (on the left) to the attribute names by which they are known in
 *           this contact source (on the right).  Turba also supports composite
 *           fields.  A composite field is defined by mapping the field name to
 *           an array containing a list of component fields and a format string
 *           (similar to a printf() format string).  Here is an example:
 *           ...
 *           'name' => array('fields' => array('firstname', 'lastname'),
 *                           'format' => '%s %s'),
 *           'firstname' => 'object_firstname',
 *           'lastname' => 'object_lastname',
 *           ...
 *
 * tabs:     All fields can be grouped into tabs with this optional entry. This
 *           list is multidimensional hash, the keys are the tab titles.  Here
 *           is an example:
 *           'tabs' => array(
 *               'Names' => array('firstname', 'lastname', 'alias'),
 *               'Addresses' => array('homeAddress', 'workAddress')
 *           );
 *
 * search:   A list of Turba attribute names that can be searched for this
 *           source.
 *
 * strict:   A list of native field/attribute names that must always be matched
 *           exactly in a search.
 *
 * public:   If set to true, this source will be available to all users.  See
 *           also 'readonly' -- public=true readonly=false means writable by
 *           all users!
 *
 * readonly: If set to true, this source can only be modified by users on the
 *           'admin' list.
 *
 * admin:    A list (array) of users that are allowed to modify this source, if
 *           it's marked 'readonly'.
 *
 * export:   If set to true, this source will appear on the Export menu,
 *           allowing users to export the contacts to a CSV (etc.) file.
 *
 * Here are some example configurations:
 */

/**
 * A local address book in an SQL database. This implements a per-user
 * address book.
 *
 * Be sure to create a turba_objects table in your Horde database
 * from the schema in turba/scripts/db/turba.sql if you use
 * this source.
 */
$cfgSources['localsql'] = array(
    'title' => _("Mein Adressbuch"),
    'type' => 'sql',
    // The default connection details are pulled from the Horde-wide
    // SQL connection configuration.
    //
    // The old example illustrates how to use an alternate database
    // configuration.
    //
    // New Example:
    'params' => array_merge($conf['sql'], array('table' => 'turba_objects')),

    // Old Example:
    // 'params' => array(
    //     'phptype' => 'mysql',
    //     'hostspec' => 'localhost',
    //     'username' => 'horde',
    //     'password' => '*****',
    //     'database' => 'horde',
    //     'table' => 'turba_objects',
    //     'charset' => 'iso-8859-1'
    // ),
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
    'export' => true
);

/**
 * Schule
 */
$cfgSources['schule'] = array(
    'title' => _("@@schoolname@@ Adressbuch"),
    'type' => 'ldap',
    'params' => array(
        'server' => 'localhost',
        'port' => 389,
        'tls' => false,
        'root' => 'ou=accounts,@@basedn@@',
        'dn' => array('cn'),
        'objectclass' => 'person',
        'filter' => '',
        'charset' => 'iso-8859-1'
    ),
    'map' => array(
        '__key' => 'dn',
        'name' => 'cn',
        'email' => 'uid'
    ),
    'search' => array(
        'name',
        'email'
    ),
    'strict' => array(
        'dn'
    ),
    'public' => true,
    'readonly' => true,
    'export' => false
);
