#!/usr/bin/gawk -f

#
# Parser helper routines to report various errors.
#
function syntax_err()
{
	printf "USRXML: %d: syntax error\n",
		__USRXML_linenum >"/dev/stderr"
	USRXML_errno = USRXML_E_SYNTAX;
	return USRXML_E_SYNTAX;
}

function scope_err(section)
{
	printf "USRXML: %d: <%s> scope error\n",
		__USRXML_linenum, section >"/dev/stderr"
	USRXML_errno = USRXML_E_SCOPE;
	return USRXML_E_SCOPE;
}

function inv_arg(section, value)
{
	printf "USRXML: %d: invalid argument \"%s\" in <%s>\n",
		__USRXML_linenum, value, section >"/dev/stderr"
	USRXML_errno = USRXML_E_INVAL;
	return USRXML_E_INVAL;
}

function ept_val(section)
{
	printf "USRXML: %d: empty value in <%s>\n",
		__USRXML_linenum, section >"/dev/stderr"
	USRXML_errno = USRXML_E_EMPTY;
	return USRXML_E_EMPTY;
}

function dup_arg(section)
{
	printf "USRXML: %d: duplicated argument <%s>\n",
		__USRXML_linenum, section >"/dev/stderr"
	USRXML_errno = USRXML_E_DUP;
	return USRXML_E_DUP;
}

function missing_arg(section)
{
	printf "USRXML: %d: missing mandatory argument <%s>\n",
		__USRXML_linenum, section >"/dev/stderr"
	USRXML_errno = USRXML_E_MISS;
	return USRXML_E_MISS;
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
	USRXML_errno	= 0;

	#
	# Following variables are populated from parsing
	# XML document.
	#
	USRXML_nusers	= 0;

	# USRXML_usernames[userid]
	#
	# USRXML_userpipe[userid]
	# USRXML_userpipezone[userid,pipeid]
	# USRXML_userpipedir[userid,pipeid]
	# USRXML_userpipebw[userid,pipeid]
	#
	# USRXML_userif[userid]
	#
	# USRXML_usernets[userid,netid]
	#
	# USRXML_usernets6[userid,net6id]
	#
	# USRXML_usernats[userid,natid]
	#
	# USRXML_ifusers[ifaceid]

	#
	# These variables are *internal*, but needed to be
	# preserved accross library function calls.
	#
	__USRXML_linenum	= 0;
	__USRXML_useropen	= 0;
	__USRXML_pipeopen	= 0;
	# user
	__USRXML_if_once	= 0;
	__USRXML_net_ok		= 0;
	__USRXML_net6_ok	= 0;
	__USRXML_nat_ok		= 0;
	# pipe
	__USRXML_bw_once	= 0;
	__USRXML_zone_once	= 0;
	__USRXML_dir_once	= 0;

	__USRXML_FS	= FS;
	FS		= "[<>]";

	return 0;
}

#
# Finish XML document validation.
# This is usually called from END{} section.
#
function fini_usr_xml_parser(    zd_bits, zone_dir_bits, zones_dirs,
			     userid, pipeid)
{
	# Check for library errors first.
	if (USRXML_errno)
		return USRXML_errno;

	# Check for open sections.
	if (__USRXML_useropen)
		return scope_err("user");
	if (__USRXML_pipeopen)
		return scope_err("pipe");

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
		zones_dirs = 0;
		for (pipeid = 0; pipeid < USRXML_userpipe[userid]; pipeid++) {
			zd_bits = zone_dir_bits[USRXML_userpipezone[userid,pipeid],
						USRXML_userpipedir[userid,pipeid]];
			if (and(zones_dirs, zd_bits)) {
				__USRXML_linenum = USRXML_userpipelinenum[userid,pipeid];
				return inv_arg("pipe", "zone|dir");
			}

			zones_dirs = or(zones_dirs, zd_bits);
		}
	}

	FS = __USRXML_FS;
}

#
# Parse and validate XML document.
#
function run_usr_xml_parser(line,    name, val, token, nfields, a, n, seps)
{
	__USRXML_linenum++;

	if (line ~ /^[[:space:]]*$/)
		return 0;

	#
	# ^[[:space:]]+token[[:space:]]+$
	#
	token = gensub(/^[[:space:]]+|[[:space:]]+$/, "", "g", line);

	#
	# a[1]<a[2]>a[3]
	# <user USR>, </user>
	#
	nfields = split(token, a, /[<>]+/, seps);
	if (nfields != 3 ||
	    a[1] != "" || seps[1] != "<" ||
	    a[3] != "" || seps[2] != ">")
		return syntax_err();

	#
	# a[1]([[:space:]]+a[2])?
	# <user USR>, </user>
	#
	nfields = split(a[2], a, /[[:space:]]+/, seps);
	if (nfields > 2 || a[1] == "" || a[nfields] == "")
		return syntax_err();

	name	= a[1];
	val	= a[2];

	if (name == "user") {
		if (__USRXML_useropen)
			return scope_err(name);
		if (val == "")
			return ept_val(name);
		__USRXML_useropen = 1;

		__USRXML_if_once = 0;
		__USRXML_net_ok = 0;
		__USRXML_net6_ok = 0;

		USRXML_usernames[USRXML_nusers] = val;
		USRXML_userpipe[USRXML_nusers] = 0;
		USRXML_usernets[USRXML_nusers] = 0;
		USRXML_usernets6[USRXML_nusers] = 0;
		USRXML_usernats[USRXML_nusers] = 0;
	} else if (name == "if") {
		if (!__USRXML_useropen || __USRXML_pipeopen)
			return scope_err(name);
		if (val == "")
			return ept_val(name);
		if (__USRXML_if_once)
			return dup_arg(name);
		__USRXML_if_once = 1;

		if (val in USRXML_ifusers)
			USRXML_ifusers[val] = USRXML_ifusers[val]","USRXML_nusers;
		else
			USRXML_ifusers[val] = USRXML_nusers;

		USRXML_userif[USRXML_nusers] = val;
	} else if (name == "net") {
		if (!__USRXML_useropen || __USRXML_pipeopen)
			return scope_err(name);
		if (val == "")
			return ept_val(name);
		__USRXML_net_ok = 1;

		n = USRXML_usernets[USRXML_nusers]++;
		USRXML_usernets[USRXML_nusers,n] = val;
	} else if (name == "net6") {
		if (!__USRXML_useropen || __USRXML_pipeopen)
			return scope_err(name);
		if (val == "")
			return ept_val(name);
		__USRXML_net6_ok = 1;

		n = USRXML_usernets6[USRXML_nusers]++;
		USRXML_usernets6[USRXML_nusers,n] = val;
	} else if (name == "nat") {
		if (!__USRXML_useropen || __USRXML_pipeopen)
			return scope_err(name);
		if (val == "")
			return ept_val(name);
		__USRXML_nat_ok = 1;

		n = USRXML_usernats[USRXML_nusers]++;
		USRXML_usernats[USRXML_nusers,n] = val;
	} else if (name == "pipe") {
		if (!__USRXML_useropen || __USRXML_pipeopen)
			return scope_err(name);
		if (val == "")
			return ept_val(name);
		if (val != USRXML_userpipe[USRXML_nusers] + 1)
			return inv_arg(name, val);
		__USRXML_pipeopen = 1;

		__USRXML_bw_once = 0;
		__USRXML_zone_once = 0;
		__USRXML_dir_once = 0;

		n = USRXML_userpipe[USRXML_nusers];
		USRXML_userpipelinenum[USRXML_nusers,] = __USRXML_linenum;
	} else if (name == "zone") {
		if (!__USRXML_pipeopen)
			return scope_err(name);
		if (val == "")
			return ept_val(name);
		if (__USRXML_zone_once)
			return dup_arg(name);
		if (val != "local" &&
		    val != "world" &&
		    val != "all")
			return inv_arg(name, val);

		__USRXML_zone_once = 1;

		USRXML_userpipezone[USRXML_nusers,USRXML_userpipe[USRXML_nusers]] = val;
	} else if (name == "dir" ) {
		if (!__USRXML_pipeopen)
			return scope_err(name);
		if (val == "")
			return ept_val(name);
		if (__USRXML_dir_once)
			return dup_arg(name);
		if (val != "all" &&
		    val != "in" &&
		    val != "out")
			return inv_arg(name, val);

		__USRXML_dir_once = 1;

		USRXML_userpipedir[USRXML_nusers,USRXML_userpipe[USRXML_nusers]] = val;
	} else if (name == "bw") {
		if (!__USRXML_pipeopen)
			return scope_err(name);
		if (val == "")
			return ept_val(name);
		if (__USRXML_bw_once)
			return dup_arg(name);

		val = int(val);
		if (!val)
			return inv_arg(name, val);

		__USRXML_bw_once = 1;

		USRXML_userpipebw[USRXML_nusers,USRXML_userpipe[USRXML_nusers]] = val;
	}else if (name == "/pipe") {
		if (!__USRXML_pipeopen)
			return scope_err(name);
		if (val != "" && val != USRXML_userpipe[USRXML_nusers] + 1)
			return inv_arg(name, val);

		if (!__USRXML_bw_once)
			return missing_arg("bw");
		if (!__USRXML_zone_once)
			return missing_arg("zone");
		if (!__USRXML_dir_once)
			return missing_arg("dir");

		__USRXML_pipeopen = 0;

		USRXML_userpipe[USRXML_nusers]++;
	} else if (name == "/user") {
		if (!__USRXML_useropen || __USRXML_pipeopen)
			return scope_err(name);
		if (val != "" && val != USRXML_usernames[USRXML_nusers])
			return inv_arg(name, val);

		if (!__USRXML_if_once)
			return missing_arg("if");
		if (!__USRXML_net_ok && !__USRXML_net6_ok)
			return missing_arg("net|net6");

		__USRXML_useropen = 0;

		USRXML_nusers++;
	} else {
		return syntax_err();
	}

	return 0;
}

#
# Print users entry in xml format
#
function print_usr_xml_entry(userid,    pipeid, netid, net6id, natid)
{
	printf "<user %s>\n", USRXML_usernames[userid];
	for (pipeid = 0; pipeid < USRXML_userpipe[userid]; pipeid++) {
		printf "\t<pipe %d>\n" \
		       "\t\t<zone %s>\n" \
		       "\t\t<dir %s>\n" \
		       "\t\t<bw %sKb>\n" \
		       "\t</pipe>\n",
			pipeid + 1,
			USRXML_userpipezone[userid,pipeid],
			USRXML_userpipedir[userid,pipeid],
			USRXML_userpipebw[userid,pipeid];
	}
	printf "\t<if %s>\n", USRXML_userif[userid];
	for (netid = 0; netid < USRXML_usernets[userid]; netid++)
		printf "\t<net %s>\n", USRXML_usernets[userid,netid];
	for (net6id = 0; net6id < USRXML_usernets6[userid]; net6id++)
		printf "\t<net6 %s>\n", USRXML_usernets6[userid,net6id];
	for (natid = 0; natid < USRXML_usernats[userid]; natid++)
		printf "\t<nat %s>\n", USRXML_usernats[userid,natid];
	print "</user>\n";
}

#
# Print users entry in one line xml format
#
function print_usr_xml_entry_oneline(userid,    pipeid, netid, net6id, natid)
{
	printf "<user %s>", USRXML_usernames[userid];
	for (pipeid = 0; pipeid < USRXML_userpipe[userid]; pipeid++) {
		printf "<pipe %d><zone %s><dir %s><bw %sKb></pipe>",
			pipeid + 1,
			USRXML_userpipezone[userid,pipeid],
			USRXML_userpipedir[userid,pipeid],
			USRXML_userpipebw[userid,pipeid];
	}
	printf "<if %s>", USRXML_userif[userid];
	for (netid = 0; netid < USRXML_usernets[userid]; netid++)
		printf "<net %s>", USRXML_usernets[userid,netid];
	for (net6id = 0; net6id < USRXML_usernets6[userid]; net6id++)
		printf "<net6 %s>", USRXML_usernets6[userid,net6id];
	for (natid = 0; natid < USRXML_usernats[userid]; natid++)
		printf "<nat %s>", USRXML_usernats[userid,natid];
	print "</user>";
}
