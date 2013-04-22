<?php

/**
 * linuxmuster.net configuration for turba
 * thomas@linuxmuster.net
 * 22.04.2013
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
    // The default connection details are pulled from the Horde-wide SQL
    // connection configuration.
    'params' => array_merge($GLOBALS['conf']['sql'], array('table' => 'turba_objects')),
    // Using two tables as datasource.
    // 'params' => array_merge($GLOBALS['conf']['sql'],
    //                         array('table' => 'leaddetails LEFT JOIN leadaddress ON leaddetails.leadid = leadaddress.leadaddressid',
    //                               'filter' => 'leaddetails.converted = 0')),
    'map' => array(
        '__key' => 'object_id',
        '__owner' => 'owner_id',
        '__type' => 'object_type',
        '__members' => 'object_members',
        '__uid' => 'object_uid',
        'firstname' => 'object_firstname',
        'lastname' => 'object_lastname',
        'middlenames' => 'object_middlenames',
        'namePrefix' => 'object_nameprefix',
        'nameSuffix' => 'object_namesuffix',
        'name' => array('fields' => array('namePrefix', 'firstname',
                                          'middlenames', 'lastname',
                                          'nameSuffix'),
                        'format' => '%s %s %s %s %s',
                        'parse' => array(
                            array('fields' => array('firstname', 'middlenames',
                                                    'lastname'),
                                  'format' => '%s %s %s'),
                            array('fields' => array('firstname', 'lastname'),
                                  'format' => '%s %s'))),
        // This is a shorter version of a "name" composite field which only
        // consists of the first name and last name.
        // 'name' => array('fields' => array('firstname', 'lastname'),
        //                 'format' => '%s %s'),
        'alias' => 'object_alias',
        'birthday' => 'object_bday',
        // The photo field requires at least Horde 3.3 and a matching type
        // field.
        // 'photo' => 'object_photo',
        // 'phototype' => 'object_phototype',
        'homeStreet' => 'object_homestreet',
        'homePOBox' => 'object_homepob',
        'homeCity' => 'object_homecity',
        'homeProvince' => 'object_homeprovince',
        'homePostalCode' => 'object_homepostalcode',
        'homeCountry' => 'object_homecountry',
        // This is an example composite field for addresses, so you can display
        // the various map links. If you use this, be sure to add 'homeAddress'
        // to the 'tabs' parameter below.
        // 'homeAddress' => array('fields' => array('homeStreet', 'homeCity',
        //                                          'homeProvince',
        //                                          'homePostalCode'),
        //                        'format' => "%s \n %s, %s  %s"),
        'workStreet' => 'object_workstreet',
        'workPOBox' => 'object_workpob',
        'workCity' => 'object_workcity',
        'workProvince' => 'object_workprovince',
        'workPostalCode' => 'object_workpostalcode',
        'workCountry' => 'object_workcountry',
        'timezone' => 'object_tz',
        'email' => 'object_email',
        'homePhone' => 'object_homephone',
        'workPhone' => 'object_workphone',
        'cellPhone' => 'object_cellphone',
        'fax' => 'object_fax',
        'pager' => 'object_pager',
        'title' => 'object_title',
        'role' => 'object_role',
        'company' => 'object_company',
        // The logo field requires at least Horde 3.3 and a matching type
        // field.
        // 'logo' => 'object_logo',
        // 'logotype' => 'object_logotype',
        'category' => 'object_category',
        'notes' => 'object_notes',
        'website' => 'object_url',
        'freebusyUrl' => 'object_freebusyurl',
        'pgpPublicKey' => 'object_pgppublickey',
        'smimePublicKey' => 'object_smimepublickey',
    ),
    'tabs' => array(
        _("Personal") => array('firstname', 'lastname', 'middlenames',
                               'namePrefix', 'nameSuffix', 'name', 'alias',
                               'birthday', 'photo'),
        _("Location") => array('homeStreet', 'homePOBox', 'homeCity',
                               'homeProvince', 'homePostalCode', 'homeCountry',
                               'workStreet', 'workPOBox', 'workCity',
                               'workProvince', 'workPostalCode', 'workCountry',
                               'timezone'),
        _("Communications") => array('email', 'homePhone', 'workPhone',
                                     'cellPhone', 'fax', 'pager'),
        _("Organization") => array('title', 'role', 'company', 'logo'),
        _("Other") => array('category', 'notes', 'website', 'freebusyUrl',
                            'pgpPublicKey', 'smimePublicKey'),
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
    'export' => true,
    'browse' => true,
    'use_shares' => true,
    'list_name_field' => 'lastname',
    'alternative_name' => 'company',
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
