#!/usr/bin/gawk -f

function mac_normalize(str, sep,    nfields, v, s, o, t, ret)
{
	if (sep != ":" && sep != "-" && sep != "." && sep != "")
		return "";

	nfields = split(str, s, "[[:xdigit:]]{2}", o);
	if (nfields != 7)
		return "";

	# begin and end are ""
	if (s[1] != "" || s[7] != "")
		return "";

	v = s[3];
	if (v == ".") {
		# 1122.3344.5566
		if (s[5] != ".")
			return "";
		t = "";
		# mark entry for [s]kip
		s[5] = "s";
	} else if (v == ":" || v == "-" || v == "") {
		# 11:22:33:44:55:66, 11-22-33-44-55-66 and 112233445566
		t = v;
	} else {
		return "";
	}

	# mark entries for [s]kip
	s[1] = s[7] = s[3] = "s";

	for (v = 1; v <= nfields; v++) {
		if (s[v] == "s")
			continue;
		if (s[v] != t)
			return "";
	}

	ret = "";

	for (v = 1; v < nfields; v++) {
		if (v >= nfields - 1)
			t = "";
		else if (sep == ".")
			t = (v % 2 == 0) ? sep : "";
		else
			t = sep;
		ret = ret o[v] t;
	}

	return ret;
}

function mac2colon(str)
{
	return mac_normalize(str, ":");
}

function mac2dash(str)
{
	return mac_normalize(str, "-");
}

function mac2cisco(str)
{
	return mac_normalize(str, ".");
}

function mac2raw(str)
{
	return mac_normalize(str, "");
}

function is_valid_mac(str)
{
	return mac_normalize(str, "") != "";
}

function ip4_normalize(str,    nfields, v, vals)
{
	nfields = split(str, vals, ".");
	# "1.1.1.1" gives four fields
	if (nfields != 4)
		return "";
	while (nfields) {
		v = vals[nfields];
		# there might be '-' or '+'
		if (v !~ "^[[:digit:]]+$")
			return "";
		if (v < 0 || v > 255)
			return "";
		nfields--;
	}
	return sprintf("%d.%d.%d.%d", vals[1], vals[2], vals[3], vals[4]);
}

function is_valid_ipv4(str)
{
	return ip4_normalize(str) != "";
}

function __ipv4_to_int(str,    nfields, v, vals)
{
	nfields = split(str, vals, ".");
	if (nfields != 4)
		return -1;

	vals[1] = lshift(vals[1], 24);
	vals[2] = lshift(vals[2], 16);
	vals[3] = lshift(vals[3],  8);
	vals[4] = lshift(vals[4],  0);

	vals[1] = or(vals[1], vals[4]);
	vals[2] = or(vals[2], vals[3]);

	return or(vals[1], vals[2]);
}

function ipv4_to_int(str)
{
	str = ip4_normalize(str);
	if (str == "")
		return -1;
	return __ipv4_to_int(str);
}

function ip6_normalize(str,    nfields, v, vals, mfields, n, short, nshort, ishort)
{
	n = nfields = split(str, vals, ":");

	# "::" gives three fields
	if (nfields < 3)
		return "";

	# empty, hex or dotted-quad
	v = vals[n];
	if (v !~ "^[[:xdigit:]]{0,4}$") {
		v = ip4_normalize(v)
		if (v == "")
			return v;
		short = __ipv4_to_int(v);
		# 1:2:3:4:5:6:1.1.1.1 -> 1:2:3:4:5:6:0101:0101
		vals[n] = sprintf("%x", rshift(short, 16));
		n = ++nfields;
		vals[n] = sprintf("%x", and(short, 0xffff));
	}

	# 1:2:3:4:5:6:7::
	short = v == "";

	# 1:2:3:4:5:6:7:8 or 1:2:3:4:5:6:7::
	mfields = 8 + short;

	# ::1:2:3:4:5:6:7
	if (vals[1] == "")
		mfields++;

	# no more than max fields
	if (nfields > mfields)
		return "";

	nshort = short;
	ishort = 0;

	# :1, :1:2, ...
	vals[0] = "1";

	# :1:2
	while (n > 0) {
		v = vals[--n];
		if (v == "") {
			if (short > 1) {
				# ::, ::1, ::1:2, ...
				if (n <= 1)
					break;
				return "";
			}
			if (n > 1) {
				nshort += n;
				# 1:::2
				short++;
			}
			short++;
		} else {
			# :1, :1:2, ..., 1:, 1:2:, ...
			if (short == 1)
				return "";
			if (v !~ "^[[:xdigit:]]{1,4}$")
				return "";
			if (short && !ishort) {
				nshort -= n;
				ishort = n;
			}
		}
	}

	# no short: max fields
	if (!short && nfields != mfields)
		return "";

	mfields = 8;
	v = "";

	for (n = 1; n <= ishort; n++) {
		short = vals[n];
		short = strtonum("0x" short);
		v = v sprintf("%x:", short);
	}

	nshort = mfields - (nfields - nshort);
	while (nshort) {
		v = v "0:";
		nshort--;
	}

	for (; n <= nfields; n++) {
		short = vals[n];
		if (short == "")
			continue;
		short = strtonum("0x" short);
		v = v sprintf("%x:", short);
	}

	gsub(":$", "", v);

	return v;
}

function is_valid_ipv6(str)
{
	return ip6_normalize(str) != "";
}

function ipa_normalize(str,    addr)
{
	addr = ip4_normalize(str);
	if (addr != "")
		return addr;
	addr = ip6_normalize(str);
	if (addr != "")
		return addr;
	return "";
}

function ipa_compare(str1, str2,    v1, v2)
{
	v1 = ipa_normalize(str1);
	if (v1 == "")
		return -1;
	v2 = ipa_normalize(str2);
	if (v2 == "")
		return -1;
	return v1 == v2;
}

function ipa_equal(str1, str2)
{
	return ipa_compare(str1, str2) == 1;
}

function ipa_not_equal(str1, str2)
{
	return ipa_compare(str1, str2) == 0;
}

function ipp_length(str,    nfields, vals, plen)
{
	nfields = split(str, vals, "/");
	if (nfields != 2)
		return -1;

	plen = vals[2];
	if (plen !~ "^[[:digit:]]{1,3}$")
		return -1;

	if (plen > 128)
		return -1;

	return plen;
}

function ipp_normalize(str,    nfields, vals, addr, plen)
{
	nfields = split(str, vals, "/");
	if (nfields != 2)
		return "";

	plen = vals[2];
	if (plen !~ "^[[:digit:]]{1,3}$")
		return "";

	addr = ip4_normalize(vals[1]);
	if (addr != "") {
		if (plen > 32)
			return "";
	} else {
		addr = ip6_normalize(vals[1]);
		if (addr == "")
			return "";
		if (plen > 128)
			return "";
	}

	return addr "/" plen;
}

function ipp_network(str,    nfields, o, b, m, vals, sep, addr, plen)
{
	nfields = split(str, vals, "/");
	if (nfields != 2)
		return "";

	plen = vals[2];
	if (plen !~ "^[[:digit:]]{1,3}$")
		return "";

	addr = ip4_normalize(vals[1]);
	if (addr != "") {
		if (plen > 32)
			return "";
		sep = ".";
		split(addr, vals, sep);
		o = int(plen / 8) + 1;
		b = plen % 8;
		if (b != 0) {
			m = compl(rshift(0xff, b));
			vals[o] = and(vals[o], m);
			o++;
		}
	} else {
		addr = ip6_normalize(vals[1]);
		if (addr == "")
			return "";
		if (plen > 128)
			return "";
		sep = ":";
		split(addr, vals, sep);
		o = int(plen / 16) + 1;
		b = plen % 16;
		if (b != 0) {
			m = compl(rshift(0xffff, b));
			vals[o] = sprintf("%x", and(strtonum("0x" vals[o]), m));
			o++;
		}
	}

	while (vals[o] != "")
		vals[o++] = "0";

	str = "";
	for (o = 1; vals[o] != ""; o++)
		str = str vals[o] sep;
	gsub(sep "$", "", str);
	str = str "/" plen;

	return str;
}

function is_ipp_network(str)
{
	str = ipp_normalize(str);
	if (str == "")
		return 0;
	return ipp_network(str) == str;
}

function is_ipp_host(str)
{
	str = ipp_normalize(str);
	if (str == "")
		return 0;
	return ipp_network(str) != str;
}

function ipa_do_match(net, address,    nfields, o, b, m, v, valsN, valsA, sep, addr, plen)
{
	nfields = split(net, valsN, "/");
	if (nfields != 2)
		return -1;

	plen = valsN[2];
	if (plen !~ "^[[:digit:]]{1,3}$")
		return -1;

	address = ipa_normalize(address);
	if (address == "")
		return -1;
	split(address, valsA, "[.:]", sep);

	addr = ip4_normalize(valsN[1]);
	if (addr != "") {
		if (plen > 32)
			return -1;
		if (sep[1] != ".")
			return -1;
		split(addr, valsN, ".");
		o = int(plen / 8) + 1;
		b = plen % 8;
		if (b != 0)
			m = compl(rshift(0xff, b));
	} else {
		addr = ip6_normalize(valsN[1]);
		if (addr == "")
			return -1;
		if (plen > 128)
			return -1;
		if (sep[1] != ":")
			return -1;
		split(addr, valsN, ":");
		o = int(plen / 16) + 1;
		b = plen % 16;
		if (b != 0)
			m = compl(rshift(0xffff, b));
	}

	if (b != 0) {
		v = xor(valsN[o], valsA[o]);
		if (and(v, m))
			return 0;
	}

	while (--o > 0) {
		if (valsN[o] != valsA[o])
			return 0;
	}

	return 1;
}

function ipa_match(net, address)
{
	return ipa_do_match(net, address) == 1;
}

function ipa_not_match(net, address)
{
	return ipa_do_match(net, address) == 0;
}
