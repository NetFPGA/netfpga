#!/usr/bin/perl -w

#
# Script to verify the correctness of the PHY output
#
# $Id: check_phy.pl 6036 2010-04-01 00:30:59Z grg $
#

use strict;
use NF::SimExtraCheck;


# Check the log for errors
my $failCount = `grep -i "INFO: PHY test:" $log | tail -n 1 | grep -c -i pass`;
chomp $failCount;
if ($? >> 8 != 0 || $failCount ne '1') {
	warn "Error: Expected but did not find PHY test pass";
	exit 1;
}
else {
	print "OK: Saw PHY test pass as expected\n";
	exit 0;
}
