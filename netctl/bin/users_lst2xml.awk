#!/usr/bin/gawk -f

# Source USRXML database parsing library.
@include "@target@/netctl/lib/awk/libusrxml.awk"

################################################################################

BEGIN{
	RS	= ">"

	##
	## Initialize user database parser
	##
	h = init_usrxml_parser();
	if (h < 0)
		exit 1;
}

{
	##
	## Parse user database
	##
	line = ($0 !~ /^[[:space:]]*$/) ? $0">" : "";
	if (run_usrxml_parser(h, line) < 0)
		exit 1;
}

END{
	##
	## Print entries
	##
	n = USRXML_users[h,"num"];
	for (u = 0; u < n; u++)
		print_usrxml_entry(h, u);

	##
	## Finish user database parsing
	##
	if (fini_usrxml_parser(h) < 0)
		exit 1;
}
