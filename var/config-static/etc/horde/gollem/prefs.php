<?php
/**
 * $Horde: gollem/config/prefs.php.dist,v 1.32.2.1 2008-10-09 20:54:40 jan Exp $
 *
 * See horde/config/prefs.php for documentation on the structure of this file.
 *
 * thomas@linuxmuster.net
 * 19.02.2013
 */

// Make sure that constants are defined.
@define('GOLLEM_BASE', '/usr/share/horde3/gollem');
require_once GOLLEM_BASE . '/lib/Gollem.php';

$prefGroups['display'] = array(
    'column' => _("User Interface"),
    'label' => _("File Display"),
    'desc' => _("Change your file sorting options."),
    'members' => array('show_dotfiles', 'sortdirsfirst', 'columnselect',
                       'sortby', 'sortdir', 'perpage'));

$prefGroups['settings'] = array(
    'column' => _("User Interface"),
    'label' => _("Settings"),
    'desc' => _("Change file and folder handling settings."),
    'members' => array('recursive_deletes'));

// show dotfiles?
$_prefs['show_dotfiles'] = array(
    'value' => 1,
    'locked' => false,
    'shared' => false,
    'type' => 'checkbox',
    'desc' => _("Show dotfiles?")
);

// columns selection widget
$_prefs['columnselect'] = array(
    'locked' => false,
    'type' => 'special'
);

// columns to be displayed
$_prefs['columns'] = array(
    'value' => "ftp\ttype\tname\tdownload\tmodified\tsize\tpermission\towner\tgroup",
    'locked' => false,
    'shared' => false,
    'type' => 'implicit'
);

// user preferred sorting column
$_prefs['sortby'] = array(
    'value' => GOLLEM_SORT_TYPE,
    'locked' => false,
    'shared' => false,
    'type' => 'enum',
    'enum' => array(
        GOLLEM_SORT_TYPE => _("File Type"),
        GOLLEM_SORT_NAME => _("File Name"),
        GOLLEM_SORT_DATE => _("File Modification Time"),
        GOLLEM_SORT_SIZE => _("File Size")
    ),
    'desc' => _("Default sorting criteria:")
);

// user preferred sorting direction
$_prefs['sortdir'] = array(
    'value' => 0,
    'locked' => false,
    'shared' => false,
    'type' => 'enum',
    'enum' => array(
        GOLLEM_SORT_ASCEND => _("Ascending"),
        GOLLEM_SORT_DESCEND => _("Descending")
    ),
    'desc' => _("Default sorting direction:")
);

// always sort directories before files
$_prefs['sortdirsfirst'] = array(
    'value' => 0,
    'locked' => false,
    'shared' => false,
    'type' => 'checkbox',
    'desc' => _("List folders first?")
);

// number of items per page
$_prefs['perpage'] = array(
    'value' => 20,
    'locked' => false,
    'shared' => true,
    'type' => 'number',
    'desc' => _("Items per page")
);

// user preferred recursive deletes
$_prefs['recursive_deletes'] = array(
    'value' => 'disabled',
    'locked' => false,
    'shared' => false,
    'type' => 'enum',
    'enum' => array(
        'disabled' => _("No"),
        'enabled' => _("Yes"),
        'warn' => _("Ask")
    ),
    'desc' => _("Delete folders recursively?")
);
