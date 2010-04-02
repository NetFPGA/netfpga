#!/usr/bin/perl
# Author: David Erickson
# Date: 11/20/2007

# Objective: Ensure route tables get pushed to
# hardware

use NF::Base "projects/reference_router/lib/Perl5";
use Error qw(:try);
use IO::Socket;
use NF::RegressLib;
use NF::PacketLib;
use RegressRouterLib;
use reg_defines_reference_router;
use strict;

use reg_defines_reference_router;

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

		# format: ip-mask-nexthop-outputport
		my $missing_routes =
		  nftest_contains_LPM_table_entries([
		  "10.10.0.0-255.255.255.0-0.0.0.0-0x01",
		  "10.10.1.0-255.255.255.0-0.0.0.0-0x04",
		  "10.10.2.0-255.255.255.0-0.0.0.0-0x10",
		  "10.10.3.0-255.255.255.0-0.0.0.0-0x40"]);
		if (scalar(@$missing_routes) == 0) {
			print "Success!\n";
			$exitCode = 0;
		} else {
			print "Failure:\n";
			foreach my $missing_route (@$missing_routes) {
				print "Missing Route: " . $missing_route . "\n";
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
