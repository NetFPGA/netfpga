#!/usr/bin/perl
# Author: David Erickson
# Date: 11/20/2007

# Objective: Ensure IP DST Filters get pushed to
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

		my $missing_ips = nftest_contains_dst_ip_filter_entries(["10.10.0.1", "10.10.1.1", "10.10.2.1", "10.10.3.1"]);
		if (scalar(@$missing_ips) == 0) {
			print "Success!\n";
			$exitCode = 0;
		} else {
			print "Failure:\n";
			foreach my $missing_ip (@$missing_ips) {
				print "Missing Destination IP Filter: " . $missing_ip . "\n";
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
