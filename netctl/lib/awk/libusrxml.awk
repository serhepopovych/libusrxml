#!/usr/bin/gawk -f

# Source USRXML database parsing library.
@include "@target@/netctl/lib/awk/libinet.awk"

#
# Parser descriptor handling helper routines.
#

function is_valid_usrxml_handle(h)
{
	return ("h",0 + h) in USRXML__instance;
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

	USRXML__instance["h",h] = 1;
	USRXML__instance["h"] = h;
	USRXML__instance["h","num"]++;

	return h;
}

function usrxml__free_handle(h)
{
	if (is_valid_usrxml_handle(h)) {
		delete USRXML__instance["h",h];
		if (--USRXML__instance["h","num"] <= 0) {
			delete USRXML__instance["h","num"];
			delete USRXML__instance["h"];
		} else {
			USRXML__instance["h"] = h - 1;
		}
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
			USRXML_users[userid] >"/dev/stderr"
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
# Misc helpers
#

function usrxml_dev_valid_name(name)
{
	if (name == "." || name == "..")
		return 0;
	# Network interface name length within [1 .. IFNAMSIZ - 1]
	# range, where IFNAMSIZ is 16 bytes.
	return name ~ "^[^[:space:]/:]{1,15}$";
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
	USRXML_E_GETLINE        = -204;
	# entry
	USRXML_E_NOENT	= -301;

	# Establish next (first) instance
	h = usrxml__alloc_handle();
	if (h < 0)
		return h;

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

	# FILENAME might be empty (e.g. when called directly from BEGIN{})
	if (FILENAME == "")
		FILENAME = "/dev/stdin";

	USRXML__instance[h,"filename"] = FILENAME;
	USRXML__instance[h,"linenum"] = 0;

	# USRXML__fileline[key,{ "file" | "line" },n]

	# Document format and parameters mapping
	# --------------------------------------
	#
	# When run_usrxml_parser() used after result_usrxml_parser() names of
	# modified user entries are put to USRXML_modusers[]:
	#
	# nmodusers = USRXML_modusers[h,"num"]
	# muserid = [0 .. nmodusers - 1]
	# username = USRXML_modusers[h,muserid]
	# muserid = USRXML_modusers[h,username,"id"]
	# free muserid = USRXML_modusers[h] + 1 || nmodusers++
	#
	# nusers = USRXML_users[h,"num"]
	# userid = [0 .. nusers - 1]
	# username = USRXML_users[h,userid]
	# userid = USRXML_users[h,username,"id"]
	# free userid = USRXML_users[h] + 1 || nusers++
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
	USRXML_users[h,"num"] = USRXML_users[h] = 0;

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
	n = USRXML_users[h,"num"];
	for (u = 0; u < n; u++) {
		# h,userid
		i = h SUBSEP u;

		# Skip holes entries
		if (!(i in USRXML_users))
			continue;

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

	# Build extra maps again if they exist before modification
	if (USRXML__instance[h,"modified"] > 1)
		val = build_usrxml_extra(h);
	else
		val = USRXML_E_NONE;

	return usrxml__seterrno(h, val);
}

function usrxml__map_add_val(h, val, map,    n, m, i, num)
{
	# h,val,"id"
	n = h SUBSEP val SUBSEP "id";

	if (n in map) {
		i = h SUBSEP map[n];
	} else {
		num = map[h,"num"];
		do {
			if (map[h] < num)
				m = map[h]++;
			else
				m = map[h] = map[h,"num"]++;
			i = h SUBSEP m;
		} while (i in map);
		map[n] = m;
		map[i] = val;
	}

	return i;
}

function usrxml__map_del_by_val(h, val, map,    n, id)
{
	# h,val,"id"
	n = h SUBSEP val SUBSEP "id";

	id = map[n];
	delete map[n];
	delete map[h,id];

	if (id < map[h])
		map[h] = id;

	# Not decrementing map[h,"num"]

	return id;
}

function usrxml__map_del_by_id(h, id, map,    n, val)
{
	# h,id
	n = h SUBSEP id;

	val = map[n];
	delete map[n];
	delete map[h,val,"id"];

	if (id < map[h])
		map[h] = id;

	# Not decrementing map[h,"num"]

	return val;
}

function usrxml__delete_map(h, i, map, umap,    m, j, p, val)
{
	m = umap[i];
	for (p = 0; p < m; p++) {
		# h,userid,id
		j = i SUBSEP p;

		val = umap[j];
		delete umap[j];
		# These are "net" and "net6" specific
		delete umap[j,"src"];
		delete umap[j,"via"];
		delete umap[j,"mac"];
		delete umap[j,"has_opts"];

		# duplicate detection map
		delete map[h,val];

		# "extra"
		usrxml__map_del_by_val(h, val, map);
	}
	delete umap[i];
}

function usrxml__delete_user(h, userid,    n, m, i, j, p, o, val)
{
	# h,userid
	i = h SUBSEP userid;

	val = USRXML_users[i];

	usrxml__map_del_by_val(h, val, USRXML_users);
	usrxml__map_del_by_val(h, val, USRXML_modusers);

	# pipe
	m = USRXML_userpipe[i];
	for (p = 0; p < m; p++) {
		# h,userid,pipeid
		j = i SUBSEP p;

		delete USRXML_userpipe[j];
		delete USRXML_userpipe[j,"zone"];
		delete USRXML_userpipe[j,"dir"];
		delete USRXML_userpipe[j,"bw"];

		delete USRXML_userpipe[j,"qdisc"];

		# h,userid,pipeid,opts
		j = j SUBSEP "opts";

		val = USRXML_userpipe[j];
		delete USRXML_userpipe[j];
		for (o = 0; o < val; o++)
			delete USRXML_userpipe[j,o];
	}
	delete USRXML_userpipe[i];

	# if
	val = USRXML_userif[i];
	delete USRXML_userif[i];

	# h,userif ("extra")
	j = h SUBSEP val;

	m = USRXML_ifusers[j];

	if (sub(" " val " ", " ", m) == 1 ||   # 1 x 3 == 1 3
	    sub(val " ", "", m)      == 1 ||   # x 2 3 == 2 3
	    sub(" " val, "", m)      == 1) {   # 1 2 x == 1 2
		USRXML_ifusers[j] = m;
	} else {
		delete USRXML_ifusers[j];
	}

	usrxml__map_del_by_val(h, val, USRXML_ifnames);

	# net
	usrxml__delete_map(h, i, USRXML_nets, USRXML_usernets);

	# net6
	usrxml__delete_map(h, i, USRXML_nets6, USRXML_usernets6);

	# nat
	usrxml__delete_map(h, i, USRXML_nats, USRXML_usernats);

	# nat6
	usrxml__delete_map(h, i, USRXML_nats6, USRXML_usernats6);
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
	n = USRXML_users[h,"num"];
	for (u = 0; u < n; u++) {
		# h,userid
		i = h SUBSEP u;

		# Skip holes entries
		if (!(i in USRXML_users))
			continue;

		usrxml_section_delete_fileline(h, "user" SUBSEP i);

		# pipe
		m = USRXML_userpipe[i];
		for (p = 0; p < m; p++) {
			# h,userid,pipeid
			j = i SUBSEP p;

			usrxml_section_delete_fileline(h, "pipe" SUBSEP j);
			usrxml_section_delete_fileline(h, "qdisc" SUBSEP j);
		}

		# net
		m = USRXML_usernets[i];
		for (p = 0; p < m; p++) {
			# h,userid,netid
			j = i SUBSEP p;

			usrxml_section_delete_fileline(h, "net" SUBSEP j);
		}

		# net6
		m = USRXML_usernets6[i];
		for (p = 0; p < m; p++) {
			# h,userid,net6id
			j = i SUBSEP p;

			usrxml_section_delete_fileline(h, "net6" SUBSEP j);
		}

		usrxml__delete_user(h, u);
	}
	delete USRXML_users[h,"num"];
	delete USRXML_users[h];

	delete USRXML__instance[h,"extra"];
	delete USRXML_ifnames[h,"num"];
	delete USRXML_ifnames[h];
	delete USRXML_nets[h,"num"];
	delete USRXML_nets[h];
	delete USRXML_nets6[h,"num"];
	delete USRXML_nets6[h];
	delete USRXML_nats[h,"num"];
	delete USRXML_nats[h];
	delete USRXML_nats6[h,"num"];
	delete USRXML_nats6[h];

	delete USRXML__instance[h,"modified"];
	delete USRXML_modusers[h,"num"];
	delete USRXML_modusers[h];

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

	# File name and line number
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

		if (USRXML__instance[h,"modified"])
			usrxml__map_add_val(h, val, USRXML_modusers);

		i = usrxml__map_add_val(h, val, USRXML_users);
		if (!(i in USRXML_userif)) {
			# New element allocated
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
		if (val != "" && val != USRXML_users[i])
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_none;
	} else if (name == "if") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (!usrxml_dev_valid_name(val))
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
		# Destroy modified users mapping since new changes will come
		usrxml__clear_modusers(h);

		# Signal to run_usrxml_parser() and it's callees to create
		# modified users mapping
		USRXML__instance[h,"modified"] = 1;

		# Signal if we have extra maps before and want to rebuild
		# them in result_usrxml_parser()
		USRXML__instance[h,"modified"] += !!USRXML__instance[h,"extra"];

		# Destroy extra maps since they no longer valid
		usrxml__unbuild_extra(h);

		# Reset order since data updated and needs to be revalidated
		USRXML__instance[h,"order"] = USRXML__order_parse;
	}

	# When called from main block with multiple files on command line
	# FILENAME is set each time to next file being processed
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

function usrxml__build_map(h, i, map, umap,    m, j, p, o, val)
{
	# i = h,userid

	o = map[h,"num"];
	m = umap[i];
	for (p = 0; p < m; p++) {
		val = umap[i,p];
		map[h,o] = val;
		map[h,val,"id"] = o++;
	}
	map[h,"num"] = o;
}

function build_usrxml_extra(h,    n, m, i, j, u, p, o, val)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	if (USRXML__instance[h,"order"] < USRXML__order_result)
		return usrxml__seterrno(h, USRXML_E_API_ORDER);

	# These are build when calling this helper
	# ----------------------------------------
	#
	# nifn = USRXML_ifnames[h,"num"]
	# ifid = [0 .. nifn - 1]
	# ifid = USRXML_ifnames[h,userif,"id"]
	# userif = USRXML_ifnames[h,ifid]
	# free ifid = USRXML_ifnames[h] + 1 || nifn++
	# userid ...  = USRXML_ifusers[h,userif]
	# <user 'name'>
	#
	#   nnets = USRXML_nets[h,"num"]
	#   nid = [0 .. nnets - 1]
	#   nid = USRXML_nets[h,net,"id"]
	#   free nid = USRXML_nets[h] + 1 || nnets++
	#   <net 'cidr'>
	#     net = USRXML_nets[h,nid]
	#
	#   nnets6 = USRXML_nets6[h,"num"]
	#   nid6 = [0 .. nnets6 - 1]
	#   nid6 = USRXML_nets6[h,net6,"id"]
	#   free nid6 = USRXML_nets6[h] + 1 || nnets6++
	#   <net6 'cidr6'>
	#     net6 = USRXML_nets6[h,nid6]
	#
	#   nnats = USRXML_nats[h,"num"]
	#   tid = [0 .. nnats - 1]
	#   tid = USRXML_nats[h,nat,"id"]
	#   free tid = USRXML_nats[h] + 1 || nnats++
	#   <nat 'cidr'>
	#     nat = USRXML_nats[h,tid]
	#
	#   nnats6 = USRXML_nats6[h,"num"]
	#   tid6 = [0 .. nnats6 - 1]
	#   tid6 = USRXML_nats6[h,nat6,"id"]
	#   free tid6 = USRXML_nats6[h] + 1 || nnats6++
	#   <nat6 'cidr6'>
	#     nat6 = USRXML_nats6[h,tid6]
	#
	# </user>

	# h,"num"
	i = h SUBSEP "num";

	USRXML_ifnames[i] = USRXML_ifnames[h] = 0;
	USRXML_nets[i]    = USRXML_nets[h]    = 0;
	USRXML_nets6[i]   = USRXML_nets6[h]   = 0;
	USRXML_nats[i]    = USRXML_nats[h]    = 0;
	USRXML_nats6[i]   = USRXML_nats6[h]   = 0;

	# user
	n = USRXML_users[i];
	for (u = 0; u < n; u++) {
		# h,userid
		i = h SUBSEP u;

		# Skip holes entries
		if (!(i in USRXML_users))
			continue;

		# if
		val = USRXML_userif[i];

		m = h SUBSEP val;
		if (m in USRXML_ifusers) {
			USRXML_ifusers[m] = USRXML_ifusers[m] " " u;
		} else {
			USRXML_ifusers[m] = u;

			usrxml__map_add_val(h, val, USRXML_ifnames);
		}

		# net
		usrxml__build_map(h, i, USRXML_nets, USRXML_usernets);

		# net6
		usrxml__build_map(h, i, USRXML_nets6, USRXML_usernets6);

		# nat
		usrxml__build_map(h, i, USRXML_nats, USRXML_usernats);

		# nat6
		usrxml__build_map(h, i, USRXML_nats6, USRXML_usernats6);
	}

	# Signal to fini_usrxml_parser() to release extra maps
	USRXML__instance[h,"extra"] = 1;

	return usrxml__seterrno(h, USRXML_E_NONE);
}

function usrxml__unbuild_map(h, map,    m, p)
{
	m = map[h];
	for (p = 0; p < m; p++)
		usrxml__map_del_by_id(h, p, map);
	delete map[h];
}

function usrxml__unbuild_extra(h,    m, p, val)
{
	# Release extra maps allocated with build_usrxml_extra()
	if (USRXML__instance[h,"extra"]) {
		# if
		m = USRXML_ifnames[h];
		for (p = 0; p < m; p++) {
			val = usrxml__map_del_by_id(h, p, USRXML_ifnames);
			delete USRXML_ifusers[h,val];
		}
		delete USRXML_ifnames[h];

		# net
		usrxml__unbuild_map(h, USRXML_nets);

		# net6
		usrxml__unbuild_map(h, USRXML_nets6);

		# nat
		usrxml__unbuild_map(h, USRXML_nats);

		# nat6
		usrxml__unbuild_map(h, USRXML_nats6);

		delete USRXML__instance[h,"extra"];
	}
}

function unbuild_usrxml_extra(h)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;

	usrxml__unbuild_extra(h);
}

function usrxml__clear_modusers(h,    n)
{
	if (USRXML__instance[h,"modified"]) {
		# user
		n = USRXML_modusers[h,"num"];
		for (u = 0; u < n; u++) {
			# Skip holes entries
			if (!((h,u) in USRXML_modusers))
				continue;

			usrxml__map_del_by_id(h, u, USRXML_modusers);
		}
		delete USRXML_modusers[h,"num"];
		delete USRXML_modusers[h];

		delete USRXML__instance[h,"modified"];
	}
}

function clear_usrxml_modusers(h)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;

	usrxml__clear_modusers(h);
}

#
# Print users entry in xml format
#

function print_usrxml_entry(h, userid, file,    n, m, i, j, u, p, o)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	if (USRXML__instance[h,"order"] < USRXML__order_result)
		return usrxml__seterrno(h, USRXML_E_API_ORDER);

	i = h SUBSEP userid;

	if (!(i in USRXML_users))
		return usrxml__seterrno(h, USRXML_E_NOENT);

	if (file == "")
		file = "/dev/stdout";

	printf "<user %s>\n", USRXML_users[i] >>file;

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
			USRXML_userpipe[j,"bw"] >>file;

		o = USRXML_userpipe[j,"qdisc"];
		if (o != "") {
			printf "\t\t<qdisc %s>\n", o >>file;

			j = j SUBSEP "opts";
			m = USRXML_userpipe[j];
			for (o = 0; o < m; o++)
				printf "\t\t\t<opts %s>\n",
					USRXML_userpipe[j,o] >>file;

			printf "\t\t</qdisc>\n" >>file;
		}

		printf "\t</pipe>\n" >>file;
	}

	printf "\t<if %s>\n", USRXML_userif[i] >>file;

	n = USRXML_usernets[i];
	for (p = 0; p < n; p++) {
		j = i SUBSEP p;

		printf "\t<net %s>\n", USRXML_usernets[j] >>file;
		if ((j,"has_opts") in USRXML_usernets) {
			if ((j,"src") in USRXML_usernets)
				printf "\t\t<src %s>\n",
					USRXML_usernets[j,"src"] >>file;
			if ((j,"via") in USRXML_usernets)
				printf "\t\t<via %s>\n",
					USRXML_usernets[j,"via"] >>file;
			if ((j,"mac") in USRXML_usernets)
				printf "\t\t<mac %s>\n",
					USRXML_usernets[j,"mac"] >>file;
			printf "\t</net>\n";
		}
	}

	n = USRXML_usernets6[i];
	for (p = 0; p < n; p++) {
		j = i SUBSEP p;

		printf "\t<net6 %s>\n", USRXML_usernets6[j] >>file;
		if ((j,"has_opts") in USRXML_usernets6) {
			if ((j,"src") in USRXML_usernets6)
				printf "\t\t<src %s>\n",
					USRXML_usernets6[j,"src"] >>file;
			if ((j,"via") in USRXML_usernets6)
				printf "\t\t<via %s>\n",
					USRXML_usernets6[j,"via"] >>file;
			if ((j,"mac") in USRXML_usernets6)
				printf "\t\t<mac %s>\n",
					USRXML_usernets6[j,"mac"] >>file;
			printf "\t</net>\n" >>file;
		}
	}

	n = USRXML_usernats[i];
	for (p = 0; p < n; p++)
		printf "\t<nat %s>\n", USRXML_usernats[i,p] >>file;

	n = USRXML_usernats6[i];
	for (p = 0; p < n; p++)
		printf "\t<nat6 %s>\n", USRXML_usernats6[i,p] >>file;

	print "</user>\n" >>file;

	# Callers should flush output buffers using fflush(file) to ensure
	# all pending data is written to a file or named pipe before quit.

	return usrxml__seterrno(h, USRXML_E_NONE);
}

function print_usrxml_entries(h, file,    n, u, o, stdout)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	stdout = "/dev/stdout"

	if (file == "")
		file = stdout;

	n = USRXML_users[h,"num"];
	for (u = 0; u < n; u++) {
		# Skip holes entries
		if (!((h,u) in USRXML_users))
			continue;

		o = print_usrxml_entry(h, u, file);
		if (o != USRXML_E_NONE)
			break;
	}

	fflush(file);

	if (file != stdout)
		close(file);

	return o;
}

#
# Print users entry in one line xml format
#

function print_usrxml_entry_oneline(h, userid, file,    n, m, i, j, u, p, o)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	if (USRXML__instance[h,"order"] < USRXML__order_result)
		return usrxml__seterrno(h, USRXML_E_API_ORDER);

	i = h SUBSEP userid;

	if (!(i in USRXML_users))
		return usrxml__seterrno(h, USRXML_E_NOENT);

	if (file == "")
		file = "/dev/stdout";

	printf "<user %s>", USRXML_users[i] >>file;

	n = USRXML_userpipe[i];
	for (p = 0; p < n; p++) {
		j = i SUBSEP p;

		printf "<pipe %d><zone %s><dir %s><bw %sKb>",
			USRXML_userpipe[j],
			USRXML_userpipe[j,"zone"],
			USRXML_userpipe[j,"dir"],
			USRXML_userpipe[j,"bw"] >>file;

		o = USRXML_userpipe[j,"qdisc"];
		if (o != "") {
			printf "<qdisc %s>", o >>file;

			j = j SUBSEP "opts";
			m = USRXML_userpipe[j];
			for (o = 0; o < m; o++)
				printf "<opts %s>",
					USRXML_userpipe[j,o] >>file;

			printf "</qdisc>" >>file;
		}

		printf "</pipe>" >>file;
	}

	printf "<if %s>", USRXML_userif[i] >>file;

	n = USRXML_usernets[i];
	for (p = 0; p < n; p++) {
		j = i SUBSEP p;

		printf "<net %s>", USRXML_usernets[j] >>file;
		if ((j,"has_opts") in USRXML_usernets) {
			if ((j,"src") in USRXML_usernets)
				printf "<src %s>",
					USRXML_usernets[j,"src"] >>file;
			if ((j,"via") in USRXML_usernets)
				printf "<via %s>",
					USRXML_usernets[j,"via"] >>file;
			if ((j,"mac") in USRXML_usernets)
				printf "<mac %s>",
					USRXML_usernets[j,"mac"] >>file;
			printf "</net>" >>file;
		}
	}

	n = USRXML_usernets6[i];
	for (p = 0; p < n; p++) {
		j = i SUBSEP p;

		printf "<net6 %s>", USRXML_usernets6[j] >>file;
		if ((j,"has_opts") in USRXML_usernets6) {
			if ((j,"src") in USRXML_usernets6)
				printf "<src %s>",
					USRXML_usernets6[j,"src"] >>file;
			if ((j,"via") in USRXML_usernets6)
				printf "<via %s>",
					USRXML_usernets6[j,"via"] >>file;
			if ((j,"mac") in USRXML_usernets6)
				printf "<mac %s>",
					USRXML_usernets6[j,"mac"] >>file;
			printf "</net6>" >>file;
		}
	}

	n = USRXML_usernats[i];
	for (p = 0; p < n; p++)
		printf "<nat %s>", USRXML_usernats[i,p] >>file;

	n = USRXML_usernats6[i];
	for (p = 0; p < n; p++)
		printf "<nat6 %s>", USRXML_usernats6[i,p] >>file;

	print "</user>" >>file;

	# Callers should flush output buffers using fflush(file) to ensure
	# all pending data is written to a file or named pipe before quit.

	return usrxml__seterrno(h, USRXML_E_NONE);
}

function print_usrxml_entries_oneline(h, file,    n, u, o, stdout)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	stdout = "/dev/stdout"

	if (file == "")
		file = stdout;

	n = USRXML_users[h,"num"];
	for (u = 0; u < n; u++) {
		# Skip holes entries
		if (!((h,u) in USRXML_users))
			continue;

		o = print_usrxml_entry_oneline(h, u, file);
		if (o != USRXML_E_NONE)
			break;
	}

	fflush(file);

	if (file != stdout)
		close(file);

	return o;
}

function load_usrxml_file(_h, file,    h, line, rc, ret, s_fn, stdin)
{
	stdin = "/dev/stdin";

	if (file == "")
		file = stdin;

	s_fn = FILENAME;
	FILENAME = file;

	if (is_valid_usrxml_handle(_h)) {
		h = _h;
	} else {
		h = init_usrxml_parser();
		if (h < 0) {
			FILENAME = s_fn;
			return h;
		}
		# Make sure that h != _h always
		_h = -1;
	}

	while ((rc = (getline line <FILENAME)) > 0) {
		ret = run_usrxml_parser(h, line);
		if (ret != USRXML_E_NONE)
			break;
	}

	if (file != stdin)
		close(file);

	if (rc < 0) {
		ret = usrxml__seterrno(USRXML_E_GETLINE);
	} else if (ret == USRXML_E_NONE) {
		# Commit result after each call so we can see
		# differences between loaded files
		ret = result_usrxml_parser(h);
		if (ret == USRXML_E_NONE) {
			FILENAME = s_fn;
			return h;
		}
	}

	if (h != _h)
		fini_usrxml_parser(h);

	FILENAME = s_fn;
	return ret;
}

function store_usrxml_file(h, file)
{
	print_usrxml_entries(h, file);
}
