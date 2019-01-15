#!/usr/bin/gawk -f

# Source USRXML database parsing library.
@include "/netctl/lib/awk/libusrxml.awk"

################################################################################

BEGIN{
	RS	= ">"

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
	line = ($0 !~ /^[[:space:]]*$/) ? $0">" : "";
	if (run_usr_xml_parser(line) < 0)
		exit 1;
}

END{
	##
	## Finish user database parsing.
	##
	if (fini_usr_xml_parser() < 0)
		exit 1;

	for (userid = 0; userid < USRXML_nusers; userid++)
		print_usr_xml_entry(userid);
}
