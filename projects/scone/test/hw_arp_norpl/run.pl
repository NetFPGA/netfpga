#!/usr/bin/perl
# Author: Jianying Luo
# Date: 11/05/2007

# Objective:
# Sending an arp request in to the software router for an ip address
# that is not one of its interfaces does not return an arp reply

use Error qw(:try);
use IO::Socket;
use NF::RegressLib;
use NF::PacketLib;
use strict;

# Move to SCONE's root directory
chdir $ENV{'NF_DESIGN_DIR'}.'/sw' or die "Can't cd: $!\n";

my $pid;

# Fork off a process for SCONE
if ( !( $pid = fork ) ) {

	#
	# Run SCONE from this process
	#
	exec "./scone", "-r", "rtable.netfpga";
	die "Failed to launch SCONE: $!";
}
else {
	my $exitCode = 1;
	try {

		#
		# Run control from this process
		#

		# Wait for router to initialize
		sleep(1);

		# monitor if pkts get out from SCONE
		# launch PCAP listenting to eth1, eth2
		my @interfaces = ( "eth1", "eth2", );
		nftest_init( \@ARGV, \@interfaces );
		nftest_start_vhosts( \@interfaces );

		# Register the router's IP addresses
		# Note: The IP addresses are deliberately BOGUS!
		nftest_register_router( 'eth1', '00:00:00:00:00:01', '192.168.0.200' );
		nftest_register_router( 'eth2', '00:00:00:00:00:02', '192.168.1.200' );

		# Register the hosts
		nftest_create_host( 'eth1', 'aa:bb:cc:dd:ee:f0', '192.168.0.1' );
		nftest_create_host( 'eth2', 'ca:fe:f0:0d:00:00', '192.168.1.1' );

		# Send in a pair of ARPs
		nftest_send_ARP_req( '192.168.0.1', '192.168.0.200' );
		nftest_send_ARP_req( '192.168.1.1', '192.168.1.200' );

		# Expect the ARP exchanges
		nftest_expect_ARP_request( '192.168.0.1', '192.168.0.200' );
		nftest_expect_ARP_request( '192.168.1.1', '192.168.1.200' );

		sleep(2);

		# Finish and print errors, if any
		nftest_finish();
		my $total_errors = nftest_print_vhost_errors();

		if ( $total_errors == 0 ) {
			print "SUCCESS!\n";
			$exitCode = 0;
		}
		else {
			print "FAIL: $total_errors errors\n";
			$exitCode = 1;
		}
	}
	catch Error with {

		# Catch and print any errors that occurred during control processing
		my $ex = shift;
		if ($ex) {
			print $ex->stringify();
		}
	}
	finally {

		# Ensure SCONE is killed even if we have an error
		kill 9, $pid;

		# Exit with the resulting exit code
		exit($exitCode);
	};

}    # test process
