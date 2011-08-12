#!/usr/bin/perl -w
# Author: David Erickson
# Date: 11/03/07

use Error qw(:try);
use IO::Socket;
use NF::RegressLib;
use NF::PacketLib;
use strict;

# Move to SCONE's root directory
chdir $ENV{'NF_DESIGN_DIR'}.'/sw' or die "Can't cd: $!\n";

# Default to an error exit code
my $exitCode = 1;

my $pid;
# Fork off a process for SCONE
if (!($pid = fork)) {
	#
	# Run SCONE from this process
	#
	exec "./scone", "-r", "rtable.netfpga";
	die "Failed to launch SCONE: $!";
} else {
	try {
		#
		# Run control from this process
		#

		# Wait for router to initialize
		sleep(1);

		# Create a Telnet Socket to the router
		my $sock = new IO::Socket::INET (
			PeerAddr => '192.168.0.2',
			PeerPort => 23,
			Proto => 'tcp',
		);
		die "Failed to create socket: $!\n" unless $sock;

		# Send the eth1 (nf2c1) disable command to the telnet socket
		print $sock "ip interface eth1 down\n";
		sleep(1);

		# Close Socket
		close($sock);

		# Launch PCAP listenting to eth1,eth2
		my @interfaces = ("eth1","eth2",);
		nftest_init(\@ARGV,\@interfaces,);
		nftest_start_vhosts( \@interfaces );

		# Register the router's IP addresses
		nftest_register_router('eth1', '00:00:00:00:00:01', '192.168.0.2');
		nftest_register_router('eth2', '00:00:00:00:00:02', '192.168.1.2');

		# Register the hosts
		nftest_create_host('eth1', 'aa:bb:cc:dd:ee:ff', '192.168.0.1');
		nftest_create_host('eth2', 'ca:fe:f0:0d:00:00', '192.168.1.1');

		# send 100 packets out of eth1->nf2c0, ensure none come out from nf2c1->eth2
		foreach (1..100) {
			nftest_send_IP('192.168.0.1', '192.168.1.1', len => 100);
		}

		# Expect various packets
		nftest_expect_ARP_exchange('192.168.0.1', '192.168.0.2');

		# Give it 5 seconds to make sure no packets come through
		sleep 5;

		# Turn off PCAP
		nftest_finish();

		# Get the number of packets snooped on eth2, should have received 0
		my $unexpected_packets = nftest_get_unexpected("eth2");

		if ($unexpected_packets == 0) {
			print "SUCCESS!\n";
			$exitCode = 0;
		} else {
			print "FAIL: $unexpected_packets unexpected packets\n";
			$exitCode = 1;
		}
	} catch Error with {
		# Catch and print any errors that occurred during control processing
		my $ex = shift;
		print $ex->stringify();
	} finally {
		# Ensure SCONE is killed even if we have an error
		kill 9, $pid;
		# Exit with the resulting exit code
		exit($exitCode);
	};
}
