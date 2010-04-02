#!/usr/local/bin/perl -w
# nf2_compare_evts.pl
#

##############################################
# $Id: nf2_compare_evts.pl 6042 2010-04-01 05:59:23Z grg $
#
# Run the event matching subroutine
#
##############################################

my $testDir=$ENV{NF_WORK_DIR}."/verif";
if(EvtsLib::compare_rcvd_evts($testDir . "/$testName/packet_data/egress_port_1", 0x9999)){
	print "--- Test Failed. \n";
	system "touch FAIL";
	exit 1;
}
