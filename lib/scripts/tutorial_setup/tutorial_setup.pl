#!/usr/bin/perl -W

#
# Perl script to perform tutorial setup
#
#
# Arguments: num_hosts -- number of hosts in setup
#            this_host -- host number of this computer
#
# Files generated:
#   cpuhw
#   iperf.sh
#
# rc.local modifications:
#   added routes
#   added ifconfig
#

use strict;
use Getopt::Long;

# Global configuration
my $cpuhwDest = "~/netfpga/projects/scone/sw/cpuhw";
my $iperfDest = "~/netfpga/projects/tutorial_router/sw/iperf.sh";
my $rclocalDest = "/etc/rc.local";

#
# Process arguments
#

my $dryRun = 0;  # Dry run doesn't actually do anything ;-)
my $help = '';

unless ( GetOptions ( "dry-run" => \$dryRun,
		      "help" => \$help,
		    )
	 and ($help eq '')
       ) { usage(); exit 1 }

# Verify the command line arguments
if ($#ARGV != 1) {
	usage();
	exit 1;
}

# Extract the number of hosts and this hosts
my $numHosts = $ARGV[0];
my $thisHost = $ARGV[1];

if ($numHosts =~ /\D/ || $numHosts < 1) {
	die "Number of hosts should be a positive integer (Value given: $numHosts)";
}

if ($thisHost =~ /\D/ || $thisHost < 1 || $thisHost > $numHosts) {
	die "This host should be a positive integer between 1 and num hosts ($numHosts) (Value given: $thisHost)";
}

# Print out the information
print "Process host $thisHost of $numHosts...\n\n";

my $now = localtime;

# Calculate the 3rd octet for the various interfaces
my $nf2c0 = 3 * $thisHost;
my $nf2c1 = 3 * $thisHost - 1;
my $nf2c2 = 3 * $thisHost - 2;
my $nf2c3 = 3 * $thisHost - 3;
if ($nf2c3 == 0) {
	$nf2c3 = 3 * $numHosts;
}

my $eth1 = 3 * $thisHost - 2;
my $eth2 = 3 * $thisHost - 4;
if ($eth2 <= 0) {
	$eth2 += 3 * $numHosts;
}

my $prevNeighbor = 3 * $thisHost - 5;
if ($prevNeighbor <= 0) {
	$prevNeighbor += 3 * $numHosts;
}

# Create the cpuhw file
createCpuhw();

# Create the iperf.sh file
createIperf();

# Update the rc.local file
updateRclocal();


##########################################################################

sub usage {
	(my $cmd = $0) =~ s/.*\///;
	print <<"HERE1";
NAME
   $cmd - Generate the setup files for a tutorial

SYNOPSIS
   $cmd [--dry-run] <num_hosts> <this_host>

   $cmd --help  - show detailed help

HERE1
}

#
# Create the CPUHW file
#
sub createCpuhw {
	my $dest = glob($cpuhwDest);

	print "Generating cpuhw file...\n\n";

	if (!$dryRun) {
		open CPUHW, ">$dest" or die "Couldn't open $dest: $!";
	}
	else {
		open CPUHW, ">&STDOUT" or die "Couldn't dup STDOUT: $!";
	}
	#print CPUHW "# CPUHW file -- generated $now\n";
	printf CPUHW "eth0 192.168.%01d.1 255.255.255.0 00:00:00:00:%02x:01\n", $nf2c0, $nf2c2;
	printf CPUHW "eth1 192.168.%01d.2 255.255.255.0 00:00:00:00:%02x:02\n", $nf2c1, $nf2c2;
	printf CPUHW "eth2 192.168.%01d.2 255.255.255.0 00:00:00:00:%02x:03\n", $nf2c2, $nf2c2;
	printf CPUHW "eth3 192.168.%01d.2 255.255.255.0 00:00:00:00:%02x:04\n", $nf2c3, $nf2c2;

	close CPUHW;

	print "\n";
}

#
# Create the iperf.sh file
#
sub createIperf {
	my $dest = glob($iperfDest);

	print "Generating iperf.sh file...\n\n";

	if (!$dryRun) {
		open IPERF, ">$dest" or die "Couldn't open $dest: $!";
	}
	else {
		open IPERF, ">&STDOUT" or die "Couldn't dup STDOUT: $!";
	}
	print IPERF "#!/bin/sh\n\n";
	print IPERF "# iperf.sh file -- generated $now\n\n";
	print IPERF "iperf -c 192.168.$nf2c1.1 -t 100000 -i 1\n";

	close IPERF;

	print "\n";
}

#
# Update rc.local
#
sub updateRclocal {
	my $dest = glob($rclocalDest);

	print "Updating rc.local...\n\n";

	my $iperf_dir = `which iperf`;
	chomp($iperf_dir);

	if (!$dryRun) {
		open RC, ">>$dest" or die "Couldn't open $dest: $!";
	}
	else {
		open RC, ">&STDOUT" or die "Couldn't dup STDOUT: $!";
	}
	print RC "\n";
	print RC "# NetFPGA tutorial modifications -- generated $now\n\n";
	print RC "# Ethernet port IP address assignment\n";
	print RC "ifconfig eth1 192.168.$eth1.1\n";
	print RC "ifconfig eth2 192.168.$eth2.1\n\n";
	print RC "# Routes\n";
	print RC "route add -net 192.168.$prevNeighbor.0 netmask 255.255.255.0 gw 192.168.$eth2.2\n";
	print RC "route add -net 192.168.0.0 netmask 255.255.0.0 gw 192.168.$nf2c2.2 dev eth1\n";
	print RC "\n";
	print RC "$iperf_dir -s & >> /var/log/iperf";

	close RC;

	print "\n";
}
