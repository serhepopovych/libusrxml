#!/usr/bin/gawk -f

# Source USRXML database parsing library.
@include "@target@/netctl/lib/awk/libusrxml.awk"

################################################################################

BEGIN{
	##
	## Initialize user database parser.
	##
	if (init_usr_xml_parser() < 0)
		exit 1;
}

{
	##
	## Parse user database.
	##
	if (run_usr_xml_parser($0) < 0)
		exit 1;
}

END{
	##
	## Finish user database parsing.
	##
	if (fini_usr_xml_parser() < 0)
		exit 1;

	for (userid = 0; userid < USRXML_nusers; userid++)
		print_usr_xml_entry_oneline(userid);
}
