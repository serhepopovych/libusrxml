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
	if (run_usrxml_parser(h, line) != USRXML_E_NONE)
		exit 1;
}

END{
	##
	## Exit code
	##
	rc = 0;

	##
	## Perform final validations and return result
	##
	rc += result_usrxml_parser(h) != USRXML_E_NONE;

	##
	## Print entries
	##
	if (!rc) {
		n = USRXML_users[h];
		for (u = 0; u < n; u++)
			print_usrxml_entry(h, u);
	}

	##
	## Finish user database parsing
	##
	rc += fini_usrxml_parser(h);

	##
	## Exit with given code
	##
	exit rc;
}
