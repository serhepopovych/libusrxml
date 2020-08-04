#!/usr/bin/gawk -f

# Source USRXML database parsing library.
@include "@target@/netctl/lib/awk/libusrxml.awk"

################################################################################

function run_usrxml_parser_cb(h, data, a)
{
	return print_usrxml_entry(h, a["id"]);
}

BEGIN{
	RS	= ">"

	##
	## Initialize user database parser
	##
	h = init_usrxml_parser("users_lst2xml.awk", 1);
	if (h < 0)
		exit 1;
}

{
	##
	## Parse user database
	##
	line = ($0 !~ /^[[:space:]]*$/) ? $0">" : "";
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
