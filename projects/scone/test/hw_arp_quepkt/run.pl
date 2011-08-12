#!/usr/bin/perl
# Author: Jianying Luo
# Date: 11/05/2007

# Objective:
# Create a route from interface 1 to interface 2. Send 2 packets in interface 1 that
# are destined for an ip on the route out of interface 2, an arp request should come
# out interface 2, reply with an arp reply, then ensure that both packets are sent
# out of interface 2 with the correct ethernet mac destinations.

use NF::Base "projects/reference_router/lib/Perl5";
use Error qw(:try);
use IO::Socket;
use NF::RegressLib;
use RegressRouterLib;
use NF::PacketLib;
use reg_defines_reference_router;
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

		my $host1_MAC = "aa:bb:cc:dd:ee:f0";
		my $host2_MAC = "aa:bb:cc:dd:ee:f1";

		my $host1_IP = "192.168.0.100";
		my $host2_IP = "192.168.1.100";

		my $router1_MAC = "00:00:00:00:00:01";
		my $router2_MAC = "00:00:00:00:00:02";

		my $router1_IP = "192.168.0.2";
		my $router2_IP = "192.168.1.2";

		# launch PCAP listenting to eth1, eth2
		my @interfaces = ( "eth1", "eth2", );
		nftest_init( \@ARGV, [ @interfaces, 'nf2c0' ] );
		nftest_start_vhosts( \@interfaces );

		# Register the router's IP addresses
		nftest_register_router( 'eth1', $router1_MAC, $router1_IP );
		nftest_register_router( 'eth2', $router2_MAC, $router2_IP );

		# Register the hosts
		nftest_create_host( 'eth1', $host1_MAC, $host1_IP );
		nftest_create_host( 'eth2', $host2_MAC, $host2_IP );

		# Send a packet
		my $pkt = nftest_send_IP( $host1_IP, $host2_IP, len => 100 );
		$pkt->set(
			SA => $router2_MAC,
			DA => $host2_MAC
		);
		$pkt->decrement_ttl;
		nftest_vhost_expect( $host2_IP, $pkt->packed );

		my $pkt = nftest_send_IP( $host1_IP, $host2_IP, len => 100 );
		$pkt->set(
			SA => $router2_MAC,
			DA => $host2_MAC
		);
		$pkt->decrement_ttl;
		nftest_vhost_expect( $host2_IP, $pkt->packed );

		# Expect various packets
		nftest_expect_ARP_exchange( $host1_IP,   $router1_IP );
		nftest_expect_ARP_exchange( $router2_IP, $host2_IP );

		#--------------------------------------------
		# Give it 1 seconds to make sure no packets come through
		sleep(1);
		print "Done sleep\n";

		my $total_errors = 0;

		print "Checking ARP table entry\n";
		nftest_check_ARP_table_entry( 'nf2c0', 0, $host2_IP, $host2_MAC );
		my @badReads    = nftest_get_badReads();
		my $readFailCnt = $#badReads + 1;
		if ( @badReads != () ) {
			print
			  "FAIL: nftest_check_ARP_table_entry() sees $readFailCnt error\n";
			$total_errors += $readFailCnt;
		}

		print "Checking pkts\n";

		nftest_finish();
		$total_errors += nftest_print_vhost_errors();

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
