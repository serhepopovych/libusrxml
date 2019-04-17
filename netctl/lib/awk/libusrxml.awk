#!/usr/bin/gawk -f

# Source USRXML database parsing library.
@include "@target@/netctl/lib/awk/libinet.awk"

#
# Parser descriptor handling helper routines.
#

function is_valid_usrxml_handle(h)
{
	return USRXML__instance["h",h] == h;
}

function usrxml__alloc_handle(    h)
{
	h = int(USRXML__instance["h"]);

	do {
		if (h + 1 < 1) {
			return USRXML_E_HANDLE_FULL;
		}
		h++;
	} while (is_valid_usrxml_handle(h));

	USRXML__instance["h",h] = h;
	USRXML__instance["h"] = h;

	return h;
}

function usrxml__free_handle(h)
{
	if (is_valid_usrxml_handle(h)) {
		delete USRXML__instance["h",h];
		USRXML__instance["h"] = h - 1;
	}
}

#
# Error handling functions.
#

function usrxml_errno(h)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;
	return USRXML__instance[h,"errno"];
}

function usrxml__seterrno(h, val)
{
	USRXML__instance[h,"errno"] = val;
	return val;
}

function usrxml_seterrno(h, val)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;
	return usrxml__seterrno(h, val);
}

#
# Control library verbosity levels.
#

function usrxml_getverbose(h)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;
	return USRXML__instance[h,"verbose"];
}

function usrxml_setverbose(h, val)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;
	USRXML__instance[h,"verbose"] = val;
	return USRXML_E_NONE;
}

#
# Parser helper routines to report various errors.
#

function usrxml_syntax_err(h)
{
	if (USRXML__instance[h,"verbose"]) {
		printf "USRXML[%u]: %s:%d: syntax error\n",
			h,
			USRXML__instance[h,"filename"],
			USRXML__instance[h,"linenum"] >"/dev/stderr"
	}
	return usrxml__seterrno(h, USRXML_E_SYNTAX);
}

function usrxml_scope_err(h, section)
{
	if (USRXML__instance[h,"verbose"]) {
		printf "USRXML[%u]: %s:%d: <%s> scope error\n",
			h,
			USRXML__instance[h,"filename"],
			USRXML__instance[h,"linenum"],
			section >"/dev/stderr"
	}
	return usrxml__seterrno(h, USRXML_E_SCOPE);
}

function usrxml_inv_arg(h, section, value)
{
	if (USRXML__instance[h,"verbose"]) {
		printf "USRXML[%u]: %s:%d: invalid argument \"%s\" in <%s>\n",
			h,
			USRXML__instance[h,"filename"],
			USRXML__instance[h,"linenum"],
			value, section >"/dev/stderr"
	}
	return usrxml__seterrno(h, USRXML_E_INVAL);
}

function usrxml_ept_val(h, section)
{
	if (USRXML__instance[h,"verbose"]) {
		printf "USRXML[%u]: %s:%d: empty value in <%s>\n",
			h,
			USRXML__instance[h,"filename"],
			USRXML__instance[h,"linenum"],
			section >"/dev/stderr"
	}
	return usrxml__seterrno(h, USRXML_E_EMPTY);
}

function usrxml_dup_val(h, section, value)
{
	if (USRXML__instance[h,"verbose"]) {
		printf "USRXML[%u]: %s:%d: duplicated value \"%s\" in <%s>\n",
			h,
			USRXML__instance[h,"filename"],
			USRXML__instance[h,"linenum"],
			value, section >"/dev/stderr"
	}
	return usrxml__seterrno(h, USRXML_E_DUP);
}

function usrxml_dup_arg(h, section)
{
	if (USRXML__instance[h,"verbose"]) {
		printf "USRXML[%u]: %s:%d: duplicated argument <%s>\n",
			h,
			USRXML__instance[h,"filename"],
			USRXML__instance[h,"linenum"],
			section >"/dev/stderr"
	}
	return usrxml__seterrno(h, USRXML_E_DUP);
}

function usrxml_dup_net(h, section, value, userid,    ret)
{
	if (userid == USRXML__instance[h,"userid"])
		return usrxml__seterrno(h, USRXML_E_NONE);

	ret = usrxml_dup_val(h, section, value);

	if (USRXML__instance[h,"verbose"]) {
		printf "USRXML[%u]: %s:%d: already defined by \"%s\" user\n",
			h,
			USRXML__instance[h,"filename"],
			USRXML__instance[h,"linenum"],
			USRXML_usernames[userid] >"/dev/stderr"
	}
	return ret;
}

function usrxml_missing_arg(h, section)
{
	if (USRXML__instance[h,"verbose"]) {
		printf "USRXML[%u]: %s:%d: missing mandatory argument <%s>\n",
			h,
			USRXML__instance[h,"filename"],
			USRXML__instance[h,"linenum"],
			section >"/dev/stderr"
	}
	return usrxml__seterrno(h, USRXML_E_MISS);
}

#
# Helper routines to track section (e.g. <user>, <pipe>) filename and linenum.
#

function usrxml_section_record_fileline(h, key,    n)
{
	n = USRXML__fileline[key]++;
	USRXML__fileline[key,"file",n] = USRXML__instance[h,"filename"];
	USRXML__fileline[key,"line",n] = USRXML__instance[h,"linenum"];
}

function usrxml_section_delete_fileline(h, key,    n, i)
{
	n = USRXML__fileline[key];
	delete USRXML__fileline[key];
	for (i = 0; i < n; i++) {
		delete USRXML__fileline[key,"file",i];
		delete USRXML__fileline[key,"line",i];
	}
}

function usrxml_section_fn_arg(h, section, key, fn,    n, ret, s_fn, s_ln)
{
	ret = usrxml__seterrno(h, USRXML_E_SYNTAX);

	s_fn = USRXML__instance[h,"filename"];
	s_ln = USRXML__instance[h,"linenum"];

	n = USRXML__fileline[key];
	while (n--) {
		USRXML__instance[h,"filename"] = USRXML__fileline[key,"file",n];
		USRXML__instance[h,"linenum"]  = USRXML__fileline[key,"line",n];

		ret = @fn(h, section);
	}

	USRXML__instance[h,"filename"] = s_fn;
	USRXML__instance[h,"linenum"]  = s_ln;

	return ret;
}

function usrxml__inv_arg(h, section)
{
	return usrxml_inv_arg(h, section["name"], section["value"]);
}

function usrxml_section_inv_arg(h, _section, value, key,    section)
{
	section["name"]  = _section;
	section["value"] = value;

	return usrxml_section_fn_arg(h, section, key, "usrxml__inv_arg");
}

function usrxml_section_missing_arg(h, section, key)
{
	return usrxml_section_fn_arg(h, section, key, "usrxml_missing_arg");
}

#
# Initialize users database XML document parser/validator.
# This is usually called from BEGIN{} section.
#
# Returns parser instance handle that may be passed to others.
#

function init_usrxml_parser(    h)
{
	## Constants (public)

	# USRXML error codes (visible in case of handle allocation error)
	USRXML_E_NONE	= 0;
	USRXML_E_INVAL	= -1;
	USRXML_E_EMPTY	= -2;
	USRXML_E_DUP	= -3;
	USRXML_E_MISS	= -4;
	USRXML_E_SCOPE	= -50;
	# generic
	USRXML_E_SYNTAX	= -100;
	# API
	USRXML_E_HANDLE_INVALID = -201;
	USRXML_E_HANDLE_FULL    = -202;
	USRXML_E_API_ORDER      = -203;
	# entry
	USRXML_E_NOENT	= -301;

	# Establish next (first) instance
	h = usrxml__alloc_handle();
	if (h < 0)
		return h;

	# Network interface name size (including '\0' byte)
	USRXML_IFNAMSIZ = 16;

	## Constants (internal, arrays get cleaned )

	# Tag scope
	USRXML__scope_none	= 0;
	USRXML__scope_user	= 1;
	USRXML__scope_pipe	= 2;
	USRXML__scope_qdisc	= 3;
	USRXML__scope_net	= 4;
	USRXML__scope_net6	= 5;

	USRXML__scope2name[USRXML__scope_none]	= "none";
	USRXML__scope2name[USRXML__scope_user]	= "user";
	USRXML__scope2name[USRXML__scope_pipe]	= "pipe";
	USRXML__scope2name[USRXML__scope_qdisc]	= "qdisc";
	USRXML__scope2name[USRXML__scope_net]	= "net";
	USRXML__scope2name[USRXML__scope_net6]	= "net6";

	# Valid "zone" values
	USRXML__zone["world"]	= 1;
	USRXML__zone["local"]	= 1;
	USRXML__zone["all"]	= 1;

	# Valid "dir" values
	USRXML__dir["in"]	= 1;
	USRXML__dir["out"]	= 1;
	USRXML__dir["all"]	= 1;

	## Variables

	# USRXML__instance[] internal information about parser instance

	# Library public functions call order
	USRXML__order_none   = 0;
	USRXML__order_parse  = 1
	USRXML__order_result = 2;
	USRXML__instance[h,"order"] = USRXML__order_parse;

	# Extra maps build by build_usrxml_extra()
	USRXML__instance[h,"extra"] = 0;

	# Report errors by default
	USRXML__instance[h,"verbose"] = 1;

	# Error number updated on each library call
	USRXML__instance[h,"errno"] = USRXML_E_NONE;

	# Current scope
	USRXML__instance[h,"scope"] = USRXML__scope_none;

	# Populated from parsing XML document
	USRXML__instance[h,"userid"] = 0;
	USRXML__instance[h,"pipeid"] = 0;
	USRXML__instance[h,"netid"] = 0;
	USRXML__instance[h,"net6id"] = 0;

	# FILENAME might be unknown if called from BEGIN{} sections
	USRXML__instance[h,"filename"] = FILENAME;
	USRXML__instance[h,"linenum"] = 0;

	# USRXML__fileline[key,{ "file" | "line" },n]

	# Document format and parameters mapping
	# --------------------------------------
	#
	# nusers = USRXML_usernames[h]
	# userid = [0 .. nusers - 1]
	# username = USRXML_usernames[h,userid]
	# userid   = USRXML_userids[h,username]
	# <user 'name'>
	#
	#   npipes = USRXML_userpipe[h,userid]
	#   pipeid = [0 .. npipes - 1]
	#   <pipe 'num'>
	#     USRXML_userpipe[h,userid,pipeid]
	#     <zone local|world|all>
	#       zone = USRXML_userpipe[h,userid,pipeid,"zone"]
	#     <dir in|out>
	#       dir =USRXML_userpipe[h,userid,pipeid,"dir"]
	#     <bw kbits>
	#       bw = USRXML_userpipe[h,userid,pipeid,"bw"]
	#     <qdisc 'name'>
	#       qdisc = USRXML_userpipe[h,userid,pipeid,"qdisc"]
	#
	#       nopts = USRXML_userpipe[h,userid,pipeid,"opts"]
	#       optid = [0 .. nopts - 1]
	#       <opts 'params'>
	#         opts += USRXML_userpipe[h,userid,pipeid,"opts",optid]
	#     </qdisc>
	#   </pipe>
	#
	#   <if>
	#     userif = USRXML_userif[h,userid]
	#
	#   nunets = USRXML_usernets[h,userid]
	#   netid = [0 .. nunets - 1]
	#   <net 'cidr'>
	#     net = USRXML_usernets[h,userid,netid]
	# [
	#     <!-- These are optional -->
	#     <src>
	#       src = USRXML_usernets[h,userid,netid,"src"]
	#     <via>
	#       via = USRXML_usernets[h,userid,netid,"via"]
	#     <mac>
	#       mac = USRXML_usernets[h,userid,netid,"mac"]
	#   </net>
	# ]
	#
	#   nunets6 = USRXML_usernets6[h,userid]
	#   netid6 = [0 .. nunets6 - 1]
	#   <net6 'cidr6'>
	#     net6 = USRXML_usernets6[h,userid,netid6]
	# [
	#     <!-- These are optional -->
	#     <src>
	#       src = USRXML_usernets6[h,userid,netid6,"src"]
	#     <via>
	#       via = USRXML_usernets6[h,userid,netid6,"via"]
	#     <mac>
	#       mac = USRXML_usernets6[h,userid,netid6,"mac"]
	#   </net6>
	# ]
	#
	#   nunats = USRXML_usernats[h,userid]
	#   natid = [0 .. nunats - 1]
	#   <nat 'cidr'>
	#     nat = USRXML_usernats[h,userid,natid]
	#
	#   nunats6 = USRXML_usernats6[h,userid]
	#   natid6 = [0 .. nunats6 - 1]
	#   <nat6 'cidr6'>
	#     nat6 = USRXML_usernats6[h,userid,natid6]
	#
	# </user>

	# These are used to find duplicates at parse time
	# -----------------------------------------------
	#
	# <user 'name'>
	#
	#   <net 'cidr'>
	#     h,userid = USRXML_nets[h,net]
	#
	#   <net6 'cidr6'>
	#     h,userid = USRXML_nets6[h,net6]
	#
	#   <nat 'cidr'>
	#     h,userid = USRXML_nats[h,nat]
	#
	#   <nat6 'cidr6'>
	#     h,userid = USRXML_nats6[h,nat6]
	#
	# </user>

	# Number of users
	USRXML_usernames[h] = 0;

	# Note that rest of USRXML_user*[] arrays
	# initialized in usrxml__scope_user()

	return h;
}

#
# Return XML document parsing result performing final validation steps.
#

function result_usrxml_parser(h,    zone_dir_bits, zones_dirs, zd_bits,
			      n, m, i, j, u, p, val)
{
	val = usrxml_errno(h);
	if (val != USRXML_E_NONE)
		return val;

	if (USRXML__instance[h,"order"] != USRXML__order_parse)
		return usrxml__seterrno(h, USRXML_E_API_ORDER);

	# Check for open sections
	val = USRXML__instance[h,"scope"];
	if (val != USRXML__scope_none)
		return usrxml_scope_err(h, USRXML__scope2name[val]);

	# Zone and direction names to mask mapping
	zone_dir_bits["world","in"]	= 0x01;
	zone_dir_bits["world","out"]	= 0x02;
	zone_dir_bits["world","all"]	= 0x03;
	zone_dir_bits["local","in"]	= 0x04;
	zone_dir_bits["local","out"]	= 0x08;
	zone_dir_bits["local","all"]	= 0x0c;
	zone_dir_bits["all","in"]	= 0x05;
	zone_dir_bits["all","out"]	= 0x0a;
	zone_dir_bits["all","all"]	= 0x0f;

	# user
	n = USRXML_usernames[h];
	for (u = 0; u < n; u++) {
		i = h SUBSEP u;

		val = "user" SUBSEP i;

		if (USRXML_userif[i] == "")
			return usrxml_section_missing_arg(h, "if", val);
		if (!USRXML_usernets[i] && !USRXML_usernets6[i])
			return usrxml_section_missing_arg(h, "net|net6", val);

		zones_dirs = 0;

		# pipe
		m = USRXML_userpipe[i];
		for (p = 0; p < m; p++) {
			j = i SUBSEP p;

			val = "pipe" SUBSEP j;

			if (!((j,"zone") in USRXML_userpipe))
				return usrxml_section_missing_arg(h, "zone", val);
			if (!((j,"dir") in USRXML_userpipe))
				return usrxml_section_missing_arg(h, "dir", val);
			if (!((j,"bw") in USRXML_userpipe))
				return usrxml_section_missing_arg(h, "bw", val);

			zd_bits = zone_dir_bits[USRXML_userpipe[j,"zone"],
						USRXML_userpipe[j,"dir"]];
			if (and(zones_dirs, zd_bits))
				return usrxml_section_inv_arg(h, "pipe", "zone|dir", val);

			zones_dirs = or(zones_dirs, zd_bits);
		}
	}

	# Change API order
	USRXML__instance[h,"order"] = USRXML__order_result;

	return usrxml__seterrno(h, USRXML_E_NONE);
}

#
# Destroy XML document parser instance.
# This is usually called from END{} section.
#

function fini_usrxml_parser(h,    n, m, i, j, u, p, o, val)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;

	# Disable library functions at all levels
	delete USRXML__instance[h,"order"];

	# user
	n = USRXML_usernames[h];
	for (u = 0; u < n; u++) {
		# h,userid
		i = h SUBSEP u;

		usrxml_section_delete_fileline(h, "user" SUBSEP i);

		val = USRXML_usernames[i];
		delete USRXML_usernames[i];
		delete USRXML_userids[h,val];

		# pipe
		m = USRXML_userpipe[i];
		delete USRXML_userpipe[i];
		for (p = 0; p < m; p++) {
			# h,userid,pipeid
			j = i SUBSEP p;

			usrxml_section_delete_fileline(h, "pipe" SUBSEP j);
			delete USRXML_userpipe[j];
			delete USRXML_userpipe[j,"zone"];
			delete USRXML_userpipe[j,"dir"];
			delete USRXML_userpipe[j,"bw"];

			usrxml_section_delete_fileline(h, "qdisc" SUBSEP j);
			delete USRXML_userpipe[j,"qdisc"];

			# h,userid,pipeid,opts
			j = j SUBSEP "opts";

			val = USRXML_userpipe[j];
			delete USRXML_userpipe[j];
			for (o = 0; o < val; o++)
				delete USRXML_userpipe[j,o];
		}

		# if
		delete USRXML_userif[i];

		# net
		m = USRXML_usernets[i];
		delete USRXML_usernets[i];
		for (p = 0; p < m; p++) {
			# h,userid,netid
			j = i SUBSEP p;

			usrxml_section_delete_fileline(h, "net" SUBSEP j);
			val = USRXML_usernets[j];
			delete USRXML_usernets[j];
			delete USRXML_usernets[j,"src"];
			delete USRXML_usernets[j,"via"];
			delete USRXML_usernets[j,"mac"];
			delete USRXML_usernets[j,"has_opts"];
			delete USRXML_nets[h,val];
		}

		# net6
		m = USRXML_usernets6[i];
		delete USRXML_usernets6[i];
		for (p = 0; p < m; p++) {
			# h,userid,net6id
			j = i SUBSEP p;

			usrxml_section_delete_fileline(h, "net6" SUBSEP j);
			val = USRXML_usernets6[j];
			delete USRXML_usernets6[j];
			delete USRXML_usernets6[j,"src"];
			delete USRXML_usernets6[j,"via"];
			delete USRXML_usernets6[j,"mac"];
			delete USRXML_usernets6[j,"has_opts"];
			delete USRXML_nets6[h,val];
		}

		# nat
		m = USRXML_usernats[i];
		delete USRXML_usernats[i];
		for (p = 0; p < m; p++) {
			# h,userid,natid
			j = i SUBSEP p;

			val = USRXML_usernats[j];
			delete USRXML_usernats[j];
			delete USRXML_nats[h,val];
		}

		# nat6
		m = USRXML_usernats6[i];
		delete USRXML_usernats6[i];
		for (p = 0; p < m; p++) {
			# h,userid,nat6id
			j = i SUBSEP p;

			val = USRXML_usernats6[j];
			delete USRXML_usernats6[j];
			delete USRXML_nats6[h,val];
		}
	}
	delete USRXML_usernames[h];

	# Extra maps build by build_usrxml_extra()
	__unbuild_usrxml_extra(h);

	# Report errors by default
	delete USRXML__instance[h,"verbose"];

	# Error encountered during XML parsing/validation
	delete USRXML__instance[h,"errno"];

	# Current scope
	delete USRXML__instance[h,"scope"];

	# Populated from parsing XML document
	delete USRXML__instance[h,"userid"];
	delete USRXML__instance[h,"pipeid"];
	delete USRXML__instance[h,"netid"];
	delete USRXML__instance[h,"net6id"];

	# FILENAME might be unknown if called from BEGIN{} sections
	delete USRXML__instance[h,"filename"];
	delete USRXML__instance[h,"linenum"];

	usrxml__free_handle(h);

	return USRXML_E_NONE;
}

#
# Parse and validate XML document.
#

function usrxml__scope_none(h, name, val,    n, i)
{
	if (name == "user") {
		if (val == "")
			return usrxml_ept_val(h, name);

		n = h SUBSEP val;
		if (n in USRXML_userids) {
			i = h SUBSEP USRXML_userids[n];
		} else {
			i = USRXML_usernames[h]++;
			USRXML_userids[n] = i;
			i = h SUBSEP i;

			USRXML_usernames[i] = val;
			USRXML_userpipe[i]  = 0;
			USRXML_usernets[i]  = 0;
			USRXML_usernets6[i] = 0;
			USRXML_usernats[i]  = 0;
			USRXML_usernats6[i] = 0;
		}

		USRXML__instance[h,"userid"] = i;
		USRXML__instance[h,"scope"] = USRXML__scope_user;

		usrxml_section_record_fileline(h, name SUBSEP i);
	} else {
		return usrxml_syntax_err(h);
	}

	return USRXML_E_NONE;
}

function usrxml__scope_user(h, name, val,    n, i)
{
	i = USRXML__instance[h,"userid"];

	if (name == "/user") {
		if (val != "" && val != USRXML_usernames[i])
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_none;
	} else if (name == "if") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (length(val) >= USRXML_IFNAMSIZ)
			return usrxml_inv_arg(h, name, val);

		USRXML_userif[i] = val;
	} else if (name == "net") {
		if (val == "")
			return usrxml_ept_val(h, name);

		n = val;

		val = ipp_normalize(val);
		if (val == "")
			return usrxml_inv_arg(h, name, n);

		if ((h,val) in USRXML_nets)
			return usrxml_dup_net(h, name, n, USRXML_nets[h,val]);
		USRXML_nets[h,val] = i;

		n = i SUBSEP USRXML_usernets[i]++;
		USRXML_usernets[n] = val;

		USRXML__instance[h,"netid"] = n;
		USRXML__instance[h,"scope"] = USRXML__scope_net;

		usrxml_section_record_fileline(h, name SUBSEP n);
	} else if (name == "net6") {
		if (val == "")
			return usrxml_ept_val(h, name);

		n = val;

		val = ipp_normalize(val);
		if (val == "")
			return usrxml_inv_arg(h, name, n);

		if ((h,val) in USRXML_nets6)
			return usrxml_dup_net(h, name, n, USRXML_nets6[h,val]);
		USRXML_nets6[h,val] = i;

		n = i SUBSEP USRXML_usernets6[i]++;
		USRXML_usernets6[n] = val;

		USRXML__instance[h,"net6id"] = n;
		USRXML__instance[h,"scope"] = USRXML__scope_net6;

		usrxml_section_record_fileline(h, name SUBSEP n);
	} else if (name == "nat") {
		if (val == "")
			return usrxml_ept_val(h, name);

		n = val;

		val = ipp_normalize(val);
		if (val == "")
			return usrxml_inv_arg(h, name, n);

		if ((h,val) in USRXML_nats)
			return usrxml_dup_net(h, name, n, USRXML_nats[h,val]);
		USRXML_nats[h,val] = i;

		n = i SUBSEP USRXML_usernats[i]++;
		USRXML_usernats[n] = val;
	} else if (name == "nat6") {
		if (val == "")
			return usrxml_ept_val(h, name);

		n = val;

		val = ipp_normalize(val);
		if (val == "")
			return usrxml_inv_arg(h, name, n);

		if ((h,val) in USRXML_nats6)
			return usrxml_dup_net(h, name, n, USRXML_nats6[h,val]);
		USRXML_nats6[h,val] = i;

		n = i SUBSEP USRXML_usernats6[i]++;
		USRXML_usernats6[n] = val;
	} else if (name == "pipe") {
		if (val == "")
			return usrxml_ept_val(h, name);

		val = 0 + val;
		if (val <= 0)
			return usrxml_inv_arg(h, name, val);

		n = val - 1;
		if (n > USRXML_userpipe[i])
			return usrxml_inv_arg(h, name, val);

		if (val > USRXML_userpipe[i])
			USRXML_userpipe[i] = val;

		n = i SUBSEP n;
		USRXML_userpipe[n] = val;
		USRXML_userpipe[n,"qdisc"] = "";

		USRXML__instance[h,"pipeid"] = n;
		USRXML__instance[h,"scope"] = USRXML__scope_pipe;

		usrxml_section_record_fileline(h, name SUBSEP n);
	} else {
		return usrxml_syntax_err(h);
	}

	return USRXML_E_NONE;
}

function usrxml__scope_pipe(h, name, val,    n)
{
	n = USRXML__instance[h,"pipeid"];

	if (name == "/pipe") {
		if (val != "" && val != USRXML_userpipe[n])
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_user;
	} else if (name == "zone") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (!(val in USRXML__zone))
			return usrxml_inv_arg(h, name, val);

		USRXML_userpipe[n,name] = val;
	} else if (name == "dir" ) {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (!(val in USRXML__dir))
			return usrxml_inv_arg(h, name, val);

		USRXML_userpipe[n,name] = val;
	} else if (name == "bw") {
		if (val == "")
			return usrxml_ept_val(h, name);

		val = 0 + val;
		if (!val)
			return usrxml_inv_arg(h, name, val);

		USRXML_userpipe[n,name] = val;
	} else if (name == "qdisc") {
		if (val == "")
			return usrxml_ept_val(h, name);

		USRXML_userpipe[n,name] = val;
		USRXML_userpipe[n,"opts"] = 0;

		USRXML__instance[h,"scope"] = USRXML__scope_qdisc;

		usrxml_section_record_fileline(h, name SUBSEP n);
	} else {
		return usrxml_syntax_err(h);
	}

	return USRXML_E_NONE;
}

function usrxml__scope_qdisc(h, name, val,    n, o)
{
	n = USRXML__instance[h,"pipeid"];

	if (name == "/qdisc") {
		if (val != "" && val != USRXML_userpipe[n,"qdisc"])
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_pipe;
	} else if (name == "opts") {
		o = USRXML_userpipe[n,name]++;
		USRXML_userpipe[n,name,o] = val;
	} else {
		return usrxml_syntax_err(h);
	}

	return USRXML_E_NONE;
}

function usrxml__scope_net(h, name, val,    n, o, net)
{
	n = USRXML__instance[h,"netid"];
	net = USRXML_usernets[n];

	if (name == "/net") {
		if (val != "" && val != net)
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_user;

		return USRXML_E_NONE;
	} else if (name == "src") {
		if (val == "")
			return usrxml_ept_val(h, name);

		o = val;

		val = ipa_normalize(val);
		if (val == "")
			return usrxml_inv_arg(h, name, o);

		USRXML_usernets[n,name] = val;
	} else if (name == "via") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if ((n, "mac") in USRXML_usernets)
			return usrxml_inv_arg(h, name, val);

		o = val;

		val = ipa_normalize(val);
		if (val == "")
			return usrxml_inv_arg(h, name, o);

		USRXML_usernets[n,name] = val;
	} else if (name == "mac") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if ((n, "via") in USRXML_usernets)
			return usrxml_inv_arg(h, name, val);

		if (!is_ipp_host(net))
			return usrxml_inv_arg(h, name, val);

		USRXML_usernets[n,name] = val;
	} else if ((n,"has_opts") in USRXML_usernets) {
		return usrxml_syntax_err(h);
	} else {
		USRXML__instance[h,"scope"] = USRXML__scope_user;

		# Signal caller to lookup with new scope
		return 1;
	}

	USRXML_usernets[n,"has_opts"] = 1;
	return USRXML_E_NONE;
}

function usrxml__scope_net6(h, name, val,    n, o, net6)
{
	n = USRXML__instance[h,"net6id"];
	net6 = USRXML_usernets6[n];

	if (name == "/net6") {
		if (val != "" && val != net6)
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_user;

		return USRXML_E_NONE;
	} else if (name == "src") {
		if (val == "")
			return usrxml_ept_val(h, name);

		o = val;

		val = ipa_normalize(val);
		if (val == "")
			return usrxml_inv_arg(h, name, o);

		USRXML_usernets6[n,name] = val;
	} else if (name == "via") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if ((n, "mac") in USRXML_usernets6)
			return usrxml_inv_arg(h, name, val);

		o = val;

		val = ipa_normalize(val);
		if (val == "")
			return usrxml_inv_arg(h, name, o);

		USRXML_usernets6[n,name] = val;
	} else if (name == "mac") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if ((n, "via") in USRXML_usernets6)
			return usrxml_inv_arg(h, name, val);

		if (!is_ipp_host(net6))
			return usrxml_inv_arg(h, name, val);

		USRXML_usernets6[n,name] = val;
	} else if ((n,"has_opts") in USRXML_usernets6) {
		return usrxml_syntax_err(h);
	} else {
		USRXML__instance[h,"scope"] = USRXML__scope_user;

		# Signal caller to lookup with new scope
		return 1;
	}

	USRXML_usernets6[n,"has_opts"] = 1;
	return USRXML_E_NONE;
}

function run_usrxml_parser(h, line,    a, nfields, fn, val)
{
	val = usrxml_errno(h);
	if (val != USRXML_E_NONE)
		return val;

	val = USRXML__instance[h,"order"];
	if (val < USRXML__order_parse)
		return usrxml__seterrno(h, USRXML_E_API_ORDER);

	if (val > USRXML__order_parse) {
		# Destroy extra maps since they no longer valid
		__unbuild_usrxml_extra(h);

		# Reset order since data updated and needs to be revalidated
		USRXML__instance[h,"order"] = USRXML__order_parse;
	}

	if (USRXML__instance[h,"filename"] != FILENAME) {
		USRXML__instance[h,"filename"] = FILENAME;
		USRXML__instance[h,"linenum"] = 0;
	}
	USRXML__instance[h,"linenum"]++;

	if (line ~ /^[[:space:]]*$/)
		return USRXML_E_NONE;

	nfields = match(line, "^[[:space:]]*<([[:alpha:]_][[:alnum:]_]+)[[:space:]]+([^<>]+)>[[:space:]]*$", a);
	if (!nfields) {
		nfields = match(line, "^[[:space:]]*<(/[[:alpha:]_][[:alnum:]_]+)[[:space:]]*([^<>]*)>[[:space:]]*$", a);
		if (!nfields)
			return usrxml_syntax_err(h);
	}

	# name = a[1]
	# val  = a[2]

	do {
		val = USRXML__instance[h,"scope"];

		fn = "usrxml__scope_" USRXML__scope2name[val];
		val = @fn(h, a[1], a[2]);
	} while (val > 0);

	return val;
}

function build_usrxml_extra(h,    n, m, i, j, u, p, o)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	if (USRXML__instance[h,"order"] < USRXML__order_result)
		return usrxml__seterrno(h, USRXML_E_API_ORDER);

	# These are build when calling this helper
	# ----------------------------------------
	#
	# nifn = USRXML_ifnames[h]
	# ifid = [0 .. nifn - 1]
	# userif = USRXML_ifnames[h,ifid]
	# userid ...  = USRXML_ifusers[h,userif]
	# <user 'name'>
	#
	#   nnets = USRXML_nets[h]
	#   nid = [0 .. nnets - 1]
	#   <net 'cidr'>
	#     net = USRXML_nets[h,nid]
	#
	#   nnets6 = USRXML_nets6[h]
	#   nid6 = [0 .. nnets6 - 1]
	#   <net6 'cidr6'>
	#     net6 = USRXML_nets6[h,nid6]
	#
	#   nnats = USRXML_nats[h]
	#   tid = [0 .. nnats - 1]
	#   <nat 'cidr'>
	#     nat = USRXML_nats[h,tid]
	#
	#   nnats6 = USRXML_nats6[h]
	#   tid6 = [0 .. nnats6 - 1]
	#   <nat6 'cidr6'>
	#     nat6 = USRXML_nats6[h,tid6]
	#
	# </user>

	USRXML_ifnames[h] = 0;
	USRXML_nets[h] = 0;
	USRXML_nets6[h] = 0;
	USRXML_nats[h] = 0;
	USRXML_nats6[h] = 0;

	# user
	n = USRXML_usernames[h];
	for (u = 0; u < n; u++) {
		# h,userid
		i = h SUBSEP u;

		# if
		m = h SUBSEP USRXML_userif[i];
		if (m in USRXML_ifusers) {
			USRXML_ifusers[m] = USRXML_ifusers[m] " " u;
		} else {
			USRXML_ifusers[m] = u;
			o = USRXML_ifnames[h]++;
			USRXML_ifnames[h,o] = USRXML_userif[i];
		}

		# net
		o = USRXML_nets[h];
		m = USRXML_usernets[i];
		for (p = 0; p < m; p++)
			USRXML_nets[h,o + p] = USRXML_usernets[i,p];
		USRXML_nets[h] += m;

		# net6
		o = USRXML_nets6[h];
		m = USRXML_usernets6[i];
		for (p = 0; p < m; p++)
			USRXML_nets6[h,o + p] = USRXML_usernets6[i,p];
		USRXML_nets6[h] += m;

		# nat
		o = USRXML_nats[h];
		m = USRXML_usernats[i];
		for (p = 0; p < m; p++)
			USRXML_nats[h,o + p] = USRXML_usernats[i,p];
		USRXML_nats[h] += m;

		# nat6
		o = USRXML_nats6[h];
		m = USRXML_usernats6[i];
		for (p = 0; p < m; p++)
			USRXML_nats6[h,o + p] = USRXML_usernats6[i,p];
		USRXML_nats6[h] += m;
	}

	# Signal to fini_usrxml_parser() to release extra maps
	USRXML__instance[h,"extra"] = 1;

	return usrxml__seterrno(h, USRXML_E_NONE);
}

function __unbuild_usrxml_extra(h,    m, j, p, o, val)
{
	# Release extra maps allocated with build_usrxml_extra()
	if (USRXML__instance[h,"extra"]) {
		# if
		m = USRXML_ifnames[h];
		for (p = 0; p < m; p++) {
			# h,p
			j = h SUBSEP p;

			val = USRXML_ifnames[j];
			delete USRXML_ifnames[j];
			delete USRXML_ifusers[h,val];
		}
		delete USRXML_ifnames[h];

		# net
		m = USRXML_nets[h];
		for (p = 0; p < m; p++)
			delete USRXML_nets[h,p];
		delete USRXML_nets[h];

		# net6
		m = USRXML_nets6[h];
		for (p = 0; p < m; p++)
			delete USRXML_nets6[h,p];
		delete USRXML_nets6[h];

		# nat
		m = USRXML_nats[h];
		for (p = 0; p < m; p++)
			delete USRXML_nats[h,p];
		delete USRXML_nats[h];

		# nat6
		m = USRXML_nats6[h];
		for (p = 0; p < m; p++)
			delete USRXML_nats6[h,p];
		delete USRXML_nats6[h];

		delete USRXML__instance[h,"extra"];
	}
}

function unbuild_usrxml_extra(h)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;

	__unbuild_usrxml_extra(h);
}

#
# Print users entry in xml format
#

function print_usrxml_entry(h, userid,    n, m, i, j, u, p, o)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	if (USRXML__instance[h,"order"] < USRXML__order_result)
		return usrxml__seterrno(h, USRXML_E_API_ORDER);

	i = h SUBSEP userid;

	if (!(i in USRXML_usernames))
		return usrxml__seterrno(h, USRXML_E_NOENT);

	printf "<user %s>\n", USRXML_usernames[i];

	n = USRXML_userpipe[i];
	for (p = 0; p < n; p++) {
		j = i SUBSEP p;

		printf "\t<pipe %d>\n" \
		       "\t\t<zone %s>\n" \
		       "\t\t<dir %s>\n" \
		       "\t\t<bw %sKb>\n",
			USRXML_userpipe[j],
			USRXML_userpipe[j,"zone"],
			USRXML_userpipe[j,"dir"],
			USRXML_userpipe[j,"bw"];

		o = USRXML_userpipe[j,"qdisc"];
		if (o != "") {
			printf "\t\t<qdisc %s>\n", o;

			j = j SUBSEP "opts";
			m = USRXML_userpipe[j];
			for (o = 0; o < m; o++) {
				printf "\t\t\t<opts %s>\n",
					USRXML_userpipe[j,o];
			}

			printf "\t\t</qdisc>\n";
		}

		printf "\t</pipe>\n";
	}

	printf "\t<if %s>\n", USRXML_userif[i];

	n = USRXML_usernets[i];
	for (p = 0; p < n; p++) {
		j = i SUBSEP p;

		printf "\t<net %s>\n", USRXML_usernets[j];
		if ((j,"has_opts") in USRXML_usernets) {
			if ((j,"src") in USRXML_usernets)
				printf "\t\t<src %s>\n", USRXML_usernets[j,"src"];
			if ((j,"via") in USRXML_usernets)
				printf "\t\t<via %s>\n", USRXML_usernets[j,"via"];
			if ((j,"mac") in USRXML_usernets)
				printf "\t\t<mac %s>\n", USRXML_usernets[j,"mac"];
			printf "\t</net>\n";
		}
	}

	n = USRXML_usernets6[i];
	for (p = 0; p < n; p++) {
		j = i SUBSEP p;

		printf "\t<net6 %s>\n", USRXML_usernets6[j];
		if ((j,"has_opts") in USRXML_usernets6) {
			if ((j,"src") in USRXML_usernets6)
				printf "\t\t<src %s>\n", USRXML_usernets6[j,"src"];
			if ((j,"via") in USRXML_usernets6)
				printf "\t\t<via %s>\n", USRXML_usernets6[j,"via"];
			if ((j,"mac") in USRXML_usernets6)
				printf "\t\t<mac %s>\n", USRXML_usernets6[j,"mac"];
			printf "\t</net>\n";
		}
	}

	n = USRXML_usernats[i];
	for (p = 0; p < n; p++)
		printf "\t<nat %s>\n", USRXML_usernats[i,p];

	n = USRXML_usernats6[i];
	for (p = 0; p < n; p++)
		printf "\t<nat6 %s>\n", USRXML_usernats6[i,p];

	print "</user>\n";

	return usrxml__seterrno(h, USRXML_E_NONE);
}

#
# Print users entry in one line xml format
#

function print_usrxml_entry_oneline(h, userid,    n, m, i, j, u, p, o)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	if (USRXML__instance[h,"order"] < USRXML__order_result)
		return usrxml__seterrno(h, USRXML_E_API_ORDER);

	i = h SUBSEP userid;

	if (!(i in USRXML_usernames))
		return usrxml__seterrno(h, USRXML_E_NOENT);

	printf "<user %s>", USRXML_usernames[i];

	n = USRXML_userpipe[i];
	for (p = 0; p < n; p++) {
		j = i SUBSEP p;

		printf "<pipe %d><zone %s><dir %s><bw %sKb>",
			USRXML_userpipe[j],
			USRXML_userpipe[j,"zone"],
			USRXML_userpipe[j,"dir"],
			USRXML_userpipe[j,"bw"];

		o = USRXML_userpipe[j,"qdisc"];
		if (o != "") {
			printf "<qdisc %s>", o;

			j = j SUBSEP "opts";
			m = USRXML_userpipe[j];
			for (o = 0; o < m; o++) {
				printf "<opts %s>",
					USRXML_userpipe[j,o];
			}

			printf "</qdisc>";
		}

		printf "</pipe>";
	}

	printf "<if %s>", USRXML_userif[i];

	n = USRXML_usernets[i];
	for (p = 0; p < n; p++) {
		j = i SUBSEP p;

		printf "<net %s>", USRXML_usernets[j];
		if ((j,"has_opts") in USRXML_usernets) {
			if ((j,"src") in USRXML_usernets)
				printf "<src %s>", USRXML_usernets[j,"src"];
			if ((j,"via") in USRXML_usernets)
				printf "<via %s>", USRXML_usernets[j,"via"];
			if ((j,"mac") in USRXML_usernets)
				printf "<mac %s>", USRXML_usernets[j,"mac"];
			printf "</net>";
		}
	}

	n = USRXML_usernets6[i];
	for (p = 0; p < n; p++) {
		j = i SUBSEP p;

		printf "<net6 %s>", USRXML_usernets6[j];
		if ((j,"has_opts") in USRXML_usernets6) {
			if ((j,"src") in USRXML_usernets6)
				printf "<src %s>", USRXML_usernets6[j,"src"];
			if ((j,"via") in USRXML_usernets6)
				printf "<via %s>", USRXML_usernets6[j,"via"];
			if ((j,"mac") in USRXML_usernets6)
				printf "<mac %s>", USRXML_usernets6[j,"mac"];
			printf "</net6>";
		}
	}

	n = USRXML_usernats[i];
	for (p = 0; p < n; p++)
		printf "<nat %s>", USRXML_usernats[i,p];

	n = USRXML_usernats6[i];
	for (p = 0; p < n; p++)
		printf "<nat6 %s>", USRXML_usernats6[i,p];

	print "</user>";

	return usrxml__seterrno(h, USRXML_E_NONE);
}
