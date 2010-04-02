#!/usr/bin/perl -w
# vim:set shiftwidth=3 softtabstop=3 expandtab:
# $id:$

# Perl equivalent of the C regread function

use strict;
use NF::RegAccess;
use Getopt::Long;

# Parse the command line arguments
my $iface = 'nf2c0';   		# Default device
my $help = '';

unless ( GetOptions (
		      "iface|i=s" => \$iface,
		      "help|h|?" => \$help,
		     )
	 and ($help eq '') and ($#ARGV > -1)
       ) { usage(); exit 1 }

# Process each register
foreach my $reg (@ARGV) {
   my $addr = 0;

   # Work out what sort of argument this is
   if ($reg =~ /^\d+$/) {
      $addr = $reg;
   }
   elsif ($reg =~ /^0x[0-9a-fA-F]+$/) {
      $addr = hex($reg);
   }
   else {
      warn "Cannot identify register named '$reg'";
      next;
   }

   # Perform the read
   my $val = nf_regread($iface, $addr);
   printf("Reg 0x%08x (%u):   0x%08x (%u)\n", $addr, $addr, $val, $val);
}

exit (0);


#########################################################
# usage
#   print usage information
sub usage {
  (my $cmd = $0) =~ s/.*\///;
  print <<"HERE1";
NAME
   $cmd - Read registers from a NetFPGA device

SYNOPSIS
   $cmd [--iface <device>] [-i <device>] [register] [register] ...

   $cmd --help  - show detailed help

HERE1

  return unless ($help);
  print <<"HERE";

DESCRIPTION

   This script reads one or more registers and returns the value.


OPTIONS
   -i <device>
   --iface <device>
     Device to read registers from.


EXAMPLE

   To read register 0x0:

   % $cmd 0x0

HERE
}


