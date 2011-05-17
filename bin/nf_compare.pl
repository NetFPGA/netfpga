#!/usr/bin/perl -w
#/usr/pubsw/bin/perl -w

#################################################################
# $Id: nf_compare.pl 6046 2010-04-01 06:07:04Z grg $
#
# This program is used to compare expected packets with packets
# that were actually received.
#
#
#################################################################

# Need to make it use OUR version of Expat
BEGIN {
   die "Environment variable NF_ROOT must be set.\n" unless (defined $ENV{NF_ROOT} );
}

use lib "$ENV{NF_ROOT}/lib/Perl5";

use NF::PacketCmp;
use Getopt::Long;
use File::Copy;
use strict;
$|++;

#
# Process arguments
#

my $help = '';
my $dir = 'packet_data';
my $verbose = 0;
my $last_port = 0;

unless ( GetOptions (
		     "dir=s" => \$dir,
		     "verbose" => \$verbose,
		     "last_port=i" => \$last_port,
		     "help" => \$help
		    )
	 and ($help eq '')
       ) { usage(); exit 1 }

$dir =~ s|/$||;  # remove trailing /

my $fname;
my $hardware_fname = "$dir/egress_hardware";
my $error;
my $any_error = 0;

$last_port = get_last_port();


for my $port (1..$last_port) {

  # Get expected packets

  $fname = "$dir/expected_port_".$port;
  my ($exp_pkts,$rules,$num_required) = nf_parse_xml_file($port,$fname);

  # Get actual egress packets

  $fname = "$dir/egress_port_".$port;
  if (-e $fname) { # if simulation file exist

    print "\tComparing simulation output for port $port ...\n";
    $verbose && print "\tParsing XML file $fname ... \n";
    my ($egress_pkts,$tmp) = nf_parse_xml_file($port,$fname);
    $verbose && print "\tInfo: port $port: Saw ",scalar(@{$exp_pkts}),
      " expected pkts and ",scalar(@{$egress_pkts})," actual egress packets.\n";

    # check_packets returns number of errors.
    $error = check_packets ($port, $exp_pkts, $egress_pkts, $num_required, $rules);

    if ($error) { print "\tPort $port saw $error errors.\n\n" }
    else { print "\tPort $port matches [",scalar(@{$egress_pkts})," packets]\n"
    }

    $any_error += $error;
  }
  else {
    $verbose && print "\tNo simulation files to compare\n";
  }

} # iterate over ports


# Verify DMA data
# Get expected packets

$last_port = get_last_dma_port();

for my $port (1..$last_port) {

  $fname = "$dir/expected_dma_".$port;
  my ($exp_pkts,$rules,$num_required) = nf_parse_xml_file("dma",$fname);

  # Get actual egress packets

  $fname = "$dir/egress_dma_".$port;
  if (-e $fname) { # if simulation file exist

    print "\tComparing simulation output for DMA queue $port ...\n";
    $verbose && print "\tParsing XML file $fname ... \n";
    my ($egress_pkts,$tmp) = nf_parse_xml_file("dma",$fname);
    $verbose && print "\tInfo: DMA queue $port: Saw ",scalar(@{$exp_pkts}),
      " expected pkts and ",scalar(@{$egress_pkts})," actual egress packets.\n";

    # check_packets returns number of errors.
    $error = check_packets ("dma", $exp_pkts, $egress_pkts, $num_required, $rules);

    if ($error) { print "\tDMA queue $port saw $error errors.\n\n" }
    else { print "\tDMA queue $port matches [",scalar(@{$egress_pkts})," packets]\n"
    }

    $any_error += $error;
  }
  else {
    $verbose && print "\tNo DMA simulation files to compare\n";
  }

} # iterate over dma queues


my $hardware_pkts;

# if output hardware file exist
if (-e $hardware_fname) {

  print "\tFound hardware egress file - comparing hardware output...\n";
  $hardware_pkts = nf_read_hardware_file($hardware_fname, "LITTLE_ENDIAN");

  # for each port's packets
  for my $port (0..$last_port) {

    # Get expected packets
    $fname = "$dir/expected_port_".$port;
    my ($exp_pkts, $rules, $num_required) = nf_parse_xml_file($port, $fname);

    # check_packets returns number of errors
    $error = check_packets ($port, $exp_pkts, \@{${$hardware_pkts}[$port]}, $num_required, $rules);
    if ($error) {
      print "\tPort $port saw $error errors.\n\n"
    }
    else {
      print "\tPort $port matches [",scalar(@{${$hardware_pkts}[$port]})," packets]\n"
    }

  }

}
else {
  $verbose && print "\tNo hardware file to compare\n";
}

exit $any_error;

#################################################################
# Pretty print packet info
#################################################################
sub show_pkts {

  my $pkts = shift;

  for my $pkt (@$pkts) {
    print "Length stated: $pkt->{'length'} actual:",scalar(@{$pkt->{'data'}})."\n";
    print "Rules : @{$pkt->{'rules'}}\n";
    print "Time (delay) : $pkt->{'delay'}\n";
    print "Port : $pkt->{'port'}\n";
    print "Data : @{$pkt->{'data'}}\n";
  }
}

#################################################################
# Print Usage
#################################################################
sub usage {
  (my $cmd = $0) =~ s/.*\///;
  print <<"HERE1";
NAME
   $cmd - compare expected packets with actual received packets.

SYNOPSIS
   $cmd [--dir <directory>] [--verbose]

   $cmd --help  - show detailed help

HERE1

  return unless ($help);
  print <<"HERE";

DESCRIPTION

   This script will compare packets that were expected to be received against
   packets that were actually received (either from a simultion or from the
   actual NetFPGA hardware).

   You generally want to run it in the directory that contains the packet_data
   directory (not within packet_data itself)

OPTIONS

   --dir <directory>
     Specify the directory where the various files are located.
     Default is ./packet_data/

   --verbose

   --last_port <port#>  Specify this if you need to change the default
     number of ports (which is 1). Ports are numbered from 0, so if you
     have 4 ports then specify 3: --last_port 3

EXAMPLE

   % $cmd

   will compare files in the local packet_data directory.

HERE
}

#################################################################
# Compare two lists of packets
#
# Params: Port   [0..$last_port]
#         reference to first list of packets
#         reference to second list of packets
#         reference to list of rules
#
# Returns: number of errors
#
#
#################################################################
sub check_packets {

  my $port = shift;
  my $exp_pkts = shift;
  my $egress_pkts = shift;
  my $egress_required = shift;
  my $rules = shift;

  my $strict_ordering = 0;#1; # flag for strict packet ordering (default is on)

  #if ($#$exp_pkts != $#$egress_pkts) {
  if ($#$egress_pkts < ($egress_required - 1) || $#$egress_pkts > $#$exp_pkts) {
    print "\tERROR: Number of packets mismatch: expected ".($#$exp_pkts+1).
      " but saw ".($#$egress_pkts+1)."\n";
    return 1;
  }

  if ($#$exp_pkts == -1) { return 0 }   # no packets

  for (@{$rules}) {
    if ($_ eq 'UNORDERED') { $strict_ordering = 0 }
  }

  if ($strict_ordering) {
    return check_packets_strict_ordering ($port, $exp_pkts, $egress_pkts, $rules);
  }

  return check_packets_loose_ordering ($port, $exp_pkts, $egress_pkts, $rules);
}

#################################################################
# Compare two lists of packets that should match up in exact order.
#
# Params: Port   [0..$last_port]
#         reference to first list of packets
#         reference to second list of packets
#         reference to list of rules
#
# Returns: number of errors
#
#
#################################################################
sub check_packets_strict_ordering {
  my $port = shift;
  my $exp_pkts = shift;
  my $egress_pkts = shift;
  my $rules = shift;
  my ($error, $pkt_i, $p1, $p2, $res);

  $error = 0;

  for ($pkt_i = 0; $pkt_i <= $#$exp_pkts; $pkt_i++) {

    $p1 = $exp_pkts->[$pkt_i];
    $p2 = $egress_pkts->[$pkt_i];
    if ($res = compare_2_pkts($p1,$p2,$rules)) {
      $error++;
      print "\tERROR: Packet ",($pkt_i+1)," (starting from 1) $res\n";
    }
  }

  return $error

} # check_packets_strict_ordering

#################################################################
# Compare two lists of packets that should match up but the
# ordering of the packets may be different.
#
# Params: Port   [0..$last_port]
#         reference to first list of packets
#         reference to second list of packets
#         reference to list of rules
#
# Returns: number of errors
#
#################################################################
sub check_packets_loose_ordering {
  my $port = shift;
  my $exp_pkts = shift;
  my $egress_pkts = shift;
  my $rules = shift;
  my ($error, $pkt_i, $p1, $p2, $res, $exp_i, $optMatch);

  $error = 0;

  my @exp_matched = ();

  # mark each egress packet as not matched
  for ($pkt_i = 0; $pkt_i <= $#$exp_pkts; $pkt_i++) {
    $exp_matched[$pkt_i] = 0;
  }

  # now go through each exp_pkt and try to match it with an egress pkt.

  for ($pkt_i = 0; $pkt_i <= $#$egress_pkts; $pkt_i++) {

    $p1 = $egress_pkts->[$pkt_i];
    $exp_i = 0;

    $optMatch = -1;
    do {
      $res = 1;
      unless ( $exp_matched[$exp_i]) {
	$p2 = $exp_pkts->[$exp_i];
	$res = compare_2_pkts($p2,$p1,$rules);  # res is non-zero on mismatch
	if (defined($exp_pkts->[$exp_i]->{'optional'}) &&
	    $exp_pkts->[$exp_i]{'optional'} != 0) {
	  $optMatch = $exp_i;
        }
      }
      $exp_i++;
    } while (($exp_i <= $#$exp_pkts) && $res);

    # Check if we found an optional packet to match with
    if ($res && $optMatch != -1) {
      $res = 0;
      $exp_i = $optMatch;
    }

    if ($res) {  # no matches!
      $error++;
      print "\tError: Port $port packet ",($pkt_i+1)," : not Matched.\n";
    }
    else {
      $verbose && print "\tPort $port matched egress pkt ",($pkt_i+1)," to exp pkt $exp_i.\n";
      $exp_matched[--$exp_i] = $pkt_i+1;
    }
  }

  return $error

} # check_packets_loose_ordering

#################################################################
# Find out how many 'expected_port_N' files there should be.
# There must be a expected_port_1 file, and in that there should be a
# line such as:
#  <!-- PHYS_PORTS = 1 MAX_PORTS = 4 -->
#
# The PHYS_PORTS value tells us how many fiels there should be.
#
# Returns: number of last file.
#
#################################################################

sub get_last_port {

  my $f = "$dir/expected_port_1";

  unless ( -r $f ) {
    die "Cannot compare files unless there is file $f.\n";
  }

  open F,"<$f" or die "Unable to open $f";

  while (<F>) {
    if (/<!-- PHYS_PORTS = (\d+) MAX_PORTS = 4 -->/) {
      close F;
      return $1;
    }
  }
  close F;

  die "Did not see definition of PHYS_PORTS in $f";
}

#################################################################
# Find out how many 'expected_dma_N' files there should be.
# There must be a expected_dma_1 file, and in that there should be a
# line such as:
#  <!-- DMA_QUEUES = 4 -->
#
# The DMA_QUEUES value tells us how many fiels there should be.
#
# Returns: number of last file.
#
#################################################################

sub get_last_dma_port {

  my $f = "$dir/expected_dma_1";

  unless ( -r $f ) {
    die "Cannot compare files unless there is file $f.\n";
  }

  open F,"<$f" or die "Unable to open $f";

  while (<F>) {
    if (/<!-- DMA_QUEUES = (\d+) -->/) {
      close F;
      return $1;
    }
  }
  close F;

  die "Did not see definition of DMA_QUEUES in $f";
}

