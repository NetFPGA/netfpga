#!/usr/bin/perl
# Author: David Erickson
# Date: 11/20/2007

# Objective: Ensure arp table entries get pushed to
# hardware

use NF::Base "projects/reference_router/lib/Perl5";
use Error qw(:try);
use IO::Socket;
use NF::RegressLib;
use NF::PacketLib;
use RegressRouterLib;
use reg_defines_reference_router;
use strict;

# Move to Router Kit's Directory
chdir '../../sw' or die "Can't cd: $!\n";

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
		nftest_init(\@ARGV, ["nf2c0"]);

		# format: ip-mac
		my $missing_arps =
		  nftest_contains_ARP_table_entries([
		  "10.10.0.200-01:00:00:00:00:01",
		  "10.10.1.200-02:00:00:00:00:02",
		  "10.10.2.200-03:00:00:00:00:03",
		  "10.10.3.200-04:00:00:00:00:04"]);
		if (scalar(@$missing_arps) == 0) {
			print "Success!\n";
			$exitCode = 0;
		} else {
			print "Failure:\n";
			foreach my $missing_arp (@$missing_arps) {
				print "Missing Arp entry: " . $missing_arp . "\n";
			}
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
