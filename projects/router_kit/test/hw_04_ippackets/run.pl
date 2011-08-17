#!/usr/bin/perl
# Author: David Erickson
# Date: 11/20/2007

# Objective: Test IP Packet Forwarding

use NF::Base "projects/reference_router/lib/Perl5";
use Error qw(:try);
use IO::Socket;
use NF::RegressLib;
use NF::PacketLib;
use RegressRouterLib;
use reg_defines_reference_router;
use strict;
use Time::HiRes qw(usleep);

# Move to Router Kit's Directory
chdir $ENV{'NF_DESIGN_DIR'}.'/sw' or die "Can't cd: $!\n";

my $pid;

# Fork off a process for Router Kit
if ( !( $pid = fork ) ) {
	# Run Router Kit from this process
	exec "./rkd";
	die "Failed to launch Router Kit: $!";
} else {
	my $exitCode = 1;
	try {
		# Run control from this process

		# Wait for initialization
		sleep(1);

		my $vhost_0_ip = '10.10.0.100';
		my $vhost_1_ip = '10.10.1.100';
		my $nf2c0_ip = '10.10.0.1';
		my $nf2c1_ip = '10.10.1.1';
		nftest_init( \@ARGV, ["nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2"]);

		# launch PCAP listenting to eth1, eth2
		nftest_start_vhosts(["eth1", "eth2"]);

		nftest_ignore_igmp("eth1", "eth2");
		nftest_ignore_mdns("eth1", "eth2");

		# Register the router's IP addresses
		nftest_register_router('eth1', nftest_get_router_MAC("nf2c0"), $nf2c0_ip);
		nftest_register_router('eth2', nftest_get_router_MAC("nf2c1"), $nf2c1_ip);

		# Register the hosts
		nftest_create_host('eth1', 'aa:bb:cc:dd:ee:ff', $vhost_0_ip);
		nftest_create_host('eth2', 'ff:ee:dd:cc:bb:aa', $vhost_1_ip);

		# Expect various packets
		nftest_expect_ARP_exchange($vhost_0_ip, $nf2c0_ip);
		nftest_expect_ARP_exchange($nf2c1_ip, $vhost_1_ip);

		# Send packets
		for (0..30) {
			my $pkt = nftest_send_IP($vhost_0_ip, $vhost_1_ip, len => (100 + $_));
			# 1ms sleep between each packet send
			`usleep 1000`;

			# Expect the packet at the destination
			$pkt->set(
				SA => nftest_get_vhost_mac($nf2c1_ip),
				DA => nftest_get_vhost_mac($vhost_1_ip)
			);

			$pkt->decrement_ttl;
			nftest_vhost_expect($vhost_1_ip, $pkt->packed);
		}

		sleep(1);
		# Finish and print errors, if any
		my $total_errors = nftest_print_errors(nftest_finish());
		if ( $total_errors == 0 ) {
			print "SUCCESS!\n";
			$exitCode = 0;
		} else {
			print "FAIL: $total_errors errors\n";
			$exitCode = 1;
		}
	} catch Error with {
		# Catch and print any errors that occurred during control processing
		my $ex = shift;
		if ($ex) {
			print $ex->stringify();
		}
	} finally {
		# Ensure Router Kit is killed even if we have an error
		kill 9, $pid;
		# Exit with the resulting exit code
		exit($exitCode);
	};
}
