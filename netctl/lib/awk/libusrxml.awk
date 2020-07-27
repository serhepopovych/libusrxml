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
# Library messages handling helper routines.
#

function usrxml_split_tag(str, res, r,    tag, n, k)
{
	n = split(str, res, r, tag);
	if (!n)
		return n;

	# res[1] == "<"
	if (res[1] !~ "^[[:space:]]*<")
		return 0;

	# res[n] == ">"
	if (!sub(">[[:space:]]*$", "", res[n]))
		return 0;

	delete res[1];

	# strip ":" at the end tag name (i.e. @r is "(tag1|tag2):")
	for (k in tag) {
		sub(":$", "", tag[k]);
	}

	# strip leading and trailing whitespace
	for (k in res) {
		gsub("^[[:space:]]+|[[:space:]]+$", "", res[k]);
	}

	# tag[1] .. tag[n - 1]
	#   ||        ||
	# res[2] .. res[n]
	for (k = 2; k <= n; k++) {
		r = tag[k - 1];
		res[r] = res[k];
		delete res[k];
	}

	return n;
}

function usrxml_split_tag_msg(str, res,    r)
{
	r = "(priority|stamp|prog|h|file|line|str|errno):";
	return usrxml_split_tag(str, res, r);
}

function usrxml_priority2name(priority)
{
	if (priority in USRXML__priority2name)
		return USRXML__priority2name[priority];
	else
		return "";
}

function usrxml_timestamp()
{
	return strftime("%Y%m%d-%H%M%S", systime(), "UTC");
}

function usrxml_msg_format(params, append,
			   h, err, subsys, priority, str,
			   fileline, file, line, msg, stdout, tag)
{
	h = params["h"];
	if (!is_valid_usrxml_handle(h))
		h = params["h"] = "";

	if ("errno" in params)
		err = int(params["errno"]);
	else if (h != "")
		err = USRXML__instance[h,"errno"];
	else
		err = USRXML_E_NONE;
	params["errno"] = err;

	subsys = params["subsys"];
	if (subsys != "logger")
		subsys = params["subsys"] = "result";

	priority = params["priority"];
	if (!(priority in USRXML__priority2name)) {
		if (err != USRXML_E_NONE)
			priority = USRXML_MSG_PRIO_ERR;
		else if (h == "")
			priority = USRXML_MSG_PRIO_CRIT;
		else
			priority = USRXML__instance[h,subsys,"dflt_priority"];
		params["priority"] = priority;
	}

	## Mandatory params

	# prio, stamp
	params["prio"] = USRXML__priority2name[priority];
	params["stamp"] = usrxml_timestamp();

	# prog
	if (params["prog"] == "") {
		if (h == "") {
			str = "usrxml";
		} else {
			str = USRXML__instance[h,"prog"];
			if (str == "")
				str = "usrxml";
		}
		params["prog"] = str;
	}
	str = "";

	## Optional params

	# filename and linenum
	if (h != "") {
		file = params["filename"] = USRXML__instance[h,"filename"];
		line = params["linenum"] = USRXML__instance[h,"linenum"];
	} else {
		file = line = "";
	}

	if (file != "" && line != "")
		fileline = params["fileline"] = file ":" line;
	else
		delete params["fileline"];

	## Format message

	tag = 0;

	if (params["fmt"] == "log") {
		msg = sprintf("{%d} %s %s",
			      params["priority"],
			      params["stamp"], params["prog"]);

		if (h != "")
			msg = msg sprintf("[%u]", h);

		if (fileline != "")
			msg = msg sprintf(": %s", fileline);

		str = params["str"];
		if (str != "")
			msg = msg sprintf(": %s", str);

		if (err != USRXML_E_NONE)
			msg = msg sprintf(": %d", err);
	} else {
		msg = sprintf("<priority:%s stamp:%s prog:%s",
			      params["priority"],
			      params["stamp"], params["prog"]);

		if (h != "")
			msg = msg sprintf(" h:%u", h);

		if (fileline != "")
			msg = msg sprintf(" file:%s line:%u", file, line);

		str = params["str"];
		if (str != "")
			msg = msg sprintf(" str:%s", str);

		msg = msg sprintf(" errno:%d", err);

		tag = 1;
	}

	# Append user supplied string
	if (append != "")
		msg = msg " " append;

	# Close tag
	if (tag)
		msg = msg ">";

	# Output file
	stdout = params["stdout"] = "/dev/stdout";

	if (params["file"] == "") {
		if (h == "") {
			file = stdout;
		} else {
			file = USRXML__instance[h,subsys,"file"];
			if (file == "")
				file = stdout;
		}
		params["file"] = file;
	}

	params["msg"] = msg;

	return USRXML_E_NONE;
}

function usrxml_msg_output(params,    h, err, subsys, priority, file)
{
	h = params["h"];

	if (!("msg" in params)) {
		if (is_valid_usrxml_handle(h))
			usrxml__seterrno(h, USRXML_E_API_ORDER);
		return USRXML_E_API_ORDER;
	}

	err = params["errno"];

	if (h != "") {
		subsys = params["subsys"];
		if (subsys != "logger") {
			usrxml__seterrno(h, err);
		} else {
			priority = params["priority"]
			if (priority > USRXML__instance[h,subsys,"level"])
				return err;
		}
	}

	file = params["file"];

	print params["msg"] >>file;

	fflush(file);

	if (file != params["stdout"])
		close(file);

	return err;
}

function usrxml_msg_getopt(h, opts,    subsys, val)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;

	if (isarray(opts))
		delete opts;

	subsys = "logger";

	val = subsys SUBSEP "level";
	opts[val] = USRXML__instance[h,val];
	val = subsys SUBSEP "dflt_priority";
	opts[val] = USRXML__instance[h,val];
	val = subsys SUBSEP "file";
	opts[val] = USRXML__instance[h,val];

	subsys = "result";

	val = subsys SUBSEP "dflt_priority";
	opts[val] = USRXML__instance[h,val];
	val = subsys SUBSEP "file";
	opts[val] = USRXML__instance[h,val];

	return USRXML_E_NONE;
}

function usrxml__msg_setopt(h, opts, subsys,    val)
{
	val = subsys SUBSEP "dflt_priority";
	if (val in opts) {
		if (!(opts[val] in USRXML__priority2name))
			return USRXML_E_PRIORITY_INVALID;
		USRXML__instance[h,val] = opts[val];
	}

	val = subsys SUBSEP "file";
	if (val in opts) {
		if (opts[val] != "")
			USRXML__instance[h,val] = opts[val];
		else
			USRXML__instance[h,val] = "/dev/stdout";
	}

	return USRXML_E_NONE;
}

function usrxml_msg_setopt(h, opts,    subsys, val, ret)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;

	if (!isarray(opts))
		return USRXML_E_NOT_ARRAY;

	subsys = "logger";

	val = subsys SUBSEP "level";
	if (val in opts) {
		if (!(opts[val] in USRXML__priority2name))
			return USRXML_E_PRIORITY_INVALID;
		USRXML__instance[h,val] = opts[val];
	}

	ret = usrxml__msg_setopt(h, opts, subsys);
	if (ret != USRXML_E_NONE)
		return ret;

	subsys = "result";

	ret = usrxml__msg_setopt(h, opts, subsys);
	if (ret != USRXML_E_NONE)
		return ret;

	return USRXML_E_NONE;
}

function usrxml_msg(h, err, subsys, priority, str, prog, file,    params, ret)
{
	params["h"]		= h;
	params["errno"]		= err;
	params["subsys"]	= subsys;
	params["priority"]	= priority;
	params["str"]		= str;

	params["fmt"] = (subsys != "logger") ? "tag" : "log";

	# These optional and determined from handle (h) if given
	params["prog"] = prog;
	params["file"] = file;

	ret = usrxml_msg_format(params);
	if (ret != USRXML_E_NONE)
		return ret;

	return usrxml_msg_output(params);
}

function usrxml_logger(h, err, priority, str, prog, file)
{
	return usrxml_msg(h, err, "logger", priority, str, prog, file);
}

function usrxml_result(h, err, priority, str, prog, file)
{
	return usrxml_msg(h, err, "result", priority, str, prog, file);
}

#
# Parser helper routines to report various errors.
#

function usrxml_syntax_err(h,    errstr)
{
	errstr = "syntax error";
	return usrxml_result(h, USRXML_E_SYNTAX, USRXML_MSG_PRIO_ERR, errstr);
}

function usrxml_scope_err(h, section,    errstr)
{
	errstr = sprintf("<%s> scope error", section);
	return usrxml_result(h, USRXML_E_SCOPE, USRXML_MSG_PRIO_ERR, errstr);
}

function usrxml_inv_arg(h, section, value,    errstr)
{
	errstr = sprintf("invalid argument \"%s\" in <%s>", value, section);
	return usrxml_result(h, USRXML_E_INVAL, USRXML_MSG_PRIO_ERR, errstr);
}

function usrxml_ept_val(h, section,    errstr)
{
	errstr = sprintf("empty value in <%s>", section);
	return usrxml_result(h, USRXML_E_EMPTY, USRXML_MSG_PRIO_ERR, errstr);
}

function usrxml_nept_val(h, section,    errstr)
{
	errstr = sprintf("non-empty value in <%s>", section);
	return usrxml_result(h, USRXML_E_NOT_EMPTY, USRXML_MSG_PRIO_ERR, errstr);
}

function usrxml_dup_val(h, section, value,    errstr)
{
	errstr = sprintf("duplicated value \"%s\" in <%s>", value, section);
	return usrxml_result(h, USRXML_E_DUP, USRXML_MSG_PRIO_ERR, errstr);
}

function usrxml_dup_arg(h, section,    errstr)
{
	errstr = sprintf("duplicated argument <%s>", section);
	return usrxml_result(h, USRXML_E_DUP, USRXML_MSG_PRIO_ERR, errstr);
}

function usrxml_dup_attr(h, section, value, i,    name, type, err, errstr)
{
	if (!(i in USRXML_ifnames)) {
		# This is assert and thus not reported via usrxml_result()
		return USRXML_E_NOENT;
	}

	name = USRXML_ifnames[i];

	if (name == USRXML__instance[h,"name"])
		return USRXML_E_NONE;

	type = USRXML_ifnames[h,name];
	err = usrxml_dup_val(h, section, value);

	errstr = sprintf("already defined by \"%s\" %s", name, type);
	return usrxml_result(h, err, USRXML_MSG_PRIO_ERR, errstr);
}

function usrxml_missing_arg(h, section,    errstr)
{
	errstr = sprintf("missing mandatory argument <%s>", section);
	return usrxml_result(h, USRXML_E_MISS, USRXML_MSG_PRIO_ERR, errstr);
}

function usrxml_self_ref(h, section, value,    errstr)
{
	errstr = sprintf("self referencing \"%s\" with <%s>\n", value, section);
	return usrxml_result(h, USRXML_E_SELF_REF, USRXML_MSG_PRIO_ERR, errstr);
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
	ret = USRXML_E_SYNTAX;

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

	return usrxml__seterrno(h, ret);
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
	return usrxml_dup_attr(h, section["name"], section["value"], section["i"]);
}

function usrxml_section_dup_attr(h, _section, value, i, key,    section)
{
	section["name"]  = _section;
	section["value"] = value;
	section["i"]     = i;

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

function usrxml_make_var_name(val)
{
	if (val == "")
		return "";

	# Replace all not alnum or underline symbols with "_"
	gsub("[^[:alnum:]_]", "_", val);

	# Prefix with "_" if beginning with digit
	if (val ~ "^[[:digit:]]")
		val = "_" val;

	return val;
}

function usrxml_match(s, r, a,    n, s_rs, s_rl)
{
	# These are modified by match(): save them
	s_rs = RSTART;
	s_rl = RLENGTH;

	n = match(s, r, a);

	RLENGTH = s_rl;
	RSTART = s_rs;

	return n;
}

function usrxml_in_array(key, arr)
{
	return key in arr;
}

function usrxml_in_array_get(key, arr)
{
	if (key in arr)
		return arr[key];
	else
		return "";
}

function usrxml_copy_array(darr, sarr,    key, cnt)
{
	delete darr;

	cnt = 0;

	for (key in sarr) {
		darr[key] = sarr[key];
		cnt++;
	}

	return cnt;
}

#
# Map helpers
#

function usrxml__map_add_val(h, attr, map, val,    n, i, id, num, min, max)
{
	if (attr ~ "^(num|min|max|cnt|id|[[:digit:]]+)$")
		return -1;

	# h,attr,"id"
	n = h SUBSEP attr SUBSEP "id";

	if (n in map) {
		i = h SUBSEP map[n];
	} else {
		num = strtonum(map[h,"num"]);
		min = strtonum(map[h,"min"]);
		max = strtonum(map[h,"max"]);

		do {
			id = min;

			if (min < max)
				min++;
			else if (max >= num)
				min = max = ++num;
			else
				min = (max += (num - max));

			i = h SUBSEP id;
		} while (i in map);

		map[n] = id;
		map[i] = attr;

		map[h,"num"] = num;
		map[h,"min"] = min;
		map[h,"max"] = max;
		map[h,"cnt"]++;
	}

	if (val != SUBSEP)
		map[h,attr] = val;
	else
		map[h,attr]++;

	return i;
}

function usrxml__map_add_attr(h, attr, map)
{
	return usrxml__map_add_val(h, attr, map, SUBSEP);
}

function usrxml__map_del_by_attr(h, attr, map,    n, id, num)
{
	# Always delete single value (main user dynamic maps)
	delete map[h,attr];

	# h,attr,"id"
	n = h SUBSEP attr SUBSEP "id";

	if (!(n in map))
		return -1;

	id = map[n];
	delete map[n];
	delete map[h,id];

	# Not decrementing map[h,"num"]

	if (--map[h,"cnt"] <= 0) {
		delete map[h,"cnt"];
		delete map[h,"max"];
		delete map[h,"min"];
		delete map[h,"num"];
	} else {
		if (id < map[h,"min"]) {
			if (map[h,"max"] >= map[h,"num"])
				map[h,"max"] = id;
			map[h,"min"] = id;
		} else if (id > map[h,"max"]) {
			map[h,"max"] = id;
		}
	}

	return id;
}

function usrxml__map_add_attr_once(h, attr, map,    n)
{
	# h,attr,"id"
	n = h SUBSEP attr SUBSEP "id";

	if (n in map)
		return h SUBSEP map[n];
	else
		return usrxml__map_add_val(h, attr, map, SUBSEP);
}

function usrxml__map_add_attr_retval(h, attr, map, _once,    n, ret)
{
	# h,attr
	n = h SUBSEP attr;

	if (_once && n in map)
		return map[n];

	ret = usrxml__map_add_val(h, attr, map, SUBSEP);
	if (ret < 0)
		return "";

	return map[n];
}

function usrxml__map_add_attr_once_retval(h, attr, map)
{
	return usrxml__map_add_attr_retval(h, attr, map, 1);
}

function usrxml__map_del_if_zero_attr(h, attr, map,    val)
{
	val = map[h,attr];
	if (val < 0)
		return -1;

	if (--val <= 0)
		return usrxml__map_del_by_attr(h, attr, map);
	else
		return -1;
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

function usrxml__map_del_all(h, map,    n, i, p, cnt)
{
	# h,"num"
	i = h SUBSEP "num";

	if (!(i in map))
		return 0;

	cnt = map[h,"cnt"];

	n = map[i];
	for (p = 0; p < n; p++) {
		# h,id
		i = h SUBSEP p;

		# Skip holes entries
		if (!(i in map))
			continue;

		usrxml__map_del_by_attr(h, map[i], map);
	}

	return cnt;
}

function usrxml__map_copy_all(dh, dmap, sh, smap,    n, i, p, attr, cnt)
{
	if (dh == sh)
		return 0;

	# sh,"num"
	i = sh SUBSEP "num";

	if (!(i in smap))
		return 0;

	n = smap[i];
	if (!n)
		return 0;

	usrxml__map_del_all(dh, dmap);

	dmap[dh,"num"] = n;
	dmap[dh,"min"] = smap[sh,"min"];
	dmap[dh,"max"] = smap[sh,"max"];
	dmap[dh,"cnt"] = cnt = smap[sh,"cnt"];

	for (p = 0; p < n; p++) {
		# sh,id
		i = sh SUBSEP p;

		# Skip holes entries
		if (!(i in smap))
			continue;

		attr = smap[i];

		dmap[dh,p] = attr;
		dmap[dh,attr] = smap[sh,attr];
		dmap[dh,attr,"id"] = p;
	}

	return cnt;
}

function usrxml__map_copy_one(dh, dmap, sh, smap, attr,    n, i)
{
	if (dh == sh)
		return "";

	if (attr ~ "^[[:digit:]]+$") {
		# sh,id
		i = sh SUBSEP attr;

		if (!(i in smap)) {
			# Not deleting from dest by id
			return "";
		}

		attr = smap[i];
	} else {
		# sh,attr,"id"
		i = sh SUBSEP attr SUBSEP "id";

		if (!(i in smap)) {
			usrxml__map_del_by_attr(dh, attr, dmap);
			return "";
		}
	}

	return usrxml__map_add_val(dh, attr, dmap, smap[sh,attr]);
}

#
# Dynamic array helpers
#

function usrxml__dyn_is_array(h, dyn, arr)
{
	if (isarray(arr))
		return (h,dyn,"num") in arr;
	else
		return (h,dyn,"num") in USRXML__dynmap;
}

function usrxml___dyn_length(h, dyn, arr,    i)
{
	# h,dyn,"cnt"
	i = h SUBSEP dyn SUBSEP "cnt";

	return (i in arr) ? arr[i] : 0;
}

function usrxml__dyn_length(h, dyn, arr)
{
	if (isarray(arr))
		return usrxml___dyn_length(h, dyn, arr);
	else
		return usrxml___dyn_length(h, dyn, USRXML__dynmap);
}

function usrxml__dyn_test_attr(h, dyn, attr, arr)
{
	if (isarray(arr))
		return (h,dyn,attr) in arr;
	else
		return (h,dyn,attr) in USRXML__dynmap;
}

function usrxml__dyn_get_val(h, dyn, attr, arr,    n)
{
	# h,dyn
	n = h SUBSEP dyn;

	if (attr != "") {
		# h,dyn,attr
		n = n SUBSEP attr;
	}

	if (isarray(arr))
		return (n in arr) ? arr[n] : "";
	else
		return (n in USRXML__dynmap) ? USRXML__dynmap[n] : "";
}

function usrxml__dyn_get_dval(h, dyn, arr)
{
	return usrxml__dyn_get_val(h, dyn, "", arr);
}

function usrxml___dyn_add_val(h, dyn, attr, val, arr, dval,    hh, ret)
{
	# h,dyn
	hh = h SUBSEP dyn;

	# Add dynamic array value (dval) if specified
	# or count number of elements if not.
	#
	# Take handle (h) from map id (> 0) or error code (< 0).
	if (dval != SUBSEP)
		ret = int(usrxml__map_add_val(h, dyn, arr, dval));
	else if (!((hh,attr) in arr))
		ret = int(usrxml__map_add_attr(h, dyn, arr));
	else
		ret = 0;

	if (ret < 0)
		return ret;

	return usrxml__map_add_val(hh, attr, arr, val);
}

function usrxml__dyn_add_val(h, dyn, attr, val, arr,    hh)
{
	if (isarray(arr))
		return usrxml___dyn_add_val(h, dyn, attr, val, arr, SUBSEP);
	else
		return usrxml___dyn_add_val(h, dyn, attr, val, USRXML__dynmap, SUBSEP);
}

function usrxml__dyn_add_attr(h, dyn, attr, arr)
{
	return usrxml__dyn_add_val(h, dyn, attr, SUBSEP, arr);
}

function usrxml___dyn_del_by_attr(h, dyn, attr, arr, dval,    hh, id)
{
	# h,dyn
	hh = h SUBSEP dyn;

	id = usrxml__map_del_by_attr(hh, attr, arr);

	if ((hh,"num") in arr) {
		if (dval != SUBSEP)
			arr[h,dyn] = dval;
	} else {
		usrxml__map_del_by_attr(h, dyn, arr);
	}

	return id;
}

function usrxml__dyn_del_by_attr(h, dyn, attr, arr)
{
	if (isarray(arr))
		return usrxml___dyn_del_by_attr(h, dyn, attr, arr, SUBSEP);
	else
		return usrxml___dyn_del_by_attr(h, dyn, attr, USRXML__dynmap, SUBSEP);
}

function usrxml___dyn_del_by_id(h, dyn, id, arr, dval,    hh, attr)
{
	# h,dyn
	hh = h SUBSEP dyn;

	attr = usrxml__map_del_by_id(hh, id, arr);

	if ((hh,"num") in arr) {
		if (dval != SUBSEP)
			arr[h,dyn] = dval;
	} else {
		usrxml__map_del_by_attr(h, dyn, arr);
	}

	return attr;
}

function usrxml__dyn_del_by_id(h, dyn, id, arr)
{
	if (isarray(arr))
		return usrxml___dyn_del_by_id(h, dyn, id, arr, SUBSEP);
	else
		return usrxml___dyn_del_by_id(h, dyn, id, USRXML__dynmap, SUBSEP);
}

function usrxml____dyn_for_each(h, dyn, cb, data, arr, from, dec,
				n, i, hh, attr, ret)
{
	# h,dyn
	hh = h SUBSEP dyn;

	# h,dyn,"num"
	n = hh SUBSEP "num";

	if (!(n in arr))
		return USRXML_E_NONE;

	n = arr[n] - 1;

	dec = !!dec;

	if (from != "") {
		if (from < 0 || from > n)
			return USRXML_E_RANGE;
		n = dec ? from : n - from;
	} else {
		from = n * dec;
	}

	dec = 1 - 2 * dec;

	for (; n-- >= 0; from += dec) {
		# h,dyn,id
		i = hh SUBSEP from;

		# Skip hole entries
		if (!(i in arr))
			continue;

		attr = arr[i];
		ret = @cb(h, dyn, attr, data, arr, dec);
		if (ret < 0)
			return ret SUBSEP from;
		if (ret > 0)
			usrxml___dyn_del_by_attr(h, dyn, attr, arr);
	}

	return USRXML_E_NONE;
}

function usrxml___dyn_for_each(h, dyn, cb, data, arr)
{
	return usrxml____dyn_for_each(h, dyn, cb, data, arr);
}

function usrxml__dyn_for_each(h, dyn, cb, data, arr)
{
	if (isarray(arr))
		return usrxml___dyn_for_each(h, dyn, cb, data, arr);
	else
		return usrxml___dyn_for_each(h, dyn, cb, data, USRXML__dynmap);
}

function usrxml___dyn_for_each_from(h, dyn, cb, data, from, arr)
{
	return usrxml____dyn_for_each(h, dyn, cb, data, arr, from);
}

function usrxml__dyn_for_each_from(h, dyn, cb, data, from, arr)
{
	if (isarray(arr))
		return usrxml___dyn_for_each_from(h, dyn, cb, data, from, arr);
	else
		return usrxml___dyn_for_each_from(h, dyn, cb, data, from, USRXML__dynmap);
}

function usrxml___dyn_for_each_reverse(h, dyn, cb, data, arr)
{
	return usrxml____dyn_for_each(h, dyn, cb, data, arr, "", -1);
}

function usrxml__dyn_for_each_reverse(h, dyn, cb, data, arr)
{
	if (isarray(arr))
		return usrxml___dyn_for_each_reverse(h, dyn, cb, data, arr);
	else
		return usrxml___dyn_for_each_reverse(h, dyn, cb, data, USRXML__dynmap);
}

function usrxml___dyn_for_each_reverse_from(h, dyn, cb, data, from, arr)
{
	return usrxml____dyn_for_each(h, dyn, cb, data, arr, from, -1);
}

function usrxml__dyn_for_each_reverse_from(h, dyn, cb, data, from, arr)
{
	if (isarray(arr))
		return usrxml___dyn_for_each_reverse_from(h, dyn, cb, data, from, arr);
	else
		return usrxml___dyn_for_each_reverse_from(h, dyn, cb, data, from, USRXML__dynmap);
}

function usrxml__dyn_cnt_val_cb(h, dyn, attr, data, arr, dec,    val)
{
	val = arr[h,dyn,attr];

	if (val ~ data["val"]) {
		data["cnt","eq"]++;
		return data["ret"];
	} else {
		data["cnt","ne"]++;
		return 0;
	}
}

function usrxml__dyn_cnt_val(h, dyn, val, ret, data, arr, from, dec,    cb)
{
	data["val"] = val;
	data["ret"] = ret;
	data["cnt","eq"] = data["cnt","ne"] = 0;

	# Not using array specific helper here as @arr might be omitted
	cb = "usrxml__dyn_cnt_val_cb";

	if (isarray(arr))
		return usrxml____dyn_for_each(h, dyn, cb, data, arr, from, dec);
	else
		return usrxml____dyn_for_each(h, dyn, cb, data, USRXML__dynmap, from, dec);
}

function usrxml__dyn_del_by_val(h, dyn, val, arr, from,    data)
{
	usrxml__dyn_cnt_val(h, dyn, val, 1, data, arr, from);
	return data["cnt","eq"];
}

function usrxml__dyn_cnt_eq_val(h, dyn, val, arr, from,    data)
{
	usrxml__dyn_cnt_val(h, dyn, val, 0, data, arr, from);
	return data["cnt","eq"];
}

function usrxml__dyn_cnt_ne_val(h, dyn, val, arr, from,    data)
{
	usrxml__dyn_cnt_val(h, dyn, val, 0, data, arr, from);
	return data["cnt","ne"];
}

function usrxml___dyn_fnd_by_val(h, dyn, val, arr, from, dec,    data)
{
	val = usrxml__dyn_cnt_val(h, dyn, val, -1, data, arr, from, dec);
	if (split(val, data, SUBSEP) != 2)
		return USRXML_E_NOENT;
	return data[2];
}

function usrxml__dyn_fnd_by_val(h, dyn, val, arr, from)
{
	return usrxml___dyn_fnd_by_val(h, dyn, val, arr, from);
}

function usrxml__dyn_fnd_by_val_reverse(h, dyn, val, arr, from)
{
	return usrxml___dyn_fnd_by_val(h, dyn, val, arr, from, -1);
}

function usrxml__dyn_del_all(h, dyn, arr)
{
	return usrxml__dyn_del_by_val(h, dyn, ".*", arr);
}

function usrxml___dyn_clear(h, arr,    n, i, p)
{
	# h,"num"
	n = h SUBSEP "num";

	if (!(n in arr))
		return;

	n = arr[n];
	for (p = 0; p < n; p++) {
		# h,id
		i = h SUBSEP p;

		# Skip hole entries
		if (!(i in arr))
			continue;

		usrxml__dyn_del_all(h, arr[i], arr);
	}
}

function usrxml__dyn_clear(h, arr)
{
	if (isarray(arr))
		usrxml___dyn_clear(h, arr);
	else
		usrxml___dyn_clear(h, USRXML__dynmap);
}

function usrxml___dyn_copy_cb(sh, dyn, attr, dh, arr, dec)
{
	usrxml__map_add_val(dh SUBSEP dyn, attr, arr, arr[sh,dyn,attr]);

	return 0;
}

function usrxml___dyn_copy(dh, sh, dyn, arr,    i_src, i_dst)
{
	# sh,dyn
	i_src = sh SUBSEP dyn;
	if (!(i_src in arr))
		return "";

	if (dh == sh)
		return sh SUBSEP arr[i_src,"id"];

	usrxml__dyn_del_all(dh, dyn, arr);

	i_dst = usrxml__map_add_val(dh, dyn, arr, arr[i_src]);

	usrxml___dyn_for_each(sh, dyn, "usrxml___dyn_copy_cb", dh, arr);

	return i_dst;
}

function usrxml__dyn_copy(dh, sh, dyn, arr)
{
	if (isarray(arr))
		return usrxml___dyn_copy(dh, sh, dyn, arr);
	else
		return usrxml___dyn_copy(dh, sh, dyn, USRXML__dynmap);
}

#
# Preference management helpers
#

function usrxml__pref_pick_first(h, arr,    si, id)
{
	si = PROCINFO["sorted_in"];
	PROCINFO["sorted_in"] = "@ind_num_asc";

	id = USRXML_E_NOENT;

	for (id in arr)
		break;

	PROCINFO["sorted_in"] = si;

	return id;
}

function usrxml__pref_add_val(h, arr, val, id, tid)
{
	if (id ~ "^[[:digit:]]+$") {
		if (id >= arr[h]["id"])
			arr[h]["id"] = id + 1;
		arr[h]["cnt"] += !usrxml_in_array(id, arr[h]);
	} else {
		id = arr[h]["id"]++;
		arr[h]["cnt"]++;
	}

	arr[h][id] = val;
	if (tid != "")
		arr[h]["tid"] = id;

	return id;
}

function usrxml__pref_del_by_id(h, arr, id)
{
	if (id == "") {
		id = usrxml__pref_pick_first(h, arr);
		if (id < 0)
			return id;
	} else if (id == "*" || id == "all") {
		arr[h]["cnt"] = 0;
		id = -1;
	} else if (id ~ "^[[:digit:]]+$") {
		if (!usrxml_in_array(id, arr[h]))
			return USRXML_E_NOENT;
	} else {
		return USRXML_E_INVAL;
	}

	if (--arr[h]["cnt"] <= 0) {
		delete arr[h];
	} else {
		if (usrxml_in_array_get("tid", arr[h]) == id)
			delete arr[h]["tid"];
		delete arr[h][id];
	}

	return id;
}

function usrxml__pref_copy_all(dh, darr, sh, sarr)
{
	if (dh == sh)
		return 0;

	if (!(sh in sarr) || !isarray(sarr[sh]))
		return USRXML_E_NOT_ARRAY;

	# Make darr[dh]
	darr[dh]["cnt"] = 0;

	return usrxml_copy_array(darr[dh], sarr[sh]) - 2;
}

#
# Name/type helpers
#

function usrxml__id(h, idn,    i)
{
	# h,username/userid
	i = h SUBSEP idn;

	if (idn ~ "^[[:digit:]]+$")
		return (i in USRXML_ifnames) ? idn : USRXML_E_NOENT;

	# Skip holes entries
	if (i in USRXML_ifnames)
		return USRXML_ifnames[i,"id"];
	else if (sub(":$", "", i) == 1)
		if (i in USRXML_ifnames)
			return USRXML_ifnames[i,"id"];

	return USRXML_E_NOENT;
}

function usrxml__name(h, idn)
{
	idn = usrxml__id(h, idn);
	if (idn < 0)
		return "";
	return USRXML_ifnames[h,idn];
}

function usrxml__type(h, idn)
{
	idn = usrxml__name(h, idn);
	if (idn == "")
		return "";
	return USRXML_ifnames[h,idn];
}

function usrxml__type_is_user(h, idn, type)
{
	if (type == "")
		type = usrxml__type(h, idn);
	return type == "user";
}

function usrxml__type_is_if(h, idn, type)
{
	if (type == "")
		type = usrxml__type(h, idn);
	return type != "" && type != "user";
}

function usrxml__type_cmp(h, name,    n, type, cmp, len, num, dyn)
{
	# h,name
	n = h SUBSEP name;

	# Item being deleted: force compare mismatch
	if ((n,"cmp") in USRXML_ifnames)
		return 0;

	type = USRXML_ifnames[n];

	cmp = USRXML_types[type,"cmp"];

	if (cmp == USRXML_type_cmp_inf)
		return 1;

	dyn = "lower-" name;
	if (usrxml__type_is_user(h, name, type))
		dyn = dyn ":";

	# h,dyn,"act"
	len = h SUBSEP dyn SUBSEP "act";
	len = (len in USRXML__dynmap) ? USRXML__dynmap[len] : 0;

	if (cmp == USRXML_type_cmp_nan)
		return len == 0;

	num = USRXML_types[type,"num"];

	if (cmp == USRXML_type_cmp_eql)
		return len == num;
	if (cmp == USRXML_type_cmp_zeq)
		return len == 0 || len == num;
	if (cmp == USRXML_type_cmp_geq)
		return len >= num;
	if (cmp == USRXML_type_cmp_leq)
		return len <= num;

	return 0;
}

#
# Helpers to manage number of "act"ive lowers/uppers
#

function usrxml___act_copy(dh, sh, dyn, arr)
{
	# dh,dyn
	dh = dh SUBSEP dyn;
	# sh,dyn
	sh = sh SUBSEP dyn;

	if ((sh,"act") in arr)
		arr[dh,"act"] = arr[sh,"act"];
	else
		delete arr[dh,"act"];
}

function usrxml__act_copy(dh, sh, dyn, arr)
{
	if (isarray(arr))
		usrxml___act_copy(dh, sh, dyn, arr);
	else
		usrxml___act_copy(dh, sh, dyn, USRXML__dynmap);
}

function usrxml____act_adjust(h, dyn, val, arr, dec,    i)
{
	# h,dyn,"act"
	i = h SUBSEP dyn SUBSEP "act";

	dec = (1 - 2 * !!dec) * val;

	if ((arr[i] += dec) <= 0)
		delete arr[i];
}

function usrxml___act_adjust(h, dyn, ifname, arr, dec,    val)
{
	val = !USRXML_ifnames[h,ifname,"inactive"];
	usrxml____act_adjust(h, dyn, val, arr, dec);
}

function usrxml___act_adjust_force(h, dyn, arr, dec)
{
	usrxml____act_adjust(h, dyn, 1, arr, dec);
}

function usrxml___act_inc(h, dyn, ifname, arr)
{
	usrxml___act_adjust(h, dyn, ifname, arr);
}

function usrxml___act_dec(h, dyn, ifname, arr)
{
	usrxml___act_adjust(h, dyn, ifname, arr, 1);
}

function usrxml___act_inc_force(h, dyn, arr)
{
	usrxml___act_adjust_force(h, dyn, arr);
}

function usrxml___act_dec_force(h, dyn, arr)
{
	usrxml___act_adjust_force(h, dyn, arr, 1);
}

function usrxml__act_inc(h, dyn, ifname)
{
	usrxml___act_inc(h, dyn, ifname, USRXML__dynmap);
}

function usrxml__act_dec(h, dyn, ifname)
{
	usrxml___act_dec(h, dyn, ifname, USRXML__dynmap);
}

function usrxml__act_inc_force(h, dyn)
{
	usrxml___act_inc_force(h, dyn, USRXML__dynmap);
}

function usrxml__act_dec_force(h, dyn)
{
	usrxml___act_dec_force(h, dyn, USRXML__dynmap);
}

#
# User (slave)
#

function usrxml__map_add_umap_attr2map(h, userid, map, umap,
				       m, i, j, p, val, name)
{
	# h,userid
	i = h SUBSEP userid;

	if (!((i,"num") in umap))
		return USRXML_E_NONE;

	name = umap["tname"];

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

		# Note that USRXML__instance[h,"name"] must be set
		val = usrxml_section_dup_attr(h, name, val, map[h,val], j);
		if (val != USRXML_E_NONE)
			return val;
	}

	return USRXML_E_NONE;
}

function usrxml__map_del_umap_attr4map(h, userid, map, umap,
				       m, i, j, p, val)
{
	# h,userid
	i = h SUBSEP userid;

	if (!((i,"num") in umap))
		return;

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

function usrxml__activate_user(h, username,    userid, n, t, dval)
{
	# h,username
	n = h SUBSEP username;

	userid = USRXML_ifnames[n,"id"];

	# if
	n = USRXML_userif[h,userid];

	dval = usrxml__dyn_get_dval(h, n, USRXML_ifuser);
	t = "^" userid " |( )" userid " | " userid "$";
	dval = gensub(t, "\\1", "g", dval);
	dval = (dval != "") ? dval " " userid : userid;

	usrxml___dyn_add_val(h, n, username, userid, USRXML_ifuser, dval);

	# net
	t = usrxml__map_add_umap_attr2map(h, userid,
					  USRXML_nets, USRXML_usernets);
	if (t != USRXML_E_NONE)
		return t;

	# net6
	t = usrxml__map_add_umap_attr2map(h, userid,
					  USRXML_nets6, USRXML_usernets6);
	if (t != USRXML_E_NONE)
		return t;

	# nat
	t = usrxml__map_add_umap_attr2map(h, userid,
					  USRXML_nats, USRXML_usernats);
	if (t != USRXML_E_NONE)
		return t;

	# nat6
	t = usrxml__map_add_umap_attr2map(h, userid,
					  USRXML_nats6, USRXML_usernats6);
	if (t != USRXML_E_NONE)
		return t;

	return USRXML_E_NONE;
}

function usrxml__activate_user_by_name(h, username)
{
	if (usrxml__activate_user(h, username) != USRXML_E_NONE)
		usrxml__deactivate_user_by_name(h, username);

	return USRXML_E_NONE;
}

function usrxml__deactivate_user_by_name(h, username,    userid, n, t, dval)
{
	# h,username
	n = h SUBSEP username;

	userid = USRXML_ifnames[n,"id"];

	# if
	n = USRXML_userif[h,userid];

	dval = usrxml__dyn_get_dval(h, n, USRXML_ifuser);
	t = "^" userid " |( )" userid " | " userid "$";
	dval = gensub(t, "\\1", "g", dval);

	usrxml___dyn_del_by_attr(h, n, username, USRXML_ifuser, dval);

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
	if (usrxml__map_copy_all(i_dst, umap, i_src, umap) == 0)
		return;

	n = umap[i_src,"num"];
	for (p = 0; p < n; p++) {
		# sh,userid,netid
		j_src = i_src SUBSEP p;
		# dh,userid,netid
		j_dst = i_dst SUBSEP p;

		# Remove from destination
		delete umap[j_dst,"has_opts"];

		delete umap[j_dst,"src"];
		delete umap[j_dst,"via"];
		delete umap[j_dst,"mac"];

		# Skip holes entries
		if (!(j_src in umap))
			continue;

		if ((j_src,"has_opts") in umap) {
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

function usrxml__copy_user(dh, i_dst, sh, i_src, username, cb, data,
			   n, m, p, o, i, j_dst, j_src)
{
	# user
	i_dst = usrxml__map_add_val(dh, username, USRXML_ifnames, USRXML_ifnames[i_src]);

	i_src = sh SUBSEP USRXML_ifnames[i_src,"id"];

	# pipe
	n = USRXML_userpipe[i_src];
	USRXML_userpipe[i_dst] = n;

	for (p = 0; p < n; p++) {
		# sh,userid,pipeid
		j_src = i_src SUBSEP p;
		# dh,userid,pipeid
		j_dst = i_dst SUBSEP p;

		# Remove from destination
		delete USRXML_userpipe[j_dst,"qdisc"];

		i = j_dst SUBSEP "opts";

		m = USRXML_userpipe[i];
		delete USRXML_userpipe[i];

		for (o = 0; o < m; o++)
			delete USRXML_userpipe[i,o];

		delete USRXML_userpipe[j_dst];
		delete USRXML_userpipe[j_dst,"zone"];
		delete USRXML_userpipe[j_dst,"dir"];
		delete USRXML_userpipe[j_dst,"bw"];

		# Skip holes entries
		if (!(j_src in USRXML_userpipe))
			continue;

		# Copy to destination
		USRXML_userpipe[j_dst] = USRXML_userpipe[j_src];
		USRXML_userpipe[j_dst,"zone"] = USRXML_userpipe[j_src,"zone"];
		USRXML_userpipe[j_dst,"dir"] = USRXML_userpipe[j_src,"dir"];
		USRXML_userpipe[j_dst,"bw"] = USRXML_userpipe[j_src,"bw"];

		o = USRXML_userpipe[j_src,"qdisc"];
		if (o != "") {
			USRXML_userpipe[j_dst,"qdisc"] = o;

			# sh,userid,pipeid,"opts"
			j_src = j_src SUBSEP "opts";
			# dh,userid,pipeid,"opts"
			j_dst = i;

			m = USRXML_userpipe[j_src];
			USRXML_userpipe[j_dst] = m;

			for (o = 0; o < m; o++)
				USRXML_userpipe[j_dst,o] = USRXML_userpipe[j_src,o];
		}
	}

	# if
	USRXML_userif[i_dst] = USRXML_userif[i_src];

	i = "lower-" username ":";
	usrxml__dyn_del_all(dh, i);
	usrxml__dyn_for_each(sh, i, cb, data);

	usrxml__act_copy(dh, sh, i);

	# net
	usrxml__copy_user_net(i_dst, i_src, USRXML_usernets);
	# net6
	usrxml__copy_user_net(i_dst, i_src, USRXML_usernets6);

	# nat
	usrxml__map_copy_all(i_dst, USRXML_usernats, i_src, USRXML_usernats);
	# nat6
	usrxml__map_copy_all(i_dst, USRXML_usernats6, i_src, USRXML_usernats6);

	return i_dst;
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

function usrxml__delete_umap(i, val, umap,    n, ret)
{
	ret = usrxml__map_del_if_zero_attr(i, val, umap);
	if (ret < 0)
		return ret;

	# h,userid,id
	n = i SUBSEP ret;

	usrxml_section_delete_fileline(umap["tname"] SUBSEP n);

	# These are "net" and "net6" specific
	delete umap[n,"src"];
	delete umap[n,"via"];
	delete umap[n,"mac"];
	delete umap[n,"has_opts"];

	return ret;
}

function usrxml__delete_map(i, val, map, umap,    a, h, ret)
{
	ret = usrxml__delete_umap(i, val, umap);
	if (ret < 0)
		return ret;

	# i = h,userid
	split(i, a, SUBSEP);

	h = a[1];

	if (((h,val) in map) && map[h,val] == i)
		usrxml__map_del_by_attr(h, val, map);

	return ret;
}

function usrxml__delete_umaps(i, umap,    m, j, p)
{
	# i = h,userid

	m = umap[i,"num"];
	for (p = 0; p < m; p++) {
		# h,userid,id
		j = i SUBSEP p;

		# Skip holes entries
		if (!(j in umap))
			continue;

		usrxml__delete_umap(i, umap[j], umap);
	}
	# Remove in case of umap[i,"num"] is not defined (e.g. no <net6> tags)
	delete umap[i,"num"];
}

function usrxml__delete_user(h, username, n, i, cb, data,    m, j, p, dyn, name)
{
	m = username ":";

	data["ifname"] = m;

	data["lu"] = dyn = "lower";
	dyn = dyn "-" m;
	usrxml__dyn_for_each(h, dyn, cb, data);

	# pipe
	m = USRXML_userpipe[i];
	for (p = 0; p < m; p++) {
		# h,userid,pipeid
		j = i SUBSEP p;

		usrxml__delete_pipe(j);
	}
	delete USRXML_userpipe[i];

	# if
	name = USRXML_userif[i];
	delete USRXML_userif[i];

	usrxml___dyn_del_by_attr(h, name, username, USRXML_ifuser);

	# net
	usrxml__delete_umaps(i, USRXML_usernets);
	# net6
	usrxml__delete_umaps(i, USRXML_usernets6);
	# nat
	usrxml__delete_umaps(i, USRXML_usernats);
	# nat6
	usrxml__delete_umaps(i, USRXML_usernats6);

	# user
	usrxml_section_delete_fileline(USRXML_ifnames[n] SUBSEP i);

	usrxml__map_del_by_attr(h, username, USRXML_ifnames);

	delete USRXML_ifnames[n,"inactive"];

	return USRXML_E_NONE;
}

#
# If (master)
#

function usrxml__activate_if_by_name(h, dyn, iflu, ifname, arr,    i, cb, val)
{
	val = usrxml__name(h, iflu);
	if (ifname != "") {
		# Skip when lower isn't resolved (i.e. points to "?" and
		# not in USRXML_ifnames[]) and called recursively for
		# "upper-{iflu}".
		#
		if (val == "")
			return USRXML_E_NONE;

		# We are upper of already active lower
		arr[h,"lower-" iflu,"act"]++;
	} else {
		# Fail with USRXML_E_NOENT otherwise if called with
		# non-existing @iflu for example.
		if (val == "")
			return USRXML_E_NOENT;
	}
	iflu = val;

	# h,iflu,"inactive"
	i = h SUBSEP iflu SUBSEP "inactive";

	val = USRXML_ifnames[i];

	if (val > 0)
		return USRXML_E_NONE;

	if (usrxml__type_cmp(h, iflu) > 0) {
		if (val == 0)
			return USRXML_E_NONE;
	} else {
		if (val != 0)
			return USRXML_E_NONE;

		return usrxml__deactivate_if_by_name(h, dyn, iflu);
	}

	# Activate interface and it's uppers
	USRXML_ifnames[i] = 0;

	if (ifname == "")
		ifname = iflu;
	usrxml___dyn_add_val(h, ifname, iflu, 1, USRXML_ifupdown);

	if (usrxml__type_is_user(h, iflu, USRXML_ifnames[h,iflu]))
		return usrxml__activate_user_by_name(h, iflu);

	cb = "usrxml__activate_if_by_name";
	return int(usrxml__dyn_for_each(h, "upper-" iflu, cb, iflu));
}

function usrxml__deactivate_if_by_name(h, dyn, iflu, ifname, arr,    i, cb, val)
{
	val = usrxml__name(h, iflu);
	if (ifname != "") {
		# Skip when lower isn't resolved (i.e. points to "?" and
		# not in USRXML_ifnames[]) and called recursively for
		# "upper-{iflu}".
		#
		if (val == "")
			return USRXML_E_NONE;

		# We are upper of already active lower
		arr[h,"lower-" iflu,"act"]--;
	} else {
		# Fail with USRXML_E_NOENT otherwise if called with
		# non-existing @iflu for example.
		if (val == "")
			return USRXML_E_NOENT;
	}
	iflu = val;

	# h,iflu,"inactive"
	i = h SUBSEP iflu SUBSEP "inactive";

	val = USRXML_ifnames[i];

	if (val > 0)
		return USRXML_E_NONE;

	if (usrxml__type_cmp(h, iflu) > 0) {
		if (val == 0)
			return USRXML_E_NONE;

		return usrxml__activate_if_by_name(h, dyn, iflu);
	} else {
		if (val != 0)
			return USRXML_E_NONE;
	}

	# Deactivate interface and it's uppers
	USRXML_ifnames[i] = -1;

	if (ifname == "")
		ifname = iflu;
	usrxml___dyn_add_val(h, ifname, iflu, -1, USRXML_ifupdown);

	if (usrxml__type_is_user(h, iflu, USRXML_ifnames[h,iflu]))
		return usrxml__deactivate_user_by_name(h, iflu);

	cb = "usrxml__deactivate_if_by_name";
	return int(usrxml__dyn_for_each(h, "upper-" iflu, cb, iflu));
}

function usrxml__copy_if_cb(sh, dyn, iflu, data, arr, dec,    t, val, dh, ifname)
{
	dh = data["dh"];
	ifname = data["ifname"];

	# sh,unres-{iflu}
	res = "unres-" iflu;

	val = arr[sh,dyn,iflu];

	if (data["new"]) {
		if (val != "/")
			val = "";
		t = "";
	} else {
		t = usrxml__dyn_get_val(sh, res, ifname, arr);

		if (t != "") {
			if (val != "/")
				val = "?";
			else
				t = "";
		} else {
			if (val == "?")
				t = data["lu"];
		}
	}

	if (t != "")
		usrxml___dyn_add_val(dh, res, ifname, t, arr);
	else
		usrxml___dyn_del_by_attr(dh, res, ifname, arr);

	usrxml___dyn_add_val(dh, dyn, iflu, val, arr);

	return 0;
}

function usrxml__copy_if_by_name(dh, sh, ifname, new,
				 i, i_dst, i_src, name, cb, data)
{
	# sh,ifname
	i_src = sh SUBSEP ifname;

	if (!(i_src in USRXML_ifnames))
		return "";

	if (dh == sh)
		return sh SUBSEP USRXML_ifnames[i_src,"id"];

	# dh,ifname
	i_dst = dh SUBSEP ifname;

	USRXML_ifnames[i_dst,"inactive"] = USRXML_ifnames[i_src,"inactive"];

	cb = "usrxml__copy_if_cb";

	data["dh"] = dh;
	data["ifname"] = ifname;
	data["new"] = new;

	if (usrxml__type_is_user(sh, ifname, USRXML_ifnames[i_src]))
		return usrxml__copy_user(dh, i_dst, sh, i_src, ifname, cb, data);

	for (name in USRXML_ifparms) {
		usrxml__pref_copy_all(i_dst SUBSEP name, USRXML_ifnames,
				      i_src SUBSEP name, USRXML_ifnames);
	}

	i_dst = usrxml__map_add_val(dh, ifname,
				    USRXML_ifnames, USRXML_ifnames[i_src]);

	data["lu"] = i = "lower";
	i = i "-" ifname;
	usrxml__dyn_del_all(dh, i);
	usrxml__dyn_for_each(sh, i, cb, data);

	usrxml__act_copy(dh, sh, i);

	data["lu"] = i = "upper";
	i = i "-" ifname;
	usrxml__dyn_del_all(dh, i);
	usrxml__dyn_for_each(sh, i, cb, data);

	return i_dst;
}

function usrxml__delete_if_cb(h, dyn, iflu, data, arr, dec,    type, rev, ifname)
{
	type = arr[h,dyn,iflu];

	if (type == "?") {
		# iflu reference is unresolved: simply delete it
		usrxml___dyn_del_by_attr(h, "unres-" iflu, data["ifname"], arr);
	} else if (type == "") {
		# iflu added, but no resolution happened at all
	} else {
		# iflu marked for delete with "/" or resolved

		if (data["norefs"]) {
			if (data["lu"] != "upper")
				usrxml___act_dec_force(h, dyn, arr);
		} else {
			ifname = data["ifname"];

			if (data["lu"] == "upper") {
				rev = "lower-" iflu;
				usrxml___act_dec(h, rev, ifname, arr);
				usrxml__deactivate_if_by_name(h, "", iflu);
			} else {
				rev = "upper-" iflu;
				usrxml___act_dec_force(h, dyn, arr);
			}

			usrxml___dyn_del_by_attr(h, rev, ifname, arr);
		}
	}

	return 1;
}

function usrxml__delete_if_by_name(h, ifname, norefs,
				   n, i, ret, dyn, name, cb, data)
{
	# h,ifname
	n = h SUBSEP ifname;

	if (!(n in USRXML_ifnames))
		return USRXML_E_NOENT;

	# h,ifid
	i = h SUBSEP USRXML_ifnames[n,"id"];

	# lower and upper
	cb = "usrxml__delete_if_cb";

	data["norefs"] = norefs;

	if (!norefs)
		usrxml___dyn_add_val(h, ifname, ifname, -1, USRXML_ifupdown);

	if (usrxml__type_is_user(h, ifname, USRXML_ifnames[n])) {
		if (!norefs) {
			ret = usrxml__deactivate_user_by_name(h, ifname);
			if (ret != USRXML_E_NONE)
				return ret;
		}
		return usrxml__delete_user(h, ifname, n, i, cb, data);
	}

	data["ifname"] = ifname;

	data["lu"] = dyn = "lower";
	dyn = dyn "-" ifname;
	usrxml__dyn_for_each(h, dyn, cb, data);

	data["lu"] = dyn = "upper";
	dyn = dyn "-" ifname;
	usrxml__dyn_for_each(h, dyn, cb, data);

	# parms
	for (name in USRXML_ifparms)
		delete USRXML_ifnames[n,name];

	# if
	usrxml_section_delete_fileline(USRXML_ifnames[n] SUBSEP i);

	usrxml__map_del_by_attr(h, ifname, USRXML_ifnames);

	delete USRXML_ifnames[n,"inactive"];

	return USRXML_E_NONE;
}

function usrxml__delete_if_by_id(h, ifid,    n)
{
	# h,ifid
	n = h SUBSEP ifid;

	# Skip holes entries
	if (!(n in USRXML_ifnames))
		return;

	usrxml__delete_if_by_name(h, USRXML_ifnames[n]);
}

function usrxml__save_if(h, ifname)
{
	return usrxml__copy_if_by_name(h SUBSEP USRXML_orig, h, ifname);
}

function usrxml__restore_if(h, refs,    ifname)
{
	ifname = USRXML__instance[h,"name"];

	usrxml__delete_if_by_name(h, ifname, !refs);

	if (usrxml__copy_if_by_name(h, h SUBSEP USRXML_orig, ifname, refs))
		if (refs)
			usrxml__resolve_refs(h, ifname);

	usrxml__cleanup_if(h);
}

function usrxml__cleanup_if(h,    ifname)
{
	ifname = USRXML__instance[h,"name"];
	if (ifname != "")
		usrxml__delete_if_by_name(h SUBSEP USRXML_orig, ifname, 1);

	# Populated from parsing XML document
	delete USRXML__instance[h,"name"];
	delete USRXML__instance[h,"inactive"];
	delete USRXML__instance[h,"if"];

	delete USRXML__instance[h,"i"];
	delete USRXML__instance[h,"n"];

	usrxml___dyn_clear(h, USRXML_ifupdown);
}

#
# Initialize users database XML document parser/validator.
# This is usually called from BEGIN{} section.
#
# Returns parser instance handle that may be passed to others.
#

function declare_usrxml_consts()
{
	# Avoid multiple initializations
	if ("consts" in USRXML__instance)
		return;

	## Constants (public)

	# USRXML error codes (visible in case of handle allocation error)

	# Also applies to non-libusrxml code
	USRXML_E_NONE	= 0;

	# Program exit code usually from to 0 to 255.
	# Start libusrxml errors from 300.
	USRXML_E_BASE	= 300;

	# Document syntax errors
	USRXML_E_SYNTAX    = -(USRXML_E_BASE + 0);
	USRXML_E_INVAL     = -(USRXML_E_BASE + 1);
	USRXML_E_EMPTY     = -(USRXML_E_BASE + 2);
	USRXML_E_NOT_EMPTY = -(USRXML_E_BASE + 3);
	USRXML_E_DUP       = -(USRXML_E_BASE + 4);
	USRXML_E_MISS      = -(USRXML_E_BASE + 5);
	USRXML_E_SELF_REF  = -(USRXML_E_BASE + 6);
	USRXML_E_SCOPE     = -(USRXML_E_BASE + 50);

	# API
	USRXML_E_HANDLE_INVALID	= -(USRXML_E_BASE + 101);
	USRXML_E_HANDLE_FULL	= -(USRXML_E_BASE + 102);
	USRXML_E_API_ORDER	= -(USRXML_E_BASE + 103);
	USRXML_E_GETLINE	= -(USRXML_E_BASE + 104);

	# Generic
	USRXML_E_NOENT		= -(USRXML_E_BASE + 201);
	USRXML_E_RANGE		= -(USRXML_E_BASE + 202);
	USRXML_E_NOT_ARRAY	= -(USRXML_E_BASE + 203);

	# Messaging
	USRXML_E_PRIORITY_INVALID = -(USRXML_E_BASE + 301);

	## Constants (internal, arrays get cleaned)

	# Logging priority
	USRXML_MSG_PRIO_NONE	= -1;
	USRXML_MSG_PRIO_EMERG	= 0;
	USRXML_MSG_PRIO_ALERT	= 1;
	USRXML_MSG_PRIO_CRIT	= 2;
	USRXML_MSG_PRIO_ERR	= 3;
	USRXML_MSG_PRIO_WARN	= 4;
	USRXML_MSG_PRIO_NOTICE	= 5;
	USRXML_MSG_PRIO_INFO	= 6;
	USRXML_MSG_PRIO_DEBUG	= 7;

	USRXML__priority2name[USRXML_MSG_PRIO_EMERG]  = "emergency";
	USRXML__priority2name[USRXML_MSG_PRIO_ALERT]  = "alert";
	USRXML__priority2name[USRXML_MSG_PRIO_CRIT]   = "critical";
	USRXML__priority2name[USRXML_MSG_PRIO_ERR]    = "error";
	USRXML__priority2name[USRXML_MSG_PRIO_WARN]   = "warning";
	USRXML__priority2name[USRXML_MSG_PRIO_NOTICE] = "notice";
	USRXML__priority2name[USRXML_MSG_PRIO_INFO]   = "info";
	USRXML__priority2name[USRXML_MSG_PRIO_DEBUG]  = "debug";

	# Tag scope
	USRXML__scope_error	= "error";
	USRXML__scope_none	= "none";

	USRXML__scope_if	= "if";

	USRXML__scope_user	= "user";
	USRXML__scope_pipe	= "pipe";
	USRXML__scope_qdisc	= "qdisc";
	USRXML__scope_net	= "net";
	USRXML__scope_net6	= "net6";

	# Library public functions call order
	USRXML__order_none	= 0;
	USRXML__order_parse	= 1;

	# Handle suffix to store "orig"inal item in same map
	USRXML_orig		= "orig";

	# Load/store flags
	USRXML_LOAD_SKIP_FAILED	= lshift(1, 0);

	# Types and dependencies map
	USRXML_type_cmp_nan = 0x00; # no value supported
	USRXML_type_cmp_eql = 0x01; # equal
	USRXML_type_cmp_geq = 0x02; # greather or equal
	USRXML_type_cmp_leq = 0x03; # less or equal
	USRXML_type_cmp_zeq = 0x04; # zero or equal
	USRXML_type_cmp_inf = 0x7f; # do not compare

	# ifb
	USRXML_types["ifb","cmp"]       = USRXML_type_cmp_nan;
	# vrf
	USRXML_types["vrf","cmp"]       = USRXML_type_cmp_inf;
	# bridge
	USRXML_types["bridge","cmp"]    = USRXML_type_cmp_inf;
	# bond
	USRXML_types["bond","cmp"]      = USRXML_type_cmp_inf;
	# host
	USRXML_types["host","cmp"]      = USRXML_type_cmp_nan;
	# dummy
	USRXML_types["dummy","cmp"]     = USRXML_type_cmp_nan;
	# veth
	USRXML_types["veth","cmp"]      = USRXML_type_cmp_nan;
	# gretap
	USRXML_types["gretap","cmp"]    = USRXML_type_cmp_zeq;
	USRXML_types["gretap","num"]    = 1;
	# ip6gretap
	USRXML_types["ip6gretap","cmp"] = USRXML_type_cmp_zeq;
	USRXML_types["ip6gretap","num"] = 1;
	# vxlan
	USRXML_types["vxlan","cmp"]     = USRXML_type_cmp_zeq;
	USRXML_types["vxlan","num"]     = 1;
	# vlan
	USRXML_types["vlan","cmp"]      = USRXML_type_cmp_eql;
	USRXML_types["vlan","num"]      = 1;
	# macvlan
	USRXML_types["macvlan","cmp"]   = USRXML_type_cmp_eql;
	USRXML_types["macvlan","num"]   = 1;
	# ipvlan
	USRXML_types["ipvlan","cmp"]    = USRXML_type_cmp_eql;
	USRXML_types["ipvlan","num"]    = 1;
	# gre
	USRXML_types["gre","cmp"]       = USRXML_type_cmp_zeq;
	USRXML_types["gre","num"]       = 1;
	# ip6gre
	USRXML_types["ip6gre","cmp"]    = USRXML_type_cmp_zeq;
	USRXML_types["ip6gre","num"]    = 1;
	# user
	USRXML_types["user","cmp"]      = USRXML_type_cmp_eql;
	USRXML_types["user","num"]      = 1;

	# Network interface parameters
	USRXML_ifparms["ip-link"]	= 1;
	USRXML_ifparms["ethtool"]	= 2;
	USRXML_ifparms["sysctl"]	= 3;
	USRXML_ifparms["ip-address"]	= 4;
	USRXML_ifparms["tc-qdisc"]	= 5;
	USRXML_ifparms["tc-class"]	= 6;
	USRXML_ifparms["tc-filter"]	= 7;

	# Valid "zone" values
	USRXML__zone["world"]	= 1;
	USRXML__zone["local"]	= 1;
	USRXML__zone["all"]	= 1;

	# Valid "dir" values
	USRXML__dir["in"]	= 1;
	USRXML__dir["out"]	= 1;
	USRXML__dir["all"]	= 1;

	# Zone and direction names to mask mapping
	USRXML__zone_dir_bits["world","in"]	= 0x01;
	USRXML__zone_dir_bits["world","out"]	= 0x02;
	USRXML__zone_dir_bits["world","all"]	= 0x03;
	USRXML__zone_dir_bits["local","in"]	= 0x04;
	USRXML__zone_dir_bits["local","out"]	= 0x08;
	USRXML__zone_dir_bits["local","all"]	= 0x0c;
	USRXML__zone_dir_bits["all","in"]	= 0x05;
	USRXML__zone_dir_bits["all","out"]	= 0x0a;
	USRXML__zone_dir_bits["all","all"]	= 0x0f;

	# Mark as initialized
	USRXML__instance["consts"] = 1;
}

function init_usrxml_parser(prog,    h)
{
	# Declare constants
	declare_usrxml_consts();

	# Establish next (first) instance
	h = usrxml__alloc_handle();
	if (h < 0)
		return h;

	## Variables

	# USRXML__instance[] internal information about parser instance

	# Parse document first
	USRXML__instance[h,"order"] = USRXML__order_parse;

	# Name of program that uses API
	USRXML__instance[h,"prog"] = prog ? prog : "usrxml";

	# Library messages handling
	USRXML__instance[h,"logger","level"] = USRXML_MSG_PRIO_INFO;

	USRXML__instance[h,"logger","dflt_priority"] = \
	USRXML__instance[h,"result","dflt_priority"] = \
		USRXML_MSG_PRIO_INFO;

	USRXML__instance[h,"logger","file"] = \
	USRXML__instance[h,"result","file"] = \
		"/dev/stdout";

	# Error number updated on each library call
	USRXML__instance[h,"errno"] = USRXML_E_NONE;

	# Current entry type, scope and depth
	USRXML__instance[h,"scope"] = USRXML__scope_none;
	USRXML__instance[h,"depth"] = 0;

	# Real values set by run_usrxml_parser()
	USRXML__instance[h,"filename"] = "";
	USRXML__instance[h,"linenum"] = "";

	# USRXML__fileline[key,{ "file" | "line" },n]

	# Document format and parameters mapping
	# --------------------------------------
	#
	# num = USRXML_ifnames[h,"num"]
	# id = [0 .. num - 1]
	# name = USRXML_ifnames[h,id]
	# id = USRXML_ifnames[h,name,"id"]
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
	#   <nat 'cidr'>
	#     nat = USRXML_usernats[h,userid,natid]
	#
	#   nunats6 = USRXML_usernats6[h,userid,"num"]
	#   natid6 = [0 .. nunats6 - 1]
	#   natid6 = USRXML_usernats6[h,nat6,"id"]
	#   <nat6 'cidr6'>
	#     nat6 = USRXML_usernats6[h,userid,natid6]
	#
	# </user>

	# These are used to find duplicates at parse time
	# -----------------------------------------------
	#
	# nifn = USRXML_ifuser[h,"num"]
	# ifid = [0 .. nifn - 1]
	# ifid = USRXML_ifuser[h,userif,"id"]
	# userif = USRXML_ifuser[h,ifid]
	# userids = USRXML_ifuser[h,userif]
	#
	# nifu = USRXML_ifuser[h,userif,"num"]
	# iuid = [0 .. nifu - 1]
	# username = USRXML_ifuser[h,userif,iuid]
	# userid = USRXML_ifuser[h,userif,username]
	#
	# <user 'name'>
	#
	#   nnets = USRXML_nets[h,"num"]
	#   nid = [0 .. nnets - 1]
	#   nid = USRXML_nets[h,net,"id"]
	#   <net 'cidr'>
	#     net = USRXML_nets[h,nid]
	#     h,userid = USRXML_nets[h,net]
	#
	#   nnets6 = USRXML_nets6[h,"num"]
	#   nid6 = [0 .. nnets6 - 1]
	#   nid6 = USRXML_nets6[h,net6,"id"]
	#   <net6 'cidr6'>
	#     net6 = USRXML_nets6[h,nid6]
	#     h,userid = USRXML_nets6[h,net6]
	#
	#   nnats = USRXML_nats[h,"num"]
	#   tid = [0 .. nnats - 1]
	#   tid = USRXML_nats[h,nat,"id"]
	#   <nat 'cidr'>
	#     nat = USRXML_nats[h,tid]
	#     h,userid = USRXML_nats[h,nat]
	#
	#   nnats6 = USRXML_nats6[h,"num"]
	#   tid6 = [0 .. nnats6 - 1]
	#   tid6 = USRXML_nats6[h,nat6,"id"]
	#   <nat6 'cidr6'>
	#     nat6 = USRXML_nats6[h,tid6]
	#     h,userid = USRXML_nats6[h,nat6]
	#
	# </user>

	# isarray() has side effect in that when variable isn't
	# defined it will be created as "uninitialized scalar"
	# making iterations like "for (v in arr)" to fail.
	delete USRXML__dynmap[1];
	delete USRXML_ifuser[1];
	delete USRXML_ifupdown[1];

	delete USRXML_ifnames[1];

	USRXML_usernets["tname"]  = USRXML_nets["tname"]  = "net";
	USRXML_usernets6["tname"] = USRXML_nets6["tname"] = "net6";

	USRXML_usernats["tname"]  = USRXML_nats["tname"]  = "nat";
	USRXML_usernats6["tname"] = USRXML_nats6["tname"] = "nat6";

	# Note that rest of USRXML_user*[] arrays
	# initialized in usrxml__scope_user()

	return h;
}

#
# Destroy XML document parser instance.
# This is usually called from END{} section.
#

function release_usrxml_consts()
{
	if (!("consts" in USRXML__instance))
		return;

	## Constants (internal, arrays get cleaned)

	# Library messages handling
	delete USRXML__priority2name;

	# Network interfaces
	delete USRXML_types;
	delete USRXML_ifparms;

	# Valid "zone" values
	delete USRXML__zone;

	# Valid "dir" values
	delete USRXML__dir;

	# Zone and direction names to mask mapping
	delete USRXML__zone_dir_bits;

	# Mark as uninitialized
	delete USRXML__instance["consts"];
}

function fini_usrxml_parser(h,    n, p)
{
	if (!is_valid_usrxml_handle(h))
		return USRXML_E_HANDLE_INVALID;

	# Disable library functions at all levels
	delete USRXML__instance[h,"order"];

	# Cleanup saved if/user; if exists
	usrxml__cleanup_if(h);

	# user/if
	n = USRXML_ifnames[h,"num"];
	for (p = 0; p < n; p++)
		usrxml__delete_if_by_id(h, p);
	delete USRXML_ifnames[h,"num"];

	# user net/net6/nat/nat6
	delete USRXML_usernets["tname"];
	delete USRXML_usernets6["tname"];
	delete USRXML_usernats["tname"];
	delete USRXML_usernats6["tname"];

	# net/net6/nat/nat6
	delete USRXML_nets["tname"];
	delete USRXML_nets6["tname"];
	delete USRXML_nats["tname"];
	delete USRXML_nats6["tname"];

	# Dynamic mappings
	usrxml___dyn_clear(h, USRXML_ifnames);
	usrxml___dyn_clear(h, USRXML_ifuser);
	usrxml___dyn_clear(h, USRXML_ifupdown);
	usrxml___dyn_clear(h, USRXML__dynmap);

	# Name of program that uses API
	delete USRXML__instance[h,"prog"];

	# Library messages handling
	delete USRXML__instance[h,"logger","level"];

	delete USRXML__instance[h,"logger","dflt_priority"];
	delete USRXML__instance[h,"result","dflt_priority"];

	delete USRXML__instance[h,"logger","file"];
	delete USRXML__instance[h,"result","file"];

	# Error encountered during XML parsing/validation
	delete USRXML__instance[h,"errno"];

	# Current entry type, scope and depth
	delete USRXML__instance[h,"scope"];
	delete USRXML__instance[h,"depth"];

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
	# Skip all lines until new section

	if ((name,"cmp") in USRXML_types) {
		USRXML__instance[h,"scope"] = USRXML__scope_none;
		# Note that "depth" reset in caller on "scope" setup

		usrxml__clearerrno(h);

		# Signal caller to lookup with new scope
		return 1;
	} else {
		return usrxml_errno(h);
	}
}

function usrxml__scope_none(h, sign, name, val,    n, i)
{
	if ((name,"cmp") in USRXML_types) {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (name != "user" && !usrxml_dev_valid_name(val))
			return usrxml_inv_arg(h, name, val);

		# h,val
		n = h SUBSEP val;

		if (n in USRXML_ifnames) {
			if (USRXML_ifnames[n] != name)
				return usrxml_inv_arg(h, name, val);
		} else {
			n = USRXML_E_NONE;
		}

		if (sign > 0) {
			if (n != USRXML_E_NONE) {
				# h,ifid
				i = h SUBSEP USRXML_ifnames[n,"id"];
				usrxml__save_if(h, val);
			} else {
				i = usrxml__map_add_val(h, val, USRXML_ifnames, name);
				if (int(i) < 0)
					return usrxml_inv_arg(h, name, val);

				# New interfaces are inactive by default and
				# activated on section closure. Old ones marked
				# as inactive if they was active before.

				USRXML_ifnames[h,val,"inactive"] = -1;

				usrxml___dyn_add_val(h, val, val, -1, USRXML_ifupdown);
			}

			USRXML__instance[h,"name"] = val;
			USRXML__instance[h,"inactive"] = 0;
			USRXML__instance[h,"scope"] = (name == "user") ?
				USRXML__scope_user : USRXML__scope_if;
			USRXML__instance[h,"depth"]++;

			usrxml_section_record_fileline(h, name SUBSEP i);
		} else {
			if (n != USRXML_E_NONE) {
				USRXML__instance[h,"name"] = val;

				# Save entry before delete to make
				# it visible to run_usrxml_parser()
				# and their callbacks
				i = usrxml__save_if(h, val);

				usrxml__delete_if_by_name(h, val);

				# We can't return > 0 here as this
				# will collide with parse retry
				return i;
			}
		}
	} else {
		return usrxml_syntax_err(h);
	}

	return USRXML_E_NONE;
}

function usrxml__resolve_refs_cb(h, dyn, iflu, data, arr, dec,
				 i, ifname, lu, rev)
{
	ifname = data["ifname:"];
	lu = data["lu:"];

	# Processing unresolved entries
	if (lu == "unres") {
		# Parent (lower) is last; no <upper en0.32> specified
		#
		# <vlan en0.32>
		#   <lower en0>
		# </vlan>
		#
		# lower-en0.32,en0 = ""
		# unres-en0,en0.32 = "lower"
		#
		# <host en0>
		#   <!--upper en0.32-->
		# </host>
		#
		# upper-en0,en0.32 = ""
		# lower-en0.32,en0 <-- from "unres"

		# {lower|upper}
		lu = arr[h,dyn,iflu];
		usrxml___dyn_del_by_attr(h, dyn, iflu, arr);

		# exchange
		i = ifname;
		ifname = iflu;
		iflu = i;

		# {lower|upper}-ifname (lower-en0.32 from (2))
		dyn = lu "-" ifname;
		rev = (lu == "upper") ? "lower" : "upper";

		# Add interface to activate map
		data[ifname] = 1;

		# Add ("?" -> "")
		i = "";
	} else {
		rev = (lu == "upper") ? "lower" : "upper";

		# Parent (lower) is first; <upper en0.32> specified
		#
		# <host en0>
		#   <upper en0.32>
		# </host>
		#
		# upper-en0,en0.32 = ""
		# unres-en0.32,en0 = "upper"
		#
		# <vlan en0.32>
		#   <lower en0>
		# </vlan>
		#
		# lower-en0.32,en0 = ""
		# unres-en0.32,en0 <-- removed by lower cb; thus no unres

		# Remove from unresolved map
		# unres: @ifname (en0.32, former @iflu) only exists for
		#        case (1); thus usrxml__dyn_get_val() == rev
		#        will not met for case (2) and other cases
		i = "unres-" ifname;
		if (usrxml__dyn_get_val(h, i, iflu, arr) == rev)
			usrxml___dyn_del_by_attr(h, i, iflu, arr);

		i = arr[h,dyn,iflu];
	}

	if (i == "") {
		## Add

		# Upper/lower interface doesn't exist: mark as unresolved
		# unres: @iflu (en0, former @ifname) exists as we called
		#        from dynamic map iterator
		if (!((h,iflu) in USRXML_ifnames)) {
			usrxml___dyn_add_val(h, "unres-" iflu, ifname, lu, arr);
			usrxml___dyn_add_val(h, dyn, iflu, "?", arr);
			return 0;
		}

		data[iflu] = 1;

		rev = rev "-" iflu;

		i = iflu;
		sub(":$", "", i);
		usrxml___dyn_add_val(h, dyn, iflu, i, arr);

		i = ifname;
		sub(":$", "", i);
		usrxml___dyn_add_val(h, rev, ifname, i, arr);

		i = 0;
	} else if (i == "/") {
		## Del

		# Upper/lower interface doesn't exist: remove it and unres
		if (!((h,iflu) in USRXML_ifnames)) {
			usrxml___dyn_del_by_attr(h, "unres-" iflu, ifname, arr);
			usrxml___dyn_del_by_attr(h, dyn, iflu, arr);
			return 0;
		}

		# Was active (i.e. usrxml__dyn_get_val() != "") but now marked
		# for delete by setting to "/" which is not valid ifname
		# according to usrxml_dev_valid_name() helper.

		# Lowers/uppers deletion can activate interface(s):
		#
		# <vlan en0.32.1>
		#   <ip-link link en0.32 mtu 1500 group downlink type @kind@ id 1>
		#   <lower en0.32>
		#   <lower en0.33>    <-- only one lower (parent) allowed
		#   <inactive forced> <-- put to inactive
		# </vlan>
		#
		# <vlan en0.32.2>
		#   <ip-link link en0.32 mtu 1500 group downlink type @kind@ id 2>
		#   <lower en0.32>
		# </vlan>
		#
		# <vlan en0.32>
		#   <ip-link link en0 mtu 1504 type @kind@ id 32>
		#   <upper en0.32.1>
		#   <upper en0.32.2>
		#   <lower en0>
		# </vlan>
		#
		# <vlan en0.33>
		#   <ip-link link en0 mtu 1504 type @kind@ id 33>
		#   <upper en0.32.1>
		#   <lower en0>
		# </vlan>
		#
		# <host en0>
		#   <ip-link mtu 1504>
		# </host>
		#
		# <vlan en0.33>
		#   <-upper en0.32.1> <-- will activate en0.32.1
		# </vlan>

		data[iflu] = 1;

		rev = rev "-" iflu;

		usrxml___dyn_del_by_attr(h, dyn, iflu, arr);

		usrxml___dyn_del_by_attr(h, rev, ifname, arr);

		i = 1;
	} else {
		return 0;
	}

	if (lu == "upper")
		usrxml___act_adjust(h, rev, ifname, arr, i);
	else
		usrxml___act_adjust(h, dyn, iflu, arr, i);

	return 0;
}

function usrxml__resolve_refs(h, ifname,    n, i, v, r, cmp, cb, data)
{
	# h,ifname
	n = h SUBSEP ifname;

	i = ifname;
	if (usrxml__type_is_user(h, ifname, USRXML_ifnames[n]))
		i = i ":";

	# At this point we should not fail since upper/lower
	# links could be modified during resolve.

	cb = "usrxml__resolve_refs_cb";

	# Use ":" suffix which is not valid ifname according
	# to usrxml_dev_valid_name() helper to avoid interface
	# name clash with keys used to pass params to callback.
	data["ifname:"] = i;

	# Resolve interface reference links (order is important)
	data["lu:"] = "lower";
	usrxml__dyn_for_each(h, "lower-" i, cb, data);

	data["lu:"] = "upper";
	usrxml__dyn_for_each(h, "upper-" i, cb, data);

	# Resolve interfaces that refer this one
	data["lu:"] = "unres";
	usrxml__dyn_for_each(h, "unres-" i, cb, data);

	delete data["lu:"];
	delete data["ifname:"];

	# Handle user supplied <inactive> tag, if any

	# h,ifname,"inactive"
	r = n SUBSEP "inactive";

	# v < 0 - inactive   (<inactive forced>)
	# v > 0 - inactive   (<inactive yes>)
	# v = 0 - active     (<inactive no>)
	v = USRXML_ifnames[r];

	# i < 0 - activate   (<inactive no> or <-inactive>)
	# i > 0 - deactivate (<inactive yes>)
	# i = 0 - noop       (no <inactive> tag)
	i = USRXML__instance[h,"inactive"];

	# v + i
	# -----
	#  -1 + -1 == -2  -> -1 # inactive forced -> inactive forced
	#  -1 +  1 ==  0  ->  1 # inactive forced -> inactive yes (ret)
	#
	#   1 + -1 ==  0        # inactive yes -> inactive forced
	#   1 +  1 ==  2  ->  1 # inactive yes -> inactive yes    (ret)
	#
	#   0 + -1 == -1  ->  0 # active -> active
	#   0 +  1 ==  1        # active -> inactive yes   (deactivate)

	if (i > 0) {
		if (v < 0) {
			# inactive forced -> inactive yes
			USRXML_ifnames[r] = 1;
			return;
		}
		if (v > 0) {
			# inactive yes -> inactive yes
			return;
		}
		# active -> inactive yes
		cmp = -1;
	} else {
		# active,inactive (yes|forced) -> inactive forced
		if (i != 0 || v == 0)
			USRXML_ifnames[r] = -1;
		cmp = usrxml__type_cmp(h, ifname);
	}

	if (cmp > 0) {
		usrxml__activate_if_by_name(h, "", ifname);
	} else {
		USRXML_ifnames[n,"cmp"] = -1; # force type cmp
		usrxml__deactivate_if_by_name(h, "", ifname);
		delete USRXML_ifnames[n,"cmp"];

		if (cmp < 0)
			USRXML_ifnames[r] = 1;
	}

	if (!((h,ifname,ifname) in USRXML_ifupdown)) {
		cmp = 1 - 2 * !!USRXML_ifnames[r];
		usrxml___dyn_add_val(h, ifname, ifname, cmp, USRXML_ifupdown);
	}

	# Activate user(s)/interface(s)
	for (ifname in data)
		usrxml__activate_if_by_name(h, "", ifname);
}

function usrxml__scope_if(h, sign, name, val,    n, i, r, a, ifname, type)
{
	ifname = USRXML__instance[h,"name"];

	# h,ifname
	n = h SUBSEP ifname;

	# h,ifid
	i = h SUBSEP USRXML_ifnames[n,"id"];

	type = USRXML_ifnames[n];

	if (sub("^/", "", name) == 1) {
		if (name != type)
			return usrxml_syntax_err(h);

		if (val != "" && val != ifname)
			return usrxml_inv_arg(h, name, val);

		# Host is the only type of interface that can have no options.

		if (type != "host") {
			# h,ifname,"ip-link"
			n = n SUBSEP "ip-link";

			if (n in USRXML_ifnames) {
				if (!usrxml_in_array("tid", USRXML_ifnames[n]))
					return usrxml_missing_arg(h, "type::ip-link");
			} else {
				return usrxml_missing_arg(h, "ip-link");
			}
		}

		usrxml__resolve_refs(h, ifname);

		USRXML__instance[h,"scope"] = USRXML__scope_none;
		USRXML__instance[h,"depth"]--;

		# We can't return > 0 here as this
		# will collide with parse retry
		return i;
	} else if (name == "lower" || name == "upper") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (val == ifname)
			return usrxml_self_ref(h, name, val);

		if (!usrxml_dev_valid_name(val))
			return usrxml_inv_arg(h, name, val);

		n = name "-" ifname;

		if (sign > 0) {
			if (usrxml__dyn_get_val(h, n, val) != val) {
				usrxml__dyn_add_val(h, n, val, "");

				# Replace <upper/lower en0> to <lower/upper en0>
				r = (name == "upper") ? "lower" : "upper";
				r = r "-" ifname;

				if (usrxml__dyn_get_val(h, r, val) != "")
					usrxml__dyn_add_val(h, r, val, "/");
				else
					usrxml__dyn_del_by_attr(h, r, val);
			}
		} else {
			usrxml__dyn_add_val(h, n, val, "/");
		}
	} else if (name == "user") {
		if (val == "")
			return usrxml_ept_val(h, name);

		# For user/if lower/upper relation is handled
		# on user section closure (i.e. on </user> tag)
	} else if (name == "inactive") {
		if (sign > 0) {
			if (val == "yes")
				val = 1;
			else if (val == "no")
				val = -1;
			else if (val == "forced")
				val = 0;
			else if (val == "")
				return usrxml_ept_val(h, name);
			else
				return usrxml_inv_arg(h, name, val);
		} else {
			val = -1;
		}

		if (val != 0)
			USRXML__instance[h,"inactive"] = val;
	} else if (usrxml_match(name, "^([^:]+)(:([[:digit:]]+|*|all))?$", a) &&
		   (name = a[1]) in USRXML_ifparms) {
		i = a[3];

		# h,ifname,name
		n = n SUBSEP name;

		if (sign > 0) {
			if (val == "")
				return usrxml_ept_val(h, name);

			if (i == "*" || i == "all")
				return usrxml_inv_arg(h, name, val);

			gsub("@if@", ifname, val);
			gsub("@kind@", type, val);

			if (name == "ip-link" && type != "host") {
				r = "[[:space:]]type[[:space:]]+" \
				    "([^[:space:]]+)" \
				    "([[:space:]]|$)";
				if (usrxml_match(val, r, a)) {
					if (type != a[1])
						return usrxml_inv_arg(h, name, val);
					type = "";
				}
			}

			usrxml__pref_add_val(n, USRXML_ifnames, val, i, type == "");
		} else {
			if (val != "")
				return usrxml_nept_val(h, name);

			i = usrxml__pref_del_by_id(n, USRXML_ifnames, i);
			if (i < 0)
				return usrxml__seterrno(h, i);
		}
	} else {
		return usrxml_syntax_err(h);
	}

	return USRXML_E_NONE;
}

function usrxml__scope_validate_pipe(i,    m, j, p, val, zones_dirs, zd_bits)
{
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

		zd_bits = USRXML__zone_dir_bits[USRXML_userpipe[j,"zone"],
					USRXML_userpipe[j,"dir"]];
		if (and(zones_dirs, zd_bits))
			return usrxml_section_inv_arg(h, "pipe", "zone|dir", val);

		zones_dirs = or(zones_dirs, zd_bits);
	}

	return USRXML_E_NONE;
}

function usrxml__scope_user(h, sign, name, val,    n, i, username, dyn, iif, uif)
{
	username = USRXML__instance[h,"name"];

	# h,username
	n = h SUBSEP username;

	# h,userid
	i = h SUBSEP USRXML_ifnames[n,"id"];

	if (name == "/user") {
		if (val != "" && val != username)
			return usrxml_inv_arg(h, name, val);

		uif = USRXML_userif[i];

		# h,"if"
		val = h SUBSEP "if";
		if (val in USRXML__instance) {
			iif = USRXML__instance[val];
			delete USRXML__instance[val];
		} else {
			iif = uif;
		}

		# pipe
		val = usrxml__scope_validate_pipe(i);
		if (val != USRXML_E_NONE)
			return val;

		if (uif != iif) {
			dyn = "lower-" username ":";

			if (uif != "")
				usrxml__dyn_add_val(h, dyn, uif, "/");
			if (iif != "")
				usrxml__dyn_add_val(h, dyn, iif, "");

			USRXML_userif[i] = iif;
		}

		usrxml__resolve_refs(h, username);

		USRXML__instance[h,"scope"] = USRXML__scope_none;
		USRXML__instance[h,"depth"]--;

		# We can't return > 0 here as this
		# will collide with parse retry
		return i;
	} else if (name == "if") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if (!usrxml_dev_valid_name(val))
			return usrxml_inv_arg(h, name, val);

		# <if> in <user> equivalent to <lower> in <@if@>
		# with one exception that it can appear only once

		if (sign < 0) {
			uif = USRXML_userif[i];
			if (uif != "" && val != uif)
				return usrxml_inv_arg(h, name, val);
			val = "";
		}

		USRXML__instance[h,"if"] = val;
	} else if (name == "net") {
		if (val == "")
			return usrxml_ept_val(h, name);

		n = val;

		val = ipp_normalize(val, "4");
		if (val == "")
			return usrxml_inv_arg(h, name, n);

		if (sign > 0) {
			n = usrxml__map_add_attr_once(i, val, USRXML_usernets);

			USRXML__instance[h,"n"] = n;
			USRXML__instance[h,"scope"] = USRXML__scope_net;
			USRXML__instance[h,"depth"]++;

			usrxml_section_record_fileline(h, name SUBSEP n);
		} else {
			usrxml__delete_map(i, val,
					   USRXML_nets, USRXML_usernets);
		}
	} else if (name == "net6") {
		if (val == "")
			return usrxml_ept_val(h, name);

		n = val;

		val = ipp_normalize(val, "6");
		if (val == "")
			return usrxml_inv_arg(h, name, n);

		if (sign > 0) {
			n = usrxml__map_add_attr_once(i, val, USRXML_usernets6);

			USRXML__instance[h,"n"] = n;
			USRXML__instance[h,"scope"] = USRXML__scope_net6;
			USRXML__instance[h,"depth"]++;

			usrxml_section_record_fileline(h, name SUBSEP n);
		} else {
			usrxml__delete_map(i, val,
					   USRXML_nets6, USRXML_usernets6);
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
			usrxml__delete_map(i, val,
					   USRXML_nats, USRXML_usernats);
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
			usrxml__delete_map(i, val,
					   USRXML_nats6, USRXML_usernats6);
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

			USRXML__instance[h,"n"] = n;
			USRXML__instance[h,"scope"] = USRXML__scope_pipe;
			USRXML__instance[h,"depth"]++;

			usrxml_section_record_fileline(h, name SUBSEP n);
		} else {
			if (n < USRXML_userpipe[i]) {
				# h,userid,pipeid
				n = i SUBSEP n;

				usrxml__delete_pipe(n);
			}
		}
	} else if (name == "inactive") {
		if (sign > 0) {
			if (val == "yes")
				val = 1;
			else if (val == "no")
				val = -1;
			else if (val == "forced")
				val = 0;
			else if (val == "")
				return usrxml_ept_val(h, name);
			else
				return usrxml_inv_arg(h, name, val);
		} else {
			val = -1;
		}

		if (val != 0)
			USRXML__instance[h,"inactive"] = val;
	} else {
		return usrxml_syntax_err(h);
	}

	return USRXML_E_NONE;
}

function usrxml__scope_pipe(h, sign, name, val,    n)
{
	n = USRXML__instance[h,"n"];

	if (name == "/pipe") {
		if (val != "" && val != USRXML_userpipe[n])
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_user;
		USRXML__instance[h,"depth"]--;

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
			USRXML__instance[h,"depth"]++;

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
	n = USRXML__instance[h,"n"];

	if (name == "/qdisc") {
		if (val != "" && val != USRXML_userpipe[n,"qdisc"])
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_pipe;
		USRXML__instance[h,"depth"]--;
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

function usrxml__scope_nets(h, sign, name, val, umap,    n, o, s)
{
	n = USRXML__instance[h,"n"];
	s = umap["tname"];

	if (name == "/" s) {
		if (val != "" && val != umap[n])
			return usrxml_inv_arg(h, name, val);

		USRXML__instance[h,"scope"] = USRXML__scope_user;
		USRXML__instance[h,"depth"]--;

		if (umap[n,"has_opts"] <= 0)
			delete umap[n,"has_opts"];

		return USRXML_E_NONE;
	} else if (name == "src") {
		if (val == "")
			return usrxml_ept_val(h, name);

		o = val;

		val = ipa_normalize(val, (s == "net") ? "4" : "6");
		if (val == "")
			return usrxml_inv_arg(h, name, o);
	} else if (name == "via") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if ((n, "mac") in umap)
			return usrxml_inv_arg(h, name, val);

		o = val;

		val = ipa_normalize(val, (s == "net") ? "4" : "6");
		if (val == "")
			return usrxml_inv_arg(h, name, o);
	} else if (name == "mac") {
		if (val == "")
			return usrxml_ept_val(h, name);

		if ((n, "via") in umap)
			return usrxml_inv_arg(h, name, val);

		if (s == "net") {
			s = "4";
			o = 32;
		} else {
			s = "6";
			o = 128;
		}

		if (ipp_network(net, s) == net && ipp_length(net, s) != o)
			return usrxml_inv_arg(h, name, val);
	} else if ((n,"has_opts") in umap) {
		return usrxml_syntax_err(h);
	} else {
		USRXML__instance[h,"scope"] = USRXML__scope_user;
		USRXML__instance[h,"depth"]--;

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
	return usrxml__scope_nets(h, sign, name, val, USRXML_usernets);
}

function usrxml__scope_net6(h, sign, name, val)
{
	return usrxml__scope_nets(h, sign, name, val, USRXML_usernets6);
}

function usrxml__ifupdown_cb(h, ifname, iflu, data, arr, dec,    ud, fn)
{
	# ifdown(-1),ifup(1)
	ud = arr[h,ifname,iflu];

	r = "usrxml" SUBSEP "ifupdown";

	# Skip entries not matching current iterator
	if ((dec - 2 * dec * usrxml_in_array("rb", data[r,"a"])) != ud)
		return 0;

	if (ud < 0) {
		# ifdown

		# Find handle in case of deleted entry which
		# is stored as h,USRXML_orig handle.

		if (!((h,ifname) in USRXML_ifnames)) {
			# h,USRXML_orig
			h = h SUBSEP USRXML_orig;

			if (!((h,ifname) in USRXML_ifnames)) {
				# Assert as we must have saved entry
				return USRXML_E_NOENT;
			}
		}
	}

	# "usrxml","ifupdown","fn"
	fn = r SUBSEP "fn";

	fn = (fn in data) ? data[fn] : "";

	if (fn != "")
		return @fn(h, ifname, iflu, data, arr, dec);

	return 0;
}

function usrxml__ifupdown(h, data, a,    b, n, i, p, f, ret, cb, ifname)
{
	if (!isarray(a)) {
		n = "usrxml" SUBSEP "ifupdown" SUBSEP "a";

		if (n in data) {
			if (!isarray(data[n]))
				return USRXML_E_NOT_ARRAY;
		} else {
			# Last resort: create empty array
			data[n][1] = 1;
			delete data[n][1];
		}

		return usrxml__ifupdown(h, data, data[n]);
	}

	# h,"num"
	n = h SUBSEP "num";

	if (!(n in USRXML_ifupdown))
		return USRXML_E_NONE;

	n = USRXML_ifupdown[n];

	if (!("rb" in a)) {
		delete a["fwd","p"];
		delete a["rev","p"];
	}

	if (("rev","p") in a) {
		p = a["rev","p"];
		f = a["rev","f"];
	} else {
		p = n - 1;
		f = "";

		a["rev","p"] = -1;
	}

	cb = "usrxml__ifupdown_cb";

	for (; p >= 0; p--) {
		# h,id
		i = h SUBSEP p;

		# Skip hole entries
		if (!(i in USRXML_ifupdown))
			continue;

		ifname = USRXML_ifupdown[i];

		ret = usrxml___dyn_for_each_reverse_from(h, ifname, cb, data,
							 f, USRXML_ifupdown);
		if (split(ret, b, SUBSEP) != 2)
			continue;

		if ("rb" in a)
			continue;

		a["fwd","p"] = p;
		a["fwd","f"] = b[2];

		a["rb"] = 1;
		usrxml__ifupdown(h, data, a);

		return b[1];
	}

	if (("fwd","p") in a) {
		p = a["fwd","p"];
		f = a["fwd","f"];
	} else {
		p = a["fwd","p"] = 0;
		f = a["fwd","f"] = "";
	}

	for (; p < n; p++) {
		# h,id
		i = h SUBSEP p;

		# Skip hole entries
		if (!(i in USRXML_ifupdown))
			continue;

		ifname = USRXML_ifupdown[i];

		ret = usrxml___dyn_for_each_from(h, ifname, cb, data,
						 f, USRXML_ifupdown);
		if (split(ret, b, SUBSEP) != 2)
			continue;

		if ("rb" in a)
			continue;

		a["rev","p"] = p;
		a["rev","f"] = b[2];

		a["rb"] = 1;
		usrxml__ifupdown(h, data, a);

		return b[1];
	}

	return USRXML_E_NONE;
}

function run_usrxml_parser(h, line, cb, data,
			   n, r, a, b, fn, sign, name, val, ret)
{
	# h,"order"
	n = h SUBSEP "order";

	if (!(n in USRXML__instance))
		return usrxml__seterrno(h, USRXML_E_API_ORDER);

	val = USRXML__instance[n];
	if (val < USRXML__order_parse)
		return usrxml__seterrno(h, USRXML_E_API_ORDER);

	if (val > USRXML__order_parse)
		USRXML__instance[n] = USRXML__order_parse;

	# When called from main block with multiple files on command line
	# FILENAME is set each time to next file being processed
	if (USRXML__instance[h,"filename"] != FILENAME) {
		if (FILENAME == "" || FILENAME == "-")
			FILENAME = "/dev/stdin";
		USRXML__instance[h,"filename"] = FILENAME;
		USRXML__instance[h,"linenum"] = 0;
	}
	USRXML__instance[h,"linenum"]++;

	if (line ~ "^[[:space:]]*(#|$)")
		return USRXML_E_NONE;

	r = "^[[:space:]]*" \
	    "<(|[/?@!+-])([[:alpha:]_][[:alnum:]_:-]+)(|[[:space:]]+[^<>]+)>" \
	    "[[:space:]]*$";

	n = usrxml_match(line, r, a);

	# On line mismatch make sure name (a[2]) is empty to
	# trigger syntax error at any scope as it cannot be
	# empty (see match() regular expression above).
	if (!n)
		delete a;

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
		n = USRXML__instance[h,"depth"];

		fn = "usrxml__scope_" USRXML__instance[h,"scope"];
		ret = @fn(h, sign, name, val);

		if (int(ret) <= 0) {
			# Handle (h) always greather than zero (USRXML_E_NONE)
			if (ret < 0 && n > 0) {
				USRXML__instance[h,"scope"] = USRXML__scope_error;
				USRXML__instance[h,"depth"] = 0;
				usrxml__restore_if(h);
			}
			return ret;
		}
		if (split(ret, a, SUBSEP) >= 2) {
			# h,ifid (2) or h,USRXML_orig,ifid (3)
			if (a[2] == USRXML_orig) {
				a[USRXML_orig] = USRXML_orig;
				a["id"] = a[3];
			} else {
				a["id"] = a[2];
			}
			a["i"] = ret;

			if (cb != "") {
				r = "usrxml" SUBSEP "ifupdown" SUBSEP "a";

				if (isarray(data)) {
					delete data[r];

					data[r]["id"] = a["id"];
					data[r]["i"] = a["i"];
					if (USRXML_orig in a)
						data[r][USRXML_orig] = a[USRXML_orig];

					ret = @cb(h, data, data[r]);
				} else {
					delete b;

					b[r]["id"] = a["id"];
					b[r]["i"] = a["i"];
					if (USRXML_orig in a)
						b[r][USRXML_orig] = a[USRXML_orig];

					ret = @cb(h, b, b[r]);
				}

				if (ret < 0) {
					usrxml__restore_if(h, 1);
					return ret;
				}
			}

			usrxml__cleanup_if(h);
			return a["id"] + 1;
		}
		# ret > 0
	} while (1);
}

#
# Print if/user entry in oneline usrxml format
#

function usrxml__get_inactive_val(i,   val)
{
	val = USRXML_ifnames[i,"inactive"];

	if (val < 0)
		val = "forced";
	else if (val > 0)
		val = "yes";
	else
		val = "";

	return val;
}

function usrxml__get_prefix_lu(h, dyn, iflu,    val)
{
	val = usrxml__dyn_get_val(h, dyn, iflu);

	if (val == "?" || val == "") {
		val = "?";		# unresolved
	} else {
		val = USRXML_ifnames[h,val,"inactive"];
		if (val < 0)
			val = "@";	# <inactive forced>
		else if (val > 0)
			val = "!";	# <inactive yes>
		else
			val = "";	# <inactive no>
	}

	return val;
}

function usrxml__print_if_cb(h, dyn, iflu, data, arr, dec,
			     s1, s2, lu, sign, file)
{
	s1 = data["s1"];
	s2 = data["s2"];
	lu = data["lu"];
	file = data["file"];

	sign = usrxml__get_prefix_lu(h, dyn, iflu);

	if (sub(":$", "", iflu) == 1)
		lu = "user";

	printf s1 "<%s%s %s>" s2, sign, lu, iflu >>file;

	return 0;
}

function usrxml__print_if(h, i, file, s1, s2,
			  n, p, o, t, v, ifname, cb, data, si)
{
	ifname = USRXML_ifnames[i];

	# h,ifname
	i = h SUBSEP ifname;

	t = USRXML_ifnames[i];

	# if
	printf "<%s %s>" s2, t, ifname >>file;

	# inactive
	o = usrxml__get_inactive_val(i);

	if (o != "")
		printf s1 "<inactive %s>" s2, o >>file;

	si = PROCINFO["sorted_in"];
	PROCINFO["sorted_in"] = "@val_num_asc";

	for (n in USRXML_ifparms) {
		# h,ifname,n
		p = i SUBSEP n;

		if (!(p in USRXML_ifnames))
			continue;

		PROCINFO["sorted_in"] = "@ind_num_asc";

		for (o in USRXML_ifnames[p]) {
			if (o !~ "^[[:digit:]]+$")
				continue;

			v = USRXML_ifnames[p][o];

			gsub(ifname, "@if@", v);
			gsub(t, "@kind@", v);

			if (USRXML_ifnames[p]["cnt"] > 1)
				printf s1 "<%s:%u %s>" s2, n, o, v >>file;
			else
				printf s1 "<%s %s>" s2, n, v >>file;
		}

		PROCINFO["sorted_in"] = "@val_num_asc";
	}

	PROCINFO["sorted_in"] = si;

	cb = "usrxml__print_if_cb";

	data["s1"] = s1;
	data["s2"] = s2;
	data["ifname"] = ifname;
	data["file"] = file;

	data["lu"] = "lower";
	usrxml__dyn_for_each(h, "lower-" ifname, cb, data);

	data["lu"] = "upper";
	usrxml__dyn_for_each(h, "upper-" ifname, cb, data);

	printf "</%s>" s2 s2, t >>file;
}

function usrxml__print_umaps(i, umap, file, s1, s2,    n, j, p)
{
	if (!((i,"num") in umap))
		return;

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
			printf s1 "</%s>" s2, name >>file;
		}
	}
}

function usrxml__print_user(h, i, file, s1, s2,
			    n, m, j, p, o, t, username)
{
	username = USRXML_ifnames[i];

	# h,username
	o = h SUBSEP username;

	t = USRXML_ifnames[o];

	# user
	printf "<%s %s>" s2, t, username >>file;

	# inactive
	o = usrxml__get_inactive_val(o);

	if (o != "")
		printf s1 "<inactive %s>" s2, o >>file;

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
	n = USRXML_userif[i];
	if (n != "") {
		o = usrxml__get_prefix_lu(h, "lower-" username ":", n);

		printf s1 "<%sif %s>" s2, o, n >>file;
	}

	# net
	usrxml__print_umaps(i, USRXML_usernets, file, s1, s2);
	# net6
	usrxml__print_umaps(i, USRXML_usernets6, file, s1, s2);
	# nat
	usrxml__print_umaps(i, USRXML_usernats, file, s1, s2);
	# nat6
	usrxml__print_umaps(i, USRXML_usernats6, file, s1, s2);

	print "</user>" s2 >>file;
}

function print_usrxml_entry_oneline(h, idn, file, s1, s2,    i, o, t)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	# h,idn
	i = h SUBSEP idn;

	if (!(i in USRXML_ifnames))
		return usrxml__seterrno(h, USRXML_E_NOENT);

	if (idn ~ "^[[:digit:]]+$") {
		t = "";
	} else {
		t = USRXML_ifnames[i];

		idn = USRXML_ifnames[i,"id"];

		# h,idn
		i = h SUBSEP idn;
	}

	if (file == "")
		file = "/dev/stdout";

	if (usrxml__type_is_user(h, idn, t))
		usrxml__print_user(h, i, file, s1, s2);
	else
		usrxml__print_if(h, i, file, s1, s2);

	# Callers should flush output buffers using fflush(file) to ensure
	# all pending data is written to a file or named pipe before quit.

	return idn + 1;
}

function print_usrxml_entry(h, idn, file)
{
	return print_usrxml_entry_oneline(h, idn, file, "\t", "\n");
}

function print_usrxml_entries_oneline(h, file, s1, s2,    n, i, p, o, stdout)
{
	o = usrxml_errno(h);
	if (o != USRXML_E_NONE)
		return o;

	stdout = "/dev/stdout";

	if (file == "")
		file = stdout;

	n = USRXML_ifnames[h,"num"];
	for (p = 0; p < n; p++) {
		# h,id
		i = h SUBSEP p;

		# Skip holes entries
		if (!(i in USRXML_ifnames))
			continue;

		if (usrxml__type_is_user(h, p))
			usrxml__print_user(h, i, file, s1, s2);
		else
			usrxml__print_if(h, i, file, s1, s2);
	}

	fflush(file);

	if (file != stdout)
		close(file);

	return USRXML_E_NONE;
}

function print_usrxml_entries(h, file)
{
	return print_usrxml_entries_oneline(h, file, "\t", "\n");
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
			ret = USRXML_E_NONE;
		}
	}

	if (file != stdin)
		close(file);

	if (rc < 0) {
		ret = usrxml__seterrno(h, USRXML_E_GETLINE);
	} else if (ret == USRXML_E_NONE) {
		# Check for open sections
		rc = USRXML__instance[h,"depth"];
		if (rc > 0)
			ret = usrxml_scope_err(h, USRXML__instance[h,"scope"]);
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
	if (file != "")
		printf "" >file;

	print_usrxml_entries(h, file);
}
