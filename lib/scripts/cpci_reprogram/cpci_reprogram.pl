#!/usr/bin/perl -w

#
# Script to reprogram the CPCI
# $Id: cpci_reprogram.pl 6067 2010-04-01 22:36:26Z grg $
#

use strict;
use Cwd;
use Getopt::Long;

# Location of binaries
my $bindir = '/usr/local/bin';
my $sbindir = '/usr/local/sbin';

# Location of bitfiles
my $bitfiledir = '/usr/local/netfpga/bitfiles';

# Bitfiles
my $cpci = 'cpci.bit';
my $cpci_reprogrammer = 'cpci_reprogrammer.bit';

# System binaries
my $lspci = '/sbin/lspci';
my $ifconfig = '/sbin/ifconfig';

# NetFPGA PCI device ID
my $NF2_device_id = "feed:0001";

my $output;
my $dir = getcwd;

my %config;

# Verify that we're running as root
unless ($> == 0 || $< == 0) { die "Error: $0 must be run as root" }

# Parse the command line arguments
my $all = 0;   			# Program ALL devices
my $program_device = -1; 	# select which device to program default to 0
my $help = '';
my $cpci_bitfile = "$bitfiledir/$cpci";

unless ( GetOptions ( "all" => \$all,
		      "device=i" => \$program_device,
		      "help" => \$help,
		      "bit=s" => \$cpci_bitfile,
		     )
	 and ($help eq '')
       ) { usage(); exit 1 }

# Verify that the specified bitfile is valid
$cpci_bitfile = glob($cpci_bitfile);
if (! -f "$cpci_bitfile") {
	print "Error: cannot locate CPCI bitfile '$cpci_bitfile'\n\n";
	usage();
	exit(1);
}

# Work out the devices in the system
my @device_id = get_lspci();

# Work out if the device ID is valid
if ($all && $program_device != -1) {
	print "Error: cannot specify a device ID at the same time as using the -all flag\n\n";
	usage();
	exit(1);
}

if ($program_device == -1) {
	$program_device = 0;
}

if ($program_device < 0 || $program_device > $#device_id) {
	print "Error: specified device ID ($program_device) is outside of valid range (0 .. " . ($#device_id + 1) . ")\n\n";
	usage();
	exit(1);
}

# Calculate the starting/ending IDs
my ($start_val, $end_val);

if ($all) {
	$start_val = 0;
	$end_val = $#device_id;
}
else {
	$start_val = $program_device;
	$end_val = $program_device;
}

# Bring the interfaces down
for (my $i = $start_val; $i <= $end_val; $i++) {
	for (my $k = $i * 4; $k < ($i * 4) + 4; $k++) {
		$config{"nf2c$k"} = get_config("nf2c$k");
  		`$ifconfig nf2c$k down`;
	}
}

# Reporgram the CPCI
for (my $i = $start_val; $i <= $end_val; $i++) {
	my $nf2c_base = $i*4;

	# Download the reprogrammer
	print("Loading the CPCI Reprogrammer on NetFPGA $i\n");
	$output = `$bindir/nf_download -n -i nf2c$nf2c_base $bitfiledir/$cpci_reprogrammer 2>&1`
		or die "Error downloading '$bitfiledir/$cpci_reprogrammer' to NetFPGA";

	if (!($output =~ m/successfully/i))
	{
	  print("\tDownload Failed\n");
	  exit(1);
	}

	# Dump the registers
	my $regs = `$sbindir/dumpregs.sh $device_id[$i] 2>/dev/null`
		or die "Error saving the NetFPGA PCI configuration registers";

	# Download the CPCI image
	print("Loading the CPCI on NetFPGA $i\n");

	$output = `$bindir/nf_download -n -i nf2c$nf2c_base -c $cpci_bitfile 2>&1`
		or die "Error downloading '$cpci_bitfile' to NetFPGA";

	if (!($output =~ m/Instructed CPCI reprogramming to start. Please reload PCI BARs./i))
	{
	  print("\tDownload Failed\n");
	  exit(1);
	}


	# Sleep for a while...
	`sleep 1.5`;

	# Restore the registers
	$output = `echo "$regs" | $sbindir/loadregs.sh $device_id[$i]`
		or die "Error loading the NetFPGA PCI configuration registers";

	print("CPCI on NetFPGA $i has been successfully reprogrammed\n");

}

# Bring the interfaces up
for (my $i = $start_val; $i <= $end_val; $i++) {
	for (my $k = $i * 4; $k < ($i * 4) + 4; $k++) {
		set_config("nf2c$k", $config{"nf2c$k"});
	}
}

exit (0);

#########################################################
# usage
#   print usage information
sub usage {
  (my $cmd = $0) =~ s/.*\///;
  print <<"HERE1";
NAME
   $cmd - Dowload the latest CPCI design to the CPCI

SYNOPSIS
   $cmd
        [--device <device number>]
	[--bit <CPCI bit file>]
        [--all]

   $cmd --help  - show detailed help

HERE1

  return unless ($help);
  print <<"HERE";

DESCRIPTION

   This script downloads the latest CPCI image (located in the
   directory '$bitfiledir') to the NetFPGA board. This should
   always be done on bootup to ensure the NetFPGA board is
   running the latest firmware revision.


OPTIONS
   --device <device number>
     Specify which board to program in systems with multiple boards.
     This option is zero-indexed (ie. the first board in the system is
     referenced by board 0.)

   --bit <CPCI bit file>
     Reprogram the CPCI using the specified CPCI bit file.

   --all
     Program *all* boards in a system.


EXAMPLE

   To program all boards in the system:

   % $cmd -all

HERE
}


#########################################################
# get_lspci
#   run LSPCI and return all devices
sub get_lspci {
	my @device_list;
	my $output;

	# Run lspci
	$output = `$lspci 2>&1`
		or die "Error running lspci";

	# Procoess the output
	foreach my $line (split(/\n/, $output)) {
		my @words = split(/\s+/, $line);

		# Search for the NetFPGA device ID
		if ($line =~ /.*\s$NF2_device_id$/)
		{
			push (@device_list, $words[0]);
		}
	}

	return @device_list;
}

#########################################################
# get_config
#   get the config for a given port as a compact string
sub get_config {
	my $port = $_[0];

	my $output = `$ifconfig $port`;

	my $hwaddr = "";
	my $ipv4_addr = "";
	my $ipv4_bcast = "";
	my $ipv4_mask = "";
	my $state = "down";

	# Parse the output
	foreach my $line (split('\n', $output)) {
		$hwaddr = $1 if ($line =~ /HWaddr ([0-9a-eA-E:]*)/);
		$ipv4_addr = $1 if ($line =~ /inet .*addr:\s*([0-9.]*)/);
		$ipv4_bcast = $1 if ($line =~ /inet .*Bcast:\s*([0-9.]*)/);
		$ipv4_mask = $1 if ($line =~ /inet .*Mask:\s*([0-9.]*)/);

		$state = "up" if ($line =~ /\sUP\s/);
	}

	return "$state--$hwaddr--$ipv4_addr--$ipv4_bcast--$ipv4_mask";
}

#########################################################
# set_config
#   set the config for a given port given a compact string
sub set_config {
	my ($port, $config) = @_;

	# Split the config
	my ($state, $hwaddr, $ipv4_addr, $ipv4_bcast, $ipv4_mask)
		= split('--', $config);

	# Work out the command line string
	my $cmd = "$ifconfig $port $state";

	$cmd .= " $ipv4_addr" if ($ipv4_addr ne "");
	$cmd .= " broadcast $ipv4_bcast" if ($ipv4_bcast ne "");
	$cmd .= " netmask $ipv4_mask" if ($ipv4_mask ne "");

	$cmd .= " hw ether $hwaddr" if ($hwaddr ne "");

	# Execute the command
	`$cmd`;
}
