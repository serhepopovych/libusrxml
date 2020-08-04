#!/usr/bin/gawk -f

# Source USRXML database parsing library.
@include "@target@/netctl/lib/awk/libusrxml.awk"

################################################################################

function run_usrxml_parser_cb(h, data, a)
{
	return print_usrxml_entry_oneline(h, a["id"]);
}

BEGIN{
	##
	## Initialize user database parser
	##
	h = init_usrxml_parser("users_xml2lst.awk");
	if (h < 0)
		exit 1;
}

{
	##
	## Parse user database
	##
	line = $0;
	if (run_usrxml_parser(h, line, "run_usrxml_parser_cb") < 0)
		exit 1;
}

END{
	##
	## Finish user database parsing
	##
	if (fini_usrxml_parser(h) < 0)
		exit 1;
}
