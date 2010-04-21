--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: postgres
--

CREATE PROCEDURAL LANGUAGE plpgsql;


ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO postgres;

SET search_path = public, pg_catalog;

--
-- Name: create_account(); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION create_account() RETURNS integer
    AS $$SELECT setval ('posix_account_id_seq', (select case when max(id) is null then 1 else max(id) end from posix_account));
INSERT INTO posix_account (id,uidnumber,uid,gidnumber) VALUES (nextval('posix_account_id_seq'),00,0,0);
INSERT INTO samba_sam_account (id) VALUES ((SELECT max(id) FROM posix_account));
SELECT max(id) FROM posix_account$$
    LANGUAGE sql;


ALTER FUNCTION public.create_account() OWNER TO ldap;

--
-- Name: create_groups(); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION create_groups() RETURNS integer
    AS $$SELECT setval ('groups_id_seq', (select max(id) FROM groups));
INSERT INTO groups (id,gid,gidnumber) VALUES (nextval('groups_id_seq'),'',00);
INSERT INTO samba_group_mapping (id,gidnumber) VALUES ((SELECT max(id) FROM groups),00);
SELECT max(id) FROM groups
$$
    LANGUAGE sql;


ALTER FUNCTION public.create_groups() OWNER TO ldap;

--
-- Name: create_organizational_unit(); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION create_organizational_unit() RETURNS integer
    AS $$
	SELECT setval ('organizational_unit_id_seq', (select max(id) FROM organizational_unit));
	INSERT INTO organizational_unit (id,ou,description) 
		VALUES (nextval('organizational_unit_id_seq'),'','');
	SELECT max(id) FROM organizational_unit
$$
    LANGUAGE sql;


ALTER FUNCTION public.create_organizational_unit() OWNER TO ldap;

--
-- Name: create_samba_domain(); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION create_samba_domain() RETURNS integer
    AS $$INSERT INTO samba_domain (id,sambadomainname,sambasid) VALUES (nextval('posix_account_id_seq'),0,0);
SELECT max(id) FROM samba_domain$$
    LANGUAGE sql;


ALTER FUNCTION public.create_samba_domain() OWNER TO ldap;

--
-- Name: del_account_description(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_description(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET description=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_description(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_displayname(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_displayname(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET displayname=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_displayname(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_firstname(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_firstname(integer, character varying) RETURNS integer
    AS $_$UPDATE posix_account SET firstname=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_firstname(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_gecos(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_gecos(integer, character varying) RETURNS integer
    AS $_$UPDATE posix_account SET gecos=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_gecos(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_gidnumber(integer, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_gidnumber(integer, integer) RETURNS integer
    AS $_$        UPDATE posix_account SET gidnumber=1 WHERE id=CAST($1 AS INT);
        SELECT $1 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_gidnumber(integer, integer) OWNER TO ldap;

--
-- Name: del_account_homedirectory(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_homedirectory(integer, character varying) RETURNS integer
    AS $_$UPDATE posix_account SET homedirectory=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_homedirectory(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_loginshell(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_loginshell(integer, character varying) RETURNS integer
    AS $_$UPDATE posix_account SET loginshell=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_loginshell(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_memberuid(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_memberuid(integer, character varying) RETURNS integer
    AS $_$
DELETE FROM groups_users WHERE gidnumber=(SELECT gidnumber FROM groups WHERE id=$1) AND memberuidnumber=(SELECT uidnumber from posix_account WHERE uid=$2);
SELECT $1 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_memberuid(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambaacctflags(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambaacctflags(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambaacctflags=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambaacctflags(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambabadpasswordcount(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambabadpasswordcount(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambabadpasswordcount=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambabadpasswordcount(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambabadpasswordtime(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambabadpasswordtime(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambabadpasswordtime=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambabadpasswordtime(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambadomainname(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambadomainname(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambadomainname=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambadomainname(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambahomedrive(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambahomedrive(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambahomedrive=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambahomedrive(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambahomepath(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambahomepath(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambahomepath=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambahomepath(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambakickofftime(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambakickofftime(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambakickofftime=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambakickofftime(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambalmpassword(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambalmpassword(integer, character varying) RETURNS integer
    AS $_$UPDATE samba_sam_account SET sambalmpassword=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambalmpassword(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambalogofftime(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambalogofftime(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambalogofftime=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambalogofftime(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambalogonhours(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambalogonhours(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambalogonhours=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambalogonhours(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambalogonscript(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambalogonscript(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambalogonscript=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambalogonscript(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambalogontime(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambalogontime(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambalogontime=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambalogontime(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambamungeddial(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambamungeddial(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambamungeddial=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambamungeddial(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambantpassword(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambantpassword(integer, character varying) RETURNS integer
    AS $_$UPDATE samba_sam_account SET sambantpassword=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambantpassword(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambapasswordhistory(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambapasswordhistory(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambapasswordhistory=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambapasswordhistory(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambaprimarygroupsid(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambaprimarygroupsid(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambaprimarygroupsid=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambaprimarygroupsid(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambaprofilepath(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambaprofilepath(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambaprofilepath=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambaprofilepath(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambapwdcanchange(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambapwdcanchange(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambapwdcanchange=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambapwdcanchange(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambapwdlastset(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambapwdlastset(integer, character varying) RETURNS integer
    AS $_$UPDATE samba_sam_account SET sambapwdlastset=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambapwdlastset(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambapwdmustchange(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambapwdmustchange(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambapwdmustchange=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambapwdmustchange(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambasid(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambasid(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambasid=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambasid(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sambauserworkstations(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sambauserworkstations(integer, character varying) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambauserworkstations=NULL WHERE id=CAST($1 AS INT); SELECT $1 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sambauserworkstations(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_sn(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_sn(integer, character varying) RETURNS integer
    AS $_$UPDATE posix_account SET surname=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_sn(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_uid(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_uid(integer, character varying) RETURNS integer
    AS $_$UPDATE posix_account SET uid=1 WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_uid(integer, character varying) OWNER TO ldap;

--
-- Name: del_account_uidnumber(integer, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_uidnumber(integer, integer) RETURNS integer
    AS $_$UPDATE posix_account SET uidnumber=0 WHERE id=CAST($1 AS INT);
SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_uidnumber(integer, integer) OWNER TO ldap;

--
-- Name: del_account_userpassword(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_account_userpassword(integer, character varying) RETURNS integer
    AS $_$UPDATE posix_account SET userpassword=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_account_userpassword(integer, character varying) OWNER TO ldap;

--
-- Name: del_groups_cn(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_groups_cn(integer, character varying) RETURNS integer
    AS $_$
UPDATE groups SET gid='delete' WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_groups_cn(integer, character varying) OWNER TO ldap;

--
-- Name: del_groups_description(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_groups_description(integer, character varying) RETURNS integer
    AS $_$
UPDATE samba_group_mapping SET description=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_groups_description(integer, character varying) OWNER TO ldap;

--
-- Name: del_groups_displayname(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_groups_displayname(integer, character varying) RETURNS integer
    AS $_$
UPDATE samba_group_mapping SET displayname=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_groups_displayname(integer, character varying) OWNER TO ldap;

--
-- Name: del_groups_gidnumber(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_groups_gidnumber(integer, character varying) RETURNS integer
    AS $_$
UPDATE groups SET gidnumber=0 WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_groups_gidnumber(integer, character varying) OWNER TO ldap;

--
-- Name: del_groups_sambagrouptype(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_groups_sambagrouptype(integer, character varying) RETURNS integer
    AS $_$
UPDATE samba_group_mapping SET sambagrouptype=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_groups_sambagrouptype(integer, character varying) OWNER TO ldap;

--
-- Name: del_groups_sambasid(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_groups_sambasid(integer, character varying) RETURNS integer
    AS $_$
UPDATE samba_group_mapping SET sambasid=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_groups_sambasid(integer, character varying) OWNER TO ldap;

--
-- Name: del_groups_sambasidlist(integer, character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION del_groups_sambasidlist(integer, character varying) RETURNS integer
    AS $_$
UPDATE samba_group_mapping SET sambasidlist=NULL WHERE id=CAST($1 AS INT);
SELECT $1 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.del_groups_sambasidlist(integer, character varying) OWNER TO ldap;

--
-- Name: delete_account(integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION delete_account(integer) RETURNS integer
    AS $_$delete from posix_account where id=$1;
delete from samba_sam_account where id=$1;
SELECT max(id) FROM posix_account$_$
    LANGUAGE sql;


ALTER FUNCTION public.delete_account(integer) OWNER TO ldap;

--
-- Name: delete_groups(integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION delete_groups(integer) RETURNS integer
    AS $_$delete from groups where id=$1;
delete from samba_group_mapping where id=$1;
SELECT max(id) FROM groups$_$
    LANGUAGE sql;


ALTER FUNCTION public.delete_groups(integer) OWNER TO ldap;

--
-- Name: delete_organizational_unit(integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION delete_organizational_unit(integer) RETURNS integer
    AS $_$
	DELETE FROM organizational_unit WHERE id=CAST($1 AS INT);
	SELECT $1 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.delete_organizational_unit(integer) OWNER TO ldap;

--
-- Name: manual_create_ldap_for_account(character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION manual_create_ldap_for_account(character varying) RETURNS integer
    AS $_$ 
    DECLARE
     username ALIAS FOR $1;
     posix_account_id INTEGER;
     ldap_entries_id INTEGER;
     getdn VARCHAR;
    BEGIN
     SELECT INTO posix_account_id nextval('posix_account_id_seq');
     SELECT INTO ldap_entries_id nextval('ldap_entries_id_seq');
     SELECT INTO getdn dn FROM ldap_entries WHERE id=1;
     
     INSERT INTO ldap_entries (id,dn,oc_map_id,parent,keyval) VALUES (ldap_entries_id,'uid='||username||',ou=accounts,'||getdn,3,2,posix_account_id);
     
     INSERT INTO ldap_entry_objclasses (entry_id,oc_name) VALUES (ldap_entries_id,'top');
     INSERT INTO ldap_entry_objclasses (entry_id,oc_name) VALUES (ldap_entries_id,'posixAccount');
     INSERT INTO ldap_entry_objclasses (entry_id,oc_name) VALUES (ldap_entries_id,'shadowAccount');
     INSERT INTO ldap_entry_objclasses (entry_id,oc_name) VALUES (ldap_entries_id,'sambaSamAccount');
     
     RETURN posix_account_id;
    END;
    $_$
    LANGUAGE plpgsql;


ALTER FUNCTION public.manual_create_ldap_for_account(character varying) OWNER TO ldap;

--
-- Name: manual_create_ldap_for_group(character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION manual_create_ldap_for_group(character varying) RETURNS integer
    AS $_$
    DECLARE
     groupname ALIAS FOR $1;
     groups_id INTEGER;
     ldap_entries_id INTEGER;
     getdn VARCHAR;
     BEGIN
     SELECT INTO groups_id nextval('groups_id_seq');
     SELECT INTO ldap_entries_id nextval('ldap_entries_id_seq');
     SELECT INTO getdn dn FROM ldap_entries WHERE id=1;

     INSERT INTO ldap_entries (id,dn,oc_map_id,parent,keyval) VALUES (ldap_entries_id,'cn='||groupname||',ou=groups,'||getdn,4,5,groups_id);

     INSERT INTO ldap_entry_objclasses (entry_id,oc_name) VALUES (ldap_entries_id,'sambaGroupMapping');

     RETURN groups_id;
    END;
    $_$
    LANGUAGE plpgsql;


ALTER FUNCTION public.manual_create_ldap_for_group(character varying) OWNER TO ldap;

--
-- Name: manual_delete_account(character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION manual_delete_account(character varying) RETURNS integer
    AS $_$
    DECLARE
     username ALIAS FOR $1;
     posix_account_id INTEGER;
     get_uidnumber INTEGER;
     ldap_entries_id INTEGER;
    BEGIN
     SELECT INTO posix_account_id id FROM posix_account WHERE uid=username;
     SELECT INTO get_uidnumber uidnumber FROM posix_account WHERE uid=username;
     SELECT INTO ldap_entries_id id FROM ldap_entries WHERE keyval=posix_account_id AND oc_map_id=3;

     DELETE FROM ldap_entries WHERE id=ldap_entries_id;
     DELETE FROM groups_users WHERE memberuidnumber=get_uidnumber;
     DELETE FROM ldap_entry_objclasses WHERE entry_id=ldap_entries_id;
     DELETE FROM posix_account WHERE id=posix_account_id;
     DELETE FROM posix_account_details WHERE id=posix_account_id;
     DELETE FROM samba_sam_account WHERE id=posix_account_id;

     RETURN get_uidnumber;
    END;
    $_$
    LANGUAGE plpgsql;


ALTER FUNCTION public.manual_delete_account(character varying) OWNER TO ldap;

--
-- Name: manual_delete_groups(character varying); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION manual_delete_groups(character varying) RETURNS integer
    AS $_$
DECLARE
groupname ALIAS FOR $1;
groups_id INTEGER;
get_gidnumber INTEGER;
ldap_entries_id INTEGER;
BEGIN
SELECT INTO groups_id id FROM groups WHERE gid=groupname;
SELECT INTO get_gidnumber gidnumber FROM groups WHERE gid=groupname;
SELECT INTO ldap_entries_id id FROM ldap_entries WHERE keyval=groups_id AND oc_map_id=4;

DELETE FROM ldap_entries WHERE id=ldap_entries_id;
DELETE FROM groups_users WHERE gidnumber=get_gidnumber;
DELETE FROM ldap_entry_objclasses WHERE entry_id=ldap_entries_id;
DELETE FROM groups WHERE id=groups_id;
DELETE FROM samba_group_mapping WHERE id=groups_id;

RETURN get_gidnumber;
END;
$_$
    LANGUAGE plpgsql;


ALTER FUNCTION public.manual_delete_groups(character varying) OWNER TO ldap;

--
-- Name: manual_get_next_free_gid(); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION manual_get_next_free_gid() RETURNS integer
    AS $$
    DECLARE
     get_gidnumber INTEGER;
     BEGIN
     SELECT INTO get_gidnumber gidnumber from posix_account WHERE uid='NextFreeUnixId';
     UPDATE posix_account set gidnumber=get_gidnumber+1 WHERE uid='NextFreeUnixId';

     RETURN get_gidnumber;
    END;
    $$
    LANGUAGE plpgsql;


ALTER FUNCTION public.manual_get_next_free_gid() OWNER TO ldap;

--
-- Name: manual_get_next_free_uid(); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION manual_get_next_free_uid() RETURNS integer
    AS $$ 
    DECLARE
     get_uidnumber INTEGER;
    BEGIN
     SELECT INTO get_uidnumber uidnumber from posix_account WHERE uid='NextFreeUnixId';
     UPDATE posix_account set uidnumber=get_uidnumber+1 WHERE uid='NextFreeUnixId';

     RETURN get_uidnumber;
    END; 
    $$
    LANGUAGE plpgsql;


ALTER FUNCTION public.manual_get_next_free_uid() OWNER TO ldap;

--
-- Name: plpgsql_call_handler(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION plpgsql_call_handler() RETURNS language_handler
    AS '$libdir/plpgsql', 'plpgsql_call_handler'
    LANGUAGE c;


ALTER FUNCTION public.plpgsql_call_handler() OWNER TO postgres;

--
-- Name: set_account_cn(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_cn(character varying, integer) RETURNS integer
    AS $_$update posix_account set firstname = (
		select case 
			when position(' ' in $1) = 0 then $1 
			else substr($1, 1, position(' ' in $1) - 1)
		end
	),surname = (
		select case 
			when position(' ' in $1) = 0 then ''
			else substr($1, position(' ' in $1) + 1) 
		end
	) where id = $2;
select $2 as return$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_cn(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_description(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_description(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET description=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_description(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_displayname(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_displayname(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET displayname=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_displayname(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_firstname(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_firstname(character varying, integer) RETURNS integer
    AS $_$
        UPDATE posix_account SET firstname=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
        SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_firstname(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_gecos(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_gecos(character varying, integer) RETURNS integer
    AS $_$UPDATE posix_account SET gecos=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_gecos(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_gidnumber(integer, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_gidnumber(integer, integer) RETURNS integer
    AS $_$
        UPDATE posix_account SET gidnumber=CAST($1 AS INT) WHERE id=CAST($2 AS INT);
        SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_gidnumber(integer, integer) OWNER TO ldap;

--
-- Name: set_account_homedirectory(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_homedirectory(character varying, integer) RETURNS integer
    AS $_$
        UPDATE posix_account SET homedirectory=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
        SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_homedirectory(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_loginshell(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_loginshell(character varying, integer) RETURNS integer
    AS $_$
        UPDATE posix_account SET loginshell=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
        SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_loginshell(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_memberuid(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_memberuid(character varying, integer) RETURNS integer
    AS $_$
INSERT INTO groups_users (gidnumber,memberuidnumber) VALUES ((SELECT gidnumber FROM groups WHERE id=$2), (SELECT uidnumber from posix_account WHERE uid=$1));
SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_memberuid(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambaacctflags(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambaacctflags(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambaacctflags=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambaacctflags(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambabadpasswordcount(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambabadpasswordcount(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambabadpasswordcount=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambabadpasswordcount(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambabadpasswordtime(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambabadpasswordtime(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambabadpasswordtime=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambabadpasswordtime(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambadomainname(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambadomainname(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambadomainname=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambadomainname(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambahomedrive(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambahomedrive(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambahomedrive=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambahomedrive(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambahomepath(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambahomepath(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambahomepath=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambahomepath(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambakickofftime(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambakickofftime(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambakickofftime=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambakickofftime(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambalmpassword(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambalmpassword(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambalmpassword=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambalmpassword(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambalogofftime(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambalogofftime(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambalogofftime=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambalogofftime(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambalogonhours(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambalogonhours(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambalogonhours=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambalogonhours(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambalogonscript(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambalogonscript(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambalogonscript=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambalogonscript(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambalogontime(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambalogontime(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambalogontime=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambalogontime(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambamungeddial(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambamungeddial(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambamungeddial=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambamungeddial(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambantpassword(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambantpassword(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambantpassword=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambantpassword(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambapasswordhistory(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambapasswordhistory(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambapasswordhistory=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambapasswordhistory(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambaprimarygroupsid(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambaprimarygroupsid(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambaprimarygroupsid=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambaprimarygroupsid(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambaprofilepath(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambaprofilepath(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambaprofilepath=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambaprofilepath(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambapwdcanchange(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambapwdcanchange(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambapwdcanchange=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambapwdcanchange(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambapwdlastset(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambapwdlastset(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambapwdlastset=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambapwdlastset(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambapwdmustchange(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambapwdmustchange(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambapwdmustchange=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambapwdmustchange(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambasid(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambasid(character varying, integer) RETURNS integer
    AS $_$UPDATE samba_sam_account SET sambasid=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); 
INSERT INTO ldap_entry_objclasses (entry_id,oc_name) VALUES ((SELECT id from ldap_entries WHERE oc_map_id=3 AND keyval=$2),'sambaSamAccount');
SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambasid(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sambauserworkstations(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sambauserworkstations(character varying, integer) RETURNS integer
    AS $_$ UPDATE samba_sam_account SET sambauserworkstations=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sambauserworkstations(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_sn(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_sn(character varying, integer) RETURNS integer
    AS $_$        UPDATE posix_account SET surname=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
        SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_sn(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_uid(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_uid(character varying, integer) RETURNS integer
    AS $_$
        UPDATE posix_account SET uid=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
        SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_uid(character varying, integer) OWNER TO ldap;

--
-- Name: set_account_uidnumber(integer, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_uidnumber(integer, integer) RETURNS integer
    AS $_$UPDATE posix_account SET uidnumber=CAST($1 AS INT) WHERE id=CAST($2 AS INT);
SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_uidnumber(integer, integer) OWNER TO ldap;

--
-- Name: set_account_userpassword(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_account_userpassword(character varying, integer) RETURNS integer
    AS $_$
        UPDATE posix_account SET userpassword=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
        SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_account_userpassword(character varying, integer) OWNER TO ldap;

--
-- Name: set_groups_cn(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_groups_cn(character varying, integer) RETURNS integer
    AS $_$UPDATE groups SET gid=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_groups_cn(character varying, integer) OWNER TO ldap;

--
-- Name: set_groups_description(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_groups_description(character varying, integer) RETURNS integer
    AS $_$        UPDATE samba_group_mapping SET description=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
                SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_groups_description(character varying, integer) OWNER TO ldap;

--
-- Name: set_groups_displayname(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_groups_displayname(character varying, integer) RETURNS integer
    AS $_$        UPDATE samba_group_mapping SET displayname=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
                SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_groups_displayname(character varying, integer) OWNER TO ldap;

--
-- Name: set_groups_gidnumber(integer, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_groups_gidnumber(integer, integer) RETURNS integer
    AS $_$UPDATE groups SET gidnumber=CAST($1 AS INT) WHERE id=CAST($2 AS INT);
UPDATE samba_group_mapping SET gidnumber=CAST($1 AS INT) WHERE id=CAST($2 AS INT);
SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_groups_gidnumber(integer, integer) OWNER TO ldap;

--
-- Name: set_groups_sambagrouptype(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_groups_sambagrouptype(character varying, integer) RETURNS integer
    AS $_$        UPDATE samba_group_mapping SET sambagrouptype=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
                SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_groups_sambagrouptype(character varying, integer) OWNER TO ldap;

--
-- Name: set_groups_sambasid(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_groups_sambasid(character varying, integer) RETURNS integer
    AS $_$UPDATE samba_group_mapping SET sambasid=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
INSERT INTO ldap_entry_objclasses (entry_id,oc_name) VALUES ((SELECT id from ldap_entries WHERE oc_map_id=4 AND keyval=$2),'sambaGroupMapping');
SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_groups_sambasid(character varying, integer) OWNER TO ldap;

--
-- Name: set_groups_sambasidlist(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_groups_sambasidlist(character varying, integer) RETURNS integer
    AS $_$        UPDATE samba_group_mapping SET sambasidlist=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
                SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_groups_sambasidlist(character varying, integer) OWNER TO ldap;

--
-- Name: set_organizational_unit_ou(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_organizational_unit_ou(character varying, integer) RETURNS integer
    AS $_$
	UPDATE organizational_unit SET ou=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT);
        SELECT $2 AS RETURN
$_$
    LANGUAGE sql;


ALTER FUNCTION public.set_organizational_unit_ou(character varying, integer) OWNER TO ldap;

--
-- Name: set_samba_domain_name(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_samba_domain_name(character varying, integer) RETURNS integer
    AS $_$UPDATE samba_domain SET sambadomainname=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_samba_domain_name(character varying, integer) OWNER TO ldap;

--
-- Name: set_samba_domain_sid(character varying, integer); Type: FUNCTION; Schema: public; Owner: ldap
--

CREATE FUNCTION set_samba_domain_sid(character varying, integer) RETURNS integer
    AS $_$UPDATE samba_domain SET sambasid=CAST($1 AS VARCHAR) WHERE id=CAST($2 AS INT); SELECT $2 AS RETURN $_$
    LANGUAGE sql;


ALTER FUNCTION public.set_samba_domain_sid(character varying, integer) OWNER TO ldap;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: class_details; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE class_details (
    id integer NOT NULL,
    quota character varying(255),
    mailquota integer,
    schooltype character varying(255),
    department character varying(255),
    mailalias boolean,
    maillist boolean,
    type character varying(255)
);


ALTER TABLE public.class_details OWNER TO ldap;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE groups (
    id integer NOT NULL,
    gidnumber integer NOT NULL,
    gid character varying NOT NULL
);


ALTER TABLE public.groups OWNER TO ldap;

--
-- Name: samba_group_mapping; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE samba_group_mapping (
    id integer NOT NULL,
    gidnumber integer,
    sambasid character varying,
    sambagrouptype character varying,
    displayname character varying,
    description character varying,
    sambasidlist character varying
);


ALTER TABLE public.samba_group_mapping OWNER TO ldap;

--
-- Name: classdata; Type: VIEW; Schema: public; Owner: ldap
--

CREATE VIEW classdata AS
    SELECT class_details.id, class_details.quota, class_details.mailquota, class_details.schooltype, class_details.department, class_details.type, class_details.mailalias, class_details.maillist, groups.gid, groups.gidnumber, samba_group_mapping.sambasid, samba_group_mapping.sambagrouptype, samba_group_mapping.displayname, samba_group_mapping.description, samba_group_mapping.sambasidlist FROM class_details, groups, samba_group_mapping WHERE ((groups.id = class_details.id) AND (groups.id = samba_group_mapping.id));


ALTER TABLE public.classdata OWNER TO ldap;

--
-- Name: classes_admins; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE classes_admins (
    adminclassid integer NOT NULL,
    uidnumber integer NOT NULL
);


ALTER TABLE public.classes_admins OWNER TO ldap;

--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: public; Owner: ldap
--

CREATE SEQUENCE groups_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.groups_id_seq OWNER TO ldap;

--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ldap
--

ALTER SEQUENCE groups_id_seq OWNED BY groups.id;


--
-- Name: groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ldap
--

SELECT pg_catalog.setval('groups_id_seq', 116, true);


--
-- Name: groups_users; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE groups_users (
    gidnumber integer NOT NULL,
    memberuidnumber integer NOT NULL
);


ALTER TABLE public.groups_users OWNER TO ldap;

--
-- Name: institutes; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE institutes (
    id integer NOT NULL,
    name character varying(255)
);


ALTER TABLE public.institutes OWNER TO ldap;

--
-- Name: institutes_id_seq; Type: SEQUENCE; Schema: public; Owner: ldap
--

CREATE SEQUENCE institutes_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.institutes_id_seq OWNER TO ldap;

--
-- Name: institutes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ldap
--

ALTER SEQUENCE institutes_id_seq OWNED BY institutes.id;


--
-- Name: institutes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ldap
--

SELECT pg_catalog.setval('institutes_id_seq', 3, true);


--
-- Name: ldap_attr_mappings; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE ldap_attr_mappings (
    id integer NOT NULL,
    oc_map_id integer NOT NULL,
    name character varying(255) NOT NULL,
    sel_expr character varying(255) NOT NULL,
    sel_expr_u character varying(255),
    from_tbls character varying(255) NOT NULL,
    join_where character varying(255),
    add_proc character varying(255),
    delete_proc character varying(255),
    param_order integer NOT NULL,
    expect_return integer NOT NULL
);


ALTER TABLE public.ldap_attr_mappings OWNER TO ldap;

--
-- Name: ldap_attr_mappings_id_seq; Type: SEQUENCE; Schema: public; Owner: ldap
--

CREATE SEQUENCE ldap_attr_mappings_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.ldap_attr_mappings_id_seq OWNER TO ldap;

--
-- Name: ldap_attr_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ldap
--

ALTER SEQUENCE ldap_attr_mappings_id_seq OWNED BY ldap_attr_mappings.id;


--
-- Name: ldap_attr_mappings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ldap
--

SELECT pg_catalog.setval('ldap_attr_mappings_id_seq', 115, true);


--
-- Name: ldap_entries; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE ldap_entries (
    id integer NOT NULL,
    dn character varying(255) NOT NULL,
    oc_map_id integer NOT NULL,
    parent integer NOT NULL,
    keyval integer NOT NULL
);


ALTER TABLE public.ldap_entries OWNER TO ldap;

--
-- Name: ldap_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: ldap
--

CREATE SEQUENCE ldap_entries_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.ldap_entries_id_seq OWNER TO ldap;

--
-- Name: ldap_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ldap
--

ALTER SEQUENCE ldap_entries_id_seq OWNED BY ldap_entries.id;


--
-- Name: ldap_entries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ldap
--

SELECT pg_catalog.setval('ldap_entries_id_seq', 1675, true);


--
-- Name: ldap_entry_objclasses; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE ldap_entry_objclasses (
    entry_id integer NOT NULL,
    oc_name character varying(64)
);


ALTER TABLE public.ldap_entry_objclasses OWNER TO ldap;

--
-- Name: ldap_oc_mappings; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE ldap_oc_mappings (
    id integer NOT NULL,
    name character varying(64) NOT NULL,
    keytbl character varying(64) NOT NULL,
    keycol character varying(64) NOT NULL,
    create_proc character varying(255),
    delete_proc character varying(255),
    expect_return integer NOT NULL
);


ALTER TABLE public.ldap_oc_mappings OWNER TO ldap;

--
-- Name: ldap_oc_mappings_id_seq; Type: SEQUENCE; Schema: public; Owner: ldap
--

CREATE SEQUENCE ldap_oc_mappings_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.ldap_oc_mappings_id_seq OWNER TO ldap;

--
-- Name: ldap_oc_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ldap
--

ALTER SEQUENCE ldap_oc_mappings_id_seq OWNED BY ldap_oc_mappings.id;


--
-- Name: ldap_oc_mappings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ldap
--

SELECT pg_catalog.setval('ldap_oc_mappings_id_seq', 6, true);


--
-- Name: ldap_referrals; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE ldap_referrals (
    entry_id integer,
    name character(255),
    url character(255)
);


ALTER TABLE public.ldap_referrals OWNER TO ldap;

--
-- Name: posix_account; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE posix_account (
    id integer NOT NULL,
    uidnumber integer NOT NULL,
    uid character varying(255) NOT NULL,
    gidnumber integer NOT NULL,
    firstname character varying(255),
    surname character varying(255),
    homedirectory character varying(255),
    gecos character varying(255),
    loginshell character varying(255),
    userpassword character varying(255),
    description character(255)
);


ALTER TABLE public.posix_account OWNER TO ldap;

--
-- Name: posix_account_details; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE posix_account_details (
    id integer NOT NULL,
    schoolnumber character varying(255),
    unid character varying(255),
    exitunid character varying(255),
    birthname character varying(255),
    title character varying(255),
    gender character varying(255),
    birthday date,
    birthpostalcode character varying(255),
    birthcity character varying(255),
    denomination character varying(255),
    class integer,
    adminclass character varying(255),
    exitadminclass character varying(255),
    subclass character varying(255),
    creationdate timestamp without time zone,
    tolerationdate date,
    deactivationdate date,
    scheduled_toleration date,
    sophomorixstatus character varying(255),
    mymail character varying(255),
    mylanguage character varying(255),
    usertoken character varying(255),
    accountstatus boolean,
    quota character varying(255),
    mailquota integer,
    firstpassword character varying(255),
    internetstatus boolean,
    emailstatus boolean,
    lastlogin date,
    lastgid integer,
    classentry integer,
    schooltype integer,
    chiefinstructor integer,
    nationality integer,
    religionparticipation boolean,
    ethicsparticipation boolean,
    education character varying(255),
    occupation character varying(255),
    starttraining date,
    endtraining date
);


ALTER TABLE public.posix_account_details OWNER TO ldap;

--
-- Name: project_details; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE project_details (
    id integer NOT NULL,
    addquota character varying(255),
    addmailquota integer,
    mailalias boolean,
    maillist boolean,
    schooltype character varying(255),
    department character varying(255),
    sophomorixstatus character varying(255),
    enddate date,
    longname character varying(255),
    type integer,
    maxmembers integer,
    creationdate timestamp without time zone,
    tolerationdate date,
    deactivationdate date,
    joinable boolean
);


ALTER TABLE public.project_details OWNER TO ldap;

--
-- Name: memberdata; Type: VIEW; Schema: public; Owner: ldap
--

CREATE VIEW memberdata AS
    SELECT posix_account.uid, posix_account.uidnumber AS uidnum, posix_account.gecos, (SELECT groups.gid FROM groups WHERE (groups.gidnumber = posix_account.gidnumber)) AS adminclass, posix_account_details.sophomorixstatus AS s, groups.gid, groups.gidnumber AS gidnum, project_details.longname FROM ((((posix_account FULL JOIN posix_account_details ON ((posix_account.id = posix_account_details.id))) LEFT JOIN groups_users ON ((groups_users.memberuidnumber = posix_account.uidnumber))) LEFT JOIN groups ON ((groups.gidnumber = groups_users.gidnumber))) LEFT JOIN project_details ON ((project_details.id = groups.id))) ORDER BY groups.gid, posix_account.uid;


ALTER TABLE public.memberdata OWNER TO ldap;

--
-- Name: organizational_unit; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE organizational_unit (
    id integer NOT NULL,
    ou character varying(40) NOT NULL,
    description character varying(255)
);


ALTER TABLE public.organizational_unit OWNER TO ldap;

--
-- Name: organizational_unit_id_seq; Type: SEQUENCE; Schema: public; Owner: ldap
--

CREATE SEQUENCE organizational_unit_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.organizational_unit_id_seq OWNER TO ldap;

--
-- Name: organizational_unit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ldap
--

ALTER SEQUENCE organizational_unit_id_seq OWNED BY organizational_unit.id;


--
-- Name: organizational_unit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ldap
--

SELECT pg_catalog.setval('organizational_unit_id_seq', 6, true);


--
-- Name: posix_account_id_seq; Type: SEQUENCE; Schema: public; Owner: ldap
--

CREATE SEQUENCE posix_account_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.posix_account_id_seq OWNER TO ldap;

--
-- Name: posix_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ldap
--

ALTER SEQUENCE posix_account_id_seq OWNED BY posix_account.id;


--
-- Name: posix_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ldap
--

SELECT pg_catalog.setval('posix_account_id_seq', 24, true);


--
-- Name: project_groups; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE project_groups (
    projectid integer NOT NULL,
    membergid integer NOT NULL
);


ALTER TABLE public.project_groups OWNER TO ldap;

--
-- Name: projectdata; Type: VIEW; Schema: public; Owner: ldap
--

CREATE VIEW projectdata AS
    SELECT project_details.id, project_details.addquota, project_details.addmailquota, project_details.mailalias, project_details.maillist, project_details.schooltype, project_details.department, project_details.sophomorixstatus, project_details.joinable, project_details.enddate, project_details.longname, project_details.type, project_details.maxmembers, project_details.creationdate, project_details.tolerationdate, project_details.deactivationdate, groups.gid, groups.gidnumber, samba_group_mapping.sambasid, samba_group_mapping.sambagrouptype, samba_group_mapping.displayname, samba_group_mapping.description, samba_group_mapping.sambasidlist FROM project_details, groups, samba_group_mapping WHERE ((groups.id = project_details.id) AND (groups.id = samba_group_mapping.id));


ALTER TABLE public.projectdata OWNER TO ldap;

--
-- Name: projects_admins; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE projects_admins (
    projectid integer NOT NULL,
    uidnumber integer NOT NULL
);


ALTER TABLE public.projects_admins OWNER TO ldap;

--
-- Name: projects_memberprojects; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE projects_memberprojects (
    projectid integer NOT NULL,
    memberprojectid integer NOT NULL
);


ALTER TABLE public.projects_memberprojects OWNER TO ldap;

--
-- Name: projects_members; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE projects_members (
    projectid integer NOT NULL,
    memberuidnumber integer NOT NULL
);


ALTER TABLE public.projects_members OWNER TO ldap;

--
-- Name: samba_domain; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE samba_domain (
    id integer NOT NULL,
    sambadomainname character varying,
    sambasid character varying
);


ALTER TABLE public.samba_domain OWNER TO ldap;

--
-- Name: samba_domain_id_seq; Type: SEQUENCE; Schema: public; Owner: ldap
--

CREATE SEQUENCE samba_domain_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.samba_domain_id_seq OWNER TO ldap;

--
-- Name: samba_domain_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ldap
--

ALTER SEQUENCE samba_domain_id_seq OWNED BY samba_domain.id;


--
-- Name: samba_domain_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ldap
--

SELECT pg_catalog.setval('samba_domain_id_seq', 1, false);


--
-- Name: samba_group_mapping_id_seq; Type: SEQUENCE; Schema: public; Owner: ldap
--

CREATE SEQUENCE samba_group_mapping_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.samba_group_mapping_id_seq OWNER TO ldap;

--
-- Name: samba_group_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ldap
--

ALTER SEQUENCE samba_group_mapping_id_seq OWNED BY samba_group_mapping.id;


--
-- Name: samba_group_mapping_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ldap
--

SELECT pg_catalog.setval('samba_group_mapping_id_seq', 1, false);


--
-- Name: samba_sam_account; Type: TABLE; Schema: public; Owner: ldap; Tablespace: 
--

CREATE TABLE samba_sam_account (
    id integer NOT NULL,
    sambasid character varying(255),
    cn character varying(255),
    sambalmpassword character varying(255),
    sambantpassword character varying(255),
    sambapwdlastset character varying(255),
    sambalogontime character varying(255),
    sambalogofftime character varying(255),
    sambakickofftime character varying(255),
    sambapwdcanchange character varying(255),
    sambapwdmustchange character varying(255),
    sambaacctflags character varying(255),
    displayname character varying(255),
    sambahomepath character varying(255),
    sambahomedrive character varying(255),
    sambalogonscript character varying(255),
    sambaprofilepath character varying(255),
    description character varying(255),
    sambauserworkstations character varying(255),
    sambaprimarygroupsid character varying(255),
    sambadomainname character varying(255),
    sambamungeddial character varying(255),
    sambabadpasswordcount character varying(255),
    sambabadpasswordtime character varying(255),
    sambapasswordhistory character varying(255),
    sambalogonhours character varying(255)
);


ALTER TABLE public.samba_sam_account OWNER TO ldap;

--
-- Name: userdata; Type: VIEW; Schema: public; Owner: ldap
--

CREATE VIEW userdata AS
    SELECT posix_account.id, posix_account.uidnumber, posix_account.uid, posix_account.gidnumber, posix_account.firstname, posix_account.surname, posix_account.homedirectory, posix_account.gecos, posix_account.loginshell, posix_account.userpassword, posix_account.description, samba_sam_account.sambasid, samba_sam_account.cn, samba_sam_account.sambalmpassword, samba_sam_account.sambantpassword, samba_sam_account.sambapwdlastset, samba_sam_account.sambalogontime, samba_sam_account.sambalogofftime, samba_sam_account.sambakickofftime, samba_sam_account.sambapwdcanchange, samba_sam_account.sambapwdmustchange, samba_sam_account.sambaacctflags, samba_sam_account.displayname, samba_sam_account.sambahomepath, samba_sam_account.sambahomedrive, samba_sam_account.sambalogonscript, samba_sam_account.sambaprofilepath, samba_sam_account.sambauserworkstations, samba_sam_account.sambaprimarygroupsid, samba_sam_account.sambadomainname, samba_sam_account.sambamungeddial, samba_sam_account.sambabadpasswordcount, samba_sam_account.sambabadpasswordtime, samba_sam_account.sambapasswordhistory, samba_sam_account.sambalogonhours, posix_account_details.schoolnumber, posix_account_details.unid, posix_account_details.exitunid, posix_account_details.birthname, posix_account_details.title, posix_account_details.gender, posix_account_details.birthday, posix_account_details.birthpostalcode, posix_account_details.birthcity, posix_account_details.denomination, posix_account_details.class, posix_account_details.adminclass, posix_account_details.exitadminclass, posix_account_details.subclass, posix_account_details.creationdate, posix_account_details.tolerationdate, posix_account_details.deactivationdate, posix_account_details.sophomorixstatus, posix_account_details.mymail, posix_account_details.mylanguage, posix_account_details.accountstatus, posix_account_details.quota, posix_account_details.mailquota, posix_account_details.firstpassword, posix_account_details.internetstatus, posix_account_details.emailstatus, posix_account_details.lastlogin, posix_account_details.lastgid, posix_account_details.classentry, posix_account_details.schooltype, posix_account_details.chiefinstructor, posix_account_details.nationality, posix_account_details.religionparticipation, posix_account_details.ethicsparticipation, posix_account_details.education, posix_account_details.occupation, posix_account_details.starttraining, posix_account_details.usertoken, posix_account_details.scheduled_toleration, posix_account_details.endtraining, groups.gid FROM (((posix_account FULL JOIN samba_sam_account ON ((posix_account.id = samba_sam_account.id))) FULL JOIN posix_account_details ON ((posix_account_details.id = posix_account.id))) FULL JOIN groups ON ((posix_account.gidnumber = groups.gidnumber))) WHERE ((posix_account.uid)::text <> 'NextFreeUnixId'::text);


ALTER TABLE public.userdata OWNER TO ldap;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ldap
--

ALTER TABLE groups ALTER COLUMN id SET DEFAULT nextval('groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ldap
--

ALTER TABLE institutes ALTER COLUMN id SET DEFAULT nextval('institutes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ldap
--

ALTER TABLE ldap_attr_mappings ALTER COLUMN id SET DEFAULT nextval('ldap_attr_mappings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ldap
--

ALTER TABLE ldap_entries ALTER COLUMN id SET DEFAULT nextval('ldap_entries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ldap
--

ALTER TABLE ldap_oc_mappings ALTER COLUMN id SET DEFAULT nextval('ldap_oc_mappings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ldap
--

ALTER TABLE organizational_unit ALTER COLUMN id SET DEFAULT nextval('organizational_unit_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ldap
--

ALTER TABLE posix_account ALTER COLUMN id SET DEFAULT nextval('posix_account_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ldap
--

ALTER TABLE samba_domain ALTER COLUMN id SET DEFAULT nextval('samba_domain_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ldap
--

ALTER TABLE samba_group_mapping ALTER COLUMN id SET DEFAULT nextval('samba_group_mapping_id_seq'::regclass);


--
-- Data for Name: class_details; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY class_details (id, quota, mailquota, schooltype, department, mailalias, maillist, type) FROM stdin;
106	quota	-1			f	f	domaingroup
107	quota	-1			f	f	domaingroup
108	quota	-1			f	f	domaingroup
109	quota	-1			f	f	domaingroup
110	quota	-1			f	f	domaingroup
111	quota	-1			f	f	localgroup
112	quota	-1			f	f	localgroup
113	quota	-1			f	f	localgroup
114	quota	-1			f	f	localgroup
115	quota	-1			f	f	localgroup
116	quota	-1			t	f	teacher
\.


--
-- Data for Name: classes_admins; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY classes_admins (adminclassid, uidnumber) FROM stdin;
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY groups (id, gidnumber, gid) FROM stdin;
106	512	domadmins
107	513	domusers
108	514	domguests
109	515	domcomputers
110	997	wwwadmin
111	550	printoperators
112	552	replicators
113	544	administrators
114	548	accountoperators
115	551	backupoperators
116	10000	teachers
\.


--
-- Data for Name: groups_users; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY groups_users (gidnumber, memberuidnumber) FROM stdin;
544	998
550	998
10000	998
\.


--
-- Data for Name: institutes; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY institutes (id, name) FROM stdin;
1	linuxmuster
\.


--
-- Data for Name: ldap_attr_mappings; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY ldap_attr_mappings (id, oc_map_id, name, sel_expr, sel_expr_u, from_tbls, join_where, add_proc, delete_proc, param_order, expect_return) FROM stdin;
97	4	displayName	samba_group_mapping.displayname	samba_group_mapping.displayname	samba_group_mapping,groups	samba_group_mapping.id=groups.id	{ call set_groups_displayname(?,?) }	{ call del_groups_displayname(?,?) }	1	0
81	3	displayName	samba_sam_account.displayname	samba_sam_account.displayname	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_displayname(?,?) }	{ call del_account_displayname(?,?) }	1	0
71	3	sambaSID	samba_sam_account.sambasid	samba_sam_account.sambasid	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambasid(?,?) }	{ call del_account_sambasid(?,?) }	1	0
114	6	sambaSID	samba_domain.sambasid	samba_domain.sambasid	samba_domain	\N	{ call set_samba_domain_sid(?,?) }	\N	1	0
95	4	sambaSID	samba_group_mapping.sambasid	samba_group_mapping.sambasid	samba_group_mapping,groups	samba_group_mapping.id=groups.id	{ call set_groups_sambasid(?,?) }	{ call del_groups_sambasid(?,?) }	1	0
99	4	sambaSIDList	samba_group_mapping.sambasidlist	samba_group_mapping.sambasidlist	samba_group_mapping,groups	samba_group_mapping.id=groups.id	{ call set_groups_sambasidlist(?,?) }	{ call del_groups_sambasidlist(?,?) }	1	0
98	4	description	samba_group_mapping.description	samba_group_mapping.description	samba_group_mapping,groups	samba_group_mapping.id=groups.id	{ call set_groups_description(?,?) }	{ call del_groups_description(?,?) }	1	0
96	4	sambaGroupType	samba_group_mapping.sambagrouptype	samba_group_mapping.sambagrouptype	samba_group_mapping,groups	samba_group_mapping.id=groups.id	{ call set_groups_sambagrouptype(?,?) }	{ call del_groups_sambagrouptype(?,?) }	1	0
94	3	sambaLogonHours	samba_sam_account.sambalogonhours	samba_sam_account.sambalogonhours	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambalogonhours(?,?) }	{ call del_account_sambalogonhours(?,?) }	1	0
78	3	sambaPwdCanChange	samba_sam_account.sambapwdcanchange	samba_sam_account.sambalogonhours	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambapwdcanchange(?,?) }	{ call del_account_sambapwdcanchange(?,?) }	1	0
87	3	sambaUserWorkstations	samba_sam_account.sambauserworkstations	samba_sam_account.sambauserworkstations	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambauserworkstations(?,?) }	{ call del_account_sambauserworkstations(?,?) }	1	0
72	3	sambaLMPassword	samba_sam_account.sambalmpassword	samba_sam_account.sambalmpassword	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambalmpassword(?,?) }	{ call del_account_sambalmpassword(?,?) }	1	0
93	3	sambaPasswordHistory	samba_sam_account.sambapasswordhistory	samba_sam_account.sambalmpassword	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambapasswordhistory(?,?) }	{ call del_account_sambapasswordhistory(?,?) }	1	0
92	3	sambaBadPasswordTime	samba_sam_account.sambabadpasswordtime	samba_sam_account.sambalmpassword	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambabadpasswordtime(?,?) }	{ call del_account_sambabadpasswordtime(?,?) }	1	0
91	3	sambaBadPasswordCount	samba_sam_account.sambabadpasswordcount	samba_sam_account.sambabadpasswordcount	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambabadpasswordcount(?,?) }	{ call del_account_sambabadpasswordcount(?,?) }	1	0
90	3	sambaMungedDial	samba_sam_account.sambamungeddial	samba_sam_account.sambamungeddial	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambamungeddial(?,?) }	{ call del_account_sambamungeddial(?,?) }	1	0
89	3	sambaDomainName	samba_sam_account.sambadomainname	samba_sam_account.sambadomainname	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambadomainname(?,?) }	{ call del_account_sambadomainname(?,?) }	1	0
88	3	sambaPrimaryGroupSID	samba_sam_account.sambaprimarygroupsid	samba_sam_account.sambaprimarygroupsid	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambaprimarygroupsid(?,?) }	{ call del_account_sambaprimarygroupsid(?,?) }	1	0
85	3	sambaProfilePath	samba_sam_account.sambaprofilepath	samba_sam_account.sambaprofilepath	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambaprofilepath(?,?) }	{ call del_account_sambaprofilepath(?,?) }	1	0
84	3	sambaLogonScript	samba_sam_account.sambalogonscript	samba_sam_account.sambalogonscript	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambalogonscript(?,?) }	{ call del_account_sambalogonscript(?,?) }	1	0
83	3	sambaHomeDrive	samba_sam_account.sambahomedrive	samba_sam_account.sambahomedrive	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambahomedrive(?,?) }	{ call del_account_sambahomedrive(?,?) }	1	0
82	3	sambaHomePath	samba_sam_account.sambahomepath	samba_sam_account.sambahomepath	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambahomepath(?,?) }	{ call del_account_sambahomepath(?,?) }	1	0
80	3	sambaAcctFlags	samba_sam_account.sambaacctflags	samba_sam_account.sambaacctflags	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambaacctflags(?,?) }	{ call del_account_sambaacctflags(?,?) }	1	0
79	3	sambaPwdMustChange	samba_sam_account.sambapwdmustchange	samba_sam_account.sambapwdmustchange	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambapwdmustchange(?,?) }	{ call del_account_sambapwdmustchange(?,?) }	1	0
77	3	sambaKickoffTime	samba_sam_account.sambakickofftime	samba_sam_account.sambakickofftime	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambakickofftime(?,?) }	{ call del_account_sambakickofftime(?,?) }	1	0
76	3	sambaLogoffTime	samba_sam_account.sambalogofftime	samba_sam_account.sambalogofftime	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambalogofftime(?,?) }	{ call del_account_sambalogofftime(?,?) }	1	0
75	3	sambaLogonTime	samba_sam_account.sambalogontime	samba_sam_account.sambalogontime	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambalogontime(?,?) }	{ call del_account_sambalogontime(?,?) }	1	0
74	3	sambaPwdLastSet	samba_sam_account.sambapwdlastset	samba_sam_account.sambapwdlastset	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambapwdlastset(?,?) }	{ call del_account_sambapwdlastset(?,?) }	1	0
73	3	sambaNTPassword	samba_sam_account.sambantpassword	samba_sam_account.sambantpassword	samba_sam_account,posix_account	samba_sam_account.id=posix_account.id	{ call set_account_sambantpassword(?,?) }	{ call del_account_sambantpassword(?,?) }	1	0
113	6	sambaDomainName	samba_domain.sambadomainname	samba_domain.sambadomainname	samba_domain	\N	{ call set_samba_domain_name(?,?) }	\N	1	0
105	3	sn	posix_account.surname	\N	posix_account	\N	{ call set_account_sn(?,?) }	{ call del_account_sn(?,?) }	1	0
9	3	uid	posix_account.uid	\N	posix_account	\N	{ call set_account_uid(?,?) }	{ call del_account_uid(?,?) }	1	0
12	3	uidNumber	posix_account.uidnumber	\N	posix_account	\N	{ call set_account_uidnumber(?,?) }	{ call del_account_uidnumber(?,?) }	1	0
86	3	description	posix_account.description	\N	posix_account	\N	{ call set_account_description(?,?) }	{ call del_account_description(?,?) }	1	0
106	3	gn	posix_account.firstname	\N	posix_account	\N	\N	\N	0	0
5	1	o	institutes.name	\N	institutes	\N	\N	\N	0	0
17	3	gecos	posix_account.gecos	\N	posix_account	\N	{ call set_account_gecos(?,?) }	{ call del_account_gecos(?,?) }	1	0
4	3	userPassword	posix_account.userpassword	\N	posix_account	\N	{ call set_account_userpassword(?,?) }	{ call del_account_userpassword(?,?) }	1	0
15	4	memberUid	posix_account.uid	\N	posix_account,groups_users,groups	groups_users.memberuidnumber=posix_account.uidnumber AND groups_users.gidnumber=groups.gidnumber	{ call set_account_memberuid(?,?) }	{ call del_account_memberuid(?,?) }	1	0
8	2	ou	organizational_unit.ou	\N	organizational_unit	\N	{ call set_organizational_unit_ou(?,?) }	\N	1	0
10	3	gidNumber	posix_account.gidnumber	\N	posix_account	\N	{ call set_account_gidnumber(?,?) }	{ call del_account_gidnumber(?,?) }	1	0
16	3	loginShell	posix_account.loginshell	\N	posix_account	\N	{ call set_account_loginshell(?,?) }	{ call del_account_loginshell(?,?) }	1	0
11	3	homeDirectory	posix_account.homedirectory	\N	posix_account	\N	{ call set_account_homedirectory(?,?) }	{ call del_account_homedirectory(?,?) }	1	0
1	3	cn	posix_account.firstname || ' ' || posix_account.surname	\N	posix_account	\N	{ call set_account_cn(?,?) }	\N	1	0
13	4	gidNumber	groups.gidnumber	\N	groups	\N	{ call set_groups_gidnumber(?,?) }	{ call del_groups_gidnumber(?,?) }	1	0
14	4	cn	groups.gid	\N	groups	\N	{ call set_groups_cn(?,?) }	{ call del_groups_cn(?,?) }	1	0
7	1	dc	institutes.name	\N	institutes,ldap_entries AS dcObject,ldap_entry_objclasses as auxObjectClass	institutes.id=dcObject.keyval AND dcObject.oc_map_id=1 AND dcObject.id=auxObjectClass.entry_id AND auxObjectClass.oc_name='dcObject'	\N	\N	0	0
\.


--
-- Data for Name: ldap_entries; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY ldap_entries (id, dn, oc_map_id, parent, keyval) FROM stdin;
1	@@basedn@@	1	0	1
5	ou=groups,@@basedn@@	2	1	5
2	ou=accounts,@@basedn@@	2	1	1
3	ou=machines,@@basedn@@	2	1	3
4	cn=NextFreeUnixId,@@basedn@@	3	1	1
1660	cn=domadmins,ou=groups,@@basedn@@	4	5	106
1661	cn=domusers,ou=groups,@@basedn@@	4	5	107
1662	cn=domguests,ou=groups,@@basedn@@	4	5	108
1663	cn=domcomputers,ou=groups,@@basedn@@	4	5	109
1664	cn=wwwadmin,ou=groups,@@basedn@@	4	5	110
1665	cn=printoperators,ou=groups,@@basedn@@	4	5	111
1666	cn=replicators,ou=groups,@@basedn@@	4	5	112
1667	cn=administrators,ou=groups,@@basedn@@	4	5	113
1668	cn=accountoperators,ou=groups,@@basedn@@	4	5	114
1669	cn=backupoperators,ou=groups,@@basedn@@	4	5	115
1670	cn=teachers,ou=groups,@@basedn@@	4	5	116
1671	uid=administrator,ou=accounts,@@basedn@@	3	2	20
1672	uid=pgmadmin,ou=accounts,@@basedn@@	3	2	21
1673	uid=wwwadmin,ou=accounts,@@basedn@@	3	2	22
1674	uid=domadmin,ou=accounts,@@basedn@@	3	2	23
\.


--
-- Data for Name: ldap_entry_objclasses; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY ldap_entry_objclasses (entry_id, oc_name) FROM stdin;
4	sambaUnixIdPool
1660	sambaGroupMapping
1661	sambaGroupMapping
1662	sambaGroupMapping
1663	sambaGroupMapping
1664	sambaGroupMapping
1665	sambaGroupMapping
1666	sambaGroupMapping
1667	sambaGroupMapping
1668	sambaGroupMapping
1669	sambaGroupMapping
1670	sambaGroupMapping
1671	top
1671	posixAccount
1671	shadowAccount
1671	sambaSamAccount
1672	top
1672	posixAccount
1672	shadowAccount
1672	sambaSamAccount
1673	top
1673	posixAccount
1673	shadowAccount
1673	sambaSamAccount
1674	top
1674	posixAccount
1674	shadowAccount
1674	sambaSamAccount
\.


--
-- Data for Name: ldap_oc_mappings; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY ldap_oc_mappings (id, name, keytbl, keycol, create_proc, delete_proc, expect_return) FROM stdin;
1	organization	institutes	id	\N	\N	0
4	posixGroup	groups	id	SELECT create_groups()	SELECT delete_groups(?)	0
2	organizationalUnit	organizational_unit	id	SELECT create_organizational_unit()	SELECT delete_organizational_unit(?)	0
3	inetOrgPerson	posix_account	id	SELECT create_account()	SELECT delete_account(?)	0
6	sambaDomain	samba_domain	id	SELECT create_samba_domain()	\N	0
\.


--
-- Data for Name: ldap_referrals; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY ldap_referrals (entry_id, name, url) FROM stdin;
1	Referral                                                                                                                                                                                                                                                       	ldap://localhost/                                                                                                                                                                                                                                              
\.


--
-- Data for Name: organizational_unit; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY organizational_unit (id, ou, description) FROM stdin;
5	groups	Gruppen
1	accounts	PosixAccounts
3	machines	Maschinen
\.


--
-- Data for Name: posix_account; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY posix_account (id, uidnumber, uid, gidnumber, firstname, surname, homedirectory, gecos, loginshell, userpassword, description) FROM stdin;
23	996	domadmin	512	Domain	Admin	/dev/null	Domain Admin	/bin/false	{CRYPT}wCIhrFcv89CRk	Domain Admin                                                                                                                                                                                                                                                   
20	998	administrator	512	Main	Admin	/home/administrators/administrator	Administrator	/bin/bash	{CRYPT}5Q2.pGv6LKMTY	Administrator                                                                                                                                                                                                                                                  
21	999	pgmadmin	512	Program	Admin	/home/administrators/pgmadmin	Programm Administrator	/bin/false	{CRYPT}EO37paAwkhcIc	Programm Administrator                                                                                                                                                                                                                                         
22	997	wwwadmin	544	Web	Admin	/home/administrators/wwwadmin	Web Administrator	/bin/false	{CRYPT}iCEITaAi0/0S.	Web Administrator                                                                                                                                                                                                                                              
1	10018	NextFreeUnixId	10001		NextFreeUnixId					                                                                                                                                                                                                                                                               
\.


--
-- Data for Name: posix_account_details; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY posix_account_details (id, schoolnumber, unid, exitunid, birthname, title, gender, birthday, birthpostalcode, birthcity, denomination, class, adminclass, exitadminclass, subclass, creationdate, tolerationdate, deactivationdate, scheduled_toleration, sophomorixstatus, mymail, mylanguage, usertoken, accountstatus, quota, mailquota, firstpassword, internetstatus, emailstatus, lastlogin, lastgid, classentry, schooltype, chiefinstructor, nationality, religionparticipation, ethicsparticipation, education, occupation, starttraining, endtraining) FROM stdin;
23	1		\N				1970-01-01	0	0	0	0	domadmins			2010-01-01 00:00:00	\N	\N	\N	P	\N	\N	\N	\N		-1	muster	\N	\N	\N	\N	0	0	0	0	t	f			1970-01-01	1970-01-01
20	1		\N				1970-01-01	0	0	0	0	domadmins			2010-01-01 00:00:00	\N	\N	\N	P	\N	\N	\N	\N	10000+	250	muster	\N	\N	\N	\N	0	0	0	0	t	f			1970-01-01	1970-01-01
21	1		\N				1970-01-01	0	0	0	0	domadmins			2010-01-01 00:00:00	\N	\N	\N	P	\N	\N	\N	\N	10000+	10	muster	\N	\N	\N	\N	0	0	0	0	t	f			1970-01-01	1970-01-01
22	1		\N				1970-01-01	0	0	0	0	administrators			2010-01-01 00:00:00	\N	\N	\N	P	\N	\N	\N	\N	500+	10	muster	\N	\N	\N	\N	0	0	0	0	t	f			1970-01-01	1970-01-01
\.


--
-- Data for Name: project_details; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY project_details (id, addquota, addmailquota, mailalias, maillist, schooltype, department, sophomorixstatus, enddate, longname, type, maxmembers, creationdate, tolerationdate, deactivationdate, joinable) FROM stdin;
\.


--
-- Data for Name: project_groups; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY project_groups (projectid, membergid) FROM stdin;
\.


--
-- Data for Name: projects_admins; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY projects_admins (projectid, uidnumber) FROM stdin;
\.


--
-- Data for Name: projects_memberprojects; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY projects_memberprojects (projectid, memberprojectid) FROM stdin;
\.


--
-- Data for Name: projects_members; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY projects_members (projectid, memberuidnumber) FROM stdin;
\.


--
-- Data for Name: samba_domain; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY samba_domain (id, sambadomainname, sambasid) FROM stdin;
1	@@workgroup@@	@@sambasid@@
\.


--
-- Data for Name: samba_group_mapping; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY samba_group_mapping (id, gidnumber, sambasid, sambagrouptype, displayname, description, sambasidlist) FROM stdin;
116	10000	@@sambasid@@-21001	2	teachers		\N
106	512	@@sambasid@@-512	2	Domain Admins	Domain Unix group	\N
107	513	@@sambasid@@-513	2	Domain Users	Domain Unix group	\N
108	514	@@sambasid@@-514	2	Domain Guests	Domain Unix group	\N
109	515	@@sambasid@@-515	2	Domain Computers	Domain Unix group	\N
113	544	S-1-5-32-544	4	Administrators	Local Unix group	\N
114	548	S-1-5-32-548	4	Account Operators	Local Unix group	\N
111	550	S-1-5-32-550	4	Print Operators	Local Unix group	\N
115	551	S-1-5-32-551	4	Backup Operators	Local Unix group	\N
112	552	S-1-5-32-552	4	Replicators	Local Unix group	\N
\.


--
-- Data for Name: samba_sam_account; Type: TABLE DATA; Schema: public; Owner: ldap
--

COPY samba_sam_account (id, sambasid, cn, sambalmpassword, sambantpassword, sambapwdlastset, sambalogontime, sambalogofftime, sambakickofftime, sambapwdcanchange, sambapwdmustchange, sambaacctflags, displayname, sambahomepath, sambahomedrive, sambalogonscript, sambaprofilepath, description, sambauserworkstations, sambaprimarygroupsid, sambadomainname, sambamungeddial, sambabadpasswordcount, sambabadpasswordtime, sambapasswordhistory, sambalogonhours) FROM stdin;
20	@@sambasid@@-998	administrator	F2E1862E051C1C9FAAD3B435B51404EE	20615C640669625A26E7D7AF9CEA2CDB	1230770898	0	2147483647	2147483647	0	2147483647	[UX]	administrator	\\\\server\\administrator	H:	\N	\N	\N	\N	@@sambasid@@-512	\N	\N	\N	\N	\N	\N
23	@@sambasid@@-996	Domain Admin	F2E1862E051C1C9FAAD3B435B51404EE	20615C640669625A26E7D7AF9CEA2CDB	1230770904	0	2147483647	2147483647	0	2147483647	[UX]	Domain Admin	\\\\server\\domadmin	H:	\N	\N	\N	\N	@@sambasid@@-512	\N	\N	\N	\N	\N	\N
21	@@sambasid@@-999	Programm Administrator	F2E1862E051C1C9FAAD3B435B51404EE	20615C640669625A26E7D7AF9CEA2CDB	1230770901	0	2147483647	2147483647	0	2147483647	[UX]	Programm Administrator	\\\\server\\pgmadmin	H:	\N	\N	\N	\N	@@sambasid@@-512	\N	\N	\N	\N	\N	\N
22	@@sambasid@@-997	Web Administrator	F2E1862E051C1C9FAAD3B435B51404EE	20615C640669625A26E7D7AF9CEA2CDB	1230770903	0	2147483647	2147483647	0	2147483647	[DUX]	Web Administrator	\\\\server\\wwwadmin	H:	\N	\N	\N	\N	@@sambasid@@-544	\N	\N	\N	\N	\N	\N
\.


--
-- Name: groups_gidnumber_key; Type: CONSTRAINT; Schema: public; Owner: ldap; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_gidnumber_key UNIQUE (gidnumber);


--
-- Name: groups_id_key; Type: CONSTRAINT; Schema: public; Owner: ldap; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_id_key UNIQUE (id);


--
-- Name: ldap_entries_id_key; Type: CONSTRAINT; Schema: public; Owner: ldap; Tablespace: 
--

ALTER TABLE ONLY ldap_entries
    ADD CONSTRAINT ldap_entries_id_key UNIQUE (id);


--
-- Name: ldap_oc_mappings_id_key; Type: CONSTRAINT; Schema: public; Owner: ldap; Tablespace: 
--

ALTER TABLE ONLY ldap_oc_mappings
    ADD CONSTRAINT ldap_oc_mappings_id_key UNIQUE (id);


--
-- Name: posix_account_details_uidnumber_key; Type: CONSTRAINT; Schema: public; Owner: ldap; Tablespace: 
--

ALTER TABLE ONLY posix_account_details
    ADD CONSTRAINT posix_account_details_uidnumber_key UNIQUE (id);


--
-- Name: posix_account_uidnumber_key; Type: CONSTRAINT; Schema: public; Owner: ldap; Tablespace: 
--

ALTER TABLE ONLY posix_account
    ADD CONSTRAINT posix_account_uidnumber_key UNIQUE (uidnumber);


--
-- Name: samba_group_mapping_gidnumber_key; Type: CONSTRAINT; Schema: public; Owner: ldap; Tablespace: 
--

ALTER TABLE ONLY samba_group_mapping
    ADD CONSTRAINT samba_group_mapping_gidnumber_key UNIQUE (gidnumber, id);


--
-- Name: samba_sam_account_id_key; Type: CONSTRAINT; Schema: public; Owner: ldap; Tablespace: 
--

ALTER TABLE ONLY samba_sam_account
    ADD CONSTRAINT samba_sam_account_id_key UNIQUE (id);


--
-- Name: g_id_idx; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX g_id_idx ON groups USING btree (id);


--
-- Name: groups_gid_upper; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX groups_gid_upper ON groups USING btree (upper((gid)::text));

ALTER TABLE groups CLUSTER ON groups_gid_upper;


--
-- Name: groups_id; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE UNIQUE INDEX groups_id ON groups USING btree (id);


--
-- Name: institutesid; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE UNIQUE INDEX institutesid ON institutes USING btree (id);


--
-- Name: ldap_entries_dn; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE UNIQUE INDEX ldap_entries_dn ON ldap_entries USING btree (dn);


--
-- Name: ldap_entries_id; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE UNIQUE INDEX ldap_entries_id ON ldap_entries USING btree (id);


--
-- Name: ldap_entries_keyval; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX ldap_entries_keyval ON ldap_entries USING btree (keyval);


--
-- Name: ldap_entry_objclasses_entry_id; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX ldap_entry_objclasses_entry_id ON ldap_entry_objclasses USING btree (entry_id);


--
-- Name: ldap_entry_objclasses_ocname; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX ldap_entry_objclasses_ocname ON ldap_entry_objclasses USING btree (oc_name);


--
-- Name: le_id_idx; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX le_id_idx ON ldap_entries USING btree (id);


--
-- Name: le_keyval_idx; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX le_keyval_idx ON ldap_entries USING btree (keyval);


--
-- Name: le_oc_map_id_idx; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX le_oc_map_id_idx ON ldap_entries USING btree (oc_map_id);


--
-- Name: leo_entry_id_idx; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX leo_entry_id_idx ON ldap_entry_objclasses USING btree (entry_id);


--
-- Name: leo_oc_name_idx; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX leo_oc_name_idx ON ldap_entry_objclasses USING btree (upper((oc_name)::text));


--
-- Name: organizational_unit_id; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX organizational_unit_id ON organizational_unit USING btree (id);


--
-- Name: pa_id_idx; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX pa_id_idx ON posix_account USING btree (id);


--
-- Name: pac_uidnumberup; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX pac_uidnumberup ON posix_account USING btree (upper((uidnumber)::text));

ALTER TABLE posix_account CLUSTER ON pac_uidnumberup;


--
-- Name: posix_account_gidnumber_upper; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX posix_account_gidnumber_upper ON posix_account USING btree (upper((gidnumber)::text));


--
-- Name: posix_account_id; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE UNIQUE INDEX posix_account_id ON posix_account USING btree (id);


--
-- Name: samba_group_mapping_id; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE UNIQUE INDEX samba_group_mapping_id ON samba_group_mapping USING btree (id);


--
-- Name: samba_group_mapping_id_h; Type: INDEX; Schema: public; Owner: ldap; Tablespace: 
--

CREATE INDEX samba_group_mapping_id_h ON samba_group_mapping USING hash (id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

