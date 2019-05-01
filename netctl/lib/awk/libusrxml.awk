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

function usrxml__free_handle(h,    n)
{
	if (!is_valid_usrxml_handle(h))
		return -1;

	delete USRXML__instance["h",h];

	n = --USRXML__instance["h","num"];
	if (n <= 0) {
		delete USRXML__instance["h","num"];
		delete USRXML__instance["h"];
		n = 0;
	} else {
		USRXML__instance["h"] = h - 1;
	}

	return n;
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

function usrxml__clearerrno(h,    val)
{
	val = USRXML__instance[h,"errno"];
	USRXML__instance[h,"errno"] = USRXML_E_NONE;
	return val;
}

function usrxml_clearerrno(h)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;
	return usrxml__clearerrno(h);
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

function usrxml_dup_attr(h, section, value, userid,    ret)
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

function usrxml_section_delete_fileline(key,    n, i)
{
	n = USRXML__fileline[key];
	for (i = 0; i < n; i++) {
		delete USRXML__fileline[key,"file",i];
		delete USRXML__fileline[key,"line",i];
	}
	delete USRXML__fileline[key];
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

function usrxml__dup_attr(h, section)
{
	return usrxml_dup_attr(h, section["name"],
			       section["value"], section["userid"]);
}

function usrxml_section_dup_attr(h, _section, value, userid, key,    section)
{
	section["name"]   = _section;
	section["value"]  = value;
	section["userid"] = userid;

	return usrxml_section_fn_arg(h, section, key, "usrxml__dup_attr");
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

function declare_usrxml_consts()
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
	USRXML_E_EATLINE        = -205;
	# entry
	USRXML_E_NOENT	= -301;

	## Constants (internal, arrays get cleaned )

	# Tag scope
	USRXML__scope_error	= -1;
	USRXML__scope_none	= 0;
	USRXML__scope_user	= 1;
	USRXML__scope_pipe	= 2;
	USRXML__scope_qdisc	= 3;
	USRXML__scope_net	= 4;
	USRXML__scope_net6	= 5;

	USRXML__scope2name[USRXML__scope_error]	= "error";
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

	# Library public functions call order
	USRXML__order_none	= 0;
	USRXML__order_parse	= 1

	# Load/store flags
	USRXML_LOAD_SKIP_FAILED	= lshift(1, 0);

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
}

function init_usrxml_parser(    h)
{
	# Declare constants only once
	if (USRXML__instance["h","num"] == 0)
		declare_usrxml_consts();

	# Establish next (first) instance
	h = usrxml__alloc_handle();
	if (h < 0)
		return h;

	## Variables

	# USRXML__instance[] internal information about parser instance

	# Parse document first
	USRXML__instance[h,"order"] = USRXML__order_parse;

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
	#   nunets = USRXML_usernets[h,userid,"num"]
	#   netid = [0 .. nunets - 1]
	#   netid = USRXML_usernets[h,net,"id"]
	#   free netid = USRXML_usernets[h] + 1 || nunets++
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
	#   nunets6 = USRXML_usernets6[h,userid,"num"]
	#   netid6 = [0 .. nunets6 - 1]
	#   netid6 = USRXML_usernets6[h,net6,"id"]
	#   free netid6 = USRXML_usernets6[h] + 1 || nunets6++
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
	#   nunats = USRXML_usernats[h,userid,"num"]
	#   natid = [0 .. nunats - 1]
	#   natid = USRXML_usernats[h,nat,"id"]
	#   free natid = USRXML_usernats[h] + 1 || nunats++
	#   <nat 'cidr'>
	#     nat = USRXML_usernats[h,userid,natid]
	#
	#   nunats6 = USRXML_usernats6[h,userid,"num"]
	#   natid6 = [0 .. nunats6 - 1]
	#   natid6 = USRXML_usernats6[h,nat6,"id"]
	#   free natid6 = USRXML_usernats6[h] + 1 || nunats6++
	#   <nat6 'cidr6'>
	#     nat6 = USRXML_usernats6[h,userid,natid6]
	#
	# </user>

	# These are used to find duplicates at parse time
	# -----------------------------------------------
	#
	# nifn = USRXML_ifnames[h,"num"]
	# ifid = [0 .. nifn - 1]
	# ifid = USRXML_ifnames[h,userif,"id"]
	# userif = USRXML_ifnames[h,ifid]
	# userid ... = USRXML_ifnames[h,userif]
	# free ifid = USRXML_ifnames[h] + 1 || nifn++
	# <user 'name'>
	#
	#   nnets = USRXML_nets[h,"num"]
	#   nid = [0 .. nnets - 1]
	#   nid = USRXML_nets[h,net,"id"]
	#   free nid = USRXML_nets[h] + 1 || nnets++
	#   <net 'cidr'>
	#     net = USRXML_nets[h,nid]
	#     h,userid = USRXML_nets[h,net]
	#
	#   nnets6 = USRXML_nets6[h,"num"]
	#   nid6 = [0 .. nnets6 - 1]
	#   nid6 = USRXML_nets6[h,net6,"id"]
	#   free nid6 = USRXML_nets6[h] + 1 || nnets6++
	#   <net6 'cidr6'>
	#     net6 = USRXML_nets6[h,nid6]
	#     h,userid = USRXML_nets6[h,net6]
	#
	#   nnats = USRXML_nats[h,"num"]
	#   tid = [0 .. nnats - 1]
	#   tid = USRXML_nats[h,nat,"id"]
	#   free tid = USRXML_nats[h] + 1 || nnats++
	#   <nat 'cidr'>
	#     nat = USRXML_nats[h,tid]
	#     h,userid = USRXML_nats[h,nat]
	#
	#   nnats6 = USRXML_nats6[h,"num"]
	#   tid6 = [0 .. nnats6 - 1]
	#   tid6 = USRXML_nats6[h,nat6,"id"]
	#   free tid6 = USRXML_nats6[h] + 1 || nnats6++
	#   <nat6 'cidr6'>
	#     nat6 = USRXML_nats6[h,tid6]
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

function usrxml__map_add_val(h, attr, map, val,    n, m, i, num)
{
	# h,attr,"id"
	n = h SUBSEP attr SUBSEP "id";

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
		map[i] = attr;
		map[h,"cnt"]++;
	}

	if (val != SUBSEP)
		map[h,attr] = val;

	return i;
}

function usrxml__map_add_attr(h, attr, map)
{
	return usrxml__map_add_val(h, attr, map, SUBSEP);
}

function usrxml__map_del_by_attr(h, attr, map,    n, id, val)
{
	# h,attr,"id"
	n = h SUBSEP attr SUBSEP "id";

	if (!(n in map))
		return -1;

	id = map[n];
	delete map[n];
	delete map[h,id];
	delete map[h,attr];

	# Not decrementing map[h,"num"]

	if (--map[h,"cnt"] <= 0) {
		delete map[h,"cnt"];
		delete map[h,"num"];
		delete map[h];
	} else {
		if (id < map[h])
			map[h] = id;
	}

	return id;
}

function usrxml__map_del_by_id(h, id, map,    n, attr)
{
	# h,id
	n = h SUBSEP id;

	if (!(n in map))
		return "";

	attr = map[n];

	if (usrxml__map_del_by_attr(h, attr, map) < 0)
		return "";

	return attr;
}

function usrxml__map_copy(dh, dmap, sh, smap,    n, p, attr)
{
	# Not touching if source is empty
	if (!((sh,"num") in smap))
		return;

	n = smap[sh,"num"];
	if (!n)
		return;

	dmap[dh,"num"] = n;
	dmap[dh] = smap[sh];

	for (p = 0; p < n; p++) {
		# Skip holes entries
		if (!((sh,p) in smap))
			continue;

		attr = dmap[dh,p] = smap[sh,p];
		dmap[dh,attr,"id"] = p;         # optimization
		if ((sh,attr) in smap)
			dmap[dh,attr] = smap[sh,attr];
	}
}

function usrxml__map_add_umap_attr2map(h, userid, map, umap, name,    m, i, j, p, val)
{
	# h,userid
	i = h SUBSEP userid;

	m = umap[i,"num"];
	for (p = 0; p < m; p++) {
		# h,userid,id
		j = i SUBSEP p;

		# Skip holes entries
		if (!(j in umap))
			continue;

		val = umap[j];

		if (!((h,val) in map)) {
			usrxml__map_add_val(h, val, map, i);
			continue;
		}

		# name,h,userid,id
		j = name SUBSEP j;

		# Note that USRXML__instance[h,"userid"] must be set
		val = usrxml_section_dup_attr(h, name, val, map[h,val], j);
		if (val != USRXML_E_NONE)
			return val;
	}

	return USRXML_E_NONE;
}

function usrxml__map_del_umap_attr4map(h, userid, map, umap,    m, i, j, p, val)
{
	# h,userid
	i = h SUBSEP userid;

	m = umap[i,"num"];
	for (p = 0; p < m; p++) {
		# h,userid,id
		j = i SUBSEP p;

		# Skip holes entries
		if (!(j in umap))
			continue;

		val = umap[j];

		if (!((h,val) in map))
			continue;

		if (map[h,val] != i)
			continue;

		usrxml__map_del_by_attr(h, val, map);
	}
}

function usrxml__map_add_userif(h, userid,    o, val)
{
	usrxml__map_del_userif(h, userid);

	o = USRXML_userif[h,userid];

	# h,userif
	val = h SUBSEP o;

	if (val in USRXML_ifnames)
		val = USRXML_ifnames[val] " " userid;
	else
		val = userid;

	usrxml__map_add_val(h, o, USRXML_ifnames, val);

	return USRXML_E_NONE;
}

function usrxml__map_del_userif(h, userid,    m, o, val)
{
	o = USRXML_userif[h,userid];

	# h,userif
	m = h SUBSEP o;

	if (m in USRXML_ifnames) {
		val = USRXML_ifnames[m];

		if (sub(" " userid " ", " ", val) == 1 ||   # 1 x 3 == 1 3
		    sub(userid " ", "", val)      == 1 ||   # x 2 3 == 2 3
		    sub(" " userid, "", val)      == 1) {   # 1 2 x == 1 2
			USRXML_ifnames[m] = val;
		} else {
			usrxml__map_del_by_attr(h, o, USRXML_ifnames);
		}
	}
}

function usrxml__validate_if(h, userid,    i, val)
{
	# h,userid
	i = h SUBSEP userid;

	val = USRXML_userif[i];
	if (val == "")
		return usrxml_section_missing_arg(h, "if", "user" SUBSEP i);

	return USRXML_E_NONE;
}

function usrxml__validate_pipe(h, userid,    m, i, j, p, val, zones_dirs, zd_bits)
{
	# h,userid
	i = h SUBSEP userid;

	# pipe
	zones_dirs = 0;

	m = USRXML_userpipe[i];
	for (p = 0; p < m; p++) {
		# h,userid,pipeid
		j = i SUBSEP p;

		# Skip holes entries
		if (!(j in USRXML_userpipe))
			continue;

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

	return USRXML_E_NONE;
}

function usrxml__activate_user_by_id(h, userid,    val)
{
	# if
	val = usrxml__validate_if(h, userid);
	if (val != USRXML_E_NONE)
		return val;

	# pipe
	val = usrxml__validate_pipe(h, userid);
	if (val != USRXML_E_NONE)
		return val;

	# if
	val = usrxml__map_add_userif(h, userid);
	if (val != USRXML_E_NONE)
		return val;

	# net
	val = usrxml__map_add_umap_attr2map(h, userid, USRXML_nets,
					    USRXML_usernets, "net");
	if (val != USRXML_E_NONE)
		return val;

	# net6
	val = usrxml__map_add_umap_attr2map(h, userid, USRXML_nets6,
					    USRXML_usernets6, "net6");
	if (val != USRXML_E_NONE)
		return val;

	# nat
	val = usrxml__map_add_umap_attr2map(h, userid, USRXML_nats,
					    USRXML_usernats, "nat");
	if (val != USRXML_E_NONE)
		return val;

	# nat6
	val = usrxml__map_add_umap_attr2map(h, userid, USRXML_nats6,
					    USRXML_usernats6, "nat6");
	if (val != USRXML_E_NONE)
		return val;

	return USRXML_E_NONE;
}

function usrxml__deactivate_user_by_id(h, userid,    val)
{
	# if
	val = usrxml__validate_if(h, userid);
	if (val != USRXML_E_NONE)
		return val;

	# pipe
	val = usrxml__validate_pipe(h, userid);
	if (val != USRXML_E_NONE)
		return val;

	# if
	usrxml__map_del_userif(h, userid);
	# net
	usrxml__map_del_umap_attr4map(h, userid, USRXML_nets, USRXML_usernets);
	# net6
	usrxml__map_del_umap_attr4map(h, userid, USRXML_nets6, USRXML_usernets6);
	# nat
	usrxml__map_del_umap_attr4map(h, userid, USRXML_nats, USRXML_usernats);
	# nat6
	usrxml__map_del_umap_attr4map(h, userid, USRXML_nats6, USRXML_usernats6);

	return USRXML_E_NONE;
}

function usrxml__copy_user_net(i_dst, i_src, umap,    n, p, j_dst, j_src)
{
	usrxml__map_copy(i_dst, umap, i_src, umap);

	n = umap[i_src,"num"];
	for (p = 0; p < n; p++) {
		# h,userid,netid
		j_src = i_src SUBSEP p;

		# Skip holes entries
		if (!(j_src in umap))
			continue;

		if ((j_src,"has_opts") in umap) {
			# h,userid,subid,netid
			j_dst = i_dst SUBSEP p;

			umap[j_dst,"has_opts"] = umap[j_src,"has_opts"];

			if ((j_src,"src") in umap)
				umap[j_dst,"src"] = umap[j_src,"src"];
			if ((j_src,"via") in umap)
				umap[j_dst,"via"] = umap[j_src,"via"];
			if ((j_src,"mac") in umap)
				umap[j_dst,"mac"] = umap[j_src,"mac"];
		}
	}
}

function usrxml__copy_user(dh, sh, username,    n, m, p, o, i_dst, i_src, j_dst, j_src)
{
	if (dh == sh)
		return;

	# sh,userid
	i_src = sh SUBSEP USRXML_users[sh,username,"id"];

	# user
	i_dst = usrxml__map_add_attr(dh, USRXML_users[i_src], USRXML_users);

	if ((i_src,"inactive") in USRXML_users)
		USRXML_users[i_dst,"inactive"] = USRXML_users[i_src,"inactive"];

	# pipe
	n = USRXML_userpipe[i_src];
	USRXML_userpipe[i_dst] = n;

	for (p = 0; p < n; p++) {
		# sh,userid,pipeid
		j_src = i_src SUBSEP p;

		# Skip holes entries
		if (!(j_src in USRXML_userpipe))
			continue;

		# dh,userid,pipeid
		j_dst = i_dst SUBSEP p;

		USRXML_userpipe[j_dst] = USRXML_userpipe[j_src];
		USRXML_userpipe[j_dst,"zone"] = USRXML_userpipe[j_src,"zone"];
		USRXML_userpipe[j_dst,"dir"] = USRXML_userpipe[j_src,"dir"];
		USRXML_userpipe[j_dst,"bw"] = USRXML_userpipe[j_src,"bw"];

		o = USRXML_userpipe[j_src,"qdisc"];
		USRXML_userpipe[j_dst,"qdisc"] = o;

		if (o != "") {
			# sh,userid,pipeid,"opts"
			j_src = j_src SUBSEP "opts";
			# dh,userid,pipeid,"opts"
			j_dst = j_dst SUBSEP "opts";

			m = USRXML_userpipe[j_src];
			USRXML_userpipe[j_dst] = m;

			for (o = 0; o < m; o++)
				USRXML_userpipe[j_dst,o] = USRXML_userpipe[j_src,o];
		}
	}

	# if
	USRXML_userif[i_dst] = USRXML_userif[i_src];

	# net
	usrxml__copy_user_net(i_dst, i_src, USRXML_usernets);
	# net6
	usrxml__copy_user_net(i_dst, i_src, USRXML_usernets6);

	# nat
	usrxml__map_copy(i_dst, USRXML_usernats, i_src, USRXML_usernats);
	# nat6
	usrxml__map_copy(i_dst, USRXML_usernats6, i_src, USRXML_usernats6);
}

function usrxml__delete_qdisc(n,    m, p)
{
	# n = h,userid,pipeid

	usrxml_section_delete_fileline("qdisc" SUBSEP n);

	delete USRXML_userpipe[n,"qdisc"];

	# h,userid,pipeid,opts
	n = n SUBSEP "opts";

	m = USRXML_userpipe[n];
	for (p = 0; p < m; p++)
		delete USRXML_userpipe[n,p];
	delete USRXML_userpipe[n];
}

function usrxml__delete_pipe(n)
{
	# n = h,userid,pipeid

	usrxml__delete_qdisc(n);

	usrxml_section_delete_fileline("pipe" SUBSEP n);

	delete USRXML_userpipe[n];
	delete USRXML_userpipe[n,"zone"];
	delete USRXML_userpipe[n,"dir"];
	delete USRXML_userpipe[n,"bw"];
}

function usrxml__delete_if(i, map,    a, h, userid)
{
	# i = h,userid
	split(i, a, SUBSEP);

	h = a[1];
	userid = a[2];

	if (isarray(map))
		usrxml__map_del_userif(h, userid);

	delete USRXML_userif[i];
}

function usrxml__delete_map(i, val, map, umap, name,    a, n, h, id)
{
	# h,userid,id,"id"
	n = i SUBSEP val SUBSEP "id";

	if (!(n in umap))
		return;

	# i = h,userid
	split(i, a, SUBSEP);

	h = a[1];
	id = a[2];

	if (isarray(map) && ((h,val) in map) && map[h,val] == i)
		usrxml__map_del_by_attr(h, val, map);

	id = umap[n];

	# h,userid,id
	n = i SUBSEP id;

	usrxml_section_delete_fileline(name SUBSEP n);

	# These are "net" and "net6" specific
	delete umap[n,"src"];
	delete umap[n,"via"];
	delete umap[n,"mac"];
	delete umap[n,"has_opts"];

	usrxml__map_del_by_attr(i, val, umap);
}

function usrxml__delete_maps(i, map, umap, name,    m, j, p)
{
	# i = h,userid

	m = umap[i,"num"];
	for (p = 0; p < m; p++) {
		# h,userid,id
		j = i SUBSEP p;

		# Skip holes entries
		if (!(j in umap))
			continue;

		usrxml__delete_map(i, umap[j], "", umap, name);
	}
	# Remove in case of umap[i,"num"] is not defined (e.g. no <net6> tags)
	delete umap[i,"num"];
}

function usrxml__delete_user(h, username, subid,    n, m, i, p, userid)
{
	if (subid != "")
		h = h SUBSEP subid;

	userid = USRXML_users[h,username,"id"];

	# h,userid
	i = h SUBSEP userid;

	# user
	usrxml_section_delete_fileline("user" SUBSEP i);

	usrxml__map_del_by_attr(h, username, USRXML_users);

	delete USRXML_users[i,"inactive"];

	# pipe
	m = USRXML_userpipe[i];
	for (p = 0; p < m; p++) {
		# h,userid,pipeid
		n = i SUBSEP p;

		usrxml__delete_pipe(n);
	}
	delete USRXML_userpipe[i];

	# if
	usrxml__delete_if(i);
	# net
	usrxml__delete_maps(i, USRXML_nets, USRXML_usernets, "net");
	# net6
	usrxml__delete_maps(i, USRXML_nets6, USRXML_usernets6, "net6");
	# nat
	usrxml__delete_maps(i, USRXML_nats, USRXML_usernats, "nat");
	# nat6
	usrxml__delete_maps(i, USRXML_nats6, USRXML_usernats6, "nat6");
}

function usrxml__delete_user_by_id(h, userid,    n)
{
	# h,userid
	n = h SUBSEP userid;

	# Skip holes entries
	if (!(n in USRXML_users))
		return;

	# if
	usrxml__map_del_userif(h, userid);

	# net
	usrxml__map_del_umap_attr4map(h, userid, USRXML_nets, USRXML_usernets);
	# net6
	usrxml__map_del_umap_attr4map(h, userid, USRXML_nets6, USRXML_usernets6);
	# nat
	usrxml__map_del_umap_attr4map(h, userid, USRXML_nats, USRXML_usernats);
	# nat6
	usrxml__map_del_umap_attr4map(h, userid, USRXML_nats6, USRXML_usernats6);

	usrxml__delete_user(h, USRXML_users[n], "");
}

function usrxml__delete_user_by_name(h, username,    n)
{
	# h,username,"id"
	n = h SUBSEP username SUBSEP "id";

	# Skip holes entries
	if (!(n in USRXML_users))
		return;

	usrxml__delete_user_by_id(h, USRXML_users[n]);
}

function usrxml__username(h, username,    userid)
{
	if (username != "")
		return username;

	userid = USRXML__instance[h,"userid"];
	if (userid != "" && (userid in USRXML_users))
		username = USRXML_users[userid];

	return username;
}

function usrxml__save_user(h, username)
{
	usrxml__copy_user(h SUBSEP "orig", h, username);
}

function usrxml__restore_user(h, username,    userid)
{
	username = usrxml__username(h, username);
	if (username == "")
		return;

	userid = USRXML_users[h,username,"id"];

	usrxml__delete_user_by_id(h, userid);

	if ((h,"orig",userid) in USRXML_users) {
		usrxml__copy_user(h, h SUBSEP "orig", username);
		usrxml__delete_user(h, username, "orig");

		if (!((h,userid,"inactive") in USRXML_users))
			usrxml__activate_user_by_id(h, userid);
	}
}

function usrxml__cleanup_user(h, username)
{
	username = usrxml__username(h, username);
	if (username == "")
		return;

	usrxml__delete_user(h, username, "orig");
}

#
# Destroy XML document parser instance.
# This is usually called from END{} section.
#

function release_usrxml_consts()
{
	## Constants (internal, arrays get cleaned)

	delete USRXML__scope2name;

	# Valid "zone" values
	delete USRXML__zone;

	# Valid "dir" values
	delete USRXML__dir;

	# Zone and direction names to mask mapping
	delete zone_dir_bits;
}

function fini_usrxml_parser(h,    n, u)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;

	# Disable library functions at all levels
	delete USRXML__instance[h,"order"];

	# Cleanup saved user if exists
	usrxml__cleanup_user(h, "");

	# user
	n = USRXML_users[h,"num"];
	for (u = 0; u < n; u++)
		usrxml__delete_user_by_id(h, u);
	delete USRXML_users[h,"num"];

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

	if (usrxml__free_handle(h) == 0)
		release_usrxml_consts();

	return USRXML_E_NONE;
}

#
# Parse and validate XML document.
#

function usrxml__scope_error(h, sign, name, val)
{
	# Skip all lines until new user entry on error

	if (name == "user") {
		USRXML__instance[h,"scope"] = USRXML__scope_none;

		# Signal caller to lookup with new scope
		return 1;
	}

	return USRXML_E_EATLINE;
}

function usrxml__scope_none(h, sign, name, val,    n, i)
{
	if (name == "user") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (sign > 0) {
			i = usrxml__map_add_attr(h, val, USRXML_users);
			if (i in USRXML_userif) {
				usrxml__save_user(h, val);
			} else {
				# New element allocated
				USRXML_userif[i] = "";
			}

			USRXML__instance[h,"userid"] = i;
			USRXML__instance[h,"scope"] = USRXML__scope_user;

			usrxml_section_record_fileline(h, name SUBSEP i);
		} else {
			usrxml__delete_user_by_name(h, val);
		}
	} else {
		return usrxml_syntax_err(h);
	}

	return USRXML_E_NONE;
}

function usrxml__scope_user(h, sign, name, val,    n, i)
{
	i = USRXML__instance[h,"userid"];

	if (name == "/user") {
		n = USRXML_users[i];
		if (val != "" && val != n)
			return usrxml_inv_arg(h, name, val);

		n = USRXML_users[h,n,"id"];

		if ((i,"inactive") in USRXML_users)
			n = usrxml__deactivate_user_by_id(h, n);
		else
			n = usrxml__activate_user_by_id(h, n);

		if (n != USRXML_E_NONE)
			return n;

		USRXML__instance[h,"scope"] = USRXML__scope_none;

		# We can't return > 0 here as this will collide with parse retry
		return i;
	} else if (name == "if") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (!usrxml_dev_valid_name(val))
			return usrxml_inv_arg(h, name, val);

		n = USRXML_userif[i];

		if (sign > 0) {
			if (n != val) {
				if (n != "")
					return usrxml_dup_arg(h, name);
				USRXML_userif[i] = val;
			}
		} else {
			if (n != "") {
				if (n != val)
					return usrxml_inv_arg(h, name, val);
				usrxml__delete_if(i, USRXML_ifnames);
				USRXML_userif[i] = "";
			}
		}
	} else if (name == "net") {
		if (val == "")
			return usrxml_ept_val(h, name);

		n = val;

		val = ipp_normalize(val, "4");
		if (val == "")
			return usrxml_inv_arg(h, name, n);

		if (sign > 0) {
			n = usrxml__map_add_attr(i, val, USRXML_usernets);

			USRXML__instance[h,"netid"] = n;
			USRXML__instance[h,"scope"] = USRXML__scope_net;

			usrxml_section_record_fileline(h, name SUBSEP n);
		} else {
			usrxml__delete_map(i, val, USRXML_nets,
					   USRXML_usernets, name);
		}
	} else if (name == "net6") {
		if (val == "")
			return usrxml_ept_val(h, name);

		n = val;

		val = ipp_normalize(val, "6");
		if (val == "")
			return usrxml_inv_arg(h, name, n);

		if (sign > 0) {
			n = usrxml__map_add_attr(i, val, USRXML_usernets6);

			USRXML__instance[h,"net6id"] = n;
			USRXML__instance[h,"scope"] = USRXML__scope_net6;

			usrxml_section_record_fileline(h, name SUBSEP n);
		} else {
			usrxml__delete_map(i, val, USRXML_nets6,
					   USRXML_usernets6, name);
		}
	} else if (name == "nat") {
		if (val == "")
			return usrxml_ept_val(h, name);

		n = val;

		val = ipp_normalize(val, "4");
		if (val == "")
			return usrxml_inv_arg(h, name, n);

		if (sign > 0) {
			n = usrxml__map_add_attr(i, val, USRXML_usernats);

			usrxml_section_record_fileline(h, name SUBSEP n);
		} else {
			usrxml__delete_map(i, val, USRXML_nats,
					   USRXML_usernats, name);
		}
	} else if (name == "nat6") {
		if (val == "")
			return usrxml_ept_val(h, name);

		n = val;

		val = ipp_normalize(val, "6");
		if (val == "")
			return usrxml_inv_arg(h, name, n);

		if (sign > 0) {
			n = usrxml__map_add_attr(i, val, USRXML_usernats6);

			usrxml_section_record_fileline(h, name SUBSEP n);
		} else {
			usrxml__delete_map(i, val, USRXML_nats6,
					   USRXML_usernats6, name);
		}
	} else if (name == "pipe") {
		if (val == "")
			return usrxml_ept_val(h, name);

		val = 0 + val;
		if (val <= 0)
			return usrxml_inv_arg(h, name, val);

		n = val - 1;

		if (sign > 0) {
			if (n > USRXML_userpipe[i])
				return usrxml_inv_arg(h, name, val);

			if (val > USRXML_userpipe[i])
				USRXML_userpipe[i] = val;

			# h,userid,pipeid
			n = i SUBSEP n;

			USRXML_userpipe[n] = val;
			USRXML_userpipe[n,"qdisc"] = "";

			USRXML__instance[h,"pipeid"] = n;
			USRXML__instance[h,"scope"] = USRXML__scope_pipe;

			usrxml_section_record_fileline(h, name SUBSEP n);
		} else {
			if (n < USRXML_userpipe[i]) {
				# h,userid,pipeid
				n = i SUBSEP n;

				usrxml__delete_pipe(n);
			}
		}
	} else if (name == "inactive") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (sign > 0) {
			if (val == "yes")
				USRXML_users[i,"inactive"] = 1;
			else if (val == "no")
				delete USRXML_users[i,"inactive"];
			else
				return usrxml_inv_arg(h, name, val);
		} else {
			delete USRXML_users[i,"inactive"];
		}
	} else {
		return usrxml_syntax_err(h);
	}

	return USRXML_E_NONE;
}

function usrxml__scope_pipe(h, sign, name, val,    n)
{
	n = USRXML__instance[h,"pipeid"];

	if (name == "/pipe") {
		if (val != "" && val != USRXML_userpipe[n])
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_user;

		return USRXML_E_NONE;
	} else if (name == "zone") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (!(val in USRXML__zone))
			return usrxml_inv_arg(h, name, val);
	} else if (name == "dir" ) {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (!(val in USRXML__dir))
			return usrxml_inv_arg(h, name, val);
	} else if (name == "bw") {
		if (val == "")
			return usrxml_ept_val(h, name);

		val = 0 + val;
		if (!val)
			return usrxml_inv_arg(h, name, val);
	} else if (name == "qdisc") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (sign > 0) {
			USRXML_userpipe[n,"opts"] = 0;

			USRXML__instance[h,"scope"] = USRXML__scope_qdisc;

			usrxml_section_record_fileline(h, name SUBSEP n);
		} else {
			usrxml__delete_qdisc(n);
		}

		return USRXML_E_NONE;
	} else {
		return usrxml_syntax_err(h);
	}

	if (sign > 0) {
		USRXML_userpipe[n,name] = val;
	} else {
		delete USRXML_userpipe[n,name];
	}

	return USRXML_E_NONE;
}

function usrxml__scope_qdisc(h, sign, name, val,    n, o)
{
	n = USRXML__instance[h,"pipeid"];

	if (name == "/qdisc") {
		if (val != "" && val != USRXML_userpipe[n,"qdisc"])
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_pipe;
	} else if (name == "opts") {
		if (sign <= 0)
			return usrxml_inv_arg(h, "-" name, val);

		o = USRXML_userpipe[n,name]++;
		USRXML_userpipe[n,name,o] = val;
	} else {
		return usrxml_syntax_err(h);
	}

	return USRXML_E_NONE;
}

function usrxml__scope_nets(h, sign, name, val, umap, s,    n, o, net)
{
	n = USRXML__instance[h,"net" s "id"];
	net = umap[n];

	if (name == "/net" s) {
		if (val != "" && val != net)
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_user;

		if (umap[n,"has_opts"] <= 0)
			delete umap[n,"has_opts"];

		return USRXML_E_NONE;
	} else if (name == "src") {
		if (val == "")
			return usrxml_ept_val(h, name);

		o = val;

		val = ipa_normalize(val, (s == "") ? "4" : "6");
		if (val == "")
			return usrxml_inv_arg(h, name, o);
	} else if (name == "via") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if ((n, "mac") in umap)
			return usrxml_inv_arg(h, name, val);

		o = val;

		val = ipa_normalize(val, (s == "") ? "4" : "6");
		if (val == "")
			return usrxml_inv_arg(h, name, o);
	} else if (name == "mac") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if ((n, "via") in umap)
			return usrxml_inv_arg(h, name, val);

		if (!is_ipp_host(net, (s == "") ? "4" : "6"))
			return usrxml_inv_arg(h, name, val);
	} else if ((n,"has_opts") in umap) {
		return usrxml_syntax_err(h);
	} else {
		USRXML__instance[h,"scope"] = USRXML__scope_user;

		# Signal caller to lookup with new scope
		return 1;
	}

	if (sign > 0) {
		umap[n,name] = val;
	} else {
		if ((n,name) in umap) {
			delete umap[n,name];
		} else {
			sign = 0;
		}
	}
	umap[n,"has_opts"] += sign;

	return USRXML_E_NONE;
}

function usrxml__scope_net(h, sign, name, val)
{
	return usrxml__scope_nets(h, sign, name, val, USRXML_usernets, "");
}

function usrxml__scope_net6(h, sign, name, val)
{
	return usrxml__scope_nets(h, sign, name, val, USRXML_usernets6, "6");
}

function run_usrxml_parser(h, line, cb, data,    a, n, fn, sign, name, val, ret, s_rs, s_rl)
{
	val = usrxml_errno(h);
	if (val != USRXML_E_NONE)
		return val;

	val = USRXML__instance[h,"order"];
	if (val < USRXML__order_parse)
		return usrxml__seterrno(h, USRXML_E_API_ORDER);

	if (val > USRXML__order_parse)
		USRXML__instance[h,"order"] = USRXML__order_parse;

	# When called from main block with multiple files on command line
	# FILENAME is set each time to next file being processed
	if (USRXML__instance[h,"filename"] != FILENAME) {
		USRXML__instance[h,"filename"] = FILENAME;
		USRXML__instance[h,"linenum"] = 0;
	}
	USRXML__instance[h,"linenum"]++;

	if (line ~ /^[[:space:]]*$/)
		return USRXML_E_NONE;

	# These are modified by match(): save them
	s_rs = RSTART;
	s_rl = RLENGTH;

	n = match(line, "^[[:space:]]*<(|[/+-])([[:alpha:]_][[:alnum:]_]+)(|[[:space:]]+[^<>]+)>[[:space:]]*$", a);

	RSTART = s_rs;
	RLENGTH = s_rl;

	if (!n)
		return usrxml_syntax_err(h);

	sign = a[1];
	name = a[2];
	val  = a[3];

	if (sign == "/") {        # close
		name = sign name;
		sign = 0;
	} else if (sign == "-") { # del
		sign = -1;
	} else { # sign == "+"    # add
		sign = 1;
	}

	sub("[[:space:]]+", "", val);

	do {
		n = USRXML__instance[h,"scope"];

		fn = "usrxml__scope_" USRXML__scope2name[n];
		ret = @fn(h, sign, name, val);

		# userid
		if (sub(h SUBSEP, "", ret) == 1) {
			# Make sure we always return value > 0
			if (cb != "")
				ret = @cb(h, ret, data);
			else
				ret++;
			break;
		}
		# Parse error in the middle of operation: skip lines until valid
		if (ret < 0) {
			if (ret == USRXML_E_EATLINE)
				return USRXML_E_NONE;
			USRXML__instance[h,"scope"] = USRXML__scope_error;
			break;
		}
	} while (ret > 0);

	if (ret < 0)
		usrxml__restore_user(h, "");
	else if (ret > 0)
		usrxml__cleanup_user(h, "");

	return ret;
}

#
# Print users entry in oneline usrxml format
#

function usrxml__print_maps(i, umap, name, file, s1, s2,    n, j, p)
{
	n = umap[i,"num"];
	for (p = 0; p < n; p++) {
		# h,userid,netid
		j = i SUBSEP p;

		# Skip holes entries
		if (!(j in umap))
			continue;

		printf s1 "<%s %s>" s2, name, umap[j] >>file;
		if ((j,"has_opts") in umap) {
			if ((j,"src") in umap)
				printf s1 s1 "<src %s>" s2,
					umap[j,"src"] >>file;
			if ((j,"via") in umap)
				printf s1 s1 "<via %s>" s2,
					umap[j,"via"] >>file;
			if ((j,"mac") in umap)
				printf s1 s1 "<mac %s>" s2,
					umap[j,"mac"] >>file;
			printf s1 "</%s>" s2, name;
		}
	}
}

function print_usrxml_entry_oneline(h, userid, file, s1, s2,    n, m, i, j, p, o)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	i = h SUBSEP userid;

	if (!(i in USRXML_users))
		return usrxml__seterrno(h, USRXML_E_NOENT);

	if (file == "")
		file = "/dev/stdout";

	# user
	printf "<user %s>" s2, USRXML_users[i] >>file;

	# inactive
	if ((i,"inactive") in USRXML_users)
		printf s1 "<inactive yes>" s2 >>file;

	# pipe
	n = USRXML_userpipe[i];
	for (p = 0; p < n; p++) {
		# h,userid,pipeid
		j = i SUBSEP p;

		# Skip holes entries
		if (!(j in USRXML_userpipe))
			continue;

		printf s1 "<pipe %d>" s2 \
		       s1 s1 "<zone %s>" s2 \
		       s1 s1 "<dir %s>" s2 \
		       s1 s1 "<bw %sKb>" s2,
			USRXML_userpipe[j],
			USRXML_userpipe[j,"zone"],
			USRXML_userpipe[j,"dir"],
			USRXML_userpipe[j,"bw"] >>file;

		o = USRXML_userpipe[j,"qdisc"];
		if (o != "") {
			printf s1 s1 "<qdisc %s>" s2, o >>file;

			j = j SUBSEP "opts";
			m = USRXML_userpipe[j];
			for (o = 0; o < m; o++)
				printf s1 s1 s1 "<opts %s>" s2,
					USRXML_userpipe[j,o] >>file;

			printf s1 s1 "</qdisc>" s2 >>file;
		}

		printf s1 "</pipe>" s2 >>file;
	}

	# if
	printf s1 "<if %s>" s2, USRXML_userif[i] >>file;

	# net
	usrxml__print_maps(i, USRXML_usernets, "net", file, s1, s2);
	# net6
	usrxml__print_maps(i, USRXML_usernets6, "net6", file, s1, s2);
	# nat
	usrxml__print_maps(i, USRXML_usernats, "nat", file, s1, s2);
	# nat6
	usrxml__print_maps(i, USRXML_usernats6, "nat6", file, s1, s2);

	print "</user>" s2 >>file;

	# Callers should flush output buffers using fflush(file) to ensure
	# all pending data is written to a file or named pipe before quit.

	return userid + 1;
}

function print_usrxml_entries_oneline(h, file, fn,    n, u, o, stdout)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	stdout = "/dev/stdout"

	if (file == "")
		file = stdout;

	if (fn == "")
		fn = "print_usrxml_entry_oneline";

	n = USRXML_users[h,"num"];
	for (u = 0; u < n; u++) {
		# Skip holes entries
		if (!((h,u) in USRXML_users))
			continue;

		o = @fn(h, u, file);
		if (o < 0)
			break;
	}

	fflush(file);

	if (file != stdout)
		close(file);

	return o;
}

#
# Print users entry in usrxml format
#

function print_usrxml_entry(h, userid, file)
{
	return print_usrxml_entry_oneline(h, userid, file, "\t", "\n");
}

function print_usrxml_entries(h, file)
{
	return print_usrxml_entries_oneline(h, file, "print_usrxml_entry");
}

#
# Load/store batch from file/pipe/stdin
#

function load_usrxml_file(_h, file, flags, cb, data,    h, line, rc, ret, s_fn, stdin)
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
		ret = run_usrxml_parser(h, line, cb, data);
		if (ret < 0) {
			if (!and(flags, USRXML_LOAD_SKIP_FAILED))
				break;
			usrxml__clearerrno(h);
		}
	}

	if (file != stdin)
		close(file);

	if (rc < 0) {
		ret = usrxml__seterrno(USRXML_E_GETLINE);
	} else if (ret == USRXML_E_NONE) {
		# Check for open sections
		rc = USRXML__instance[h,"scope"];
		if (rc > USRXML__scope_none)
			ret = usrxml_scope_err(h, USRXML__scope2name[rc]);
	}

	if (ret < 0) {
		if (h != _h)
			fini_usrxml_parser(h);
	} else {
		ret = h;
	}

	FILENAME = s_fn;
	return ret;
}

function store_usrxml_file(h, file)
{
	print_usrxml_entries(h, file);
}
