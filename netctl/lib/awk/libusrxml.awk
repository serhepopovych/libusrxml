#!/usr/bin/gawk -f

#
# Parser helper routines to report various errors.
#
function syntax_err()
{
	printf "USRXML: %s: %d: syntax error\n",
		__USRXML_filename, __USRXML_linenum >"/dev/stderr"
	USRXML_errno = USRXML_E_SYNTAX;
	return USRXML_E_SYNTAX;
}

function scope_err(section)
{
	printf "USRXML: %s: %d: <%s> scope error\n",
		__USRXML_filename, __USRXML_linenum, section >"/dev/stderr"
	USRXML_errno = USRXML_E_SCOPE;
	return USRXML_E_SCOPE;
}

function inv_arg(section, value)
{
	printf "USRXML: %s: %d: invalid argument \"%s\" in <%s>\n",
		__USRXML_filename, __USRXML_linenum, value, section >"/dev/stderr"
	USRXML_errno = USRXML_E_INVAL;
	return USRXML_E_INVAL;
}

function ept_val(section)
{
	printf "USRXML: %s: %d: empty value in <%s>\n",
		__USRXML_filename, __USRXML_linenum, section >"/dev/stderr"
	USRXML_errno = USRXML_E_EMPTY;
	return USRXML_E_EMPTY;
}

function dup_arg(section)
{
	printf "USRXML: %s: %d: duplicated argument <%s>\n",
		__USRXML_filename, __USRXML_linenum, section >"/dev/stderr"
	USRXML_errno = USRXML_E_DUP;
	return USRXML_E_DUP;
}

function missing_arg(section)
{
	printf "USRXML: %s: %d: missing mandatory argument <%s>\n",
		__USRXML_filename, __USRXML_linenum, section >"/dev/stderr"
	USRXML_errno = USRXML_E_MISS;
	return USRXML_E_MISS;
}

#
# Helper routines to track section (e.g. <user>, <pipe>) filename and linenum.
#
function section_record_fileline(key,    n)
{
	n = __USRXML_fileline[key]++;
	__USRXML_fileline[key,"file",n] = __USRXML_filename;
	__USRXML_fileline[key,"line",n] = __USRXML_linenum;
}

function section_fn_arg(section, key, fn,    n, ret, s_fn, s_ln)
{
	ret = USRXML_E_SYNTAX;

	s_fn = __USRXML_filename;
	s_ln = __USRXML_linenum;

	n = __USRXML_fileline[key];
	while (n--) {
		__USRXML_filename = __USRXML_fileline[key,"file",n];
		__USRXML_linenum  = __USRXML_fileline[key,"line",n];

		ret = @fn(section);
	}

	__USRXML_filename = s_fn;
	__USRXML_linenum  = s_ln;

	return ret;
}

function __inv_arg(section)
{
	return inv_arg(section["name"], section["value"]);
}

function section_inv_arg(_section, value, key,    section)
{
	section["name"]  = _section;
	section["value"] = value;

	return section_fn_arg(section, key, "__inv_arg");
}

function section_missing_arg(section, key)
{
	return section_fn_arg(section, key, "missing_arg");
}

#
# Initialize users database XML document parser/validator.
# This is usually called from BEGIN{} section.
#
function init_usr_xml_parser()
{
	#
	# USRXML error codes.
	#
	USRXML_E_NONE	= 0;
	USRXML_E_INVAL	= -1;
	USRXML_E_EMPTY	= -2;
	USRXML_E_DUP	= -3;
	USRXML_E_MISS	= -4;
	USRXML_E_SCOPE	= -50;
	# generic
	USRXML_E_SYNTAX	= -100;

	#
	# USRXML error code variable is set to non-zero
	# if an error encountered during XML document
	# parsing/validation.
	USRXML_errno	= USRXML_E_NONE;

	#
	# Following variables are populated from parsing
	# XML document.
	#
	USRXML_nusers	= 0;
	USRXML_userid	= 0;
	USRXML_pipeid	= 0;

	# USRXML_usernames[userid]
	# USRXML_userids[username]
	#
	# USRXML_userpipe[userid]
	# USRXML_userpipezone[userid,pipeid]
	# USRXML_userpipedir[userid,pipeid]
	# USRXML_userpipebw[userid,pipeid]
	# USRXML_userpipeqdisc[userid,pipeid]
	#
	# USRXML_userif[userid]
	#
	# USRXML_usernets[userid,netid]
	#
	# USRXML_usernets6[userid,net6id]
	#
	# USRXML_usernats[userid,natid]
	# USRXML_usernats6[userid,nat6id]
	#
	# USRXML_ifusers[ifaceid]

	#
	# These constants and variables are *internal*, but
	# needed to be preserved accross library function calls.
	#
	__USRXML_scope_none	= 0;
	__USRXML_scope_user	= 1;
	__USRXML_scope_pipe	= 2;
	__USRXML_scope_qdisc	= 3;

	__USRXML_scope		= __USRXML_scope_none;

	__USRXML_scope2name[__USRXML_scope_none]	= "none";
	__USRXML_scope2name[__USRXML_scope_user]	= "user";
	__USRXML_scope2name[__USRXML_scope_pipe]	= "pipe";
	__USRXML_scope2name[__USRXML_scope_qdisc]	= "qdisc";

	# Valid "zone" values
	__USRXML_zone["world"]	= 1;
	__USRXML_zone["local"]	= 1;
	__USRXML_zone["all"]	= 1;

	# Valid "dir" values
	__USRXML_dir["in"]	= 1;
	__USRXML_dir["out"]	= 1;
	__USRXML_dir["all"]	= 1;

	# FILENAME might be unknown if called from BEGIN{} sections
	__USRXML_filename	= FILENAME;
	__USRXML_linenum	= 0;

	# __USRXML_usernets[userid,net]
	# __USRXML_usernets6[userid,net]
	# __USRXML_usernats[userid,nat]
	# __USRXML_usernats6[userid,nat]
	#
	# __USRXML_fileline[key,{ "file" | "line" },n]

	return 0;
}

#
# Finish XML document validation.
# This is usually called from END{} section.
#
function fini_usr_xml_parser(    zd_bits, zone_dir_bits, zones_dirs,
			     userid, pipeid, n, val)
{
	# Check for library errors first.
	if (USRXML_errno)
		return USRXML_errno;

	# Check for open sections.
	if (__USRXML_scope != __USRXML_scope_none)
		return scope_err(__USRXML_scope2name[__USRXML_scope]);

	# Zone and direction names to mask mapping.
	zone_dir_bits["world","in"]	= 0x01;
	zone_dir_bits["world","out"]	= 0x02;
	zone_dir_bits["world","all"]	= 0x03;
	zone_dir_bits["local","in"]	= 0x04;
	zone_dir_bits["local","out"]	= 0x08;
	zone_dir_bits["local","all"]	= 0x0c;
	zone_dir_bits["all","in"]	= 0x05;
	zone_dir_bits["all","out"]	= 0x0a;
	zone_dir_bits["all","all"]	= 0x0f;

	for (userid = 0; userid < USRXML_nusers; userid++) {
		if (USRXML_userif[userid] == "")
			return section_missing_arg("if", userid);
		if (!USRXML_usernets[userid] &&
		    !USRXML_usernets6[userid])
			return section_missing_arg("net|net6", userid);

		zones_dirs = 0;
		n = USRXML_userpipe[userid];
		for (pipeid = 0; pipeid < n; pipeid++) {
			if (USRXML_userpipezone[userid,pipeid] == "")
				return section_missing_arg("zone", userid SUBSEP pipeid);
			if (USRXML_userpipedir[userid,pipeid] == "")
				return section_missing_arg("dir", userid SUBSEP pipeid);
			if (USRXML_userpipebw[userid,pipeid] == "")
				return section_missing_arg("bw", userid SUBSEP pipeid);

			zd_bits = zone_dir_bits[USRXML_userpipezone[userid,pipeid],
						USRXML_userpipedir[userid,pipeid]];
			if (and(zones_dirs, zd_bits))
				return section_inv_arg("pipe", "zone|dir", userid SUBSEP pipeid);

			zones_dirs = or(zones_dirs, zd_bits);
		}

		val = USRXML_userif[userid];
		if (val in USRXML_ifusers)
			USRXML_ifusers[val] = USRXML_ifusers[val]","userid;
		else
			USRXML_ifusers[val] = userid;
	}

	delete zone_dir_bits;

	delete __USRXML_fileline;

	delete __USRXML_usernats6;
	delete __USRXML_usernats;
	delete __USRXML_usernets6;
	delete __USRXML_usernets;

	delete __USRXML_dir;

	delete __USRXML_zone;

	delete __USRXML_scope2name;
}

#
# Parse and validate XML document.
#
function __usrxml_scope_none(name, val)
{
	if (name == "user") {
		if (val == "")
			return ept_val(name);

		if (val in USRXML_userids) {
			USRXML_userid = USRXML_userids[val];
		} else {
			USRXML_userid = USRXML_nusers;

			USRXML_usernames[USRXML_userid] = val;
			USRXML_userpipe[USRXML_userid]  = 0;
			USRXML_usernets[USRXML_userid]  = 0;
			USRXML_usernets6[USRXML_userid] = 0;
			USRXML_usernats[USRXML_userid]  = 0;
			USRXML_usernats6[USRXML_userid] = 0;
		}

		__USRXML_scope = __USRXML_scope_user;

		section_record_fileline(USRXML_userid);
	} else {
		return syntax_err();
	}

	return 0;
}

function __usrxml_scope_user(name, val,    n)
{
	if (name == "/user") {
		if (val != "") {
			if (val != USRXML_usernames[USRXML_userid])
				return inv_arg(name, val);
		} else {
			val = USRXML_usernames[USRXML_userid];
		}

		if (!(val in USRXML_userids))
			USRXML_userids[val] = USRXML_nusers++;

		__USRXML_scope = __USRXML_scope_none;
	} else if (name == "if") {
		if (val == "")
			return ept_val(name);

		USRXML_userif[USRXML_userid] = val;
	} else if (name == "net") {
		if (val == "")
			return ept_val(name);
		if ((USRXML_userid, val) in __USRXML_usernets)
			return 0;
		__USRXML_usernets[USRXML_userid,val] = 1;

		n = USRXML_usernets[USRXML_userid]++;
		USRXML_usernets[USRXML_userid,n] = val;
	} else if (name == "net6") {
		if (val == "")
			return ept_val(name);
		if ((USRXML_userid, val) in __USRXML_usernets6)
			return 0;
		__USRXML_usernets6[USRXML_userid,val] = 1;

		n = USRXML_usernets6[USRXML_userid]++;
		USRXML_usernets6[USRXML_userid,n] = val;
	} else if (name == "nat") {
		if (val == "")
			return ept_val(name);
		if ((USRXML_userid, val) in __USRXML_usernats)
			return 0;
		__USRXML_usernats[USRXML_userid,val] = 1;

		n = USRXML_usernats[USRXML_userid]++;
		USRXML_usernats[USRXML_userid,n] = val;
	} else if (name == "nat6") {
		if (val == "")
			return ept_val(name);
		if ((USRXML_userid, val) in __USRXML_usernats6)
			return 0;
		__USRXML_usernats6[USRXML_userid,val] = 1;

		n = USRXML_usernats6[USRXML_userid]++;
		USRXML_usernats6[USRXML_userid,n] = val;
	} else if (name == "pipe") {
		if (val == "")
			return ept_val(name);

		val = 0 + val;
		if (val <= 0)
			return inv_arg(name, val);

		USRXML_pipeid = val - 1;
		if (USRXML_pipeid > USRXML_userpipe[USRXML_userid])
			return inv_arg(name, val);

		__USRXML_scope = __USRXML_scope_pipe;

		USRXML_userpipeqdisc[USRXML_userid,USRXML_pipeid] = "";

		section_record_fileline(USRXML_userid SUBSEP USRXML_pipeid);
	} else {
		return syntax_err();
	}

	return 0;
}

function __usrxml_scope_pipe(name, val)
{
	if (name == "/pipe") {
		USRXML_pipeid++;

		if (val != "" && val != USRXML_pipeid)
			return inv_arg(name, val);

		__USRXML_scope = __USRXML_scope_user;

		if (USRXML_pipeid > USRXML_userpipe[USRXML_userid])
			USRXML_userpipe[USRXML_userid] = USRXML_pipeid;
	} else if (name == "zone") {
		if (val == "")
			return ept_val(name);

		if (!(val in __USRXML_zone))
			return inv_arg(name, val);

		USRXML_userpipezone[USRXML_userid,USRXML_pipeid] = val;
	} else if (name == "dir" ) {
		if (val == "")
			return ept_val(name);

		if (!(val in __USRXML_dir))
			return inv_arg(name, val);

		USRXML_userpipedir[USRXML_userid,USRXML_pipeid] = val;
	} else if (name == "bw") {
		if (val == "")
			return ept_val(name);

		val = 0 + val;
		if (!val)
			return inv_arg(name, val);

		USRXML_userpipebw[USRXML_userid,USRXML_pipeid] = val;
	} else if (name == "qdisc") {
		if (val == "")
			return ept_val(name);

		__USRXML_scope = __USRXML_scope_qdisc;

		USRXML_userpipeqdisc[USRXML_userid,USRXML_pipeid] = val;
	} else {
		return syntax_err();
	}

	return 0;
}

function __usrxml_scope_qdisc(name, val,    qdisc, n)
{
	if (name == "/qdisc") {
		qdisc = USRXML_userpipeqdisc[USRXML_userid,USRXML_pipeid];
		if (val != "" && val != qdisc)
			return inv_arg(name, val);

		__USRXML_scope = __USRXML_scope_pipe;
	} else if (name == "opts") {
		n = USRXML_userpipeqdisc[USRXML_userid,USRXML_pipeid,"opts"]++;
		USRXML_userpipeqdisc[USRXML_userid,USRXML_pipeid,"opts",n] = val;
	} else {
		return syntax_err();
	}

	return 0;
}

function run_usr_xml_parser(line,    a, nfields, fn)
{
	if (__USRXML_filename != FILENAME) {
		__USRXML_filename = FILENAME;
		__USRXML_linenum = 0;
	}
	__USRXML_linenum++;

	if (line ~ /^[[:space:]]*$/)
		return 0;

	nfields = match(line, "^[[:space:]]*<([[:alpha:]_][[:alnum:]_]+)[[:space:]]+([^<>]+)>[[:space:]]*$", a);
	if (!nfields) {
		nfields = match(line, "^[[:space:]]*<(/[[:alpha:]_][[:alnum:]_]+)[[:space:]]*([^<>]*)>[[:space:]]*$", a);
		if (!nfields)
			return syntax_err();
	}

	# name = a[1]
	# val  = a[2]

	fn = "__usrxml_scope_" __USRXML_scope2name[__USRXML_scope];
	return @fn(a[1], a[2]);
}

#
# Print users entry in xml format
#
function print_usr_xml_entry(userid,    pipeid, netid, net6id, natid, nat6id, n, i)
{
	printf "<user %s>\n", USRXML_usernames[userid];
	for (pipeid = 0; pipeid < USRXML_userpipe[userid]; pipeid++) {
		printf "\t<pipe %d>\n" \
		       "\t\t<zone %s>\n" \
		       "\t\t<dir %s>\n" \
		       "\t\t<bw %sKb>\n",
			pipeid + 1,
			USRXML_userpipezone[userid,pipeid],
			USRXML_userpipedir[userid,pipeid],
			USRXML_userpipebw[userid,pipeid];

		if (USRXML_userpipeqdisc[userid,pipeid] != "") {
			printf "\t\t<qdisc %s>\n",
				USRXML_userpipeqdisc[userid,pipeid];

			n = USRXML_userpipeqdisc[userid,pipeid,"opts"];
			for (i = 0; i < n; i++) {
				printf "\t\t\t<opts %s>\n",
					USRXML_userpipeqdisc[userid,pipeid,"opts",i];
			}

			printf "\t\t</qdisc>\n";
		}

		printf "\t</pipe>\n";
	}
	printf "\t<if %s>\n", USRXML_userif[userid];
	for (netid = 0; netid < USRXML_usernets[userid]; netid++)
		printf "\t<net %s>\n", USRXML_usernets[userid,netid];
	for (net6id = 0; net6id < USRXML_usernets6[userid]; net6id++)
		printf "\t<net6 %s>\n", USRXML_usernets6[userid,net6id];
	for (natid = 0; natid < USRXML_usernats[userid]; natid++)
		printf "\t<nat %s>\n", USRXML_usernats[userid,natid];
	for (nat6id = 0; nat6id < USRXML_usernats6[userid]; nat6id++)
		printf "\t<nat6 %s>\n", USRXML_usernats6[userid,nat6id];
	print "</user>\n";
}

#
# Print users entry in one line xml format
#
function print_usr_xml_entry_oneline(userid,    pipeid, netid, net6id, natid, nat6id, n, i)
{
	printf "<user %s>", USRXML_usernames[userid];
	for (pipeid = 0; pipeid < USRXML_userpipe[userid]; pipeid++) {
		printf "<pipe %d><zone %s><dir %s><bw %sKb>",
			pipeid + 1,
			USRXML_userpipezone[userid,pipeid],
			USRXML_userpipedir[userid,pipeid],
			USRXML_userpipebw[userid,pipeid];

		if (USRXML_userpipeqdisc[userid,pipeid] != "") {
			printf "<qdisc %s>",
				USRXML_userpipeqdisc[userid,pipeid];

			n = USRXML_userpipeqdisc[userid,pipeid,"opts"];
			for (i = 0; i < n; i++) {
				printf "<opts %s>",
					USRXML_userpipeqdisc[userid,pipeid,"opts",i];
			}

			printf "</qdisc>";
		}

		printf "</pipe>";
	}
	printf "<if %s>", USRXML_userif[userid];
	for (netid = 0; netid < USRXML_usernets[userid]; netid++)
		printf "<net %s>", USRXML_usernets[userid,netid];
	for (net6id = 0; net6id < USRXML_usernets6[userid]; net6id++)
		printf "<net6 %s>", USRXML_usernets6[userid,net6id];
	for (natid = 0; natid < USRXML_usernats[userid]; natid++)
		printf "<nat %s>", USRXML_usernats[userid,natid];
	for (nat6id = 0; nat6id < USRXML_usernats6[userid]; nat6id++)
		printf "<nat6 %s>", USRXML_usernats6[userid,nat6id];
	print "</user>";
}
