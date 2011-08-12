#!/usr/bin/perl
# Author: Jianying Luo
# Date: 11/06/2007

# Objective:
#  Create 4 individual packets, one that is ip but not version 4,
#  one with options, one that is fragmented, one with a ad checksum,
#  and ensure none of them are routed.

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

		#---------------------------------------------
		# pkt 1 : ip w/ version not equal to 4
		nftest_send_IP( $host1_IP, $host2_IP, len => 100, version => 1 );

		#---------------------------------------------
		# pkt 2 : ip hdr w/ option
		nftest_send_IP( $host1_IP, $host2_IP, len => 100, ip_options => [0x0, 0x0, 0x0, 0x0], ip_hdr_len => 6 );

		#---------------------------------------------
		# pkt 3: ip fragment (MF=1, frag offset=0x10 in 8-byte unit)
		nftest_send_IP( $host1_IP, $host2_IP, len => 100, frag => 0x2010 );

		#---------------------------------------------
		# pkt 4: w/ bad checksum
		nftest_send_IP( $host1_IP, $host2_IP, len => 100, checksum => 0x0 );

		# Expect various packets
		nftest_expect_ARP_exchange( $host1_IP,   $router1_IP );

		#--------------------------------------------
		# Give it 1 seconds to make sure no packets come through
		sleep(1);
		print "Done sleep\n";

		print "Checking pkts\n";

		nftest_finish();
		my $total_errors += nftest_print_vhost_errors();

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
