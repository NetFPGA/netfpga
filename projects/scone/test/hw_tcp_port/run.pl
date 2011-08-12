#!/usr/bin/perl
# Author: Sara Bolouki
# Date: 11/06/2007

# Objective: Test TCP connections on ports 23/80 to the router

use Error qw(:try);
use IO::Socket;
use NF::RegressLib;
use NF::PacketLib;
use strict;

# Move to SCONE's root directory
chdir $ENV{'NF_DESIGN_DIR'}.'/sw' or die "Can't cd: $!\n";

my $pid;
# Fork off a process for SCONE
if (!($pid = fork)) {
	#
	# Run SCONE from this process
	#
	exec "./scone", "-r", "rtable.netfpga";
	die "Failed to launch SCONE: $!";
} else {
	#
	# Run control from this process
	#

	my $exitCode = 1;

	try {
		# Wait for router to initialize
		sleep(5);

		my $NF2C0_IP = '192.168.0.2';

		# Create a Telnet Socket to the router
		my $sock = new IO::Socket::INET (
			PeerAddr => '192.168.0.2',
			PeerPort => 23,
			Proto => 'tcp',
		);
		if ($sock) {
			print $sock "exit\r\n";
			print $sock "exit\r\n";
			$exitCode = 0;
			close($sock);
		} else {
			print "Failure Creating Socket to Telnet Port\n";
		}

		# Create an HTTP Socket to the router
		$sock = new IO::Socket::INET (
			PeerAddr => '192.168.0.2',
			PeerPort => 8080,
			Proto => 'tcp',
		);
		if ($sock) {
			print $sock "GET /blahblahblahblah.html HTTP/1.0\r\n\r\n";
			sleep(1);
			$exitCode = 0;
			close($sock);
		} else {
			print "Failure Creating Socket to HTTP Port\n";
		}

	} catch Error with {
		# Catch and print any errors that occurred during control processing
		my $ex = shift;
		print $ex->stringify();
	} finally {
		# Ensure SCONE is killed even if we have an error
		kill 9, $pid;
		# Exit with the resulting exit code
		if ($exitCode == 0) {
			print "Success!\n";
		}

		# Sleep 5 seconds just to allow the sockets to fully close
		sleep(5);

		exit($exitCode);
	};

}
