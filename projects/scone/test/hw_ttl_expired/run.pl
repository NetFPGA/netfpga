#!/usr/bin/perl
# Author: Sara Bolouki
# Date: 11/14/2007

# Objective:
# Ensure that a packet with ttl 1 sent to the software component received an icmp ttl expired message

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

	# Run SCONE from this process
	exec "./scone", "-r", "rtable.netfpga";
	die "Failed to launch SCONE: $!";
}
else {
	my $exitCode = 1;
	try {

		# Run control from this process

		# Wait for router to initialize
		sleep(1);

		# launch PCAP listenting to eth1, eth2
		my @interfaces = ( "eth1", "eth2" );
		nftest_init( \@ARGV, \@interfaces );
		nftest_start_vhosts( \@interfaces );

		# Register the router's IP addresses
		nftest_register_router('eth1', '00:00:00:00:00:01', '192.168.0.2');
		nftest_register_router('eth2', '00:00:00:00:00:02', '192.168.1.2');

		# Register the hosts
		nftest_create_host('eth1', 'aa:bb:cc:dd:ee:f0', '192.168.0.100');
		nftest_create_host('eth2', 'ca:fe:f0:0d:00:00', '192.168.1.100');

		# Send a packet
		my $pkt = nftest_send_IP('192.168.0.100', '192.168.1.100', len => 100, ttl => 1);

		# Expect various packets
		nftest_expect_ARP_exchange('192.168.0.100', '192.168.0.2');
		nftest_expect_ARP_exchange('192.168.0.2', '192.168.0.100');

		# Expect ICMP time exceeded message
		nftest_expect_ICMP_time_exceeded('192.168.0.100', '192.168.0.2', $pkt);

		sleep(2);
		print "Done sleep\n";

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
}
