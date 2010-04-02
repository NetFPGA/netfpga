#!/usr/bin/perl -w

#
# Script to verify the correctness of the SRAM output
#
# $Id: check_sram.pl 6036 2010-04-01 00:30:59Z grg $
#

use strict;
use NF::SimExtraCheck;


# Check the log for errors
my $failCount = `grep -i "INFO: SRAM test:" $log | tail -n 1 | grep -c -i fail`;
chomp $failCount;
if ($? >> 8 != 0 || $failCount ne '1') {
	warn "Error: Expected but did not find SRAM test failure";
	exit 1;
}
else {
	print "OK: Saw SRAM test failure as expected\n";
	exit 0;
}
