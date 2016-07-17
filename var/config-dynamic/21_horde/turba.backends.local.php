<?php
$cfgSources['localsql'] = array(
    // ENABLED by default
    'disabled' => false,
    'title' => _("Mein Adressbuch"),
    'type' => 'sql',
    'params' => array(
        'table' => 'turba_objects'
    ),
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
        'alias' => 'object_alias',
        'yomifirstname' => 'object_yomifirstname',
        'yomilastname' => 'object_yomilastname',
        'birthday' => 'object_bday',
        'anniversary' => 'object_anniversary',
        'spouse' => 'object_spouse',
        'photo' => 'object_photo',
        'phototype' => 'object_phototype',
        'homeStreet' => 'object_homestreet',
        'homePOBox' => 'object_homepob',
        'homeCity' => 'object_homecity',
        'homeProvince' => 'object_homeprovince',
        'homePostalCode' => 'object_homepostalcode',
        'homeCountry' => 'object_homecountry',
        'homeAddress' => array('fields' => array('homeStreet', 'homeCity',
                                                 'homeProvince',
                                                 'homePostalCode'),
                               'format' => "%s\n%s, %s  %s"),
        'workStreet' => 'object_workstreet',
        'workPOBox' => 'object_workpob',
        'workCity' => 'object_workcity',
        'workProvince' => 'object_workprovince',
        'workPostalCode' => 'object_workpostalcode',
        'workCountry' => 'object_workcountry',
        'workAddress' => array('fields' => array('workStreet', 'workCity',
                                                 'workProvince',
                                                 'workPostalCode'),
                               'format' => "%s\n%s, %s  %s"),
        'otherStreet' => 'object_otherstreet',
        'otherPOBox' => 'object_otherpob',
        'otherCity' => 'object_othercity',
        'otherProvince' => 'object_otherprovince',
        'otherPostalCode' => 'object_otherpostalcode',
        'otherCountry' => 'object_othercountry',
        'otherAddress' => array('fields' => array('otherStreet', 'otherCity',
                                                  'otherProvince',
                                                  'otherPostalCode'),
                                'format' => "%s\n%s, %s  %s"),
        'department' => 'object_department',
        'manager' => 'object_manager',
        'assistant' => 'object_assistant',
        'timezone' => 'object_tz',
        'email' => 'object_email',
        'homePhone' => 'object_homephone',
        'homePhone2' => 'object_homephone2',
        'homeFax' => 'object_homefax',
        'workPhone' => 'object_workphone',
        'workPhone2' => 'object_workphone2',
        'cellPhone' => 'object_cellphone',
        'carPhone' => 'object_carphone',
        'radioPhone' => 'object_radiophone',
        'companyPhone' => 'object_companyphone',
        'assistPhone' => 'object_assistantphone',
        'fax' => 'object_fax',
        'pager' => 'object_pager',
        'title' => 'object_title',
        'role' => 'object_role',
        'company' => 'object_company',
        'logo' => 'object_logo',
        'logotype' => 'object_logotype',
        'notes' => 'object_notes',
        'website' => 'object_url',
        'freebusyUrl' => 'object_freebusyurl',
        'pgpPublicKey' => 'object_pgppublickey',
        'smimePublicKey' => 'object_smimepublickey',
        'imaddress' => 'object_imaddress',
        'imaddress2' => 'object_imaddress2',
        'imaddress3' => 'object_imaddress3'
    ),
    'tabs' => array(
        _("Personal") => array('firstname', 'lastname', 'middlenames',
                               'namePrefix', 'nameSuffix', 'name', 'alias',
                               'birthday', 'spouse', 'anniversary',
                               'yomifirstname', 'yomilastname', 'photo'),
        _("Location") => array('homeStreet', 'homePOBox', 'homeCity',
                               'homeProvince', 'homePostalCode', 'homeCountry',
                               'homeAddress', 'workStreet', 'workPOBox',
                               'workCity', 'workProvince', 'workPostalCode',
                               'workCountry', 'workAddress', 'otherStreet',
                               'otherPOBox', 'otherCity', 'otherProvince',
                               'otherPostalCode', 'otherCountry',
                               'otherAddress','timezone'),
        _("Communications") => array('email', 'homeEmail', 'workEmail',
                                     'homePhone', 'homePhone2',
                                     'workPhone', 'workPhone2', 'carPhone',
                                     'radioPhone', 'companyPhone',
                                     'assistPhone', 'homeFax',
                                     'cellPhone', 'fax', 'pager', 'imaddress',
                                     'imaddress2', 'imaddress3'),
        _("Organization") => array('title', 'role', 'company', 'department', 'logo', 'assistant', 'manager'),
        _("Other") => array('notes', 'website', 'freebusyUrl',
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
        'object_uid'
    ),
    'export' => true,
    'browse' => true,
    'use_shares' => false,
    'list_name_field' => 'lastname',
    'alternative_name' => 'company',
);

$cfgSources['localldap'] = array(
    // Disabled by default
    'disabled' => false,
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
                               'person',
                               'posixAccout',
                               'inetOrgPerson'),
        'scope' => 'one',
        'charset' => 'utf-8',
        'checkrequired' => false,
        'checkrequired_string' => ' ',
        'checksyntax' => false,
        'version' => 3,
    ),
    'map' => array(
        '__key' => 'dn',
        '__uid' => 'uid',
        'name' => 'cn',
        'email' => 'mail',
        'homePhone' => 'homephone',
        'workPhone' => 'telephonenumber',
        'cellPhone' => 'mobiletelephonenumber',
        'homeAddress' => 'homepostaladdress',
    ),
    'search' => array(
        'name',
        'email',
    ),
    'strict' => array(
        'dn',
    ),
    'approximate' => array(
        'cn',
    ),
    'readonly' => true,
    'export' => true,
    'browse' => true,
);
